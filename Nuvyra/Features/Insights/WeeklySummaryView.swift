import SwiftUI

struct WeeklySummaryView: View {
    var insight: String

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Label("Haftalık sağlık özeti", systemImage: "sparkles")
                    .font(NuvyraTypography.section)
                Text(insight)
                    .foregroundStyle(.secondary)
                Text("Bu ekran tıbbi tavsiye vermez; yalnızca uygulama içindeki kayıtlarına göre sakin bir ritim yorumu üretir.")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
