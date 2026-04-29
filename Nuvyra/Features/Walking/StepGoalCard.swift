import SwiftUI

struct StepGoalCard: View {
    var steps: Int
    var goal: Int
    var remaining: Int

    var body: some View {
        NuvyraGlassCard {
            HStack(spacing: NuvyraSpacing.lg) {
                NuvyraProgressRing(progress: Double(steps) / Double(max(goal, 1)), center: "\(steps.formatted())", caption: "adım")
                    .frame(width: 150, height: 150)
                VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                    Text("Günlük adım hedefi")
                        .font(NuvyraTypography.section)
                    Text("Hedef: \(goal.formatted())")
                        .font(.headline.weight(.semibold))
                    Text(remaining == 0 ? "Hedef tamamlandı." : "\(remaining.formatted()) adım kaldı.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
