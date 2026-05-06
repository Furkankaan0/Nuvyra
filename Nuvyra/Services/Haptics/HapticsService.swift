@MainActor
protocol HapticsService {
    func mealLogged()
    func waterAdded()
    func walkStarted()
    func walkingHalfwayReached()
    func goalCompleted()
}

@MainActor
final class LiveHapticsService: HapticsService {
    func mealLogged() {
        HapticManager.shared.playMealAddedSuccess()
    }

    func waterAdded() {
        HapticManager.shared.playWaterAdded()
    }

    func walkStarted() {
        HapticManager.shared.playWalkStarted()
    }

    func walkingHalfwayReached() {
        HapticManager.shared.playWalkingHalfwayRhythm()
    }

    func goalCompleted() {
        HapticManager.shared.playGoalCompleted()
    }
}

@MainActor
struct MockHapticsService: HapticsService {
    func mealLogged() {}
    func waterAdded() {}
    func walkStarted() {}
    func walkingHalfwayReached() {}
    func goalCompleted() {}
}
