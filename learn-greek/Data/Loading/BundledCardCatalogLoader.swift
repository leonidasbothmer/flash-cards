import Foundation

enum BundledCardCatalogLoader {
    static let seedResourceName = "flashcards_seed"
    static let keywordsResourceName = "keywords"
    static let seedResourceSubdirectory = "Bundled"

    static func loadBundledCatalog(
        named fileName: String = seedResourceName,
        subdirectory: String = seedResourceSubdirectory
    ) throws -> [CardNote] {
        let resourceURL = Bundle.main.url(
            forResource: fileName,
            withExtension: "json",
            subdirectory: subdirectory
        ) ?? Bundle.main.url(
            forResource: fileName,
            withExtension: "json"
        )

        guard let url = resourceURL else {
            throw NSError(
                domain: "BundledCardCatalogLoader",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing bundled file: \(subdirectory)/\(fileName).json"]
            )
        }
        return try loadCatalog(from: url)
    }

    static func loadKeywordCatalog(
        named fileName: String = keywordsResourceName,
        subdirectory: String = seedResourceSubdirectory
    ) throws -> [KeywordDefinition] {
        let resourceURL = Bundle.main.url(
            forResource: fileName,
            withExtension: "json",
            subdirectory: subdirectory
        ) ?? Bundle.main.url(
            forResource: fileName,
            withExtension: "json"
        )

        guard let url = resourceURL else {
            throw NSError(
                domain: "BundledCardCatalogLoader",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Missing bundled file: \(subdirectory)/\(fileName).json"]
            )
        }
        let data = try Data(contentsOf: url)
        let document = try JSONDecoder().decode(KeywordCatalogDocument.self, from: data)
        return document.keywords
    }

    static func loadCatalog(from url: URL) throws -> [CardNote] {
        let data = try Data(contentsOf: url)
        let cards = try JSONDecoder().decode([SimpleFlashcardDTO].self, from: data)
        return cards.enumerated().compactMap { index, card in
            CardNote.fromSimpleFlashcard(card, id: "seed.\(index + 1)")
        }
    }
}

extension CardNote {
    static func fromSimpleFlashcard(_ dto: SimpleFlashcardDTO, id: String) -> CardNote? {
        let front = dto.front.trimmingCharacters(in: .whitespacesAndNewlines)
        let back = dto.back.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !front.isEmpty, !back.isEmpty else { return nil }
        var facets: [String: [String]] = [
            CardFacetKey.front: [front],
            CardFacetKey.back: [back]
        ]
        if let keywords = dto.keywords?
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .filter({ !$0.isEmpty }),
           !keywords.isEmpty {
            facets[CardFacetKey.keywords] = keywords
        }
        return CardNote(
            id: id,
            cardType: .genericV1,
            facets: facets
        )
    }
}
