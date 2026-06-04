import SwiftUI

/// Watch-sized version of the Dashboard rhythm hero. Designed for the
/// 41/44/45/49 mm screens: trades the 124pt iPhone ring for a 96pt
/// disc that still leaves room for a centred score + caption.
///
/// Mirrors the **exact same scoring formula** the iPhone widget +
/// dashboard hero use — `(calorie * 0.24) + (water * 0.28) +
/// (step * 0.32) + (protein * 0.16)` — so whichever screen the user
/// looks at, the number is identical.
struct WatchRhythmRing: View {
    var calorieProgress: Double
    var waterProgress: Double
    var stepProgress: Double
    var proteinProgress: Double

    private var score: Int {
        let combined =
            (clamp(calorieProgress) * 0.24) +
            (clamp(waterProgress) * 0.28) +
            (clamp(stepProgress) * 0.32) +
            (clamp(proteinProgress) * 0.16)
        return Int((min(combined, 1) * 100).rounded())
    }

    private var fillFraction: Double { Double(score) / 100.0 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 8)
            Circle()
                .trim(from: 0, to: fillFraction)
                .stroke(
                    AngularGradient(
                        colors: [.cyan, .mint, .green],
                        center: .center,
                        angle: .degrees(-90)
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                Text("ritim")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ritim skoru \(score) yüzde")
    }

    private func clamp(_ v: Double) -> Double { min(max(v, 0), 1) }
}

#if DEBUG
#Preview {
    WatchRhythmRing(
        calorieProgress: 0.68,
        waterProgress: 0.74,
        stepProgress: 0.84,
        proteinProgress: 0.62
    )
    .frame(width: 110, height: 110)
}
#endif
