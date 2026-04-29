import Foundation
import SwiftData

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var pageIndex = 0
    @Published var selectedGoal: GoalType = .walkMore
    @Published var name = "Furkan"
    @Published var healthState: HealthAuthorizationState = .notDetermined
    @Published var wantsNotifications = true
    @Published var isCompleting = false

    let pages: [OnboardingPageContent] = [
        OnboardingPageContent(title: "Ritmini yeniden kur.", subtitle: "Nuvyra, beslenme ve yürüyüş alışkanlığını sakin bir düzende takip eder.", systemImage: "figure.walk.circle"),
        OnboardingPageContent(title: "Kalorini karmaşa olmadan gör.", subtitle: "Öğünlerini hızlı ekle, günün dengesini tek bakışta anla.", systemImage: "fork.knife.circle"),
        OnboardingPageContent(title: "Yürüyüşü alışkanlığa çevir.", subtitle: "Adım hedeflerin, streak'lerin ve haftalık ritmin tek yerde.", systemImage: "shoeprints.fill"),
        OnboardingPageContent(title: "iPhone'unla birlikte çalışır.", subtitle: "Health verilerini izin verdiğin ölçüde okur. Verilerin sende kalır.", systemImage: "heart.text.square"),
        OnboardingPageContent(title: "Hedefini seç.", subtitle: "Bugün için gerçekçi bir kalori, su ve adım hedefi oluşturalım.", systemImage: "target")
    ]

    var isLastPage: Bool { pageIndex == pages.count - 1 }

    func next() {
        guard !isLastPage else { return }
        pageIndex += 1
    }

    func back() {
        guard pageIndex > 0 else { return }
        pageIndex -= 1
    }

    func requestHealth(dependencies: DependencyContainer) async {
        await dependencies.analytics.track(.healthPermissionRequested, payload: AnalyticsPayload())
        healthState = await dependencies.healthService.requestAuthorization()
        if healthState == .sharingAuthorized {
            await dependencies.analytics.track(.healthPermissionGranted, payload: AnalyticsPayload())
        }
    }

    func complete(context: ModelContext, dependencies: DependencyContainer) async {
        isCompleting = true
        defer { isCompleting = false }
        do {
            let repository = dependencies.userRepository(context: context)
            _ = try repository.saveOnboardingProfile(name: name, goalType: selectedGoal)
            if wantsNotifications {
                let granted = await dependencies.notificationService.requestAuthorization()
                if granted { await dependencies.notificationService.scheduleGentleReminders() }
            }
            await dependencies.analytics.track(.onboardingCompleted, payload: AnalyticsPayload(values: ["goal": selectedGoal.rawValue]))
        } catch {
            assertionFailure("Onboarding completion failed: \(error)")
        }
    }
}

struct OnboardingPageContent: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
}
