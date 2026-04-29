import SwiftUI

struct TrendCard: View {
    var title: String
    var value: String
    var detail: String
    var systemImage: String

    var body: some View {
        NuvyraCard {
            HStack(spacing: NuvyraSpacing.md) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(NuvyraColors.accent)
                    .frame(width: 44, height: 44)
                    .background(NuvyraColors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: NuvyraRadius.sm))
                VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
                    Text(title).font(NuvyraTypography.section)
                    Text(value).font(.title2.weight(.bold))
                    Text(detail).foregroundStyle(.secondary)
                }
            }
        }
    }
}
