import Foundation
import SwiftData

@MainActor
final class InsightsViewModel: ObservableObject {
    @Published var averageCalories = 0
    @Published var averageSteps = 0
    @Published var waterAverage = 0
    @Published var trendText = "Ritmin oluşmaya başlıyor. Küçük tekrarlar, büyük değişimlerden daha sürdürülebilir."

    func load(context: ModelContext, dependencies: DependencyContainer) {
        do {
            let meals = try dependencies.nutritionRepository(context: context).meals(on: Date())
            let activity = dependencies.activityRepository(context: context)
            let water = dependencies.waterRepository(context: context)
            averageCalories = meals.reduce(0) { $0 + $1.calories }
            averageSteps = try activity.averageSteps(days: 7)
            waterAverage = try water.totalWater(on: Date())
            trendText = makeTrendText(steps: averageSteps, calories: averageCalories, water: waterAverage)
        } catch {}
    }

    private func makeTrendText(steps: Int, calories: Int, water: Int) -> String {
        if steps > 6_000 && water >= 1_500 {
            return "Bu hafta yürüyüş ve su ritmin iyi bir zemine oturuyor. Aynı sakin düzeni koruyabilirsin."
        }
        if steps < 4_000 {
            return "Adım ortalaman düşük kalmış. Bugün 12 dakikalık kısa bir yürüyüş ritmini toparlayabilir."
        }
        if calories == 0 {
            return "Öğün kayıtlarını birkaç güne yaydığında kalori dengesi daha net görünür."
        }
        return "Haftalık ritminde küçük ama görünür bir temel oluşuyor. Bugün sadece devam etmek yeterli."
    }
}
