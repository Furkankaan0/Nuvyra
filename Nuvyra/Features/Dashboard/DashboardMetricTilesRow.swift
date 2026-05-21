import SwiftUI

struct DashboardMetricTilesRow: View {
    var water: WaterSummary
    var step: StepSummary
    var protein: MacroSummary?
    var onWaterTap: () -> Void
    var onStepsTap: () -> Void
    var onProteinTap: () -> Void

    private var waterColor: Color { Color(red: 0.30, green: 0.70, blue: 0.95) }

    var body: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            MetricTile(
                title: "Su",
                primary: formattedWater(water.consumedMl),
                secondary: "/ \(formattedWater(water.targetMl))",
                progress: water.progress,
                tint: waterColor,
                systemImage: "drop.fill",
                completed: water.isCompleted,
                action: onWaterTap
            )

            MetricTile(
                title: "Adım",
                primary: water.consumedMl == 0 && step.steps == 0 ? "0" : compact(step.steps),
                secondary: "/ \(compact(step.goal))",
                progress: step.progress,
                tint: NuvyraColors.accent,
                systemImage: "figure.walk",
                completed: step.isCompleted,
                action: onStepsTap
            )

            if let protein {
                MetricTile(
                    title: "Protein",
                    primary: "\(Int(protein.consumedGrams))g",
                    secondary: "/ \(Int(protein.targetGrams))g",
                    progress: protein.progress,
                    tint: NuvyraColors.mutedCoral,
                    systemImage: "bolt.heart.fill",
                    completed: protein.progress >= 1,
                    action: onProteinTap
                )
            }
        }
    }

    private func formattedWater(_ ml: Int) -> String {
        if ml >= 1_000 {
            let liters = Double(ml) / 1_000.0
            return String(format: "%.1fL", liters)
        }
        return "\(ml)ml"
    }

    private func compact(_ value: Int) -> String {
        if value >= 10_000 {
            return String(format: "%.1fk", Double(value) / 1_000)
        }
        return value.formatted(.number.grouping(.automatic))
    }
}

private struct MetricTile: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var title: String
    var primary: String
    var secondary: String
    var progress: Double
    var tint: Color
    var systemImage: String
    var completed: Bool
    var action: () -> Void
    @State private var animatedProgress: Double = 0
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(tint)
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    Spacer()
                    if completed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(tint)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(primary)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .allowsTightening(true)
                    Text(secondary)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(tint.opacity(0.16))
                        Capsule()
                            .fill(LinearGradient(colors: [tint, tint.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: proxy.size.width * animatedProgress)
                            .shadow(color: tint.opacity(0.32), radius: 4, x: 0, y: 1)
                    }
                }
                .frame(height: 5)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                    .stroke(tint.opacity(0.18))
            )
            .shadow(color: NuvyraShadow.card(scheme), radius: 10, x: 0, y: 6)
            .scaleEffect(pressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !reduceMotion, !pressed else { return }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { pressed = true }
                }
                .onEnded { _ in
                    guard !reduceMotion else { return }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { pressed = false }
                }
        )
        .onAppear { animate() }
        .onChange(of: progress) { _, _ in animate() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(primary) \(secondary)")
    }

    private func animate() {
        if reduceMotion {
            animatedProgress = min(max(progress, 0), 1)
        } else {
            withAnimation(.easeOut(duration: 0.7)) { animatedProgress = min(max(progress, 0), 1) }
        }
    }
}

#if DEBUG
#Preview {
    DashboardMetricTilesRow(
        water: DashboardMockPreviewData.water,
        step: DashboardMockPreviewData.steps,
        protein: DashboardMockPreviewData.macros.first,
        onWaterTap: {},
        onStepsTap: {},
        onProteinTap: {}
    )
    .padding()
    .background(NuvyraBackground())
}
#endif
