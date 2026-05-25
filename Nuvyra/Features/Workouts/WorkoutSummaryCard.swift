import SwiftUI

/// Daily glance: total minutes + calories + session count.
struct WorkoutSummaryCard: View {
    var summary: WorkoutDailySummary
    var label: String = "Bugün"

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                header
                HStack(spacing: NuvyraSpacing.sm) {
                    metricCell(title: "Süre", value: "\(summary.totalMinutes)", unit: "dk", icon: "clock.fill", tint: NuvyraColors.accent)
                    metricCell(title: "Kalori", value: "\(summary.totalCalories)", unit: "kcal", icon: "flame.fill", tint: NuvyraColors.mutedCoral)
                    metricCell(title: "Seans", value: "\(summary.sessionCount)", unit: "", icon: "figure.run", tint: NuvyraColors.softMint)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Egzersiz özeti")
                    .font(NuvyraTypography.section)
                Text(label)
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "figure.run.circle.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(NuvyraColors.accent)
        }
    }

    private func metricCell(title: String, value: String, unit: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.heavy))
                    .contentTransition(.numericText())
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(NuvyraSpacing.md)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        WorkoutSummaryCard(summary: WorkoutDailySummary(date: Date(), totalCalories: 420, totalMinutes: 55, sessionCount: 2)).padding()
    }
}
#endif
