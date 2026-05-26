import SwiftUI

/// Modal that lands in front of the user when an `UpsellTrigger` fires. Keeps
/// the hard ask (purchase) behind one more tap into the full `PremiumView` —
/// this sheet is the warm-up, not a forced paywall.
struct BehavioralPaywallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    let trigger: UpsellTrigger
    var onExplorePremium: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                NuvyraBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: NuvyraSpacing.lg) {
                        Spacer(minLength: NuvyraSpacing.lg)
                        hero
                        message
                        actions
                        Text("Premium ekranında fiyatlar, deneme süresi ve iptal bilgileri net şekilde gösterilir.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, NuvyraSpacing.xs)
                    }
                    .padding(.horizontal, NuvyraSpacing.lg)
                    .padding(.bottom, NuvyraSpacing.xl)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDismiss()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Kapat")
                }
            }
            .interactiveDismissDisabled(false)
        }
    }

    private var hero: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(colors: [NuvyraColors.accent, NuvyraColors.softMint], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 120, height: 120)
                .shadow(color: NuvyraColors.accent.opacity(0.35), radius: 20, y: 10)
            Image(systemName: trigger.systemImage)
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var message: some View {
        VStack(spacing: NuvyraSpacing.sm) {
            Text(trigger.title)
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                .multilineTextAlignment(.center)
                .foregroundStyle(NuvyraColors.primaryText(scheme))
            Text(trigger.subtitle)
                .font(.body.weight(.medium))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .frame(maxWidth: 360)
        }
    }

    private var actions: some View {
        VStack(spacing: NuvyraSpacing.sm) {
            NuvyraPrimaryButton(title: "Premium'u keşfet", systemImage: "sparkles") {
                onExplorePremium()
                dismiss()
            }
            Button {
                onDismiss()
                dismiss()
            } label: {
                Text("Şimdi değil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NuvyraColors.accent)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
    }
}

#if DEBUG
#Preview {
    BehavioralPaywallSheet(
        trigger: .oneWeekActive,
        onExplorePremium: {},
        onDismiss: {}
    )
}
#endif
