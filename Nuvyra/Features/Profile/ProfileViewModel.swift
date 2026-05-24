import Combine
import Foundation
import SwiftData

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var profile: UserProfile?
    @Published private(set) var subscriptionState = SubscriptionState()
    @Published private(set) var healthSnapshot = HealthSnapshot.fallback
    @Published private(set) var isLoading = false
    @Published var alertMessage: String?

    var healthStatusTitle: String {
        switch healthSnapshot.authorizationStatus {
        case .sharingAuthorized: "Apple Health bağlı"
        case .sharingDenied: "Manuel mod"
        case .unavailable: "Uygun değil"
        case .notDetermined: "İzin bekleniyor"
        }
    }

    var premiumStatusTitle: String {
        guard subscriptionState.isPremium else { return "Free plan" }
        if subscriptionState.productId == ProductID.premiumLifetime.rawValue {
            return "Ömür boyu Premium"
        }
        return "Premium aktif"
    }

    func load(context: ModelContext, dependencies: DependencyContainer) async {
        isLoading = true
        defer { isLoading = false }
        do {
            profile = try dependencies.userRepository(context: context).profile()
            subscriptionState = try dependencies.subscriptionRepository(context: context).state()
            healthSnapshot = await dependencies.healthService.todaySnapshot()
        } catch {
            alertMessage = "Profil bilgileri yüklenemedi."
        }
    }

    func requestHealth(dependencies: DependencyContainer) async {
        let state = await dependencies.healthService.requestAuthorization()
        healthSnapshot = HealthSnapshot(
            steps: healthSnapshot.steps,
            activeEnergy: healthSnapshot.activeEnergy,
            distanceKm: healthSnapshot.distanceKm,
            authorizationStatus: state,
            source: state == .sharingAuthorized ? .healthKit : .manualFallback
        )
    }

    func updateGoals(context: ModelContext, calories: Int, waterMl: Int, steps: Int) {
        guard let profile else { return }
        profile.dailyCalorieTarget = min(max(calories, 1_000), 5_000)
        profile.dailyWaterTargetMl = min(max(waterMl, 1_000), 5_000)
        profile.dailyStepTarget = min(max(steps, 2_000), 20_000)
        profile.updatedAt = Date()
        do {
            try context.save()
            self.profile = profile
        } catch {
            alertMessage = "Hedeflerin kaydedilemedi."
        }
    }
}
