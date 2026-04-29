import SwiftUI

struct TodaySummaryCard: View {
    var title: String
    var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
            Text(title)
                .font(NuvyraTypography.hero)
            Text(DateFormatter.nuvyraShortDate.string(from: date))
                .font(NuvyraTypography.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
