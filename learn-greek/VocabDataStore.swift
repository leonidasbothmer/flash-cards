import Foundation

struct VocabDatasetFile: Decodable {
    let schemaVersion: Int
    let items: [RawVocabItem]
}

struct RawVocabItem: Decodable {
    let id: String
    let greek: String
    let lemma: String?
    let pos: String?
    let translations: [String: OneOrManyStrings]?
    let english: OneOrManyStrings?
    let german: OneOrManyStrings?
}

enum OneOrManyStrings: Decodable {
    case one(String)
    case many([String])

    nonisolated var values: [String] {
        switch self {
        case .one(let value):
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? [] : [trimmed]
        case .many(let values):
            return values
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .one(value)
            return
        }
        self = .many(try container.decode([String].self))
    }
}

enum VocabDataStore {
    static func loadBundledVocab(named fileName: String = "vocab_seed") throws -> [VocabItem] {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            throw NSError(domain: "VocabDataStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing bundled file: \(fileName).json"])
        }
        return try loadVocab(from: url)
    }

    static func loadVocab(from url: URL) throws -> [VocabItem] {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()

        if let wrapped = try? decoder.decode(VocabDatasetFile.self, from: data) {
            return wrapped.items.map(asVocabItem)
        }

        let fallbackArray = try decoder.decode([RawVocabItem].self, from: data)
        return fallbackArray.map(asVocabItem)
    }

    private nonisolated static func asVocabItem(raw: RawVocabItem) -> VocabItem {
        var translations: [String: [String]] = raw.translations?.mapValues { $0.values } ?? [:]

        if translations["en"] == nil {
            translations["en"] = raw.english?.values ?? []
        }
        if translations["de"] == nil {
            translations["de"] = raw.german?.values ?? []
        }

        return VocabItem(
            id: raw.id,
            greek: raw.greek,
            lemma: raw.lemma,
            partOfSpeech: raw.pos,
            translations: translations
        )
    }
}

final class CustomVocabRepository {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileName: String = "custom-vocab.v1.json") {
        let manager = FileManager.default
        let baseURL = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = baseURL.appendingPathComponent("learn-greek", isDirectory: true)
        if !manager.fileExists(atPath: appFolder.path) {
            try? manager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }
        fileURL = appFolder.appendingPathComponent(fileName)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load() -> [VocabItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? decoder.decode([VocabItem].self, from: data)) ?? []
    }

    func save(_ items: [VocabItem]) {
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

final class DeletedVocabRepository {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileName: String = "deleted-vocab.v1.json") {
        let manager = FileManager.default
        let baseURL = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = baseURL.appendingPathComponent("learn-greek", isDirectory: true)
        if !manager.fileExists(atPath: appFolder.path) {
            try? manager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }
        fileURL = appFolder.appendingPathComponent(fileName)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load() -> Set<String> {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? decoder.decode(Set<String>.self, from: data)) ?? []
    }

    func save(_ ids: Set<String>) {
        guard let data = try? encoder.encode(ids) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

final class ProgressRepository {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileName: String = "progress.v1.json") {
        let manager = FileManager.default
        let baseURL = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = baseURL.appendingPathComponent("learn-greek", isDirectory: true)
        if !manager.fileExists(atPath: appFolder.path) {
            try? manager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }
        self.fileURL = appFolder.appendingPathComponent(fileName)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    func load() -> [String: VocabProgress] {
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        return (try? decoder.decode([String: VocabProgress].self, from: data)) ?? [:]
    }

    func save(_ progress: [String: VocabProgress]) {
        guard let data = try? encoder.encode(progress) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

final class VocabOverrideRepository {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileName: String = "vocab-overrides.v1.json") {
        let manager = FileManager.default
        let baseURL = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = baseURL.appendingPathComponent("learn-greek", isDirectory: true)
        if !manager.fileExists(atPath: appFolder.path) {
            try? manager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }
        self.fileURL = appFolder.appendingPathComponent(fileName)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load() -> [String: VocabOverride] {
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        return (try? decoder.decode([String: VocabOverride].self, from: data)) ?? [:]
    }

    func save(_ overrides: [String: VocabOverride]) {
        guard let data = try? encoder.encode(overrides) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
