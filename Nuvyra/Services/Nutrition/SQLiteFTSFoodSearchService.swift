import Foundation
import SQLite3

struct FoodSearchRecord: Hashable {
    var id: Int64?
    var name: String
    var brand: String?
    var calories: Int
    var servingDescription: String
    var keywords: String
}

struct FoodSearchResult: Identifiable, Hashable {
    let id: Int64
    let name: String
    let brand: String?
    let calories: Int
    let servingDescription: String
    let score: Double
}

enum FoodSearchError: LocalizedError {
    case databaseOpenFailed(String)
    case sqliteError(String)
    case queryPreparationFailed

    var errorDescription: String? {
        switch self {
        case .databaseOpenFailed(let message):
            return "Besin arama veritabanı açılamadı: \(message)"
        case .sqliteError(let message):
            return "Besin arama sorgusu çalışmadı: \(message)"
        case .queryPreparationFailed:
            return "Besin arama sorgusu hazırlanamadı."
        }
    }
}

final class SQLiteFTSFoodSearchService: @unchecked Sendable {
    static let shared = SQLiteFTSFoodSearchService()

    private let queue = DispatchQueue(label: "com.nuvyra.food-search.fts5", qos: .userInitiated)
    private let databaseURL: URL
    private var database: OpaquePointer?
    private var isPrepared = false

    init(databaseURL: URL? = nil) {
        self.databaseURL = databaseURL ?? Self.defaultDatabaseURL()
    }

    deinit {
        if let database {
            sqlite3_close(database)
        }
    }

    func search(_ rawQuery: String, limit: Int = 20) async throws -> [FoodSearchResult] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else { return continuation.resume(returning: []) }

                do {
                    try self.prepareIfNeeded()
                    let results = try self.searchSync(rawQuery, limit: limit)
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func upsert(records: [FoodSearchRecord]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self else { return continuation.resume() }

                do {
                    try self.prepareIfNeeded()
                    try self.upsertSync(records: records)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func prepareIfNeeded() throws {
        guard !isPrepared else { return }

        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try openDatabaseIfNeeded()
        try execute(Self.schemaSQL)
        try seedDemoFoodsIfNeeded()
        isPrepared = true
    }

    private func openDatabaseIfNeeded() throws {
        guard database == nil else { return }

        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(databaseURL.path, &database, flags, nil) != SQLITE_OK {
            throw FoodSearchError.databaseOpenFailed(lastSQLiteMessage)
        }
    }

    private func searchSync(_ rawQuery: String, limit: Int) throws -> [FoodSearchResult] {
        let ftsQuery = FoodSearchNormalizer.makeFTSQuery(from: rawQuery)
        guard !ftsQuery.isEmpty else { return [] }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, Self.searchSQL, -1, &statement, nil) == SQLITE_OK else {
            throw FoodSearchError.queryPreparationFailed
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, ftsQuery, -1, sqliteTransient)
        sqlite3_bind_int(statement, 2, Int32(max(1, min(limit, 100))))

        var results: [FoodSearchResult] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            results.append(FoodSearchResult(
                id: sqlite3_column_int64(statement, 0),
                name: sqliteColumnString(statement, 1),
                brand: sqliteOptionalColumnString(statement, 2),
                calories: Int(sqlite3_column_int(statement, 3)),
                servingDescription: sqliteColumnString(statement, 4),
                score: sqlite3_column_double(statement, 5)
            ))
        }

        return results
    }

    private func seedDemoFoodsIfNeeded() throws {
        guard try itemCount() == 0 else { return }

        let quickFoods = QuickFood.turkishDefaults.map {
            FoodSearchRecord(
                id: nil,
                name: $0.name,
                brand: nil,
                calories: $0.calories,
                servingDescription: $0.portion,
                keywords: "\($0.name) türk yemeği hızlı öğün"
            )
        }

        let demoFoods: [FoodSearchRecord] = [
            FoodSearchRecord(id: nil, name: "Şeftali", brand: nil, calories: 58, servingDescription: "1 orta boy", keywords: "seftali meyve yaz"),
            FoodSearchRecord(id: nil, name: "Şeftali suyu", brand: nil, calories: 130, servingDescription: "1 bardak", keywords: "seftali suyu içecek"),
            FoodSearchRecord(id: nil, name: "Yeşil elma", brand: nil, calories: 95, servingDescription: "1 adet", keywords: "elma meyve"),
            FoodSearchRecord(id: nil, name: "Çilek", brand: nil, calories: 45, servingDescription: "1 kase", keywords: "cilek meyve")
        ]

        try upsertSync(records: quickFoods + demoFoods)
    }

    private func upsertSync(records: [FoodSearchRecord]) throws {
        guard !records.isEmpty else { return }

        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            for record in records {
                try insert(record)
            }
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    private func insert(_ record: FoodSearchRecord) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, Self.insertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw FoodSearchError.queryPreparationFailed
        }
        defer { sqlite3_finalize(statement) }

        if let id = record.id {
            sqlite3_bind_int64(statement, 1, id)
        } else {
            sqlite3_bind_null(statement, 1)
        }

        let normalizedName = FoodSearchNormalizer.normalized(record.name)
        let normalizedKeywords = FoodSearchNormalizer.normalized(record.keywords)

        sqlite3_bind_text(statement, 2, record.name, -1, sqliteTransient)
        if let brand = record.brand {
            sqlite3_bind_text(statement, 3, brand, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 3)
        }
        sqlite3_bind_int(statement, 4, Int32(record.calories))
        sqlite3_bind_text(statement, 5, record.servingDescription, -1, sqliteTransient)
        sqlite3_bind_text(statement, 6, normalizedName, -1, sqliteTransient)
        sqlite3_bind_text(statement, 7, normalizedKeywords, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw FoodSearchError.sqliteError(lastSQLiteMessage)
        }
    }

