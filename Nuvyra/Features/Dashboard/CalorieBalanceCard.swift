import SwiftUI

struct CalorieBalanceCard: View {
    var consumed: Int
    var burned: Int
    var target: Int
    var remaining: Int

    var body: some View {
        NuvyraGlassCard {
            HStack(spacing: NuvyraSpacing.lg) {
                NuvyraProgressRing(progress: Double(consumed) / Double(max(target, 1)), center: "\(remaining)", caption: "kcal kaldı")
                    .frame(width: 132, height: 132)
                VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                    Text("Kalori dengesi")
                        .font(NuvyraTypography.section)
                    MetricLine(title: "Alınan", value: "\(consumed) kcal")
                    MetricLine(title: "Yakılan", value: "\(burned) kcal")
                    MetricLine(title: "Hedef", value: "\(target) kcal")
                }
            }
        }
        .accessibilityLabel("Kalori dengesi. Alınan \(consumed), yakılan \(burned), kalan \(remaining) kalori.")
    }
}

private struct MetricLine: View {
    var title: String
    var value: String
    var body: some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .font(NuvyraTypography.body)
    }
}
