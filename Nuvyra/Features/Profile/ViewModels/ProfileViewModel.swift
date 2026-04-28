import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    func calorieTarget(for profile: UserProfile) -> CalorieTarget {
        CalorieTargetCalculator().target(for: profile)
    }
}
