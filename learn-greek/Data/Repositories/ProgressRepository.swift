import Foundation

final class ProgressRepository {
    private let file: AppJSONFile

    init(fileName: String = "progress.v1.json", appFolderURL: URL? = nil) {
        file = AppJSONFile(fileName: fileName, appFolderURL: appFolderURL, usesISO8601Dates: true)
    }

    func load() -> [String: CardProgress] {
        file.load([String: CardProgress].self) ?? [:]
    }

    func save(_ progress: [String: CardProgress]) {
        file.save(progress)
    }
}
