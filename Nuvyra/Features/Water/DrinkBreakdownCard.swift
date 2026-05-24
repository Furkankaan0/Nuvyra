import SwiftUI

/// Per-drink breakdown for today — a tinted progress bar per drink type plus a
/// "total fluid" headline. Renders only the drink types the user actually had.
struct DrinkBreakdownCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var breakdown: [DrinkBreakdown]
    var totalFluidMl: Int
    var hydrationMl: Int
    var waterGoalMl: Int

    private var maxMl: Int {
        max(breakdown.map(\.totalMl).max() ?? 0, 250)
    }

    var body: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                header
                if breakdown.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: NuvyraSpacing.sm) {
                        ForEach(breakdown, id: \.type) { row in
                            DrinkBreakdownRow(row: row, maxMl: maxMl)
                        }
                    }
                }
                Text("Hidrasyon ağırlıklı toplam: \(hydrationMl) / \(waterGoalMl) ml — kahve ve gazlı içecek hedefe daha az katkı sağlar.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("İçecek dağılımı")
                    .font(NuvyraTypography.section)
                Text("Bugünkü toplam sıvı")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(totalFluidMl) ml")
                .font(.title3.weight(.heavy))
                .foregroundStyle(NuvyraColors.accent)
                .contentTransition(.numericText())
        }
    }

    private var emptyState: some View {
        Text("Bugün için içecek kaydı yok.")
            .font(NuvyraTypography.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
    }
}

private struct DrinkBreakdownRow: View {
    var row: DrinkBreakdown
    var maxMl: Int

    private var ratio: Double {
        guard maxMl > 0 else { return 0 }
        return Double(row.totalMl) / Double(maxMl)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: row.type.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(row.type.tint)
                Text(row.type.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(row.totalMl) ml")
                    .font(.caption.weight(.heavy))
                if row.totalCaffeineMg > 0 {
                    Text("\(Int(row.totalCaffeineMg)) mg")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(NuvyraColors.mutedCoral.opacity(0.14), in: Capsule())
                        .foregroundStyle(NuvyraColors.mutedCoral)
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(row.type.tint.opacity(0.14))
                    Capsule()
                        .fill(row.type.tint)
                        .frame(width: max(min(proxy.size.width * ratio, proxy.size.width), 0))
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.type.title): \(row.totalMl) mililitre\(row.totalCaffeineMg > 0 ? ", \(Int(row.totalCaffeineMg)) miligram kafein" : "")")
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        DrinkBreakdownCard(
            breakdown: [
                DrinkBreakdown(type: .water, totalMl: 1_200, totalCaffeineMg: 0),
                DrinkBreakdown(type: .coffee, totalMl: 400, totalCaffeineMg: 190),
                DrinkBreakdown(type: .tea, totalMl: 300, totalCaffeineMg: 60)
            ],
            totalFluidMl: 1_900,
            hydrationMl: 1_540,
            waterGoalMl: 2_000
        )
        .padding()
    }
}
#endif
