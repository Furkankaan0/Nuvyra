import CloudKit
import Foundation

/// CloudKit foundation. Today the app is local-first via SwiftData;
/// this service is the **bridge** that lets us promote selected
/// records to iCloud Private DB without rewriting the data layer.
///
/// Strategy:
///   1. Each `@Model` that opts into sync exposes a `CKRecord.RecordType`
///      via `NuvyraSyncable` conformance.
///   2. The service serialises the model into a `CKRecord` and pushes
///      to `iCloud.com.nuvyra.app` private database.
///   3. Errors are surfaced as `NuvyraSyncError` so the call sites
///      don't see CloudKit internals.
///
/// **What is NOT in scope here:**
///   - Bi-directional reconciliation (use `CKQuerySubscription` + a
///     dedicated `ChangeTokenStore` in a follow-up).
///   - Conflict resolution policies — first pass uses last-write-wins
///     on `modifiedAt`.
///   - User-visible UI; that lives in `ProfileView` toggle entries.
///
/// We deliberately keep CloudKit imports out of the model layer so the
/// app's local-first guarantee stays intact: if CloudKit is unavailable
/// (no iCloud account, country region restrictions, etc.) the rest of
/// the app keeps working.

/// CloudKit-side errors we surface to UI. The string forms are
/// localisation-ready via xcstrings keys.
enum NuvyraSyncError: Error, LocalizedError, Equatable {
    case iCloudUnavailable
    case noActiveAccount
    case networkFailure
    case quotaExceeded
    case unexpected

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable: "Bu cihazda iCloud kullanılamıyor."
        case .noActiveAccount: "Aktif iCloud hesabı bulunamadı. Ayarlar > Apple Kimliği üzerinden giriş yap."
        case .networkFailure: "iCloud bağlantısı sırasında ağ hatası oluştu."
        case .quotaExceeded: "iCloud alanın doldu. Ayarlar > iCloud > Depolama üzerinden alanı serbest bırak."
        case .unexpected: "iCloud senkronizasyonu başarısız oldu."
        }
    }
}

/// Any model that ships through CloudKit conforms to this. The
/// service uses the static `recordType` to bucket records and asks the
/// instance to populate / read its own fields, so the bridge stays
/// free of per-model branching.
protocol NuvyraSyncable {
    static var cloudRecordType: CKRecord.RecordType { get }
    var cloudRecordID: CKRecord.ID { get }
    func writeFields(to record: CKRecord)
    init?(from record: CKRecord)
}

@MainActor
protocol NuvyraCloudSyncService {
    /// Current account status. Snapshot — callers should re-check
    /// after a user action so changes from Settings.app are caught.
    func accountStatus() async -> CKAccountStatus

    /// Pushes a single record to the private DB. Idempotent — calling
    /// twice with the same `cloudRecordID` overwrites the existing
    /// record (last-write-wins by `modifiedAt`).
    func push<T: NuvyraSyncable>(_ value: T) async throws

    /// Fetches every record of a given type from the private DB.
    /// Designed for first-launch hydration; subsequent reconciliation
    /// will hook `CKQuerySubscription`s instead of polling.
    func fetchAll<T: NuvyraSyncable>(_ type: T.Type) async throws -> [T]
}

@MainActor
final class LiveNuvyraCloudSyncService: NuvyraCloudSyncService {

    /// Same container id we'll register on developer.apple.com. The
    /// `container.privateCloudDatabase` is the one Nuvyra uses; the
    /// public DB stays empty.
    static let containerIdentifier = "iCloud.com.nuvyra.app"

    private let container: CKContainer
    private let database: CKDatabase

    init(container: CKContainer = CKContainer(identifier: LiveNuvyraCloudSyncService.containerIdentifier)) {
        self.container = container
        self.database = container.privateCloudDatabase
    }

    func accountStatus() async -> CKAccountStatus {
        do {
            return try await container.accountStatus()
        } catch {
            return .couldNotDetermine
        }
    }

    func push<T: NuvyraSyncable>(_ value: T) async throws {
        let record = CKRecord(recordType: T.cloudRecordType, recordID: value.cloudRecordID)
        value.writeFields(to: record)
        do {
            _ = try await database.save(record)
        } catch let error as CKError {
            throw Self.translate(error)
        } catch {
            throw NuvyraSyncError.unexpected
        }
    }

    func fetchAll<T: NuvyraSyncable>(_ type: T.Type) async throws -> [T] {
        let query = CKQuery(recordType: T.cloudRecordType, predicate: NSPredicate(value: true))
        do {
            let (matchResults, _) = try await database.records(matching: query)
            return matchResults.compactMap { _, result in
                guard case .success(let record) = result else { return nil }
                return T(from: record)
            }
        } catch let error as CKError {
            throw Self.translate(error)
        } catch {
            throw NuvyraSyncError.unexpected
        }
    }

    /// Maps the noisy `CKError` codes onto the four user-facing buckets.
    /// We deliberately do not surface raw CloudKit errors — most of
    /// them are not user-actionable, and the few that are (quota,
    /// account) fit our enum cleanly.
    private static func translate(_ error: CKError) -> NuvyraSyncError {
        switch error.code {
        case .quotaExceeded: return .quotaExceeded
        case .networkUnavailable, .networkFailure, .serverResponseLost, .requestRateLimited:
            return .networkFailure
        case .accountTemporarilyUnavailable, .notAuthenticated:
            return .noActiveAccount
        default:
            return .unexpected
        }
    }
}

/// In-memory stub used by tests and previews. Keeps every pushed
/// record in a dictionary keyed by record type so tests can assert on
/// shape without spinning up a real CKContainer.
@MainActor
final class MockNuvyraCloudSyncService: NuvyraCloudSyncService {
    private(set) var pushed: [CKRecord.RecordType: [CKRecord]] = [:]
    var stubbedAccountStatus: CKAccountStatus = .available

    func accountStatus() async -> CKAccountStatus { stubbedAccountStatus }

    func push<T: NuvyraSyncable>(_ value: T) async throws {
        let record = CKRecord(recordType: T.cloudRecordType, recordID: value.cloudRecordID)
        value.writeFields(to: record)
        pushed[T.cloudRecordType, default: []].append(record)
    }

    func fetchAll<T: NuvyraSyncable>(_ type: T.Type) async throws -> [T] {
        let records = pushed[T.cloudRecordType] ?? []
        return records.compactMap(T.init(from:))
    }
}
