import Foundation

/// Wire format for bundled seed and interchange:
/// `[{ "front": "…", "back": "…", "keywords": ["food", "daily-life"] }]`.
struct SimpleFlashcardDTO: Decodable {
    let front: String
    let back: String
    let keywords: [String]?
}

struct KeywordCatalogDocument: Decodable {
    var schemaVersion: Int
    var keywords: [KeywordDefinition]
}

struct KeywordDefinition: Decodable, Identifiable, Hashable {
    var id: String
    var label: String
}

/// On-disk user library envelope.
struct UserCardLibraryDocument: Codable {
    var librarySchemaVersion: Int
    var notes: [CardNote]

    static let currentLibrarySchemaVersion = 1

    init(notes: [CardNote]) {
        librarySchemaVersion = Self.currentLibrarySchemaVersion
        self.notes = notes
    }
}