    private func itemCount() throws -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT COUNT(*) FROM food_items;", -1, &statement, nil) == SQLITE_OK else {
            throw FoodSearchError.queryPreparationFailed
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(statement, 0))
    }

    private func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(database, sql, nil, nil, &errorMessage) != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? lastSQLiteMessage
            sqlite3_free(errorMessage)
            throw FoodSearchError.sqliteError(message)
        }
    }

    private var lastSQLiteMessage: String {
        guard let database, let message = sqlite3_errmsg(database) else {
            return "Bilinmeyen SQLite hatası."
        }
        return String(cString: message)
    }

    private static func defaultDatabaseURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL.appendingPathComponent("NuvyraFoodSearch.sqlite")
    }

    static let schemaSQL = """
    PRAGMA journal_mode = WAL;
    PRAGMA synchronous = NORMAL;
    PRAGMA temp_store = MEMORY;

    CREATE TABLE IF NOT EXISTS food_items (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        brand TEXT,
        calories INTEGER NOT NULL,
        serving_description TEXT NOT NULL,
        name_normalized TEXT NOT NULL,
        keywords_normalized TEXT NOT NULL
    );

    CREATE VIRTUAL TABLE IF NOT EXISTS food_items_fts USING fts5(
        name_normalized,
        keywords_normalized,
        content = 'food_items',
        content_rowid = 'id',
        tokenize = 'unicode61 remove_diacritics 2'
    );

    CREATE TRIGGER IF NOT EXISTS food_items_ai AFTER INSERT ON food_items BEGIN
        INSERT INTO food_items_fts(rowid, name_normalized, keywords_normalized)
        VALUES (new.id, new.name_normalized, new.keywords_normalized);
    END;

    CREATE TRIGGER IF NOT EXISTS food_items_ad AFTER DELETE ON food_items BEGIN
        INSERT INTO food_items_fts(food_items_fts, rowid, name_normalized, keywords_normalized)
        VALUES ('delete', old.id, old.name_normalized, old.keywords_normalized);
    END;

    CREATE TRIGGER IF NOT EXISTS food_items_au AFTER UPDATE ON food_items BEGIN
        INSERT INTO food_items_fts(food_items_fts, rowid, name_normalized, keywords_normalized)
        VALUES ('delete', old.id, old.name_normalized, old.keywords_normalized);
        INSERT INTO food_items_fts(rowid, name_normalized, keywords_normalized)
        VALUES (new.id, new.name_normalized, new.keywords_normalized);
    END;
    """

    static let insertSQL = """
    INSERT INTO food_items (
        id,
        name,
        brand,
        calories,
        serving_description,
        name_normalized,
        keywords_normalized
    ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        brand = excluded.brand,
        calories = excluded.calories,
        serving_description = excluded.serving_description,
        name_normalized = excluded.name_normalized,
        keywords_normalized = excluded.keywords_normalized;
    """

    static let searchSQL = """
    SELECT
        food_items.id,
        food_items.name,
        food_items.brand,
        food_items.calories,
        food_items.serving_description,
        bm25(food_items_fts) AS score
    FROM food_items_fts
    JOIN food_items ON food_items.id = food_items_fts.rowid
    WHERE food_items_fts MATCH ?
    ORDER BY score
    LIMIT ?;
    """
}

enum FoodSearchNormalizer {
    private static let turkishCharacterMap: [Character: Character] = [
        "ç": "c", "Ç": "c",
        "ğ": "g", "Ğ": "g",
        "ı": "i", "I": "i",
        "İ": "i", "i": "i",
        "ö": "o", "Ö": "o",
        "ş": "s", "Ş": "s",
        "ü": "u", "Ü": "u"
    ]

    static func normalized(_ value: String) -> String {
        let mapped = String(value.map { turkishCharacterMap[$0] ?? $0 })
        let folded = mapped
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "tr_TR"))
            .lowercased(with: Locale(identifier: "en_US_POSIX"))

        let cleaned = folded.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : " "
        }
        .joined()

        return cleaned
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    static func makeFTSQuery(from value: String) -> String {
        normalized(value)
            .split(separator: " ")
            .prefix(6)
            .map { "\"\($0)\"*" }
            .joined(separator: " AND ")
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private func sqliteColumnString(_ statement: OpaquePointer?, _ index: Int32) -> String {
    guard let text = sqlite3_column_text(statement, index) else { return "" }
    return String(cString: text)
}

private func sqliteOptionalColumnString(_ statement: OpaquePointer?, _ index: Int32) -> String? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
    return sqliteColumnString(statement, index)
}
