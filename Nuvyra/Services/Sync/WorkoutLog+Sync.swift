import CloudKit
import Foundation

/// CloudKit bridge for manually logged workouts. HealthKit workouts are read-only
/// source data and stay out of Nuvyra's private database; user-created
/// `WorkoutLog` rows are the durable records we mirror.
extension WorkoutLog: NuvyraSyncable {
    static var cloudRecordType: CKRecord.RecordType { "WorkoutLog" }

    var cloudRecordID: CKRecord.ID {
        CKRecord.ID(recordName: id.uuidString)
    }

    func writeFields(to record: CKRecord) {
        record["date"] = date as CKRecordValue
        record["typeRaw"] = typeRaw as CKRecordValue
        record["durationMinutes"] = NSNumber(value: durationMinutes)
        record["caloriesBurned"] = NSNumber(value: caloriesBurned)
        if let distanceKm { record["distanceKm"] = distanceKm as CKRecordValue }
        if let note { record["note"] = note as CKRecordValue }
        record["sourceRaw"] = sourceRaw as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
    }

    convenience init?(from record: CKRecord) {
        guard
            let id = UUID(uuidString: record.recordID.recordName),
            let date = record["date"] as? Date,
            let typeRaw = record["typeRaw"] as? String,
            let type = WorkoutType(rawValue: typeRaw),
            let duration = record.nuvyraWorkoutInt(for: "durationMinutes"),
            let calories = record.nuvyraWorkoutInt(for: "caloriesBurned")
        else {
            return nil
        }

        self.init(
            id: id,
            date: date,
            type: type,
            durationMinutes: duration,
            caloriesBurned: calories,
            distanceKm: record["distanceKm"] as? Double,
            note: record["note"] as? String,
            source: WorkoutSource(rawValue: (record["sourceRaw"] as? String) ?? "") ?? .manual,
            createdAt: (record["createdAt"] as? Date) ?? Date()
        )
    }
}

private extension CKRecord {
    func nuvyraWorkoutInt(for key: String) -> Int? {
        if let intValue = self[key] as? Int { return intValue }
        if let number = self[key] as? NSNumber { return number.intValue }
        return nil
    }
}
