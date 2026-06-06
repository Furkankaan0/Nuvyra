//
//  ProductCacheService.swift
//  Nuvyra - Barcode Scanner
//
//  Offline mode için SQLite tabanlı kalıcı ürün cache'i.
//  iOS'a built-in olan `libsqlite3` C API'si üzerine ince bir actor wrapper.
//  Hiçbir 3. parti bağımlılık yoktur.
//

import Foundation
import SQLite3

// SQLite C makrosu `SQLITE_TRANSIENT == ((sqlite3_destructor_type)-1)` Swift karşılığı.
// SQLite'a verilen text/blob'un kopyalanmasını söyler.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Disk üzerinde kalıcı ürün cache'i.
public actor ProductCacheService {

    // MARK: - Errors

    public enum CacheError: LocalizedError {
        case openFailed(String)
        case prepareFailed(String)
        case stepFailed(String)

        public var errorDescription: String? {
            switch self {
            case .openFailed(let m):    return "SQLite açılamadı: \(m)"
            case .prepareFailed(let m): return "Sorgu hazırlanamadı: \(m)"
            case .stepFailed(let m):    return "Sorgu yürütülemedi: \(m)"
            }
        }
    }

    // MARK: - Properties

    private var db: OpaquePointer?
    private let dbURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Init

    /// Application Support altında `nuvyra_products.sqlite` açar.
    public init(filename: String = "nuvyra_products.sqlite") throws {
        let fm = FileManager.default
        let supportDir = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        self.dbURL = supportDir.appendingPathComponent(filename)

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        self.db = try Self.openAndMigrate(at: dbURL)
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    // MARK: - Public API

    /// Verilen barkod için cache'lenmiş ürünü döner; yoksa nil.
    public func get(barcode: String) throws -> ScannedProduct? {
        let sql = "SELECT payload FROM products WHERE barcode = ? LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw CacheError.prepareFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, barcode, -1, SQLITE_TRANSIENT)

        let step = sqlite3_step(stmt)
        guard step == SQLITE_ROW else { return nil }

        guard let blob = sqlite3_column_blob(stmt, 0) else { return nil }
        let bytes = sqlite3_column_bytes(stmt, 0)
        let data = Data(bytes: blob, count: Int(bytes))

        var product = try decoder.decode(ScannedProduct.self, from: data)
        // Cache'ten dönüyor: source'u .cache olarak işaretle
        product = ScannedProduct(
            barcode: product.barcode,
            name: product.name,
            brand: product.brand,
            caloriesPer100g: product.caloriesPer100g,
            protein: product.protein,
            fat: product.fat,
            carbs: product.carbs,
            fiber: product.fiber,
            imageURL: product.imageURL,
            source: .cache,
            fetchedAt: product.fetchedAt
        )
        return product
    }

    /// Bir ürünü cache'e ekler/günceller.
    public func upsert(_ product: ScannedProduct) throws {
        let payload = try encoder.encode(product)

        let sql = """
            INSERT INTO products (barcode, name, brand, payload, updated_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(barcode) DO UPDATE SET
                name = excluded.name,
                brand = excluded.brand,
                payload = excluded.payload,
                updated_at = excluded.updated_at;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw CacheError.prepareFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, product.barcode, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, product.name, -1, SQLITE_TRANSIENT)
        if let brand = product.brand {
            sqlite3_bind_text(stmt, 3, brand, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 3)
        }
        _ = payload.withUnsafeBytes { raw in
            sqlite3_bind_blob(stmt, 4, raw.baseAddress, Int32(payload.count), SQLITE_TRANSIENT)
        }
        sqlite3_bind_double(stmt, 5, Date().timeIntervalSince1970)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw CacheError.stepFailed(lastErrorMessage())
        }
    }

    /// Toplam cache satır sayısını döner (debug/UI için).
    public func count() throws -> Int {
        let sql = "SELECT COUNT(*) FROM products;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw CacheError.prepareFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    /// Cache'i temizler.
    public func clear() throws {
        let sql = "DELETE FROM products;"
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw CacheError.stepFailed(lastErrorMessage())
        }
    }

    // MARK: - Internals

    /// DB'yi açar ve şemayı kurar.
    private static func openAndMigrate(at dbURL: URL) throws -> OpaquePointer? {
        var db: OpaquePointer?
        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            let message = lastErrorMessage(for: db)
            if db != nil {
                sqlite3_close(db)
            }
            throw CacheError.openFailed(message)
        }
        let createSQL = """
            CREATE TABLE IF NOT EXISTS products (
                barcode    TEXT PRIMARY KEY NOT NULL,
                name       TEXT NOT NULL,
                brand      TEXT,
                payload    BLOB NOT NULL,
                updated_at REAL NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_products_updated_at
                ON products(updated_at);
            """
        if sqlite3_exec(db, createSQL, nil, nil, nil) != SQLITE_OK {
            let message = lastErrorMessage(for: db)
            sqlite3_close(db)
            throw CacheError.stepFailed(message)
        }
        return db
    }

    /// SQLite son hata mesajını UTF-8 String olarak çevirir.
    private func lastErrorMessage() -> String {
        Self.lastErrorMessage(for: db)
    }

    private static func lastErrorMessage(for db: OpaquePointer?) -> String {
        guard let cstr = sqlite3_errmsg(db) else { return "unknown" }
        return String(cString: cstr)
    }
}
