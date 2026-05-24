import Combine
import Foundation
import SwiftData

@MainActor
final class AICoachViewModel: ObservableObject {
    @Published var insights: [AICoachInsight] = []
    @Published var messages: [AICoachMessage] = []
    @Published var pendingMessage: String = ""
    @Published var isLoadingInsights = false
    @Published var isCoachTyping = false
    @Published var errorMessage: String?

    private let service: AICoachService
    private var contextSnapshot: AICoachContext = .empty

    init(service: AICoachService? = nil) {
        self.service = service ?? MockAICoachService()
    }

    var hasMessages: Bool { !messages.isEmpty }
    var canSend: Bool {
        !pendingMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCoachTyping
    }

    // MARK: - Loading
    func load(context modelContext: ModelContext, dependencies: DependencyContainer) async {
        isLoadingInsights = true
        errorMessage = nil
        defer { isLoadingInsights = false }
        do {
            contextSnapshot = await makeContext(modelContext: modelContext, dependencies: dependencies)
            insights = try await service.generateInsights(context: contextSnapshot)
        } catch {
            errorMessage = (error as? AICoachError)?.errorDescription ?? "İçgörüler alınamadı."
            insights = []
        }
    }

    // MARK: - Chat
    func sendCurrentMessage() async {
        let trimmed = pendingMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isCoachTyping else { return }
        pendingMessage = ""
        let userMessage = AICoachMessage(role: .user, text: trimmed)
        messages.append(userMessage)
        await fetchReply(for: trimmed)
    }

    func send(example: AICoachExampleQuestion) async {
        guard !isCoachTyping else { return }
        let userMessage = AICoachMessage(role: .user, text: example.rawValue)
        messages.append(userMessage)
        await fetchReply(for: example.rawValue)
    }

    func clearChat() {
        messages = []
        errorMessage = nil
    }

    private func fetchReply(for text: String) async {
        isCoachTyping = true
        defer { isCoachTyping = false }
        do {
            let reply = try await service.reply(to: text, context: contextSnapshot, history: messages)
            messages.append(reply)
        } catch {
            errorMessage = (error as? AICoachError)?.errorDescription ?? "Koç şu an cevap veremiyor."
        }
    }

    // MARK: - Context builder
    private func makeContext(modelContext: ModelContext, dependencies: DependencyContainer) async -> AICoachContext {
        do {
            let userRepository = dependencies.userRepository(context: modelContext)
            let nutritionRepository = dependencies.nutritionRepository(context: modelContext)
            let waterRepository = dependencies.waterRepository(context: modelContext)
            let profile = try? userRepository.profile()
            let summary = try? nutritionRepository.dailySummary(on: Date())
            let water = try? waterRepository.totalWater(on: Date())
            let weeklyWater = (try? waterRepository.weeklyTotals(endingOn: Date()).map(\.totalMl)) ?? []
            let snapshot = await dependencies.healthService.todaySnapshot()
            return AICoachContext(
                greetingName: profile?.name.isEmpty == false ? profile!.name : "Hoş geldin",
                caloriesConsumed: summary?.totals.calories ?? 0,
                caloriesTarget: profile?.dailyCalorieTarget ?? 1_900,
                proteinGrams: summary?.totals.protein ?? 0,
                proteinTargetGrams: Double(profile?.dailyProteinTargetGrams ?? 120),
                waterMl: water ?? 0,
                waterTargetMl: profile?.dailyWaterTargetMl ?? 2_000,
                steps: snapshot.steps,
                stepTarget: profile?.dailyStepTarget ?? 7_500,
                weeklyAverageSteps: 0, // Walking weekly is computed by ActivityRepository — kept conservative here.
                weeklyAverageWaterMl: weeklyWater.isEmpty ? 0 : weeklyWater.reduce(0, +) / weeklyWater.count
            )
        }
    }
}
