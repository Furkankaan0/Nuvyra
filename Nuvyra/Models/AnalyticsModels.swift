import Foundation

enum AnalyticsPeriod: String, CaseIterable, Identifiable, Equatable, Hashable {
    case weekly
    case monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly: "Haftalık"
        case .monthly: "Aylık"
        }
    }

    var dayCount: Int {
        switch self {
        case .weekly: 7
        case .monthly: 30
        }
    }
}

struct ChartDataPoint: Identifiable, Equatable {
    var date: Date
    var value: Double
    var target: Double?
    var label: String

    var id: String {
        "\(label)-\(Int(date.timeIntervalSince1970))"
    }
}

enum MacroKind: String, CaseIterable, Identifiable, Equatable, Hashable {
    case protein
    case carbs
    case fat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .protein: "Protein"
        case .carbs: "Karbonhidrat"
        case .fat: "Yağ"
        }
    }
}

struct MacroDistribution: Identifiable, Equatable {
    var kind: MacroKind
    var grams: Double
    var calories: Double
    var percentage: Double

    var id: MacroKind { kind }
}

struct DailyAnalyticsRecord: Identifiable, Equatable {
    var date: Date
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var waterMl: Int
    var steps: Int
    var activeEnergy: Double
    var distanceKm: Double
    var calorieGoal: Int
    var proteinGoal: Int
    var waterGoalMl: Int
    var stepGoal: Int

    var id: Date { date }

    var completionScore: Double {
        let calorieScore: Double
        if calories == 0 {
            calorieScore = 0
        } else {
            let distanceFromGoal = abs(Double(calories - calorieGoal)) / max(Double(calorieGoal), 1)
            calorieScore = max(0, 1 - distanceFromGoal)
        }

        let proteinScore = min(protein / max(Double(proteinGoal), 1), 1)
        let waterScore = min(Double(waterMl) / max(Double(waterGoalMl), 1), 1)
        let stepScore = min(Double(steps) / max(Double(stepGoal), 1), 1)
        return (calorieScore + proteinScore + waterScore + stepScore) / 4
    }

    var hasAnySignal: Bool {
        calories > 0 || waterMl > 0 || steps > 0 || activeEnergy > 0 || distanceKm > 0
    }
}

struct AnalyticsSummary: Equatable {
    var period: AnalyticsPeriod
    var title: String
    var dateRangeText: String
    var records: [DailyAnalyticsRecord]
    var caloriePoints: [ChartDataPoint]
    var proteinPoints: [ChartDataPoint]
    var waterPoints: [ChartDataPoint]
    var stepPoints: [ChartDataPoint]
    var macroDistribution: [MacroDistribution]
    var targetCompletionRate: Double
    var aiInsight: String
    var bestDay: Date?
    var averageCalories: Int
    var averageProtein: Int
    var averageSteps: Int
    var averageWaterMl: Int
    var totalDistanceKm: Double

    var isEmpty: Bool {
        records.allSatisfy { !$0.hasAnySignal }
    }

    var bestDayText: String {
        guard let bestDay else { return "Henüz oluşmadı" }
        return DateFormatter.nuvyraWeekday.string(from: bestDay)
    }

    var completionPercentText: String {
        "\(Int((targetCompletionRate * 100).rounded()))%"
    }
}

struct WeeklySummary: Equatable {
    var analytics: AnalyticsSummary
}

struct MonthlySummary: Equatable {
    var analytics: AnalyticsSummary
}

enum AnalyticsDataSampler {
    static func downsample(_ records: [DailyAnalyticsRecord], maxPoints: Int) -> [DailyAnalyticsRecord] {
        guard records.count > maxPoints, maxPoints > 0 else { return records }
        let chunkSize = Int(ceil(Double(records.count) / Double(maxPoints)))
        return stride(from: 0, to: records.count, by: chunkSize).map { start in
            let chunk = Array(records[start..<min(start + chunkSize, records.count)])
            return aggregate(chunk)
        }
    }

    private static func aggregate(_ records: [DailyAnalyticsRecord]) -> DailyAnalyticsRecord {
        guard let first = records.first else {
            return DailyAnalyticsRecord(
                date: Date(),
                calories: 0,
                protein: 0,
                carbs: 0,
                fat: 0,
                waterMl: 0,
                steps: 0,
                activeEnergy: 0,
                distanceKm: 0,
                calorieGoal: 1_900,
                proteinGoal: 120,
                waterGoalMl: 2_000,
                stepGoal: 7_500
            )
        }

        let count = max(records.count, 1)
        return DailyAnalyticsRecord(
            date: first.date,
            calories: records.map(\.calories).reduce(0, +) / count,
            protein: records.map(\.protein).reduce(0, +) / Double(count),
            carbs: records.map(\.carbs).reduce(0, +) / Double(count),
            fat: records.map(\.fat).reduce(0, +) / Double(count),
            waterMl: records.map(\.waterMl).reduce(0, +) / count,
            steps: records.map(\.steps).reduce(0, +) / count,
            activeEnergy: records.map(\.activeEnergy).reduce(0, +) / Double(count),
            distanceKm: records.map(\.distanceKm).reduce(0, +) / Double(count),
            calorieGoal: first.calorieGoal,
            proteinGoal: first.proteinGoal,
            waterGoalMl: first.waterGoalMl,
            stepGoal: first.stepGoal
        )
    }
}
