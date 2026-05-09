import SwiftUI

struct WaterStepRow: View {
    var water: WaterSummary
    var step: StepSummary
    var onAddWater: () -> Void
    var onRemoveWater: () -> Void
    var onWaterDetail: () -> Void = {}

    var body: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            WaterMiniCard(summary: water, onAdd: onAddWater, onRemove: onRemoveWater, onDetail: onWaterDetail)
            StepMiniCard(summary: step)
        }
    }
}

private struct WaterMiniCard: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var summary: WaterSummary
    var onAdd: () -> Void
    var onRemove: () -> Void
    var onDetail: () -> Void
    @State private var fill: CGFloat = 0
    @State private var celebrate = false

    private var tint: Color { Color(red: 0.30, green: 0.70, blue: 0.95) }

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
            HStack(spacing: 6) {
                Image(systemName: "drop.fill")
                    .foregroundStyle(tint)
                Text("Su")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                Spacer()
                if summary.isCompleted {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(tint)
                        .scaleEffect(celebrate ? 1.18 : 1)
                        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.5), value: celebrate)
                }
                Button(action: onDetail) {
                    Image(systemName: "chevron.right.circle.fill")
                        .foregroundStyle(tint.opacity(0.55))
                        .font(.subheadline.weight(.bold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Su detayını aç")
            }

            ZStack {
                Circle()
                    .stroke(tint.opacity(0.14), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: CGFloat(summary.progress) * fill)
                    .stroke(
                        LinearGradient(colors: [tint.opacity(0.7), tint], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(summary.consumedMl)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText(value: Double(summary.consumedMl)))
                    Text("/ \(summary.targetMl) ml")
                        .font(.caption2)
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                }
            }
            .frame(height: 110)

            HStack(spacing: 6) {
                CircleAction(systemImage: "minus", tint: tint, action: onRemove)
                CircleAction(systemImage: "plus", tint: tint, action: onAdd)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(NuvyraSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous)
                .stroke(tint.opacity(0.16))
        )
        .shadow(color: NuvyraShadow.card(scheme), radius: 14, x: 0, y: 8)
        .onAppear {
            if reduceMotion { fill = 1 } else {
                withAnimation(.easeOut(duration: 0.9)) { fill = 1 }
            }
        }
        .onChange(of: summary.isCompleted) { _, completed in
            guard completed, !reduceMotion else { return }
            celebrate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { celebrate = false }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Su tüketimi \(summary.consumedMl) mililitre, hedef \(summary.targetMl) mililitre")
    }
}

private struct CircleAction: View {
    var systemImage: String
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .frame(width: 36, height: 36)
                .foregroundStyle(.white)
                .background(LinearGradient(colors: [tint, tint.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                .shadow(color: tint.opacity(0.35), radius: 6, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemImage == "plus" ? "Su ekle" : "Su azalt")
    }
}

private struct StepMiniCard: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var summary: StepSummary
    @State private var animatedProgress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
            HStack(spacing: 6) {
                Image(systemName: "figure.walk")
                    .foregroundStyle(NuvyraColors.accent)
                Text("Adım")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                Spacer()
                if summary.isCompleted {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(NuvyraColors.accent)
                }
            }

            ZStack {
                Circle()
                    .stroke(NuvyraColors.accent.opacity(0.14), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        AngularGradient(colors: [NuvyraColors.accent, NuvyraColors.paleLime], center: .center),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(summary.steps.formatted())")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText(value: Double(summary.steps)))
                    Text("/ \(summary.goal.formatted())")
                        .font(.caption2)
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                }
            }
            .frame(height: 110)

            HStack(spacing: 4) {
                if let distance = summary.distanceKm {
                    Label(String(format: "%.1f km", distance), systemImage: "map")
                        .labelStyle(.titleAndIcon)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                }
                Spacer()
                if summary.activeEnergyKcal > 0 {
                    Label("\(Int(summary.activeEnergyKcal)) kcal", systemImage: "flame")
                        .labelStyle(.titleAndIcon)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(NuvyraColors.mutedCoral)
                }
            }
        }
        .padding(NuvyraSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous)
                .stroke(NuvyraColors.accent.opacity(0.16))
        )
        .shadow(color: NuvyraShadow.card(scheme), radius: 14, x: 0, y: 8)
        .onAppear { animate() }
        .onChange(of: summary.progress) { _, _ in animate() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Adım \(summary.steps), hedef \(summary.goal)")
    }

    private func animate() {
        if reduceMotion {
            animatedProgress = summary.progress
        } else {
            withAnimation(.easeOut(duration: 0.9)) { animatedProgress = summary.progress }
        }
    }
}

#if DEBUG
#Preview {
    WaterStepRow(
        water: DashboardMockPreviewData.water,
        step: DashboardMockPreviewData.steps,
        onAddWater: {},
        onRemoveWater: {}
    )
    .padding()
    .background(NuvyraBackground())
}
#endif
