import SwiftUI

struct WaterProgressCard: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var summary: WaterSummary
    @State private var animatedProgress: Double = 0
    @State private var wavePhase: CGFloat = 0

    private var tint: Color { Color(red: 0.30, green: 0.70, blue: 0.95) }

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bugünkü su tüketimin")
                            .font(NuvyraTypography.section)
                        Text("\(summary.consumedMl.formatted()) / \(summary.targetMl.formatted()) ml")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    }
                    Spacer()
                    Text("\(Int(summary.progress * 100))%")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText(value: summary.progress))
                        .foregroundStyle(tint)
                }

                ZStack {
                    GlassDropShape()
                        .fill(.ultraThinMaterial)
                        .overlay(GlassDropShape().stroke(tint.opacity(0.32), lineWidth: 2))

                    GlassDropShape()
                        .fill(
                            LinearGradient(colors: [tint.opacity(0.6), tint], startPoint: .top, endPoint: .bottom)
                        )
                        .mask(
                            WaveShape(progress: animatedProgress, phase: wavePhase)
                                .fill(Color.black)
                        )

                    Text("\(summary.consumedMl.formatted()) ml")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: tint.opacity(0.5), radius: 4)
                }
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Su tüketimi yüzde \(Int(summary.progress * 100)). \(summary.consumedMl) mililitre tüketildi, hedef \(summary.targetMl) mililitre.")
            }
        }
        .onAppear {
            animateRing()
            startWave()
        }
        .onChange(of: summary.progress) { _, _ in animateRing() }
    }

    private func animateRing() {
        if reduceMotion {
            animatedProgress = summary.progress
        } else {
            withAnimation(.easeOut(duration: 0.8)) { animatedProgress = summary.progress }
        }
    }

    private func startWave() {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
            wavePhase = .pi * 2
        }
    }
}

private struct GlassDropShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) * 0.25
        return Path(roundedRect: rect.insetBy(dx: 12, dy: 8), cornerRadius: radius)
    }
}

private struct WaveShape: Shape {
    var progress: Double
    var phase: CGFloat

    var animatableData: AnimatablePair<Double, CGFloat> {
        get { AnimatablePair(progress, phase) }
        set {
            progress = newValue.first
            phase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let waterLevel = rect.height * (1 - CGFloat(progress))
        let amplitude: CGFloat = 6
        let length = rect.width

        var path = Path()
        path.move(to: CGPoint(x: 0, y: waterLevel))
        var x: CGFloat = 0
        while x <= length {
            let relativeX = x / length
            let y = waterLevel + sin(relativeX * .pi * 4 + phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += 1
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        WaterProgressCard(summary: WaterSummary(consumedMl: 1_400, targetMl: 2_000))
        WaterProgressCard(summary: WaterSummary(consumedMl: 2_000, targetMl: 2_000))
    }
    .padding()
    .background(NuvyraBackground())
}
#endif
