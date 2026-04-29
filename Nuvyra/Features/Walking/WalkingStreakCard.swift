import SwiftUI

struct WalkingStreakCard: View {
    var streak: Int
    var averageSteps: Int
    var completionRate: Double

    var body: some View {
        HStack(spacing: NuvyraSpacing.md) {
            NuvyraMetricCard(title: "Streak", value: "\(streak)", caption: "gün", systemImage: "flame")
            NuvyraMetricCard(title: "Ortalama", value: averageSteps.formatted(), caption: "3 gün", systemImage: "chart.bar")
        }
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                Text("Hedef tamamlama")
                    .font(NuvyraTypography.section)
                ProgressView(value: completionRate)
                    .tint(NuvyraColors.accent)
                Text("Son 7 günün yüzde \(Int(completionRate * 100)) kadarı hedefe yakın ilerledi.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
