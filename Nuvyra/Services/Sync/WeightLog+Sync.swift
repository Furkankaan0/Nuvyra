import CloudKit
import Foundation

/// First model wired up to CloudKit — weight + body-composition rows.
/// Picked first because:
///   - Single owner: no cross-record relationships to resolve.
///   - Low row count (one entry/day max): well within CloudKit free
///     quota even for power users.
///   - Highest user-facing value: weight history survives device loss.
///
/// To opt another `@Model` in, conform it to `NuvyraSyncable` the same
/// way: pick a recordType string, derive a stable `CKRecord.ID`, and
/// implement `writeFields(to:)` + `init(from:)`. The sync service
/// stays generic across every model added this way.
extension WeightLog: NuvyraSyncable {
    static var cloudRecordType: CKRecord.RecordType { "WeightLog" }

    var cloudRecordID: CKRecord.ID {
        // We derive the record ID from the model's own UUID so re-syncs
        // are idempotent. Stable across device boundaries — exactly
        // what CloudKit's last-write-wins relies on.
        CKRecord.ID(recordName: id.uuidString)
    }

    func writeFields(to record: CKRecord) {
        record["date"] = date as CKRecordValue
        record["weightKg"] = weightKg as CKRecordValue
        record["source"] = source as CKRecordValue
        if let note { record["note"] = note as CKRecordValue }
        if let waistCm { record["waistCm"] = waistCm as CKRecordValue }
        if let hipCm { record["hipCm"] = hipCm as CKRecordValue }
        if let chestCm { record["chestCm"] = chestCm as CKRecordValue }
        if let shoulderCm { record["shoulderCm"] = shoulderCm as CKRecordValue }
        if let neckCm { record["neckCm"] = neckCm as CKRecordValue }
        if let bicepsCm { record["bicepsCm"] = bicepsCm as CKRecordValue }
        if let thighCm { record["thighCm"] = thighCm as CKRecordValue }
        if let bodyFatPercent { record["bodyFatPercent"] = bodyFatPercent as CKRecordValue }
        record["createdAt"] = createdAt as CKRecordValue
    }

    convenience init?(from record: CKRecord) {
        guard
            let id = UUID(uuidString: record.recordID.recordName),
            let date = record["date"] as? Date,
            let weight = record["weightKg"] as? Double
        else {
            return nil
        }
        self.init(
            id: id,
            date: date,
            weightKg: weight,
            source: (record["source"] as? String) ?? "manual",
            note: record["note"] as? String,
            createdAt: (record["createdAt"] as? Date) ?? Date(),
            waistCm: record["waistCm"] as? Double,
            hipCm: record["hipCm"] as? Double,
            chestCm: record["chestCm"] as? Double,
            shoulderCm: record["shoulderCm"] as? Double,
            neckCm: record["neckCm"] as? Double,
            bicepsCm: record["bicepsCm"] as? Double,
            thighCm: record["thighCm"] as? Double,
            bodyFatPercent: record["bodyFatPercent"] as? Double
        )
    }
}
