import Foundation

enum CardNoteDisplay {
    static func frontPlainText(for note: CardNote) -> String {
        if let front = note.facets[CardFacetKey.front]?.first {
            return front
        }

        switch note.cardType {
        case .languageV1:
            return note.facets[CardFacetKey.term]?.first ?? ""
        case .lawDefinitionV1:
            return note.facets[CardFacetKey.term]?.first ?? ""
        case .genericV1:
            return note.facets[CardFacetKey.front]?.first ?? note.facets[CardFacetKey.term]?.first ?? ""
        }
    }

    static func backPlainText(for note: CardNote) -> String {
        if let lines = note.facets[CardFacetKey.back], !lines.isEmpty {
            return lines.joined(separator: "\n")
        }

        switch note.cardType {
        case .languageV1:
            let lines = note.facets[CardFacetKey.gloss("en")] ?? []
            if lines.isEmpty {
                return note.facets[CardFacetKey.gloss("de")]?.first ?? "–"
            }
            return lines.joined(separator: "\n")
        case .lawDefinitionV1:
            return note.facets[CardFacetKey.definition]?.joined(separator: "\n") ?? "–"
        case .genericV1:
            return note.facets[CardFacetKey.back]?.joined(separator: "\n") ?? "–"
        }
    }

    static func englishGlosses(for note: CardNote) -> [String] {
        note.facets[CardFacetKey.gloss("en")] ?? []
    }

    static func definitionLines(for note: CardNote) -> [String] {
        note.facets[CardFacetKey.definition] ?? []
    }

    static func genericBackLines(for note: CardNote) -> [String] {
        note.facets[CardFacetKey.back] ?? []
    }

    static func backLines(for note: CardNote) -> [String] {
        if let lines = note.facets[CardFacetKey.back], !lines.isEmpty {
            return lines
        }

        switch note.cardType {
        case .genericV1:
            return genericBackLines(for: note)
        case .languageV1:
            return englishGlosses(for: note)
        case .lawDefinitionV1:
            return definitionLines(for: note)
        }
    }
}
