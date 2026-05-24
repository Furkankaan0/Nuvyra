import Foundation

/// Daily water target value type — derived from `UserProfile.dailyWaterTargetMl`
/// but exposed as its own struct so the water feature isn't tightly coupled to
/// the profile model.
struct WaterGoal: Equatable, Hashable {
    var dailyTargetMl: Int

    static let `default` = WaterGoal(dailyTargetMl: 2_000)

    /// Common quick-add buttons surfaced in the UI.
    static let quickAddPresets: [Int] = [200, 300, 500]

    /// Inclusive min/max for the manual `Stepper`.
    static let manualEntryRange: ClosedRange<Int> = 50...2_000
}

extension WaterGoal {
    init(profile: UserProfile?) {
        self.dailyTargetMl = profile?.dailyWaterTargetMl ?? Self.default.dailyTargetMl
    }
}
