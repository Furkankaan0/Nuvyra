import CloudKit
import Foundation

/// CloudKit bridge for nutrition rows. We sync the semantic meal data and keep
/// large local-only media (`photoData`) on-device for now to avoid surprising
/// iCloud quota use.
extension MealEntry: NuvyraSyncable {
    static var cloudRecordType: CKRecord.RecordType { "MealEntry" }

    var cloudRecordID: CKRecord.ID {
        CKRecord.ID(recordName: id.uuidString)
    }

    func writeFields(to record: CKRecord) {
        record["date"] = date as CKRecordValue
        record["mealType"] = mealType.rawValue as CKRecordValue
        record["name"] = name as CKRecordValue
        record["calories"] = NSNumber(value: calories)
        if let protein { record["protein"] = protein as CKRecordValue }
        if let carbs { record["carbs"] = carbs as CKRecordValue }
        if let fat { record["fat"] = fat as CKRecordValue }
        record["portionDescription"] = portionDescription as CKRecordValue
        record["isFavorite"] = NSNumber(value: isFavorite)
        record["isVerifiedTurkishFood"] = NSNumber(value: isVerifiedTurkishFood)
        record["isEstimated"] = NSNumber(value: isEstimated)
        record["createdAt"] = createdAt as CKRecordValue
        if let fiberGrams { record["fiberGrams"] = fiberGrams as CKRecordValue }
        if let sodiumMg { record["sodiumMg"] = sodiumMg as CKRecordValue }
        if let sugarGrams { record["sugarGrams"] = sugarGrams as CKRecordValue }
        if let saturatedFatGrams { record["saturatedFatGrams"] = saturatedFatGrams as CKRecordValue }
    }

    convenience init?(from record: CKRecord) {
        guard
            let id = UUID(uuidString: record.recordID.recordName),
            let date = record["date"] as? Date,
            let mealTypeRaw = record["mealType"] as? String,
            let mealType = MealType(rawValue: mealTypeRaw),
            let name = record["name"] as? String,
            let calories = record.nuvyraMealInt(for: "calories")
        else {
            return nil
        }

        self.init(
            id: id,
            date: date,
            mealType: mealType,
            name: name,
            calories: calories,
            protein: record["protein"] as? Double,
            carbs: record["carbs"] as? Double,
            fat: record["fat"] as? Double,
            portionDescription: (record["portionDescription"] as? String) ?? "1 porsiyon",
            isFavorite: record.nuvyraMealBool(for: "isFavorite") ?? false,
            isVerifiedTurkishFood: record.nuvyraMealBool(for: "isVerifiedTurkishFood") ?? false,
            isEstimated: record.nuvyraMealBool(for: "isEstimated") ?? true,
            createdAt: (record["createdAt"] as? Date) ?? Date(),
            fiberGrams: record["fiberGrams"] as? Double,
            sodiumMg: record["sodiumMg"] as? Double,
            sugarGrams: record["sugarGrams"] as? Double,
            saturatedFatGrams: record["saturatedFatGrams"] as? Double,
            photoData: nil
        )
    }
}

private extension CKRecord {
    func nuvyraMealInt(for key: String) -> Int? {
        if let intValue = self[key] as? Int { return intValue }
        if let number = self[key] as? NSNumber { return number.intValue }
        return nil
    }

    func nuvyraMealBool(for key: String) -> Bool? {
        if let boolValue = self[key] as? Bool { return boolValue }
        if let number = self[key] as? NSNumber { return number.boolValue }
        return nil
    }
}
