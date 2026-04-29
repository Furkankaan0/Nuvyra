import SwiftUI

struct NuvyraMetricCard: View {
    @Environment(\.colorScheme) private var scheme
    var title: String
    var value: String
    var caption: String
    var systemImage: String
    var tint: Color = NuvyraColors.accent

    var body: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                Label(title, systemImage: systemImage)
                    .font(NuvyraTypography.caption.weight(.semibold))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                Text(value)
                    .font(NuvyraTypography.metric)
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .minimumScaleFactor(0.62)
                Text(caption)
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value), \(caption)")
    }
}
