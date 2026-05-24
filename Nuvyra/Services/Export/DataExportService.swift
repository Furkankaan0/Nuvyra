import Foundation
import SwiftData

struct ExportedDataFile: Identifiable {
    let url: URL
    var id: URL { url }
}

@MainActor
final class DataExportService {
    private let context: ModelContext
    private let dateFormatter: ISO8601DateFormatter

    init(context: ModelContext) {
        self.context = context
        self.dateFormatter = ISO8601DateFormatter()
        self.dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func exportCSV() throws -> ExportedDataFile {
        let csv = try makeCSV()
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Nuvyra-Data-Export-\(Self.fileStamp()).csv")
        try csv.write(to: fileURL, atomically: true, encoding: .utf8)
        return ExportedDataFile(url: fileURL)
    }

    private func makeCSV() throws -> String {
        var rows: [[String]] = [["section", "id", "date", "type", "name", "value_1", "value_2", "value_3", "value_4", "note"]]

        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        for profile in profiles {
            rows.append([
                "profile",
                profile.id.uuidString,
                iso(profile.updatedAt),
                profile.goalType.rawValue,
                profile.name,
                String(profile.age),
                String(Int(profile.heightCm)),
                String(Int(profile.weightKg)),
                String(profile.dailyCalorieTarget),
                "water_ml=\(profile.dailyWaterTargetMl);steps=\(profile.dailyStepTarget);protein_g=\(profile.dailyProteinTargetGrams)"
            ])
        }

        let meals = try context.fetch(FetchDescriptor<MealEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
        for meal in meals {
            rows.append([
                "meal",
                meal.id.uuidString,
                iso(meal.date),
                meal.mealType.rawValue,
                meal.name,
                String(meal.calories),
                gram(meal.protein),
                gram(meal.carbs),
                gram(meal.fat),
                "portion=\(meal.portionDescription);estimated=\(meal.isEstimated);favorite=\(meal.isFavorite)"
            ])
        }

        let waterEntries = try context.fetch(FetchDescriptor<WaterEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
        for water in waterEntries {
            rows.append([
                "water",
                water.id.uuidString,
                iso(water.date),
                "water_ml",
                "Su",
                String(water.amountMl),
                "",
                "",
                "",
                ""
            ])
        }

        let walks = try context.fetch(FetchDescriptor<WalkingLog>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
        for walk in walks {
            rows.append([
                "walking",
                walk.id.uuidString,
                iso(walk.date),
                "daily_steps",
                "Yuruyus",
                String(walk.steps),
                String(Int(walk.activeEnergy.rounded())),
                walk.distanceKm.map { String(format: "%.2f", $0) } ?? "",
                String(walk.goalCompleted),
                "value_1=steps;value_2=active_energy;value_3=distance_km"
            ])
        }

        let dailyLogs = try context.fetch(FetchDescriptor<DailyLog>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
        for log in dailyLogs {
            rows.append([
                "daily_log",
                log.id.uuidString,
                iso(log.date),
                log.mood?.rawValue ?? "daily",
                "Gunluk ritim",
                String(log.totalCalories),
                String(log.caloriesBurned),
                String(log.steps),
                String(log.waterMl),
                log.note ?? ""
            ])
        }

        return rows.map(csvLine).joined(separator: "\n") + "\n"
    }

    private func iso(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    private func gram(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.1f", value)
    }

    private func csvLine(_ fields: [String]) -> String {
        fields.map { field in
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        .joined(separator: ",")
    }

    private static func fileStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
