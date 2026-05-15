import Foundation

struct BundledCardCatalogFile: Decodable {
    let schemaVersion: Int
    let items: [RawLanguageCatalogItem]
}

struct RawLanguageCatalogItem: Decodable {
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

struct UserCardLibraryDocument: Codable {
    var librarySchemaVersion: Int
    var notes: [CardNote]

    static let currentLibrarySchemaVersion = 1

    init(notes: [CardNote]) {
        librarySchemaVersion = Self.currentLibrarySchemaVersion
        self.notes = notes
    }
}

// MARK: - Legacy migration shapes

private struct LegacyVocabItem: Codable {
    let id: String
    let greek: String
    let lemma: String?
    let partOfSpeech: String?
    let translations: [String: [String]]
}

private struct LegacyVocabOverride: Codable {
    let greek: String
    let english: [String]
    let german: [String]
}

enum CardDataStore {
    static func loadBundledCatalog(named fileName: String = "vocab_seed") throws -> [CardNote] {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            throw NSError(domain: "CardDataStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing bundled file: \(fileName).json"])
        }
        return try loadCatalog(from: url)
    }

    static func loadCatalog(from url: URL) throws -> [CardNote] {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()

        if let wrapped = try? decoder.decode(BundledCardCatalogFile.self, from: data) {
            return wrapped.items.map(asLanguageCardNote)
        }

        let fallbackArray = try decoder.decode([RawLanguageCatalogItem].self, from: data)
        return fallbackArray.map(asLanguageCardNote)
    }

    private nonisolated static func asLanguageCardNote(raw: RawLanguageCatalogItem) -> CardNote {
        var translations: [String: [String]] = raw.translations?.mapValues { $0.values } ?? [:]

        if translations["en"] == nil {
            translations["en"] = raw.english?.values ?? []
        }
        if translations["de"] == nil {
            translations["de"] = raw.german?.values ?? []
        }

        var facets: [String: [String]] = [:]
        facets[CardFacetKey.term] = [raw.greek]
        if let lemma = raw.lemma {
            facets[CardFacetKey.lemma] = [lemma]
        }
        if let pos = raw.pos {
            facets[CardFacetKey.pos] = [pos]
        }
        for (lang, glosses) in translations {
            facets[CardFacetKey.gloss(lang)] = glosses
        }

        return CardNote(id: raw.id, cardType: .languageV1, facets: facets)
    }

    fileprivate static func cardNote(fromLegacy item: LegacyVocabItem) -> CardNote {
        var facets: [String: [String]] = [:]
        facets[CardFacetKey.term] = [item.greek]
        if let lemma = item.lemma {
            facets[CardFacetKey.lemma] = [lemma]
        }
        if let pos = item.partOfSpeech {
            facets[CardFacetKey.pos] = [pos]
        }
        for (lang, glosses) in item.translations {
            facets[CardFacetKey.gloss(lang)] = glosses
        }
        return CardNote(id: item.id, cardType: .languageV1, facets: facets)
    }

    fileprivate static func facetOverride(fromLegacy override: LegacyVocabOverride) -> CardFacetOverride {
        CardFacetOverride(facets: [
            CardFacetKey.term: [override.greek],
            CardFacetKey.gloss("en"): override.english,
            CardFacetKey.gloss("de"): override.german
        ])
    }
}

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

    func siblingURL(fileName: String) -> URL {
        url.deletingLastPathComponent().appendingPathComponent(fileName)
    }
}

final class UserCardLibraryRepository {
    private let file: AppJSONFile

    init(fileName: String = "user-card-library.v1.json", appFolderURL: URL? = nil) {
        file = AppJSONFile(fileName: fileName, appFolderURL: appFolderURL, usesISO8601Dates: true)
    }

    private static let legacyCustomFileName = "custom-vocab.v1.json"

    func load() -> [CardNote] {
        guard let data = file.loadData() else {
            return migrateFromLegacyCustomVocabFileIfNeeded() ?? []
        }

        if let doc = try? file.decoder.decode(UserCardLibraryDocument.self, from: data) {
            return doc.notes
        }

        if let notes = try? file.decoder.decode([CardNote].self, from: data) {
            return notes
        }

        if let legacy = try? file.decoder.decode([LegacyVocabItem].self, from: data) {
            let notes = legacy.map(CardDataStore.cardNote(fromLegacy:))
            save(notes)
            return notes
        }

        return migrateFromLegacyCustomVocabFileIfNeeded() ?? []
    }

    func save(_ notes: [CardNote]) {
        file.save(UserCardLibraryDocument(notes: notes))
    }

    private func migrateFromLegacyCustomVocabFileIfNeeded() -> [CardNote]? {
        let legacyURL = file.siblingURL(fileName: Self.legacyCustomFileName)
        guard let data = try? Data(contentsOf: legacyURL),
              let legacy = try? file.decoder.decode([LegacyVocabItem].self, from: data)
        else { return nil }

        let notes = legacy.map(CardDataStore.cardNote(fromLegacy:))
        save(notes)
        try? FileManager.default.removeItem(at: legacyURL)
        return notes
    }
}

final class DeletedCardRepository {
    private let file: AppJSONFile

    init(fileName: String = "deleted-vocab.v1.json", appFolderURL: URL? = nil) {
        file = AppJSONFile(fileName: fileName, appFolderURL: appFolderURL)
    }

    func load() -> Set<String> {
        file.load(Set<String>.self) ?? []
    }

    func save(_ ids: Set<String>) {
        file.save(ids)
    }
}

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

final class CardOverrideRepository {
    private let file: AppJSONFile

    init(fileName: String = "card-overrides.v1.json", appFolderURL: URL? = nil) {
        file = AppJSONFile(fileName: fileName, appFolderURL: appFolderURL)
    }

    private static let legacyOverrideFileName = "vocab-overrides.v1.json"

    func load() -> [String: CardFacetOverride] {
        guard let data = file.loadData() else {
            return migrateLegacyOverridesIfNeeded() ?? [:]
        }

        if let decoded = try? file.decoder.decode([String: CardFacetOverride].self, from: data) {
            return decoded
        }

        return migrateLegacyOverridesIfNeeded() ?? [:]
    }

    func save(_ overrides: [String: CardFacetOverride]) {
        file.save(overrides)
    }

    private func migrateLegacyOverridesIfNeeded() -> [String: CardFacetOverride]? {
        let legacyURL = file.siblingURL(fileName: Self.legacyOverrideFileName)
        guard let data = try? Data(contentsOf: legacyURL),
              let legacy = try? file.decoder.decode([String: LegacyVocabOverride].self, from: data)
        else { return nil }

        let migrated = legacy.mapValues(CardDataStore.facetOverride(fromLegacy:))
        save(migrated)
        try? FileManager.default.removeItem(at: legacyURL)
        return migrated
    }
}
