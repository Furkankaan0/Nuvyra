import SwiftUI

/// Premium standalone water progress card — used by both the WaterTracking screen
/// (large layout) and the Dashboard (legacy convenience init). Renders an animated
/// gradient wave inside a tall pill plus the consumed / remaining numbers.
struct WaterProgressCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @State private var wavePhase: Double = 0
    @State private var animatedFill: Double = 0

    var summary: WaterSummary
    var goalReached: Bool { summary.isGoalReached }

    init(summary: WaterSummary) {
        self.summary = summary
    }

    var body: some View {
        NuvyraGlassCard {
            HStack(alignment: .center, spacing: NuvyraSpacing.lg) {
                bottle
                VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
                    Text("Bugün")
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(.secondary)
                    Text("\(summary.consumedMl) ml")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText())
                        .foregroundStyle(.primary)
                    HStack(spacing: 4) {
                        Image(systemName: goalReached ? "checkmark.seal.fill" : "target")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(goalReached ? NuvyraColors.accent : .secondary)
                        Text(goalReached ? "Hedef tamamlandı" : "Hedef \(summary.targetMl) ml")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !goalReached {
                        Text("\(summary.remainingMl) ml kaldı")
                            .font(NuvyraTypography.caption.weight(.semibold))
                            .foregroundStyle(NuvyraColors.accent)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .onAppear {
            animateFill()
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 4.5).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
        }
        .onChange(of: summary.progress) { _, _ in animateFill() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Su: \(summary.consumedMl) ml, hedef \(summary.targetMl) ml, yüzde \(Int(summary.progress * 100))")
    }

    private var bottle: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(scheme == .dark ? 0.18 : 0.5), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
            GeometryReader { proxy in
                WaterWaveShape(phase: wavePhase, amplitude: 5, fillProgress: animatedFill)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.20, green: 0.56, blue: 0.95), Color(red: 0.45, green: 0.86, blue: 0.96)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            VStack(spacing: 2) {
                Text("\(Int(summary.progress * 100))%")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Image(systemName: "drop.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
        }
        .frame(width: 112, height: 140)
        .accessibilityHidden(true)
    }

    private func animateFill() {
        guard !reduceMotion else { animatedFill = summary.progress; return }
        withAnimation(.spring(response: 0.75, dampingFraction: 0.75)) { animatedFill = summary.progress }
    }
}

struct WaterWaveShape: Shape {
    var phase: Double
    var amplitude: Double
    var fillProgress: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(phase, fillProgress) }
        set { phase = newValue.first; fillProgress = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let clamped = max(0, min(1, fillProgress))
        let baseline = rect.height * CGFloat(1 - clamped)
        let step: CGFloat = 4
        path.move(to: CGPoint(x: 0, y: baseline))
        var x: CGFloat = 0
        while x <= rect.width {
            let relativeX = Double(x / rect.width) * .pi * 2
            let y = baseline + CGFloat(sin(relativeX + phase) * amplitude)
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        VStack(spacing: NuvyraSpacing.md) {
            WaterProgressCard(summary: WaterSummary(consumedMl: 1_250, targetMl: 2_000))
            WaterProgressCard(summary: WaterSummary(consumedMl: 2_100, targetMl: 2_000))
        }
        .padding()
    }
}
#endif
