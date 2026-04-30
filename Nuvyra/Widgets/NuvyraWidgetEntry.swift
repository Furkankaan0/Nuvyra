import Foundation
import WidgetKit

/// What `NuvyraWidgetView` actually renders. Built from a
/// `NuvyraWidgetSnapshot` that the main app writes to the shared App Group.
struct NuvyraWidgetEntry: TimelineEntry {
    let date: Date
    let steps: Int
    let stepGoal: Int
    let calorieBalance: Int
    let calorieTarget: Int
    let waterMl: Int
    let waterTargetMl: Int
    let ringProgress: Double
    let insight: String
    /// `true` when the widget is showing fallback data because nothing has
    /// been written to the App Group yet (e.g. first launch).
    let isPlaceholder: Bool

    static let preview = NuvyraWidgetEntry(snapshot: .preview, isPlaceholder: true)

    init(
        date: Date,
        steps: Int,
        stepGoal: Int,
        calorieBalance: Int,
        calorieTarget: Int,
        waterMl: Int,
        waterTargetMl: Int,
        ringProgress: Double,
        insight: String,
        isPlaceholder: Bool
    ) {
        self.date = date
        self.steps = steps
        self.stepGoal = stepGoal
        self.calorieBalance = calorieBalance
        self.calorieTarget = calorieTarget
        self.waterMl = waterMl
        self.waterTargetMl = waterTargetMl
        self.ringProgress = ringProgress
        self.insight = insight
        self.isPlaceholder = isPlaceholder
    }

    init(snapshot: NuvyraWidgetSnapshot, isPlaceholder: Bool = false) {
        self.init(
            date: snapshot.generatedAt,
            steps: snapshot.steps,
            stepGoal: snapshot.stepGoal,
            calorieBalance: snapshot.calorieBalance,
            calorieTarget: snapshot.calorieTarget,
            waterMl: snapshot.waterMl,
            waterTargetMl: snapshot.waterTargetMl,
            ringProgress: snapshot.ringProgress,
            insight: snapshot.insight,
            isPlaceholder: isPlaceholder
        )
    }
}
