import Foundation

/// Wire format for bundled seed and interchange: `[{ "front": "…", "back": "…" }]`.
struct SimpleFlashcardDTO: Decodable {
    let front: String
    let back: String
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
