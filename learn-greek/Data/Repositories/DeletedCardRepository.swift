import Foundation

final class DeletedCardRepository {
    private let file: AppJSONFile

    init(fileName: String = "deleted-cards.v1.json", appFolderURL: URL? = nil) {
        file = AppJSONFile(fileName: fileName, appFolderURL: appFolderURL)
    }

    func load() -> Set<String> {
        file.load(Set<String>.self) ?? []
    }

    func save(_ ids: Set<String>) {
        file.save(ids)
    }
}
