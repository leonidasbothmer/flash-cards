import Combine
import Foundation

struct StackTransferEvent: Equatable {
    let from: LearningStack
    let to: LearningStack
    let token: Int
}

@MainActor
final class ReviewSessionViewModel: ObservableObject {
    @Published private(set) var items: [VocabItem] = []
    @Published private(set) var progressByID: [String: VocabProgress] = [:]
    @Published var currentCard: VocabCardState?
    @Published private(set) var cardPresentationID: Int = 0
    @Published private(set) var lastStackTransfer: StackTransferEvent?

    private let repository = ProgressRepository()
    private let overrideRepository = VocabOverrideRepository()
    private let customVocabRepository = CustomVocabRepository()
    private let deletedVocabRepository = DeletedVocabRepository()
    private var overridesByID: [String: VocabOverride] = [:]
    private var customItems: [VocabItem] = []
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

    private func load() {
        progressByID = repository.load()
        overridesByID = overrideRepository.load()
        deletedIDs = deletedVocabRepository.load()

        do {
            let bundled = try VocabDataStore.loadBundledVocab()
            customItems = customVocabRepository.load()
            items = (bundled + customItems).filter { !deletedIDs.contains($0.id) }
            ensureUniqueIDs()
            applyOverrides()
            moveToNextCard()
        } catch {
            items = []
            currentCard = nil
            print("Failed to load vocab: \(error.localizedDescription)")
        }
    }

    private func ensureUniqueIDs() {
        var seen: [String: Int] = [:]
        items = items.map { item in
            let count = seen[item.id, default: 0]
            seen[item.id] = count + 1
            guard count > 0 else { return item }
            return VocabItem(
                id: "\(item.id)#\(count)",
                greek: item.greek,
                lemma: item.lemma,
                partOfSpeech: item.partOfSpeech,
                translations: item.translations
            )
        }
    }

    func updateCurrentCard(greek: String, english: [String], german: [String]) {
        guard let card = currentCard,
              let index = items.firstIndex(where: { $0.id == card.id })
        else { return }

        let override = VocabOverride(
            greek: greek,
            english: english,
            german: german
        )

        overridesByID[card.id] = override
        overrideRepository.save(overridesByID)

        let updatedItem = items[index].applying(override)
        items[index] = updatedItem

        if currentCard?.id == updatedItem.id {
            currentCard = VocabCardState(
                item: updatedItem,
                progress: progressByID[updatedItem.id] ?? .initial
            )
        }
    }

    func addNewCard(greek: String, english: [String], german: [String]) {
        let newItem = VocabItem(
            id: "custom.\(UUID().uuidString)",
            greek: greek,
            lemma: nil,
            partOfSpeech: nil,
            translations: [
                "en": english,
                "de": german
            ]
        )

        customItems.append(newItem)
        customVocabRepository.save(customItems)
        items.append(newItem)
        progressByID[newItem.id] = .initial
        repository.save(progressByID)
        currentCard = VocabCardState(item: newItem, progress: .initial)
        cardPresentationID &+= 1
    }

    func deleteCurrentCard() {
        guard let card = currentCard else { return }

        deletedIDs.insert(card.id)
        deletedVocabRepository.save(deletedIDs)

        customItems.removeAll { $0.id == card.id }
        customVocabRepository.save(customItems)

        items.removeAll { $0.id == card.id }
        progressByID.removeValue(forKey: card.id)
        overridesByID.removeValue(forKey: card.id)
        repository.save(progressByID)
        overrideRepository.save(overridesByID)

        moveToNextCard()
    }

    private func apply(result: ReviewResult) {
        guard let card = currentCard else { return }
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

    private func moveToNextCard() {
        currentCard = ReviewEngine.pickNextItem(items: items, progressByID: progressByID)
        cardPresentationID &+= 1
    }

    private func applyOverrides() {
        items = items.map { item in
            item.applying(overridesByID[item.id])
        }
    }
}
