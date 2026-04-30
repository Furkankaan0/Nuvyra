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

    // MARK: - Body metrics (entered on the BodyMetrics page)
    /// `nil` until the user explicitly picks a value. We never default to a
    /// fictional profile so the calorie preview can't show before inputs.
    @Published var gender: Gender?
    @Published var age: Int?
    @Published var heightCm: Double?
    @Published var weightKg: Double?
    @Published var activityLevel: ActivityLevel?

    private let calculator = NutritionTargetCalculator()

    let pages: [OnboardingPageContent] = [
        OnboardingPageContent(
            kind: .intro,
            eyebrow: "Sakin başlangıç",
            title: "Ritmini yeniden kur.",
            subtitle: "Nuvyra, beslenme ve yürüyüş alışkanlığını sakin bir düzende takip eder.",
            systemImage: "leaf.fill",
            metric: "1 ekran",
            metricCaption: "günün dengesi",
            highlights: ["Katı diyet dili yok", "Kalori, su ve yürüyüş tek akışta"]
        ),
        OnboardingPageContent(
            kind: .intro,
            eyebrow: "Beslenme",
            title: "Kalorini karmaşa olmadan gör.",
            subtitle: "Öğünlerini hızlı ekle, günün dengesini tek bakışta anla.",
            systemImage: "fork.knife",
            metric: "4 öğün",
            metricCaption: "sade takip",
            highlights: ["Türk yemekleri için hızlı seçim", "Değerler tahmini olarak gösterilir"]
        ),
        OnboardingPageContent(
            kind: .intro,
            eyebrow: "Yürüyüş",
            title: "Yürüyüşü alışkanlığa çevir.",
            subtitle: "Adım hedeflerin, streak'lerin ve haftalık ritmin tek yerde.",
            systemImage: "figure.walk",
            metric: "12 dk",
            metricCaption: "mini görev",
            highlights: ["HealthKit adımları desteklenir", "Düşük günlerde suçluluk yok"]
        ),
        OnboardingPageContent(
            kind: .intro,
            eyebrow: "Gizlilik",
            title: "iPhone'unla birlikte çalışır.",
            subtitle: "Apple Sağlık verilerini izin verdiğin ölçüde okur. Verilerin sende kalır.",
            systemImage: "lock.shield.fill",
            metric: "KVKK",
            metricCaption: "hazır yaklaşım",
            highlights: ["Sağlık verisi reklam için kullanılmaz", "İzinleri istediğin zaman kapatabilirsin"]
        ),
        OnboardingPageContent(
            kind: .bodyMetrics,
            eyebrow: "Sana özel",
            title: "Birkaç temel bilgi.",
            subtitle: "Günlük kalori ve su hedefini sana göre hesaplayabilmemiz için gerekli. Verilerin cihazında kalır.",
            systemImage: "person.text.rectangle",
            metric: "BMR",
            metricCaption: "Mifflin-St Jeor",
            highlights: ["Cinsiyet, yaş, boy, kilo", "Hedeflerini sonra güncelleyebilirsin"]
        ),
        OnboardingPageContent(
            kind: .activity,
            eyebrow: "Aktivite",
            title: "Bir günün nasıl geçiyor?",
            subtitle: "Aktivite seviyene göre günlük enerji ihtiyacını (TDEE) ölçeklendiriyoruz.",
            systemImage: "figure.run",
            metric: "TDEE",
            metricCaption: "BMR × aktivite",
            highlights: ["En yakın seviyeyi seç", "İstediğin zaman değiştirebilirsin"]
        ),
        OnboardingPageContent(
            kind: .goal,
            eyebrow: "Kişisel hedef",
            title: "Hedefini seç.",
            subtitle: "Bugün için gerçekçi bir kalori, su ve adım hedefi oluşturalım.",
            systemImage: "target",
            metric: "7.000+",
            metricCaption: "nazik başlangıç",
            highlights: ["Hedeflerini daha sonra değiştirebilirsin", "İlk plan sürdürülebilir başlar"]
        )
    ]

    var currentPage: OnboardingPageContent { pages[pageIndex] }
    var isLastPage: Bool { pageIndex == pages.count - 1 }
    var progress: Double { Double(pageIndex + 1) / Double(pages.count) }
    var stepLabel: String { "\(pageIndex + 1) / \(pages.count)" }

    /// Calorie/step/water preview shown on the goal page. Falls back to a
    /// neutral placeholder until the user has provided body metrics.
    var targetPreview: OnboardingTargetPreview {
        guard let gender, let age, let heightCm, let weightKg, let activityLevel else {
            return OnboardingTargetPreview(
                calories: "—",
                steps: "—",
                water: "—",
                note: "Hedefini görmek için önce vücut bilgilerini ve aktivite seviyeni gir."
            )
        }
        let result = calculator.compute(
            NutritionTargetInput(
                gender: gender,
                age: age,
                heightCm: heightCm,
                weightKg: weightKg,
                activityLevel: activityLevel,
                goal: selectedGoal
            )
        )
        return OnboardingTargetPreview(
            calories: Self.numberFormatter.string(from: NSNumber(value: result.dailyCalories)) ?? "\(result.dailyCalories)",
            steps: Self.numberFormatter.string(from: NSNumber(value: result.dailyStepTarget)) ?? "\(result.dailyStepTarget)",
            water: "\(Double(result.dailyWaterTargetMl) / 1000) L".replacingOccurrences(of: ".0 L", with: " L"),
            note: Self.note(for: selectedGoal, result: result)
        )
    }

    /// Whether the bottom "Devam" button should be enabled on the current page.
    var canProceed: Bool {
        switch currentPage.kind {
        case .intro, .goal:
            return true
        case .bodyMetrics:
            return gender != nil
                && (age.map { (15...100).contains($0) } ?? false)
                && (heightCm.map { (120...230).contains($0) } ?? false)
                && (weightKg.map { (35...250).contains($0) } ?? false)
        case .activity:
            return activityLevel != nil
        }
    }

    var healthStatusTitle: String {
        switch healthState {
        case .sharingAuthorized: return "Apple Sağlık bağlı"
        case .sharingDenied: return "Manuel mod hazır"
        case .unavailable: return "Bu cihazda uygun değil"
        case .notDetermined: return "Apple Sağlık isteğe bağlı"
        }
    }

    var healthStatusDescription: String {
        switch healthState {
        case .sharingAuthorized:
            return "Adımların otomatik gelebilir. Nuvyra yalnızca günlük ritim içgörüleri için okur."
        case .sharingDenied:
            return "Sorun değil. Nuvyra manuel modda çalışmaya devam eder."
        case .unavailable:
            return "Bu cihazda HealthKit uygun görünmüyor. Uygulama manuel takiple açılır."
        case .notDetermined:
            return "Adım ve aktif enerji verilerini izin verdiğin ölçüde okuyabiliriz."
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
        guard let gender, let age, let heightCm, let weightKg, let activityLevel else {
            errorMessage = "Lütfen önce vücut bilgilerini ve aktivite seviyeni gir."
            return
        }
        isCompleting = true
        errorMessage = nil
        defer { isCompleting = false }
        do {
            let repository = dependencies.userRepository(context: context)
            let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try repository.saveOnboardingProfile(
                name: cleanName,
                goalType: selectedGoal,
                gender: gender,
                age: age,
                heightCm: heightCm,
                weightKg: weightKg,
                activityLevel: activityLevel
            )
            if wantsNotifications {
                let granted = await dependencies.notificationService.requestAuthorization()
                if granted { await dependencies.notificationService.scheduleGentleReminders() }
            }
            await dependencies.analytics.track(
                .onboardingCompleted,
                payload: AnalyticsPayload(values: [
                    "goal": selectedGoal.rawValue,
                    "activity": activityLevel.rawValue
                ])
            )
        } catch {
            errorMessage = "Başlangıç planı kaydedilemedi. Lütfen tekrar dene."
        }
    }

    // MARK: - Formatting

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static func note(for goal: GoalType, result: NutritionTargetResult) -> String {
        switch goal {
        case .loseWeight:
            return "Yumuşak kalori açığıyla sürdürülebilir bir başlangıç (BMR ≈ \(result.bmr) kcal)."
        case .maintain:
            return "Mevcut kilonu koruyacak dengeli bir günlük ritim."
        case .gainHealthy:
            return "Sağlıklı kilo alımı için ölçülü bir kalori fazlası."
        case .walkMore:
            return "Walking-first plan: hedef gerçekçi ama motive edici."
        case .eatHealthier:
            return "Hafif bir kalori hedefiyle öğün farkındalığını artırır."
        }
    }
}

enum OnboardingPageKind {
    case intro
    case bodyMetrics
    case activity
    case goal
}

struct OnboardingPageContent: Identifiable {
    let id = UUID()
    let kind: OnboardingPageKind
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
