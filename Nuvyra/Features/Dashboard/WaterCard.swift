import SwiftUI

/// Premium water tracker card with animated wave + add / remove controls.
struct WaterCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @State private var wavePhase: Double = 0
    @State private var animatedFill: Double = 0

    var summary: WaterSummary
    var onAdd250: () -> Void
    var onAdd500: () -> Void
    var onRemove: () -> Void

    // Legacy initializer for older call sites.
    init(waterMl: Int, targetMl: Int, onAdd250: @escaping () -> Void, onAdd500: @escaping () -> Void) {
        self.summary = WaterSummary(consumedMl: waterMl, targetMl: targetMl)
        self.onAdd250 = onAdd250
        self.onAdd500 = onAdd500
        self.onRemove = {}
    }

    init(
        summary: WaterSummary,
        onAdd250: @escaping () -> Void,
        onAdd500: @escaping () -> Void,
        onRemove: @escaping () -> Void
    ) {
        self.summary = summary
        self.onAdd250 = onAdd250
        self.onAdd500 = onAdd500
        self.onRemove = onRemove
    }

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                header
                HStack(alignment: .center, spacing: NuvyraSpacing.lg) {
                    waterGlass
                    VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
                        Text("\(summary.consumedMl) ml")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .contentTransition(.numericText())
                        Text(summary.isGoalReached ? "Hedef tamamlandı 🎉" : "Hedef: \(summary.targetMl) ml")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                        Text(summary.isGoalReached ? "Bugün için tebrikler" : "Kalan: \(summary.remainingMl) ml")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(NuvyraColors.accent)
                    }
                    Spacer(minLength: 0)
                }
                actions
            }
        }
        .onAppear {
            animateFill()
            if !reduceMotion {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    wavePhase = .pi * 2
                }
            }
        }
        .onChange(of: summary.progress) { _, _ in animateFill() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Su")
                    .font(NuvyraTypography.section)
                Text("Bugünkü içme ritmin")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "drop.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(
                    LinearGradient(colors: [Color(red: 0.30, green: 0.66, blue: 0.95), Color(red: 0.40, green: 0.86, blue: 0.95)], startPoint: .top, endPoint: .bottom)
                )
        }
    }

    private var waterGlass: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(scheme == .dark ? 0.18 : 0.5), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
            GeometryReader { proxy in
                WaveShape(phase: wavePhase, amplitude: 4, fillProgress: animatedFill)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.20, green: 0.56, blue: 0.95), Color(red: 0.45, green: 0.86, blue: 0.96)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            Text("\(Int(summary.progress * 100))%")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
        }
        .frame(width: 96, height: 116)
        .accessibilityHidden(true)
    }

    private var actions: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            WaterChipButton(title: "-250", systemImage: "minus", style: .neutral, action: onRemove)
            WaterChipButton(title: "+250", systemImage: "drop", style: .primary, action: onAdd250)
            WaterChipButton(title: "+500", systemImage: "drop.fill", style: .primary, action: onAdd500)
        }
    }

    private func animateFill() {
        guard !reduceMotion else { animatedFill = summary.progress; return }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { animatedFill = summary.progress }
    }
}

private struct WaterChipButton: View {
    enum Style { case primary, neutral }
    var title: String
    var systemImage: String
    var style: Style
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(style == .primary ? Color.white : NuvyraColors.accent)
            .background(backgroundStyle, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var backgroundStyle: AnyShapeStyle {
        switch style {
        case .primary:
            AnyShapeStyle(
                LinearGradient(
                    colors: [NuvyraColors.accent, NuvyraColors.softMint],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .neutral:
            AnyShapeStyle(NuvyraColors.accent.opacity(0.10))
        }
    }
}

private struct WaveShape: Shape {
    var phase: Double
    var amplitude: Double
    var fillProgress: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(phase, fillProgress) }
        set { phase = newValue.first; fillProgress = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let baseline = rect.height * CGFloat(1 - max(0, min(1, fillProgress)))
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
#Preview("Water") {
    ZStack {
        NuvyraBackground()
        WaterCard(summary: DashboardPreviewData.water, onAdd250: {}, onAdd500: {}, onRemove: {}).padding()
    }
}
#endif
