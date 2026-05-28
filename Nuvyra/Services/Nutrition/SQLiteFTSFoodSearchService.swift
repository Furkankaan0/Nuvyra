import Foundation
import SQLite3

struct FoodSearchRecord: Hashable {
    var id: Int64?
    var name: String
    var brand: String?
    var calories: Int
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var fiber: Double = 0
    var sodium: Double = 0
    var sugar: Double = 0
    var saturatedFat: Double = 0
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
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double?
    let imageURL: URL?
    let source: ProductSource
    let externalID: String?
    let isVerified: Bool

    init(
        id: Int64,
        name: String,
        brand: String?,
        calories: Int,
        servingDescription: String,
        score: Double,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        fiber: Double? = nil,
        imageURL: URL? = nil,
        source: ProductSource = .cache,
        externalID: String? = nil,
        isVerified: Bool = false
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.calories = calories
        self.servingDescription = servingDescription
        self.score = score
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.imageURL = imageURL
        self.source = source
        self.externalID = externalID
        self.isVerified = isVerified
    }

    static func remoteID(source: ProductSource, externalID: String) -> Int64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in "\(source.rawValue):\(externalID)".utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return -Int64(hash % 9_000_000_000_000_000) - 1
    }
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

    // MARK: - Rich item store (Phase 3)

    /// Persist a rich `FoodItem` into the local catalog. Returns the SQLite
    /// rowid. Remote-sourced items get a deterministic id derived from
    /// `(source, externalID)` so the same product never duplicates across
    /// repeat lookups; manual items get a fresh AUTOINCREMENT id.
    @discardableResult
    func upsertItem(_ item: FoodItem) async throws -> Int64 {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else { return continuation.resume(returning: 0) }
                do {
                    try self.prepareIfNeeded()
                    let id = try self.upsertItemSync(item)
                    continuation.resume(returning: id)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func findItem(externalID: String, source: ProductSource) async throws -> FoodItem? {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else { return continuation.resume(returning: nil) }
                do {
                    try self.prepareIfNeeded()
                    continuation.resume(returning: try self.findItemSync(externalID: externalID, source: source))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func findItem(barcode: String) async throws -> FoodItem? {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else { return continuation.resume(returning: nil) }
                do {
                    try self.prepareIfNeeded()
                    continuation.resume(returning: try self.findItemSync(barcode: barcode))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// FTS5 keyword search that returns rich items when a payload is stored,
    /// falling back to a lean `FoodItem` materialised from the indexed row
    /// for legacy seed data.
    func searchItems(_ rawQuery: String, limit: Int = 20) async throws -> [FoodItem] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else { return continuation.resume(returning: []) }
                do {
                    try self.prepareIfNeeded()
                    continuation.resume(returning: try self.searchItemsSync(rawQuery, limit: limit))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func recordUse(rowID: Int64) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self else { return continuation.resume() }
                do {
                    try self.prepareIfNeeded()
                    try self.recordUseSync(rowID: rowID)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func isFavorite(rowID: Int64) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else { return continuation.resume(returning: false) }
                do {
                    try self.prepareIfNeeded()
                    continuation.resume(returning: try self.isFavoriteSync(rowID: rowID))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func setFavorite(rowID: Int64, _ isFavorite: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self else { return continuation.resume() }
                do {
                    try self.prepareIfNeeded()
                    try self.setFavoriteSync(rowID: rowID, isFavorite: isFavorite)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func recentItems(limit: Int = 20) async throws -> [FoodItem] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else { return continuation.resume(returning: []) }
                do {
                    try self.prepareIfNeeded()
                    continuation.resume(returning: try self.recentItemsSync(limit: limit))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func favoriteItems(limit: Int = 50) async throws -> [FoodItem] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else { return continuation.resume(returning: []) }
                do {
                    try self.prepareIfNeeded()
                    continuation.resume(returning: try self.favoriteItemsSync(limit: limit))
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
        runMigrations()
        cleanupLegacyLeanRows()
        try seedDemoFoodsIfNeeded()
        isPrepared = true
    }

    /// Pre-Phase-4 satırlar — eski `QuickFood.turkishDefaults` ve
    /// `turkishSeedFoods` arrays'ından gelen lean rows (payload=NULL, makrolar
    /// 0). ID aralığı 1000-9999 (yeni rich seed negatif ID'lerde duruyor).
    /// Aynı yemeği iki kez göstermemek için her prepare'de çalıştırılır;
    /// idempotent — temiz DB'de no-op.
    private func cleanupLegacyLeanRows() {
        try? execute("DELETE FROM food_items WHERE id BETWEEN 1000 AND 9999 AND payload IS NULL;")
    }

    /// Each migration is idempotent: re-running on an already-migrated DB
    /// raises "duplicate column" which we ignore.
    private func runMigrations() {
        for statement in Self.migrationStatements {
            try? execute(statement)
        }
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
                servingDescription: sqliteColumnString(statement, 8),
                score: sqlite3_column_double(statement, 9),
                protein: sqliteColumnDouble(statement, 4),
                carbs: sqliteColumnDouble(statement, 5),
                fat: sqliteColumnDouble(statement, 6),
                fiber: sqliteColumnDouble(statement, 7)
            ))
        }

        return results
    }

    /// Phase 4 — bundle'da gelen `LocalFoodDatabase.json` ile seed eder.
    /// PRAGMA user_version mevcut seed sürümünden geri kaldığında çalışır;
    /// `externalID = "local:<slug>"` deterministik olduğu için re-run idempotent.
    /// JSON eksikse veya parse edilemezse sessizce no-op — boş kataloga
    /// düşmek crash'ten daha iyi (remote arama ve barkod yine çalışır).
    private func seedDemoFoodsIfNeeded() throws {
        let currentVersion = readUserVersion()
        if currentVersion >= LocalFoodDatabaseSeeder.version { return }

        let items: [FoodItem]
        do {
            items = try LocalFoodDatabaseSeeder.loadSeedFoods()
        } catch {
            #if DEBUG
            print("[Nuvyra] LocalFoodDatabase seed atlandı: \(error.localizedDescription)")
            #endif
            return
        }

        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            for item in items {
                _ = try upsertItemSync(item)
            }
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }

        try execute("PRAGMA user_version = \(LocalFoodDatabaseSeeder.version);")
    }

    private func readUserVersion() -> Int32 {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "PRAGMA user_version;", -1, &statement, nil) == SQLITE_OK else {
            return 0
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return sqlite3_column_int(statement, 0)
    }
    // MARK: - Rich item store (Phase 3, sync)

    private func upsertItemSync(_ item: FoodItem) throws -> Int64 {
        let payload = try Self.jsonEncoder.encode(item)
        guard let payloadString = String(data: payload, encoding: .utf8) else {
            throw FoodSearchError.sqliteError("FoodItem payload utf-8 dönüştürme hatası.")
        }

        let resolvedID: Int64? = {
            guard let externalID = item.externalID,
                  item.source != .manual,
                  !externalID.isEmpty else { return nil }
            return FoodSearchResult.remoteID(source: item.source, externalID: externalID)
        }()

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, Self.upsertItemSQL, -1, &statement, nil) == SQLITE_OK else {
            throw FoodSearchError.queryPreparationFailed
        }
        defer { sqlite3_finalize(statement) }

        if let resolvedID {
            sqlite3_bind_int64(statement, 1, resolvedID)
        } else {
            sqlite3_bind_null(statement, 1)
        }

        let displayName = item.preferredDisplayName
        let normalizedName = FoodSearchNormalizer.normalized(displayName)
        let keywords = Self.searchKeywords(for: item)
        let normalizedKeywords = FoodSearchNormalizer.normalized(keywords)
        let portion = item.servingSizes.first(where: { !$0.isDefault })?.preferredLabel
            ?? item.defaultServing.preferredLabel

        sqlite3_bind_text(statement, 2, displayName, -1, sqliteTransient)
        if let brand = item.brand {
            sqlite3_bind_text(statement, 3, brand, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 3)
        }
        sqlite3_bind_int(statement, 4, Int32(item.caloriesPer100g))
        sqlite3_bind_double(statement, 5, item.proteinPer100g)
        sqlite3_bind_double(statement, 6, item.carbsPer100g)
        sqlite3_bind_double(statement, 7, item.fatPer100g)
        sqlite3_bind_double(statement, 8, item.fiberPer100g)
        sqlite3_bind_double(statement, 9, item.sodiumPer100g)
        sqlite3_bind_double(statement, 10, item.sugarPer100g)
        sqlite3_bind_double(statement, 11, item.saturatedFatPer100g)
        sqlite3_bind_text(statement, 12, portion, -1, sqliteTransient)
        sqlite3_bind_text(statement, 13, normalizedName, -1, sqliteTransient)
        sqlite3_bind_text(statement, 14, normalizedKeywords, -1, sqliteTransient)
        sqlite3_bind_text(statement, 15, payloadString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 16, item.source.rawValue, -1, sqliteTransient)
        if let ext = item.externalID {
            sqlite3_bind_text(statement, 17, ext, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 17)
        }
        if let bc = item.barcode {
            sqlite3_bind_text(statement, 18, bc, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 18)
        }
        if let url = item.imageURL?.absoluteString {
            sqlite3_bind_text(statement, 19, url, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 19)
        }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw FoodSearchError.sqliteError(lastSQLiteMessage)
        }

        if let resolvedID { return resolvedID }
        return sqlite3_last_insert_rowid(database)
    }

    private func findItemSync(externalID: String, source: ProductSource) throws -> FoodItem? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, Self.findByExternalSQL, -1, &statement, nil) == SQLITE_OK else {
            throw FoodSearchError.queryPreparationFailed
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, source.rawValue, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, externalID, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return materializeItem(from: statement)
    }

    private func findItemSync(barcode: String) throws -> FoodItem? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, Self.findByBarcodeSQL, -1, &statement, nil) == SQLITE_OK else {
            throw FoodSearchError.queryPreparationFailed
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, barcode, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return materializeItem(from: statement)
    }

    private func searchItemsSync(_ rawQuery: String, limit: Int) throws -> [FoodItem] {
        let ftsQuery = FoodSearchNormalizer.makeFTSQuery(from: rawQuery)
        guard !ftsQuery.isEmpty else { return [] }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, Self.searchItemsSQL, -1, &statement, nil) == SQLITE_OK else {
            throw FoodSearchError.queryPreparationFailed
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, ftsQuery, -1, sqliteTransient)
        sqlite3_bind_int(statement, 2, Int32(max(1, min(limit, 100))))

        var items: [FoodItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = materializeItem(from: statement) { items.append(item) }
        }
        return items
    }

    private func recordUseSync(rowID: Int64) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, Self.recordUseSQL, -1, &statement, nil) == SQLITE_OK else {
            throw FoodSearchError.queryPreparationFailed
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_double(statement, 1, Date().timeIntervalSince1970)
        sqlite3_bind_int64(statement, 2, rowID)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw FoodSearchError.sqliteError(lastSQLiteMessage)
        }
    }

    private func isFavoriteSync(rowID: Int64) throws -> Bool {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT is_favorite FROM food_items WHERE id = ? LIMIT 1;", -1, &statement, nil) == SQLITE_OK else {
            throw FoodSearchError.queryPreparationFailed
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, rowID)
        guard sqlite3_step(statement) == SQLITE_ROW else { return false }
        return sqlite3_column_int(statement, 0) == 1
    }

    private func setFavoriteSync(rowID: Int64, isFavorite: Bool) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, Self.setFavoriteSQL, -1, &statement, nil) == SQLITE_OK else {
            throw FoodSearchError.queryPreparationFailed
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, isFavorite ? 1 : 0)
        sqlite3_bind_int64(statement, 2, rowID)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw FoodSearchError.sqliteError(lastSQLiteMessage)
        }
    }

    private func recentItemsSync(limit: Int) throws -> [FoodItem] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, Self.recentItemsSQL, -1, &statement, nil) == SQLITE_OK else {
            throw FoodSearchError.queryPreparationFailed
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(max(1, min(limit, 100))))

        var items: [FoodItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = materializeItem(from: statement) { items.append(item) }
        }
        return items
    }

    private func favoriteItemsSync(limit: Int) throws -> [FoodItem] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, Self.favoriteItemsSQL, -1, &statement, nil) == SQLITE_OK else {
            throw FoodSearchError.queryPreparationFailed
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(max(1, min(limit, 200))))

        var items: [FoodItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = materializeItem(from: statement) { items.append(item) }
        }
        return items
    }

    /// Build a `FoodItem` from the canonical item SELECT. Decodes the JSON
    /// payload when present; otherwise rehydrates a lean item from indexed
    /// nutrition columns (used for legacy rows without a rich payload).
    private func materializeItem(from statement: OpaquePointer?) -> FoodItem? {
        if let payload = sqliteOptionalColumnString(statement, 12),
           let data = payload.data(using: .utf8),
           let item = try? Self.jsonDecoder.decode(FoodItem.self, from: data) {
            return item
        }

        let name = sqliteColumnString(statement, 1)
        guard !name.isEmpty else { return nil }
        let brand = sqliteOptionalColumnString(statement, 2)
        let calories = Int(sqlite3_column_int(statement, 3))
        let protein = sqliteColumnDouble(statement, 4)
        let carbs = sqliteColumnDouble(statement, 5)
        let fat = sqliteColumnDouble(statement, 6)
        let fiber = sqliteColumnDouble(statement, 7)
        let sodium = sqliteColumnDouble(statement, 8)
        let sugar = sqliteColumnDouble(statement, 9)
        let saturatedFat = sqliteColumnDouble(statement, 10)
        let portion = sqliteColumnString(statement, 11)
        let sourceRaw = sqliteOptionalColumnString(statement, 13) ?? ProductSource.cache.rawValue
        let externalID = sqliteOptionalColumnString(statement, 14)
        let barcode = sqliteOptionalColumnString(statement, 15)
        let imageURL = sqliteOptionalColumnString(statement, 16).flatMap(URL.init(string:))
        let source = ProductSource(rawValue: sourceRaw) ?? .cache

        let detailServing: ServingSize = ServingSize(
            label: portion.isEmpty ? "1 porsiyon" : portion,
            labelTR: portion.isEmpty ? "1 porsiyon" : portion,
            grams: 100,
            isDefault: true
        )

        return FoodItem(
            source: source,
            externalID: externalID,
            name: name,
            localizedNameTR: name,
            brand: brand,
            barcode: barcode,
            imageURL: imageURL,
            servingSizes: [.hundredGrams, detailServing],
            nutritionPer100g: NutritionValues(
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                fiber: fiber,
                sodium: sodium,
                sugar: sugar,
                saturatedFat: saturatedFat
            ),
            verifiedLevel: .approximate,
            confidenceScore: 0.45
        )
    }

    /// Concatenated, space-joined keyword corpus indexed by FTS. Order favours
    /// the most discriminating tokens first — display name, then localized
    /// name, brand, category, then secondary tags.
    private static func searchKeywords(for item: FoodItem) -> String {
        var parts: [String] = [item.name]
        if let tr = item.localizedNameTR, tr != item.name { parts.append(tr) }
        if let brand = item.brand { parts.append(brand) }
        if let category = item.category {
            parts.append(category.displayLabelTR)
            parts.append(category.displayLabelEN)
        }
        if let sub = item.subCategory { parts.append(sub) }
        if !item.allergens.isEmpty { parts.append(item.allergens.map(\.rawValue).joined(separator: " ")) }
        if let barcode = item.barcode { parts.append(barcode) }
        return parts.joined(separator: " ")
    }

    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

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
        sqlite3_bind_double(statement, 5, record.protein)
        sqlite3_bind_double(statement, 6, record.carbs)
        sqlite3_bind_double(statement, 7, record.fat)
        sqlite3_bind_double(statement, 8, record.fiber)
        sqlite3_bind_double(statement, 9, record.sodium)
        sqlite3_bind_double(statement, 10, record.sugar)
        sqlite3_bind_double(statement, 11, record.saturatedFat)
        sqlite3_bind_text(statement, 12, record.servingDescription, -1, sqliteTransient)
        sqlite3_bind_text(statement, 13, normalizedName, -1, sqliteTransient)
        sqlite3_bind_text(statement, 14, normalizedKeywords, -1, sqliteTransient)

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
        protein REAL NOT NULL DEFAULT 0,
        carbs REAL NOT NULL DEFAULT 0,
        fat REAL NOT NULL DEFAULT 0,
        fiber REAL NOT NULL DEFAULT 0,
        sodium REAL NOT NULL DEFAULT 0,
        sugar REAL NOT NULL DEFAULT 0,
        saturated_fat REAL NOT NULL DEFAULT 0,
        serving_description TEXT NOT NULL,
        name_normalized TEXT NOT NULL,
        keywords_normalized TEXT NOT NULL,
        payload TEXT,
        source TEXT NOT NULL DEFAULT 'cache',
        external_id TEXT,
        barcode TEXT,
        image_url TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        use_count INTEGER NOT NULL DEFAULT 0,
        last_used_at REAL
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

    CREATE INDEX IF NOT EXISTS idx_food_items_external
        ON food_items(source, external_id);

    CREATE INDEX IF NOT EXISTS idx_food_items_barcode
        ON food_items(barcode);

    CREATE INDEX IF NOT EXISTS idx_food_items_last_used
        ON food_items(last_used_at DESC);
    """

    /// Statements run after `schemaSQL` to bring older SQLite stores (which
    /// had the original 7-column schema) up to the Phase-3 layout. Each
    /// `ALTER TABLE` is wrapped in `try?` at call site because SQLite has no
    /// `ADD COLUMN IF NOT EXISTS` clause — we let "duplicate column" errors
    /// no-op instead.
    static let migrationStatements: [String] = [
        "ALTER TABLE food_items ADD COLUMN payload TEXT;",
        "ALTER TABLE food_items ADD COLUMN source TEXT NOT NULL DEFAULT 'cache';",
        "ALTER TABLE food_items ADD COLUMN external_id TEXT;",
        "ALTER TABLE food_items ADD COLUMN barcode TEXT;",
        "ALTER TABLE food_items ADD COLUMN image_url TEXT;",
        "ALTER TABLE food_items ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0;",
        "ALTER TABLE food_items ADD COLUMN use_count INTEGER NOT NULL DEFAULT 0;",
        "ALTER TABLE food_items ADD COLUMN last_used_at REAL;",
        "ALTER TABLE food_items ADD COLUMN protein REAL NOT NULL DEFAULT 0;",
        "ALTER TABLE food_items ADD COLUMN carbs REAL NOT NULL DEFAULT 0;",
        "ALTER TABLE food_items ADD COLUMN fat REAL NOT NULL DEFAULT 0;",
        "ALTER TABLE food_items ADD COLUMN fiber REAL NOT NULL DEFAULT 0;",
        "ALTER TABLE food_items ADD COLUMN sodium REAL NOT NULL DEFAULT 0;",
        "ALTER TABLE food_items ADD COLUMN sugar REAL NOT NULL DEFAULT 0;",
        "ALTER TABLE food_items ADD COLUMN saturated_fat REAL NOT NULL DEFAULT 0;"
    ]

    static let itemSelectColumns = """
    id,
    name,
    brand,
    calories,
    protein,
    carbs,
    fat,
    fiber,
    sodium,
    sugar,
    saturated_fat,
    serving_description,
    payload,
    source,
    external_id,
    barcode,
    image_url
    """

    static let insertSQL = """
    INSERT INTO food_items (
        id,
        name,
        brand,
        calories,
        protein,
        carbs,
        fat,
        fiber,
        sodium,
        sugar,
        saturated_fat,
        serving_description,
        name_normalized,
        keywords_normalized
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        brand = excluded.brand,
        calories = excluded.calories,
        protein = excluded.protein,
        carbs = excluded.carbs,
        fat = excluded.fat,
        fiber = excluded.fiber,
        sodium = excluded.sodium,
        sugar = excluded.sugar,
        saturated_fat = excluded.saturated_fat,
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
        food_items.protein,
        food_items.carbs,
        food_items.fat,
        food_items.fiber,
        food_items.serving_description,
        bm25(food_items_fts) AS score
    FROM food_items_fts
    JOIN food_items ON food_items.id = food_items_fts.rowid
    WHERE food_items_fts MATCH ?
    ORDER BY score
    LIMIT ?;
    """

    // MARK: - Phase 3 SQL

    static let upsertItemSQL = """
    INSERT INTO food_items (
        id,
        name,
        brand,
        calories,
        protein,
        carbs,
        fat,
        fiber,
        sodium,
        sugar,
        saturated_fat,
        serving_description,
        name_normalized,
        keywords_normalized,
        payload,
        source,
        external_id,
        barcode,
        image_url
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        brand = excluded.brand,
        calories = excluded.calories,
        protein = excluded.protein,
        carbs = excluded.carbs,
        fat = excluded.fat,
        fiber = excluded.fiber,
        sodium = excluded.sodium,
        sugar = excluded.sugar,
        saturated_fat = excluded.saturated_fat,
        serving_description = excluded.serving_description,
        name_normalized = excluded.name_normalized,
        keywords_normalized = excluded.keywords_normalized,
        payload = excluded.payload,
        source = excluded.source,
        external_id = excluded.external_id,
        barcode = excluded.barcode,
        image_url = excluded.image_url;
    """

    static let findByExternalSQL = """
    SELECT \(itemSelectColumns)
    FROM food_items
    WHERE source = ? AND external_id = ?
    LIMIT 1;
    """

    static let findByBarcodeSQL = """
    SELECT \(itemSelectColumns)
    FROM food_items
    WHERE barcode = ?
    ORDER BY use_count DESC
    LIMIT 1;
    """

    static let searchItemsSQL = """
    SELECT
        food_items.id,
        food_items.name,
        food_items.brand,
        food_items.calories,
        food_items.protein,
        food_items.carbs,
        food_items.fat,
        food_items.fiber,
        food_items.sodium,
        food_items.sugar,
        food_items.saturated_fat,
        food_items.serving_description,
        food_items.payload,
        food_items.source,
        food_items.external_id,
        food_items.barcode,
        food_items.image_url
    FROM food_items_fts
    JOIN food_items ON food_items.id = food_items_fts.rowid
    WHERE food_items_fts MATCH ?
    ORDER BY food_items.is_favorite DESC, food_items.use_count DESC, bm25(food_items_fts)
    LIMIT ?;
    """

    static let recordUseSQL = """
    UPDATE food_items
    SET use_count = use_count + 1,
        last_used_at = ?
    WHERE id = ?;
    """

    static let setFavoriteSQL = """
    UPDATE food_items
    SET is_favorite = ?
    WHERE id = ?;
    """

    static let recentItemsSQL = """
    SELECT \(itemSelectColumns)
    FROM food_items
    WHERE last_used_at IS NOT NULL
    ORDER BY last_used_at DESC
    LIMIT ?;
    """

    static let favoriteItemsSQL = """
    SELECT \(itemSelectColumns)
    FROM food_items
    WHERE is_favorite = 1
    ORDER BY use_count DESC, last_used_at DESC
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

private func sqliteColumnDouble(_ statement: OpaquePointer?, _ index: Int32) -> Double {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return 0 }
    return sqlite3_column_double(statement, index)
}
