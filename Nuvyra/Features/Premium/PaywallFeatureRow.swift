import SwiftUI

struct PaywallFeatureRow: View {
    var title: String

    var body: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(NuvyraColors.accent)
            Text(title)
                .font(NuvyraTypography.body)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}
