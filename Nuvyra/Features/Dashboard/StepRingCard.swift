import SwiftUI

/// Premium step / walking summary card with animated ring.
struct StepRingCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedProgress: Double = 0

    var summary: StepSummary
    var onStartWalking: (() -> Void)?

    // Legacy initializer for older call sites (steps + goal).
    init(steps: Int, goal: Int, onStartWalking: (() -> Void)? = nil) {
        self.summary = StepSummary(steps: steps, goal: goal, distanceKm: nil, activeEnergy: 0)
        self.onStartWalking = onStartWalking
    }

    init(summary: StepSummary, onStartWalking: (() -> Void)? = nil) {
        self.summary = summary
        self.onStartWalking = onStartWalking
    }

    var body: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                header
                HStack(spacing: NuvyraSpacing.lg) {
                    ring
                    metrics
                }
                if !summary.isGoalReached, let onStartWalking {
                    NuvyraSecondaryButton(title: "Yürüyüş başlat", systemImage: "figure.walk", action: onStartWalking)
                }
            }
        }
        .onAppear { animate() }
        .onChange(of: summary.progress) { _, _ in animate() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Yürüyüş")
                    .font(NuvyraTypography.section)
                Text(summary.isGoalReached ? "Hedef tamam — harika!" : "Hedefe \(summary.remaining.formatted()) adım")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "figure.walk.motion")
                .font(.title3.weight(.bold))
                .foregroundStyle(NuvyraColors.accent)
        }
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(NuvyraColors.accent.opacity(0.12), lineWidth: 12)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(colors: [NuvyraColors.accent, NuvyraColors.softMint, NuvyraColors.accent], center: .center),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: NuvyraColors.accent.opacity(0.35), radius: 8, x: 0, y: 4)
            VStack(spacing: 2) {
                Text("\(summary.steps.formatted())")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                Text("adım")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 110, height: 110)
    }

    private var metrics: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            metricRow(icon: "target", title: "Hedef", value: "\(summary.goal.formatted())")
            metricRow(icon: "flame", title: "Yakılan", value: "\(Int(summary.activeEnergy)) kcal")
            if let km = summary.distanceKm {
                metricRow(icon: "map", title: "Mesafe", value: String(format: "%.1f km", km))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: NuvyraSpacing.sm) {
            Image(systemName: icon)
                .font(.footnote.weight(.bold))
                .foregroundStyle(NuvyraColors.accent)
                .frame(width: 24, height: 24)
                .background(NuvyraColors.accent.opacity(0.12), in: Circle())
            Text(title)
                .font(NuvyraTypography.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }

    private func animate() {
        guard !reduceMotion else { animatedProgress = summary.progress; return }
        withAnimation(.spring(response: 0.85, dampingFraction: 0.75)) { animatedProgress = summary.progress }
    }
}

#if DEBUG
#Preview("Steps") {
    ZStack {
        NuvyraBackground()
        StepRingCard(summary: DashboardPreviewData.steps, onStartWalking: {}).padding()
    }
}
#endif
