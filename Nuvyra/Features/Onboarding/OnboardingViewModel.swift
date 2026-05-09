import Foundation
import SwiftData

enum OnboardingStep: String, CaseIterable, Identifiable {
    case welcome
    case gender
    case age
    case height
    case weight
    case activity
    case goal
    case pace
    case goalWeight
    case summary
    case health
    case premium

    var id: String { rawValue }
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var pageIndex = 0
    @Published var name = ""
    @Published var selectedGender: Gender = .preferNotToSay
    @Published var age = 30
    @Published var heightCm = 175
    @Published var weightKg = 78
    @Published var activityLevel: ActivityLevel = .lightlyActive
    @Published var selectedGoal: GoalType = .healthyLiving
    @Published var goalPace: GoalPace = .balanced
    @Published var usesGoalWeight = false
    @Published var targetWeightKg = 74
    @Published var healthState: HealthAuthorizationState = .notDetermined
    @Published var wantsNotifications = true
    @Published var isCompleting = false
    @Published var errorMessage: String?

    let pages: [OnboardingPageContent] = [
        OnboardingPageContent(
            eyebrow: "Nuvyra",
            title: "Nuvyra'ya hoş geldin.",
            subtitle: "Beslenme, su ve yürüyüş ritmini tek bir sakin wellness akışında kur.",
            systemImage: "leaf.fill",
            metric: "1 plan",
            metricCaption: "kişisel ritim",
            highlights: ["Katı diyet dili yok", "Hedeflerin kişisel bilgilerinden hesaplanır"]
        )
    ]

    private var orderedSteps: [OnboardingStep] {
        OnboardingStep.allCases.filter { step in
            if step == .pace { return selectedGoal.isPaceSensitive }
            return true
        }
    }

    var currentStep: OnboardingStep {
        let steps = orderedSteps
        return steps[min(pageIndex, steps.count - 1)]
    }

    var isLastPage: Bool { pageIndex == orderedSteps.count - 1 }
    var progress: Double { Double(pageIndex + 1) / Double(orderedSteps.count) }
    var stepLabel: String { "\(pageIndex + 1) / \(orderedSteps.count)" }
    var totalStepsCount: Int { orderedSteps.count }
    var canContinue: Bool {
        // All current steps allow continuing — selections always have a default value.
        // The summary, health, and premium steps are informational; the rest have selectors with defaults.
        true
    }
    var targets: CalculatedNutritionTargets { NutritionGoalCalculator.calculate(for: calculationInput) }
    var targetPreview: OnboardingTargetPreview {
        OnboardingTargetPreview(
            calories: targets.dailyCalories.formatted(.number.grouping(.automatic)),
            steps: targets.stepTarget.formatted(.number.grouping(.automatic)),
            water: targets.waterLitersText,
            note: "Protein \(targets.proteinGrams)g, karbonhidrat \(targets.carbsGrams)g, yağ \(targets.fatGrams)g olarak dengelendi."
        )
    }

    var calculationInput: NutritionGoalCalculationInput {
        NutritionGoalCalculationInput(
            age: age,
            gender: selectedGender,
            heightCm: Double(heightCm),
            weightKg: Double(weightKg),
            targetWeightKg: usesGoalWeight ? Double(targetWeightKg) : nil,
            activityLevel: activityLevel,
            goalType: selectedGoal,
            goalPace: goalPace
        )
    }

    var primaryButtonTitle: String {
        switch currentStep {
        case .welcome:
            "Devam"
        case .summary:
            "Apple Sağlık'ı ayarla"
        case .health:
            "Premium'u gör"
        case .premium:
            isCompleting ? "Ritmin hazırlanıyor" : "Dashboard'a geç"
        default:
            "Devam"
        }
    }

    var primaryButtonIcon: String {
        switch currentStep {
        case .premium: "sparkles"
        case .summary: "heart.text.square"
        default: "arrow.right"
        }
    }

    var healthStatusTitle: String {
        switch healthState {
        case .sharingAuthorized: "Apple Sağlık bağlı"
        case .sharingDenied: "Manuel mod hazır"
        case .unavailable: "Bu cihazda uygun değil"
        case .notDetermined: "Apple Sağlık isteğe bağlı"
        }
    }

    var healthStatusDescription: String {
        switch healthState {
        case .sharingAuthorized:
            "Adımların otomatik gelebilir. Nuvyra yalnızca günlük ritim içgörüleri için okur."
        case .sharingDenied:
            "Sorun değil. Nuvyra manuel modda çalışmaya devam eder."
        case .unavailable:
            "Bu cihazda HealthKit uygun görünmüyor. Uygulama manuel takiple açılır."
        case .notDetermined:
            "Adım ve aktif enerji verilerini izin verdiğin ölçüde okuyabiliriz."
        }
    }

    func next() {
        guard !isLastPage else { return }
        pageIndex = min(pageIndex + 1, orderedSteps.count - 1)
    }

    func back() {
        guard pageIndex > 0 else { return }
        pageIndex -= 1
    }

    func selectGoal(_ goal: GoalType) {
        selectedGoal = goal
        if !goal.isPaceSensitive, currentStep == .pace {
            pageIndex = orderedSteps.firstIndex(of: .goalWeight) ?? pageIndex
        }
    }

    func requestHealth(dependencies: DependencyContainer) async {
        await dependencies.analytics.track(.healthPermissionRequested, payload: AnalyticsPayload())
        healthState = await dependencies.healthService.requestAuthorization()
        if healthState == .sharingAuthorized {
            await dependencies.analytics.track(.healthPermissionGranted, payload: AnalyticsPayload())
        }
    }

    func complete(context: ModelContext, dependencies: DependencyContainer) async {
        guard !isCompleting else { return }
        isCompleting = true
        errorMessage = nil
        defer { isCompleting = false }

        do {
            let repository = dependencies.userRepository(context: context)
            let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try repository.savePersonalizedOnboardingProfile(
                name: cleanName,
                input: calculationInput,
                targets: targets
            )

            if wantsNotifications {
                let granted = await dependencies.notificationService.requestAuthorization()
                if granted {
                    var preferences = NotificationPreferences.default
                    preferences.masterEnabled = true
                    let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let personal = NotificationPersonalContext(
                        firstName: cleanName.isEmpty ? nil : cleanName,
                        goalType: selectedGoal,
                        activityLevel: activityLevel
                    )
                    await dependencies.notificationService.schedule(preferences: preferences, context: personal)
                    persistOnboardingPreferences(preferences, context: context)
                }
            }

            dependencies.haptics.goalCompleted()
            await dependencies.analytics.track(
                .onboardingCompleted,
                payload: AnalyticsPayload(values: [
                    "goal": selectedGoal.rawValue,
                    "activity_level": activityLevel.rawValue,
                    "goal_pace": selectedGoal.isPaceSensitive ? goalPace.rawValue : "not_applicable"
                ])
            )
        } catch {
            errorMessage = "Başlangıç planı kaydedilemedi. Lütfen tekrar dene."
        }
    }

    private func persistOnboardingPreferences(_ preferences: NotificationPreferences, context: ModelContext) {
        let descriptor = FetchDescriptor<AppSettings>()
        guard let settings = (try? context.fetch(descriptor))?.first else { return }
        settings.notificationPreferences = preferences
        try? context.save()
    }
}

struct OnboardingPageContent: Identifiable {
    let id = UUID()
    let eyebrow: String
    let title: String
    let subtitle: String
    let systemImage: String
    let metric: String
    let metricCaption: String
    let highlights: [String]
}

struct OnboardingTargetPreview: Equatable {
    let calories: String
    let steps: String
    let water: String
    let note: String
}
