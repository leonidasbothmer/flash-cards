import Foundation

enum ReviewResult {
    case correct
    case wrong
}

struct StackWeight {
    let stack: LearningStack
    let weight: Double
}

enum ReviewEngine {
    static let weightedStacks: [StackWeight] = [
        .init(stack: .new, weight: 10),
        .init(stack: .seen, weight: 40),
        .init(stack: .once, weight: 20),
        .init(stack: .solid, weight: 10),
        .init(stack: .good, weight: 7),
        .init(stack: .know, weight: 3)
    ]

    static func pickNextItem(
        items: [CardNote],
        progressByID: [String: CardProgress]
    ) -> ReviewCardState? {
        let buckets = bucketsByStack(items: items, progressByID: progressByID)

        let activeWeights = weightedStacks.compactMap { entry -> StackWeight? in
            guard let bucket = buckets[entry.stack], !bucket.isEmpty else { return nil }
            return entry
        }

        guard let chosenStack = weightedChoice(activeWeights)?.stack else { return nil }
        return pickItem(from: chosenStack, items: items, progressByID: progressByID)
    }

    static func pickItem(
        from stack: LearningStack,
        items: [CardNote],
        progressByID: [String: CardProgress],
        excluding excludedID: String? = nil
    ) -> ReviewCardState? {
        let candidates = items.filter { note in
            let progress = progressByID[note.id] ?? .initial
            return progress.stack == stack && note.id != excludedID
        }

        let fallbackCandidates = items.filter { note in
            (progressByID[note.id] ?? .initial).stack == stack
        }

        guard let note = (candidates.isEmpty ? fallbackCandidates : candidates).randomElement() else { return nil }
        return ReviewCardState(note: note, progress: progressByID[note.id] ?? .initial)
    }

    static func apply(
        result: ReviewResult,
        to progress: CardProgress
    ) -> CardProgress {
        var next = progress
        next.lastSeenAt = Date()

        if progress.stack == .new {
            if result == .correct {
                next.stack = .seen
                next.correctStreak = 1
            } else {
                next.stack = .new
                next.correctStreak = 0
            }
            return next
        }

        switch result {
        case .correct:
            next.correctStreak += 1
            if next.correctStreak >= 2 {
                next.stack = promote(progress.stack)
                next.correctStreak = 0
            }
        case .wrong:
            next.stack = demote(progress.stack)
            next.correctStreak = 0
        }

        return next
    }

    static func countsByStack(
        items: [CardNote],
        progressByID: [String: CardProgress]
    ) -> [LearningStack: Int] {
        var counts = Dictionary(uniqueKeysWithValues: LearningStack.allCases.map { ($0, 0) })
        for note in items {
            let stack = (progressByID[note.id] ?? .initial).stack
            counts[stack, default: 0] += 1
        }
        return counts
    }

    private static func bucketsByStack(
        items: [CardNote],
        progressByID: [String: CardProgress]
    ) -> [LearningStack: [CardNote]] {
        var buckets: [LearningStack: [CardNote]] = [:]
        for note in items {
            let progress = progressByID[note.id] ?? .initial
            buckets[progress.stack, default: []].append(note)
        }
        return buckets
    }

    private static func weightedChoice(_ entries: [StackWeight]) -> StackWeight? {
        guard !entries.isEmpty else { return nil }
        let total = entries.reduce(0) { $0 + $1.weight }
        let ticket = Double.random(in: 0..<total)
        var cumulative = 0.0

        for entry in entries {
            cumulative += entry.weight
            if ticket < cumulative {
                return entry
            }
        }
        return entries.last
    }

    private static func promote(_ stack: LearningStack) -> LearningStack {
        LearningStack(rawValue: min(stack.rawValue + 1, LearningStack.know.rawValue)) ?? .know
    }

    private static func demote(_ stack: LearningStack) -> LearningStack {
        LearningStack(rawValue: max(stack.rawValue - 1, LearningStack.seen.rawValue)) ?? .seen
    }
}
