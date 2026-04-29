import SwiftUI

struct NuvyraSectionHeader: View {
    var title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
            Text(title).font(NuvyraTypography.section)
            if let subtitle {
                Text(subtitle).font(NuvyraTypography.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
