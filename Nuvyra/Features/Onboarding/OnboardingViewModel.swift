import Foundation
import SwiftData

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var pageIndex = 0
    @Published var selectedGoal: GoalType = .walkMore
    @Published var name = ""
    @Published var healthState: HealthAuthorizationState = .notDetermined
    @Published var wantsNotifications = true
    @Published var isCompleting = false
    @Published var errorMessage: String?

    let pages: [OnboardingPageContent] = [
        OnboardingPageContent(
            eyebrow: "Sakin başlangıç",
            title: "Ritmini yeniden kur.",
            subtitle: "Nuvyra, beslenme ve yürüyüş alışkanlığını sakin bir düzende takip eder.",
            systemImage: "leaf.fill",
            metric: "1 ekran",
            metricCaption: "günün dengesi",
            highlights: ["Katı diyet dili yok", "Kalori, su ve yürüyüş tek akışta"]
        ),
        OnboardingPageContent(
            eyebrow: "Beslenme",
            title: "Kalorini karmaşa olmadan gör.",
            subtitle: "Öğünlerini hızlı ekle, günün dengesini tek bakışta anla.",
            systemImage: "fork.knife",
            metric: "4 öğün",
            metricCaption: "sade takip",
            highlights: ["Türk yemekleri için hızlı seçim", "Değerler tahmini olarak gösterilir"]
        ),
        OnboardingPageContent(
            eyebrow: "Yürüyüş",
            title: "Yürüyüşü alışkanlığa çevir.",
            subtitle: "Adım hedeflerin, streak'lerin ve haftalık ritmin tek yerde.",
            systemImage: "figure.walk",
            metric: "12 dk",
            metricCaption: "mini görev",
            highlights: ["HealthKit adımları desteklenir", "Düşük günlerde suçluluk yok"]
        ),
        OnboardingPageContent(
            eyebrow: "Gizlilik",
            title: "iPhone'unla birlikte çalışır.",
            subtitle: "Apple Sağlık verilerini izin verdiğin ölçüde okur. Verilerin sende kalır.",
            systemImage: "lock.shield.fill",
            metric: "KVKK",
            metricCaption: "hazır yaklaşım",
            highlights: ["Sağlık verisi reklam için kullanılmaz", "İzinleri istediğin zaman kapatabilirsin"]
        ),
        OnboardingPageContent(
            eyebrow: "Kişisel hedef",
            title: "Hedefini seç.",
            subtitle: "Bugün için gerçekçi bir kalori, su ve adım hedefi oluşturalım.",
            systemImage: "target",
            metric: "7.000+",
            metricCaption: "nazik başlangıç",
            highlights: ["Hedeflerini daha sonra değiştirebilirsin", "İlk plan sürdürülebilir başlar"]
        )
    ]

    var isLastPage: Bool { pageIndex == pages.count - 1 }
    var progress: Double { Double(pageIndex + 1) / Double(pages.count) }
    var stepLabel: String { "\(pageIndex + 1) / \(pages.count)" }
    var targetPreview: OnboardingTargetPreview { Self.targetPreview(for: selectedGoal) }

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
        guard !isCompleting else { return }
        isCompleting = true
        errorMessage = nil
        defer { isCompleting = false }
        do {
            let repository = dependencies.userRepository(context: context)
            let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try repository.saveOnboardingProfile(name: cleanName, goalType: selectedGoal)
            if wantsNotifications {
                let granted = await dependencies.notificationService.requestAuthorization()
                if granted { await dependencies.notificationService.scheduleGentleReminders() }
            }
            await dependencies.analytics.track(.onboardingCompleted, payload: AnalyticsPayload(values: ["goal": selectedGoal.rawValue]))
        } catch {
            errorMessage = "Başlangıç planı kaydedilemedi. Lütfen tekrar dene."
        }
    }

    private static func targetPreview(for goal: GoalType) -> OnboardingTargetPreview {
        switch goal {
        case .loseWeight:
            OnboardingTargetPreview(calories: "1.750", steps: "7.500", water: "2 L", note: "Daha hafif, sürdürülebilir bir başlangıç.")
        case .maintain:
            OnboardingTargetPreview(calories: "1.950", steps: "7.000", water: "2 L", note: "Dengeyi koruyan sakin bir günlük ritim.")
        case .gainHealthy:
            OnboardingTargetPreview(calories: "2.150", steps: "7.000", water: "2 L", note: "Enerjiyi artırırken yürüyüş rutinini korur.")
        case .walkMore:
            OnboardingTargetPreview(calories: "1.900", steps: "8.000", water: "2 L", note: "Walking-first başlangıç: hedef gerçekçi ama motive edici.")
        case .eatHealthier:
            OnboardingTargetPreview(calories: "1.850", steps: "7.000", water: "2 L", note: "Öğün farkındalığını sade bir hedefle başlatır.")
        }
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
