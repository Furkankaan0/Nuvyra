import SwiftUI

struct StepRingCard: View {
    var steps: Int
    var goal: Int

    private var remaining: Int { max(goal - steps, 0) }

    var body: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
                        Text("Yürüyüş")
                            .font(NuvyraTypography.section)
                        Text("\(steps.formatted())")
                            .font(NuvyraTypography.metric)
                    }
                    Spacer()
                    NuvyraProgressRing(progress: Double(steps) / Double(max(goal, 1)), lineWidth: 10, center: "\(Int(min(Double(steps) / Double(max(goal, 1)), 1) * 100))%", caption: "adım")
                        .frame(width: 104, height: 104)
                }
                Text(remaining == 0 ? "Bugünkü adım hedefin tamamlandı." : "Hedefe \(remaining.formatted()) adım kaldı.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
