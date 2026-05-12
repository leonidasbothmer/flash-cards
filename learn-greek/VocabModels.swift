import Foundation

enum LearningStack: Int, CaseIterable, Codable, Hashable {
    case new = 0
    case seen = 1
    case once = 2
    case solid = 3
    case good = 4
    case know = 5

    var title: String {
        switch self {
        case .new: return "new"
        case .seen: return "seen"
        case .once: return "once"
        case .solid: return "solid"
        case .good: return "good"
        case .know: return "know"
        }
    }
}

struct VocabItem: Identifiable, Codable, Hashable {
    let id: String
    let greek: String
    let lemma: String?
    let partOfSpeech: String?
    let translations: [String: [String]]

    var english: [String] { translations["en"] ?? [] }
    var german: [String] { translations["de"] ?? [] }

    func applying(_ override: VocabOverride?) -> VocabItem {
        guard let override else { return self }

        var updatedTranslations = translations
        updatedTranslations["en"] = override.english
        updatedTranslations["de"] = override.german

        return VocabItem(
            id: id,
            greek: override.greek,
            lemma: lemma,
            partOfSpeech: partOfSpeech,
            translations: updatedTranslations
        )
    }
}

struct VocabOverride: Codable, Hashable {
    var greek: String
    var english: [String]
    var german: [String]
}

struct VocabProgress: Codable, Hashable {
    var stack: LearningStack
    var correctStreak: Int
    var lastSeenAt: Date?

    static let initial = VocabProgress(stack: .new, correctStreak: 0, lastSeenAt: nil)
}

struct VocabCardState: Identifiable, Hashable {
    let item: VocabItem
    let progress: VocabProgress

    var id: String { item.id }
}
