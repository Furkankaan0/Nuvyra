import Foundation
import SwiftData

@MainActor
final class AICoachViewModel: ObservableObject {
    @Published var insights: [AICoachInsight] = []
    @Published var messages: [AICoachMessage] = []
    @Published var inputText: String = ""
    @Published var isSending: Bool = false
    @Published var isLoadingInsights: Bool = false
    @Published var errorMessage: String?
    @Published var freeQuotaUsed: Int = 0

    let freeQuotaLimit: Int = 3

    private(set) var context: AICoachContext = .empty

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func remainingFreeQuota(isPremium: Bool) -> Int {
        isPremium ? .max : max(freeQuotaLimit - freeQuotaUsed, 0)
    }

    func hasReachedFreeLimit(isPremium: Bool) -> Bool {
        !isPremium && freeQuotaUsed >= freeQuotaLimit
    }

    func bootstrap(context modelContext: ModelContext, dependencies: DependencyContainer) async {
        await loadContext(modelContext: modelContext, dependencies: dependencies)
        await refreshInsights(dependencies: dependencies)
    }

    func refreshInsights(dependencies: DependencyContainer) async {
        isLoadingInsights = true
        defer { isLoadingInsights = false }
        insights = await dependencies.aiCoachService.dailyInsights(context: context)
    }

    func send(dependencies: DependencyContainer, isPremium: Bool) async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }
        if hasReachedFreeLimit(isPremium: isPremium) { return }

        let userMessage = AICoachMessage(role: .user, content: trimmed)
        messages.append(userMessage)
        inputText = ""
        isSending = true
        errorMessage = nil

        let typing = AICoachMessage.typingPlaceholder()
        messages.append(typing)

        do {
            let history = messages.filter { !$0.isTyping && $0.id != userMessage.id }
            let reply = try await dependencies.aiCoachService.reply(to: trimmed, history: history, context: context)
            messages.removeAll { $0.id == typing.id }
            messages.append(reply)
            freeQuotaUsed += 1
            await dependencies.analytics.track(.aiCoachQueryAsked, payload: AnalyticsPayload(values: ["length": "\(trimmed.count)"]))
        } catch {
            messages.removeAll { $0.id == typing.id }
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "AI Coach şu an yanıt veremiyor."
        }
        isSending = false
    }

    func selectExample(_ example: AICoachExampleQuestion) {
        inputText = example.text
    }

    private func loadContext(modelContext: ModelContext, dependencies: DependencyContainer) async {
        let userRepo = dependencies.userRepository(context: modelContext)
        let nutritionRepo = dependencies.nutritionRepository(context: modelContext)
        let waterRepo = dependencies.waterRepository(context: modelContext)
        let profile = (try? userRepo.profile()) ?? nil
        let meals = (try? nutritionRepo.meals(on: Date())) ?? []
        let waterMl = (try? waterRepo.totalWater(on: Date())) ?? 0
        let snapshot = await dependencies.healthService.todaySnapshot()

        let consumedProtein = meals.reduce(0.0) { $0 + ($1.protein ?? 0) }
        let consumedCarbs = meals.reduce(0.0) { $0 + ($1.carbs ?? 0) }
        let consumedFat = meals.reduce(0.0) { $0 + ($1.fat ?? 0) }
        let totalKcal = meals.reduce(0) { $0 + $1.calories }

        context = AICoachContext(
            caloriesConsumed: totalKcal,
            calorieTarget: profile?.dailyCalorieTarget ?? 1_900,
            burnedKcal: Int(snapshot.activeEnergy),
            proteinGrams: consumedProtein,
            proteinTargetGrams: Double(profile?.dailyProteinTargetGrams ?? 120),
            carbsGrams: consumedCarbs,
            carbsTargetGrams: Double(profile?.dailyCarbsTargetGrams ?? 210),
            fatGrams: consumedFat,
            fatTargetGrams: Double(profile?.dailyFatTargetGrams ?? 65),
            waterMl: waterMl,
            waterTargetMl: profile?.dailyWaterTargetMl ?? 2_000,
            steps: snapshot.steps,
            stepGoal: profile?.dailyStepTarget ?? 7_500,
            goalType: profile?.goalType,
            userName: profile?.name
        )
    }
}
