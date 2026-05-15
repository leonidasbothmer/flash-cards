import Foundation

final class CardOverrideRepository {
    private let file: AppJSONFile

    init(fileName: String = "card-overrides.v1.json", appFolderURL: URL? = nil) {
        file = AppJSONFile(fileName: fileName, appFolderURL: appFolderURL)
    }

    func load() -> [String: CardFacetOverride] {
        file.load([String: CardFacetOverride].self) ?? [:]
    }

    func save(_ overrides: [String: CardFacetOverride]) {
        file.save(overrides)
    }
}
