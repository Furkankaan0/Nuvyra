import SwiftUI

struct PremiumFeatureGate<Content: View>: View {
    @EnvironmentObject private var dependencies: DependencyContainer
    @Environment(\.colorScheme) private var scheme
    let title: String
    let subtitle: String
    let systemImage: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String = "crown.fill",
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        if dependencies.subscriptionManager.isPremium {
            content
        } else {
            lockedCard
        }
    }

    private var lockedCard: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        LinearGradient(colors: [NuvyraColors.accent, NuvyraColors.softMint], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                    )

                Text(title)
                    .font(NuvyraTypography.section)
                    .foregroundStyle(NuvyraColors.primaryText(scheme))

                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))

                NavigationLink {
                    PremiumView()
                } label: {
                    Label("Premium'u keşfet", systemImage: "sparkles")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(NuvyraColors.accent)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
