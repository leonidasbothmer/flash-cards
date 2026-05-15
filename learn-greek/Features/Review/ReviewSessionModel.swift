import Combine
import Foundation

struct StackTransferEvent: Equatable {
    let from: LearningStack
    let to: LearningStack
    let token: Int
}

@MainActor
final class ReviewSessionModel: ObservableObject {
    @Published private(set) var items: [CardNote] = []
    @Published private(set) var progressByID: [String: CardProgress] = [:]
    @Published var currentCard: ReviewCardState?
    @Published private(set) var cardPresentationID: Int = 0
    @Published private(set) var lastStackTransfer: StackTransferEvent?
    @Published private(set) var correctSwipeStreak: Int = 0
    @Published private(set) var streakBreakEvent: StreakBreakEvent?

    private let repository = ProgressRepository()
    private let overrideRepository = CardOverrideRepository()
    private let userLibrary = UserCardLibraryRepository()
    private let deletedCardRepository = DeletedCardRepository()
    private var overridesByID: [String: CardFacetOverride] = [:]
    private var userNotes: [CardNote] = []
    private var deletedIDs: Set<String> = []
    private var stackTransferToken: Int = 0

    var countsByStack: [LearningStack: Int] {
        ReviewEngine.countsByStack(items: items, progressByID: progressByID)
    }

    init() {
        load()
    }

    func markCorrect() {
        apply(result: .correct)
    }

    func markWrong() {
        apply(result: .wrong)
    }

    func selectCard(from stack: LearningStack) {
        guard let nextCard = ReviewEngine.pickItem(
            from: stack,
            items: items,
            progressByID: progressByID,
            excluding: currentCard?.id
        ) else { return }

        currentCard = nextCard
        cardPresentationID &+= 1
    }

    func moveCurrentCard(to stack: LearningStack) {
        guard let card = currentCard else { return }

        let currentProgress = progressByID[card.id] ?? .initial
        var updated = currentProgress
        updated.stack = stack
        updated.correctStreak = 0
        updated.lastSeenAt = Date()
        progressByID[card.id] = updated

        if currentProgress.stack != stack {
            stackTransferToken &+= 1
            lastStackTransfer = StackTransferEvent(
                from: currentProgress.stack,
                to: stack,
                token: stackTransferToken
            )
        }

        repository.save(progressByID)
        moveToNextCard()
    }

    private func load() {
        progressByID = repository.load()
        overridesByID = overrideRepository.load()
        deletedIDs = deletedCardRepository.load()

        do {
            let bundled = try BundledCardCatalogLoader.loadBundledCatalog()
            userNotes = userLibrary.load()
            items = (bundled + userNotes).filter { !deletedIDs.contains($0.id) }
            ensureUniqueIDs()
            applyOverrides()
            moveToNextCard()
        } catch {
            items = []
            currentCard = nil
            print("Failed to load card catalog: \(error.localizedDescription)")
        }
    }

    private func ensureUniqueIDs() {
        var seen: [String: Int] = [:]
        items = items.map { note in
            let count = seen[note.id, default: 0]
            seen[note.id] = count + 1
            guard count > 0 else { return note }
            return note.withID("\(note.id)#\(count)")
        }
    }

    /// Merges a facet patch into the library for the given note id (user notes persist full merge; bundled notes use `CardFacetOverride`).
    func mergeFacetPatch(_ patch: [String: [String]], forNoteId id: String) {
        guard let card = currentCard, card.id == id,
              let index = items.firstIndex(where: { $0.id == id })
        else { return }

        if userNotes.contains(where: { $0.id == id }) {
            if let ui = userNotes.firstIndex(where: { $0.id == id }) {
                userNotes[ui] = userNotes[ui].replacingFacets(patch)
            }
            userLibrary.save(userNotes)
            overridesByID.removeValue(forKey: id)
            overrideRepository.save(overridesByID)
        } else {
            overridesByID[id] = CardFacetOverride(facets: patch)
            overrideRepository.save(overridesByID)
        }

        let updatedNote = items[index].replacingFacets(patch)
        items[index] = updatedNote

        if currentCard?.id == updatedNote.id {
            currentCard = ReviewCardState(
                note: updatedNote,
                progress: progressByID[updatedNote.id] ?? .initial
            )
        }
    }

    func addNote(_ note: CardNote) {
        userNotes.append(note)
        userLibrary.save(userNotes)
        items.append(note)
        progressByID[note.id] = .initial
        repository.save(progressByID)
        currentCard = ReviewCardState(note: note, progress: .initial)
        cardPresentationID &+= 1
    }

    func addNewCard(front: String, back: [String]) {
        let newNote = CardNote(
            id: "custom.\(UUID().uuidString)",
            cardType: .genericV1,
            facets: [
                CardFacetKey.front: [front],
                CardFacetKey.back: back
            ]
        )
        addNote(newNote)
    }

    func deleteCurrentCard() {
        guard let card = currentCard else { return }

        deletedIDs.insert(card.id)
        deletedCardRepository.save(deletedIDs)

        userNotes.removeAll { $0.id == card.id }
        userLibrary.save(userNotes)

        items.removeAll { $0.id == card.id }
        progressByID.removeValue(forKey: card.id)
        overridesByID.removeValue(forKey: card.id)
        repository.save(progressByID)
        overrideRepository.save(overridesByID)

        moveToNextCard()
    }

    private func apply(result: ReviewResult) {
        guard let card = currentCard else { return }
        updateCorrectSwipeStreak(for: result)

        let currentProgress = progressByID[card.id] ?? .initial
        let updated = ReviewEngine.apply(result: result, to: currentProgress)
        progressByID[card.id] = updated
        if updated.stack != currentProgress.stack {
            stackTransferToken &+= 1
            lastStackTransfer = StackTransferEvent(
                from: currentProgress.stack,
                to: updated.stack,
                token: stackTransferToken
            )
        }
        repository.save(progressByID)
        moveToNextCard()
    }

    private func updateCorrectSwipeStreak(for result: ReviewResult) {
        switch result {
        case .correct:
            correctSwipeStreak += 1
        case .wrong:
            if correctSwipeStreak > 0 {
                streakBreakEvent = StreakBreakEvent(previousStreak: correctSwipeStreak)
            }
            correctSwipeStreak = 0
        }
    }

    private func moveToNextCard() {
        currentCard = ReviewEngine.pickNextItem(items: items, progressByID: progressByID)
        cardPresentationID &+= 1
    }

    private func applyOverrides() {
        items = items.map { note in
            note.applying(overridesByID[note.id])
        }
    }
}

struct StreakBreakEvent: Equatable {
    let previousStreak: Int
    let token: UUID

    init(previousStreak: Int, token: UUID = UUID()) {
        self.previousStreak = previousStreak
        self.token = token
    }
}
