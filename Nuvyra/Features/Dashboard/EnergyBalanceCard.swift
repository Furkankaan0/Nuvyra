import SwiftUI

/// Compact Dashboard card answering "do I have a calorie deficit or surplus today?"
/// based on TDEE - intake + activity burn. Strictly informational copy — never frames
/// the number as a weight-loss promise or medical advice.
struct EnergyBalanceCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedRatio: Double = 0

    var balance: EnergyBalanceSummary

    private var primaryTint: Color {
        if balance.tdee == 0 { return NuvyraColors.accent }
        return balance.isDeficit ? NuvyraColors.accent : (balance.isSurplus ? NuvyraColors.mutedCoral : NuvyraColors.softSand)
    }

    var body: some View {
        NuvyraGlassCard(.prominent) {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                header
                if balance.tdee == 0 {
                    placeholderState
                } else {
                    summaryRow
                    balanceBar
                    breakdown
                }
            }
        }
        .onAppear { animate() }
        .onChange(of: balance.consumedRatio) { _, _ in animate() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Enerji dengesi")
                    .font(NuvyraTypography.section)
                Text("Bugün TDEE'ne göre ritmin")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "scalemass")
                .font(.title3.weight(.bold))
                .foregroundStyle(primaryTint)
                .nuvyraAmbientIcon()
        }
    }

    private var summaryRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(balance.isDeficit ? "Açık" : (balance.isSurplus ? "Fazla" : "Dengede"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(primaryTint)
                Text("\(abs(balance.netDeficit)) kcal")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("TDEE")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(balance.tdee) kcal")
                    .font(.subheadline.weight(.heavy))
            }
        }
    }

    private var balanceBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(NuvyraColors.accent.opacity(0.12))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [primaryTint, primaryTint.opacity(0.6)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(min(proxy.size.width * animatedRatio, proxy.size.width), 0))
            }
        }
        .frame(height: 10)
    }

    private var breakdown: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            metricCell(title: "Alınan", value: balance.caloriesConsumed, systemImage: "fork.knife", tint: NuvyraColors.accent)
            metricCell(title: "Yakılan", value: balance.caloriesBurned, systemImage: "flame.fill", tint: NuvyraColors.mutedCoral)
            metricCell(title: "Net hedef", value: balance.tdee + balance.caloriesBurned, systemImage: "target", tint: NuvyraColors.softSand)
        }
    }

    private func metricCell(title: String, value: Int, systemImage: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.subheadline.weight(.heavy))
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous))
    }

    private var placeholderState: some View {
        Text("Profilini tamamladığında TDEE temelli enerji dengesi burada görünecek.")
            .font(NuvyraTypography.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
    }

    private var accessibilityText: String {
        let direction = balance.isDeficit ? "açık" : (balance.isSurplus ? "fazla" : "dengede")
        return "Enerji dengesi: TDEE \(balance.tdee), alınan \(balance.caloriesConsumed), yakılan \(balance.caloriesBurned), \(abs(balance.netDeficit)) kalori \(direction)."
    }

    private func animate() {
        let target = min(max(balance.consumedRatio, 0), 1.1)
        guard !reduceMotion else { animatedRatio = target; return }
        withAnimation(.spring(response: 0.8, dampingFraction: 0.78)) { animatedRatio = target }
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        VStack(spacing: NuvyraSpacing.md) {
            EnergyBalanceCard(balance: EnergyBalanceSummary(tdee: 2150, caloriesConsumed: 1480, caloriesBurned: 320))
            EnergyBalanceCard(balance: EnergyBalanceSummary(tdee: 2150, caloriesConsumed: 2480, caloriesBurned: 180))
            EnergyBalanceCard(balance: EnergyBalanceSummary(tdee: 0, caloriesConsumed: 0, caloriesBurned: 0))
        }
        .padding()
    }
}
#endif
