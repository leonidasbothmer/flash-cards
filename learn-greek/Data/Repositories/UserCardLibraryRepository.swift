import Foundation

final class UserCardLibraryRepository {
    private let file: AppJSONFile

    init(fileName: String = "user-card-library.v1.json", appFolderURL: URL? = nil) {
        file = AppJSONFile(fileName: fileName, appFolderURL: appFolderURL, usesISO8601Dates: true)
    }

    func load() -> [CardNote] {
        guard let data = file.loadData() else { return [] }

        if let doc = try? file.decoder.decode(UserCardLibraryDocument.self, from: data) {
            return doc.notes
        }

        return (try? file.decoder.decode([CardNote].self, from: data)) ?? []
    }

    func save(_ notes: [CardNote]) {
        file.save(UserCardLibraryDocument(notes: notes))
    }
}
