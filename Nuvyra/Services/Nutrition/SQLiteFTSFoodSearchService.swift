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
        guard try itemCount() < 60 else { return }

        let quickFoods = QuickFood.turkishDefaults.enumerated().map { index, food in
            FoodSearchRecord(
                id: Int64(1_000 + index),
                name: food.name,
                brand: nil,
                calories: food.calories,
                servingDescription: food.portion,
                keywords: "\(food.name) turk yemegi hizli ogun"
            )
        }

        try upsertSync(records: quickFoods + Self.turkishSeedFoods)
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

    private static let turkishSeedFoods: [FoodSearchRecord] = [
        FoodSearchRecord(id: 2_001, name: "Seftali", brand: nil, calories: 58, servingDescription: "1 orta boy", keywords: "seftali peach meyve yaz"),
        FoodSearchRecord(id: 2_002, name: "Seftali suyu", brand: nil, calories: 130, servingDescription: "1 bardak", keywords: "seftali suyu icecek meyve"),
        FoodSearchRecord(id: 2_003, name: "Yesil elma", brand: nil, calories: 95, servingDescription: "1 adet", keywords: "elma meyve yesil"),
        FoodSearchRecord(id: 2_004, name: "Cilek", brand: nil, calories: 45, servingDescription: "1 kase", keywords: "cilek meyve"),
        FoodSearchRecord(id: 2_005, name: "Muz", brand: nil, calories: 105, servingDescription: "1 orta boy", keywords: "muz banana meyve"),
        FoodSearchRecord(id: 2_006, name: "Portakal", brand: nil, calories: 62, servingDescription: "1 adet", keywords: "portakal meyve c vitamini"),
        FoodSearchRecord(id: 2_007, name: "Domates", brand: nil, calories: 22, servingDescription: "1 orta boy", keywords: "domates sebze salata"),
        FoodSearchRecord(id: 2_008, name: "Salatalik", brand: nil, calories: 12, servingDescription: "1 adet", keywords: "salatalik salata sebze"),
        FoodSearchRecord(id: 2_009, name: "Beyaz peynir", brand: nil, calories: 95, servingDescription: "1 dilim", keywords: "peynir kahvalti protein"),
        FoodSearchRecord(id: 2_010, name: "Kasar peyniri", brand: nil, calories: 120, servingDescription: "1 dilim", keywords: "kasar peynir kahvalti tost"),
        FoodSearchRecord(id: 2_011, name: "Zeytin", brand: nil, calories: 45, servingDescription: "5 adet", keywords: "zeytin kahvalti"),
        FoodSearchRecord(id: 2_012, name: "Tam bugday ekmegi", brand: nil, calories: 70, servingDescription: "1 dilim", keywords: "ekmek tam bugday kahvalti"),
        FoodSearchRecord(id: 2_013, name: "Beyaz ekmek", brand: nil, calories: 80, servingDescription: "1 dilim", keywords: "ekmek beyaz"),
        FoodSearchRecord(id: 2_014, name: "Yulaf ezmesi", brand: nil, calories: 150, servingDescription: "40 g", keywords: "yulaf kahvalti oats"),
        FoodSearchRecord(id: 2_015, name: "Bal", brand: nil, calories: 64, servingDescription: "1 tatli kasigi", keywords: "bal kahvalti tatli"),
        FoodSearchRecord(id: 2_016, name: "Fistik ezmesi", brand: nil, calories: 95, servingDescription: "1 yemek kasigi", keywords: "fistik ezmesi peanut protein"),
        FoodSearchRecord(id: 2_017, name: "Tahin pekmez", brand: nil, calories: 180, servingDescription: "1 yemek kasigi", keywords: "tahin pekmez kahvalti"),
        FoodSearchRecord(id: 2_018, name: "Tavuk gogsu", brand: nil, calories: 165, servingDescription: "100 g", keywords: "tavuk gogsu protein izgara"),
        FoodSearchRecord(id: 2_019, name: "Izgara kofte", brand: nil, calories: 320, servingDescription: "4 adet", keywords: "kofte izgara et protein"),
        FoodSearchRecord(id: 2_020, name: "Et doner", brand: nil, calories: 620, servingDescription: "1 porsiyon", keywords: "doner et durum"),
        FoodSearchRecord(id: 2_021, name: "Tavuk sis", brand: nil, calories: 340, servingDescription: "1 porsiyon", keywords: "tavuk sis izgara"),
        FoodSearchRecord(id: 2_022, name: "Somon izgara", brand: nil, calories: 360, servingDescription: "1 fileto", keywords: "somon balik omega protein"),
        FoodSearchRecord(id: 2_023, name: "Ton baligi", brand: nil, calories: 140, servingDescription: "100 g", keywords: "ton baligi protein konserve"),
        FoodSearchRecord(id: 2_024, name: "Bulgur pilavi", brand: nil, calories: 260, servingDescription: "1 tabak", keywords: "bulgur pilav ev yemegi"),
        FoodSearchRecord(id: 2_025, name: "Makarna", brand: nil, calories: 310, servingDescription: "1 tabak", keywords: "makarna pasta"),
        FoodSearchRecord(id: 2_026, name: "Kuru fasulye", brand: nil, calories: 300, servingDescription: "1 tabak", keywords: "kuru fasulye bakliyat ev yemegi"),
        FoodSearchRecord(id: 2_027, name: "Nohut yemegi", brand: nil, calories: 320, servingDescription: "1 tabak", keywords: "nohut bakliyat ev yemegi"),
        FoodSearchRecord(id: 2_028, name: "Zeytinyagli fasulye", brand: nil, calories: 210, servingDescription: "1 tabak", keywords: "zeytinyagli fasulye sebze"),
        FoodSearchRecord(id: 2_029, name: "Dolma", brand: nil, calories: 240, servingDescription: "4 adet", keywords: "dolma sarma ev yemegi"),
        FoodSearchRecord(id: 2_030, name: "Lahmacun", brand: nil, calories: 330, servingDescription: "1 adet", keywords: "lahmacun firin"),
        FoodSearchRecord(id: 2_031, name: "Pide", brand: nil, calories: 720, servingDescription: "1 adet", keywords: "pide kiymali kasarli"),
        FoodSearchRecord(id: 2_032, name: "Cig kofte durum", brand: nil, calories: 430, servingDescription: "1 durum", keywords: "cig kofte durum"),
        FoodSearchRecord(id: 2_033, name: "Ezogelin corbasi", brand: nil, calories: 180, servingDescription: "1 kase", keywords: "ezogelin corba"),
        FoodSearchRecord(id: 2_034, name: "Tarhana corbasi", brand: nil, calories: 160, servingDescription: "1 kase", keywords: "tarhana corba"),
        FoodSearchRecord(id: 2_035, name: "Coban salata", brand: nil, calories: 90, servingDescription: "1 kase", keywords: "coban salata sebze"),
        FoodSearchRecord(id: 2_036, name: "Mevsim salata", brand: nil, calories: 80, servingDescription: "1 kase", keywords: "mevsim salata"),
        FoodSearchRecord(id: 2_037, name: "Cacik", brand: nil, calories: 110, servingDescription: "1 kase", keywords: "cacik yogurt salatalik"),
        FoodSearchRecord(id: 2_038, name: "Kefir", brand: nil, calories: 120, servingDescription: "1 bardak", keywords: "kefir icecek probiyotik"),
        FoodSearchRecord(id: 2_039, name: "Sut", brand: nil, calories: 122, servingDescription: "1 bardak", keywords: "sut icecek"),
        FoodSearchRecord(id: 2_040, name: "Filtre kahve", brand: nil, calories: 5, servingDescription: "1 kupa", keywords: "kahve filtre sekersiz"),
        FoodSearchRecord(id: 2_041, name: "Turk kahvesi", brand: nil, calories: 7, servingDescription: "1 fincan", keywords: "turk kahvesi sekersiz"),
        FoodSearchRecord(id: 2_042, name: "Latte", brand: nil, calories: 150, servingDescription: "1 bardak", keywords: "latte kahve sutlu"),
        FoodSearchRecord(id: 2_043, name: "Kola", brand: nil, calories: 139, servingDescription: "330 ml", keywords: "kola gazli icecek"),
        FoodSearchRecord(id: 2_044, name: "Soda", brand: nil, calories: 0, servingDescription: "1 sise", keywords: "soda maden suyu"),
        FoodSearchRecord(id: 2_045, name: "Baklava", brand: nil, calories: 280, servingDescription: "2 dilim", keywords: "baklava tatli"),
        FoodSearchRecord(id: 2_046, name: "Sutlac", brand: nil, calories: 260, servingDescription: "1 kase", keywords: "sutlac tatli"),
        FoodSearchRecord(id: 2_047, name: "Dondurma", brand: nil, calories: 180, servingDescription: "2 top", keywords: "dondurma tatli"),
        FoodSearchRecord(id: 2_048, name: "Ceviz", brand: nil, calories: 185, servingDescription: "30 g", keywords: "ceviz kuruyemis omega"),
        FoodSearchRecord(id: 2_049, name: "Badem", brand: nil, calories: 170, servingDescription: "30 g", keywords: "badem kuruyemis"),
        FoodSearchRecord(id: 2_050, name: "Findik", brand: nil, calories: 175, servingDescription: "30 g", keywords: "findik kuruyemis")
    ]

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
