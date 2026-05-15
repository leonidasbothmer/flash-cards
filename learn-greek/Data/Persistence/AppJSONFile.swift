import Foundation

/// JSON file read/write under Application Support / learn-greek.
final class AppJSONFile {
    let url: URL
    let encoder: JSONEncoder
    let decoder: JSONDecoder

    init(fileName: String, appFolderURL: URL? = nil, usesISO8601Dates: Bool = false) {
        let folderURL = appFolderURL ?? Self.defaultAppFolderURL()
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        url = folderURL.appendingPathComponent(fileName)

        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if usesISO8601Dates {
            encoder.dateEncodingStrategy = .iso8601
            decoder.dateDecodingStrategy = .iso8601
        }
    }

    static func defaultAppFolderURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return baseURL.appendingPathComponent("learn-greek", isDirectory: true)
    }

    func loadData() -> Data? {
        try? Data(contentsOf: url)
    }

    func load<T: Decodable>(_ type: T.Type) -> T? {
        guard let data = loadData() else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    func save<T: Encodable>(_ value: T) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
