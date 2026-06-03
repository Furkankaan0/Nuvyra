import SwiftUI

/// Hero card for the Walking screen — same hierarchy as the Dashboard
/// rhythm hero. The progress ring picks up the accent gradient and the
/// remaining-step status is shown as a glass pill so the visual language
/// matches the rest of the app.
struct StepGoalCard: View {
    @Environment(\.colorScheme) private var scheme

    var steps: Int
    var goal: Int
    var remaining: Int

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(steps) / Double(goal), 1.0)
    }

    private var isGoalReached: Bool { remaining == 0 }

    var body: some View {
        NuvyraGlassCard(.prominent) {
            HStack(spacing: NuvyraSpacing.lg) {
                NuvyraProgressRing(
                    progress: progress,
                    center: steps.formatted(),
                    caption: "adım"
                )
                .frame(width: 150, height: 150)

                VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                    Text("Günlük adım hedefi")
                        .font(NuvyraTypography.section)
                    Text("Hedef: \(goal.formatted())")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    NuvyraGlassPill(
                        systemImage: isGoalReached ? "checkmark.circle.fill" : "arrow.right.circle",
                        title: isGoalReached
                            ? "Hedef tamamlandı"
                            : "\(remaining.formatted()) adım kaldı",
                        tint: isGoalReached ? NuvyraColors.accent : NuvyraColors.softSand
                    )
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Adım hedefi: \(steps) / \(goal). \(isGoalReached ? "Tamamlandı." : "\(remaining) adım kaldı.")")
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        VStack(spacing: NuvyraSpacing.md) {
            StepGoalCard(steps: 6_240, goal: 7_500, remaining: 1_260)
            StepGoalCard(steps: 8_120, goal: 7_500, remaining: 0)
        }
        .padding()
    }
}
#endif
