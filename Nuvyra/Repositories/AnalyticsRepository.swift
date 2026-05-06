import Foundation
import SwiftData

@MainActor
protocol AnalyticsRepository {
    func weeklySummary() throws -> WeeklySummary
    func monthlySummary() throws -> MonthlySummary
}

@MainActor
final class SwiftDataAnalyticsRepository: AnalyticsRepository {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .nuvyra) {
        self.context = context
        self.calendar = calendar
    }

    func weeklySummary() throws -> WeeklySummary {
        let analytics = try makeSummary(period: .weekly, maxChartPoints: 7)
        return WeeklySummary(analytics: analytics)
    }

    func monthlySummary() throws -> MonthlySummary {
        let analytics = try makeSummary(period: .monthly, maxChartPoints: 30)
        return MonthlySummary(analytics: analytics)
    }

    private func makeSummary(period: AnalyticsPeriod, maxChartPoints: Int) throws -> AnalyticsSummary {
        let dates = dayRange(days: period.dayCount)
        let start = dates.first ?? calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: dates.last ?? start) ?? Date()
        let profile = try fetchProfile()
        let goals = try fetchNutritionGoal()
        let meals = try fetchMeals(start: start, end: end)
        let waterEntries = try fetchWaterEntries(start: start, end: end)
        let walkingLogs = try fetchWalkingLogs(start: start, end: end)

        let records = dates.map { date in
            let day = calendar.startOfDay(for: date)
            let mealsOnDay = meals.filter { calendar.isDate($0.date, inSameDayAs: day) }
            let waterOnDay = waterEntries.filter { calendar.isDate($0.date, inSameDayAs: day) }
            let walkingOnDay = walkingLogs.first { calendar.isDate($0.date, inSameDayAs: day) }

            return DailyAnalyticsRecord(
                date: day,
                calories: mealsOnDay.map(\.calories).reduce(0, +),
                protein: mealsOnDay.compactMap(\.protein).reduce(0, +),
                carbs: mealsOnDay.compactMap(\.carbs).reduce(0, +),
                fat: mealsOnDay.compactMap(\.fat).reduce(0, +),
                waterMl: waterOnDay.map(\.amountMl).reduce(0, +),
                steps: walkingOnDay?.steps ?? 0,
                activeEnergy: walkingOnDay?.activeEnergy ?? 0,
                distanceKm: walkingOnDay?.distanceKm ?? 0,
                calorieGoal: profile?.dailyCalorieTarget ?? goals?.dailyCalories ?? 1_900,
                proteinGoal: profile?.dailyProteinTargetGrams ?? Int(goals?.proteinGrams ?? 120),
                waterGoalMl: profile?.dailyWaterTargetMl ?? 2_000,
                stepGoal: profile?.dailyStepTarget ?? 7_500
            )
        }

        let chartRecords = AnalyticsDataSampler.downsample(records, maxPoints: maxChartPoints)
        let macroDistribution = makeMacroDistribution(records: records)
        let bestDay = records.max(by: { $0.completionScore < $1.completionScore })?.date
        let nonEmptyRecords = records.filter(\.hasAnySignal)
        let averageDenominator = max(nonEmptyRecords.count, 1)
        let averageCalories = nonEmptyRecords.map(\.calories).reduce(0, +) / averageDenominator
        let averageProtein = Int((nonEmptyRecords.map(\.protein).reduce(0, +) / Double(averageDenominator)).rounded())
        let averageSteps = nonEmptyRecords.map(\.steps).reduce(0, +) / averageDenominator
        let averageWater = nonEmptyRecords.map(\.waterMl).reduce(0, +) / averageDenominator
        let completion = records.map(\.completionScore).reduce(0, +) / Double(max(records.count, 1))

        return AnalyticsSummary(
            period: period,
            title: period.title,
            dateRangeText: dateRangeText(start: start, end: dates.last ?? start),
            records: records,
            caloriePoints: makePoints(records: chartRecords, label: "Kalori", value: { Double($0.calories) }, target: { Double($0.calorieGoal) }),
            proteinPoints: makePoints(records: chartRecords, label: "Protein", value: { $0.protein }, target: { Double($0.proteinGoal) }),
            waterPoints: makePoints(records: chartRecords, label: "Su", value: { Double($0.waterMl) }, target: { Double($0.waterGoalMl) }),
            stepPoints: makePoints(records: chartRecords, label: "Adım", value: { Double($0.steps) }, target: { Double($0.stepGoal) }),
            macroDistribution: macroDistribution,
            targetCompletionRate: completion,
            aiInsight: makeInsight(period: period, completion: completion, records: records, averageSteps: averageSteps, averageWater: averageWater),
            bestDay: bestDay,
            averageCalories: averageCalories,
            averageProtein: averageProtein,
            averageSteps: averageSteps,
            averageWaterMl: averageWater,
            totalDistanceKm: records.map(\.distanceKm).reduce(0, +)
        )
    }

    private func fetchProfile() throws -> UserProfile? {
        try context.fetch(FetchDescriptor<UserProfile>()).first
    }

    private func fetchNutritionGoal() throws -> NutritionGoal? {
        try context.fetch(FetchDescriptor<NutritionGoal>()).first
    }

    private func fetchMeals(start: Date, end: Date) throws -> [MealEntry] {
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date)]
        )
        return try context.fetch(descriptor)
    }

    private func fetchWaterEntries(start: Date, end: Date) throws -> [WaterEntry] {
        let descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date)]
        )
        return try context.fetch(descriptor)
    }

    private func fetchWalkingLogs(start: Date, end: Date) throws -> [WalkingLog] {
        let descriptor = FetchDescriptor<WalkingLog>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date)]
        )
        return try context.fetch(descriptor)
    }

    private func dayRange(days: Int) -> [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<days).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - (days - 1), to: today)
        }
    }

    private func makePoints(
        records: [DailyAnalyticsRecord],
        label: String,
        value: (DailyAnalyticsRecord) -> Double,
        target: (DailyAnalyticsRecord) -> Double
    ) -> [ChartDataPoint] {
        records.map {
            ChartDataPoint(date: $0.date, value: value($0), target: target($0), label: label)
        }
    }

    private func makeMacroDistribution(records: [DailyAnalyticsRecord]) -> [MacroDistribution] {
        let protein = records.map(\.protein).reduce(0, +)
        let carbs = records.map(\.carbs).reduce(0, +)
        let fat = records.map(\.fat).reduce(0, +)
        let proteinCalories = protein * 4
        let carbsCalories = carbs * 4
        let fatCalories = fat * 9
        let totalCalories = max(proteinCalories + carbsCalories + fatCalories, 1)

        return [
            MacroDistribution(kind: .protein, grams: protein, calories: proteinCalories, percentage: proteinCalories / totalCalories),
            MacroDistribution(kind: .carbs, grams: carbs, calories: carbsCalories, percentage: carbsCalories / totalCalories),
            MacroDistribution(kind: .fat, grams: fat, calories: fatCalories, percentage: fatCalories / totalCalories)
        ]
    }

    private func makeInsight(
        period: AnalyticsPeriod,
        completion: Double,
        records: [DailyAnalyticsRecord],
        averageSteps: Int,
        averageWater: Int
    ) -> String {
        guard records.contains(where: \.hasAnySignal) else {
            return "Henüz yeterli kayıt yok. Birkaç öğün, su ve yürüyüş kaydı eklediğinde Nuvyra ritmini daha net yorumlayacak."
        }

        if completion >= 0.72 {
            return "\(period.title) ritmin güçlü görünüyor. Kalori, su ve adım dengen aynı sakin çizgide devam edebilir."
        }

        if averageSteps < 4_500 {
            return "Adım ortalaman düşük kalmış. Bugün 10-12 dakikalık kısa bir yürüyüş haftalık ritmi toparlamaya yeterli olabilir."
        }

        if averageWater < 1_500 {
            return "Su ritminde küçük bir boşluk var. Gün içine iki nazik +250 ml eklemek hedefe yaklaşmanı kolaylaştırır."
        }

        return "Ritmin oluşuyor. Nuvyra bu dönemde büyük değişiklik yerine küçük tekrarları korumanı önerir."
    }

    private func dateRangeText(start: Date, end: Date) -> String {
        "\(DateFormatter.nuvyraShortDate.string(from: start)) - \(DateFormatter.nuvyraShortDate.string(from: end))"
    }
}
