import SwiftUI

struct SafetyDisclaimerView: View {
    @Environment(\.colorScheme) private var scheme
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: NuvyraSpacing.sm) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(NuvyraColors.accent)
                .font(.subheadline.weight(.bold))
            VStack(alignment: .leading, spacing: 4) {
                Text(compact ? AICoachSafetyDisclaimer.short : "AI Coach hakkında")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                if !compact {
                    Text(AICoachSafetyDisclaimer.long)
                        .font(.caption)
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(NuvyraSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NuvyraColors.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                .stroke(NuvyraColors.accent.opacity(0.18))
        )
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        SafetyDisclaimerView()
        SafetyDisclaimerView(compact: true)
    }
    .padding()
    .background(NuvyraBackground())
}
#endif
