import Foundation

// MARK: - Card taxonomy (stable raw values for imports & sync)

enum CardTypeID: String, Codable, Hashable, CaseIterable {
    case languageV1 = "language.v1"
    case lawDefinitionV1 = "law.definition.v1"
    case genericV1 = "generic.v1"
}

enum CardFacetKey {
    nonisolated static let term = "term"
    nonisolated static let lemma = "lemma"
    nonisolated static let pos = "pos"
    nonisolated static let definition = "definition"
    nonisolated static let front = "front"
    nonisolated static let back = "back"
    nonisolated static let keywords = "keywords"

    nonisolated static func gloss(_ languageCode: String) -> String {
        "gloss.\(languageCode)"
    }
}

// MARK: - SRS

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
        case .once: return "okay"
        case .solid: return "solid"
        case .good: return "good"
        case .know: return "known"
        }
    }
}

struct CardProgress: Codable, Hashable {
    var stack: LearningStack
    var correctStreak: Int
    var lastSeenAt: Date?

    static let initial = CardProgress(stack: .new, correctStreak: 0, lastSeenAt: nil)
}

struct CardFacetOverride: Codable, Hashable {
    var facets: [String: [String]]
}

struct CardExample: Identifiable, Codable, Hashable {
    var id: String
    var texts: [String: String]

    init(id: String = UUID().uuidString, texts: [String: String]) {
        self.id = id
        self.texts = texts
    }
}

struct CardProvenance: Codable, Hashable {
    var sourceDatasetId: String?
    var sourceRecordId: String?
    var importedAt: Date?
}

struct CardNote: Identifiable, Hashable {
    nonisolated static let contentSchemaVersion: Int = 1

    let id: String
    var contentSchemaVersion: Int
    var cardType: CardTypeID
    var deckId: String?
    var facets: [String: [String]]
    var examples: [CardExample]
    var provenance: CardProvenance?

    nonisolated init(
        id: String,
        contentSchemaVersion: Int = CardNote.contentSchemaVersion,
        cardType: CardTypeID,
        deckId: String? = nil,
        facets: [String: [String]],
        examples: [CardExample] = [],
        provenance: CardProvenance? = nil
    ) {
        self.id = id
        self.contentSchemaVersion = contentSchemaVersion
        self.cardType = cardType
        self.deckId = deckId
        self.facets = facets
        self.examples = examples
        self.provenance = provenance
    }

    func replacingFacets(_ patch: [String: [String]]) -> CardNote {
        var next = facets
        for (key, value) in patch {
            next[key] = value
        }
        return CardNote(
            id: id,
            contentSchemaVersion: contentSchemaVersion,
            cardType: cardType,
            deckId: deckId,
            facets: next,
            examples: examples,
            provenance: provenance
        )
    }

    func applying(_ override: CardFacetOverride?) -> CardNote {
        guard let override, !override.facets.isEmpty else { return self }
        return replacingFacets(override.facets)
    }

    func withID(_ newId: String) -> CardNote {
        CardNote(
            id: newId,
            contentSchemaVersion: contentSchemaVersion,
            cardType: cardType,
            deckId: deckId,
            facets: facets,
            examples: examples,
            provenance: provenance
        )
    }
}

extension CardNote: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, contentSchemaVersion, cardType, deckId, facets, examples, provenance
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        contentSchemaVersion = try c.decodeIfPresent(Int.self, forKey: .contentSchemaVersion) ?? Self.contentSchemaVersion
        let rawType = try c.decodeIfPresent(String.self, forKey: .cardType) ?? CardTypeID.genericV1.rawValue
        cardType = CardTypeID(rawValue: rawType) ?? .genericV1
        deckId = try c.decodeIfPresent(String.self, forKey: .deckId)
        facets = try c.decodeIfPresent([String: [String]].self, forKey: .facets) ?? [:]
        examples = try c.decodeIfPresent([CardExample].self, forKey: .examples) ?? []
        provenance = try c.decodeIfPresent(CardProvenance.self, forKey: .provenance)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(contentSchemaVersion, forKey: .contentSchemaVersion)
        try c.encode(cardType.rawValue, forKey: .cardType)
        try c.encodeIfPresent(deckId, forKey: .deckId)
        try c.encode(facets, forKey: .facets)
        try c.encode(examples, forKey: .examples)
        try c.encodeIfPresent(provenance, forKey: .provenance)
    }
}
