import SwiftUI

struct OnboardingPageView: View {
    @Environment(\.colorScheme) private var scheme
    var page: OnboardingPageContent
    var progress: Double

    var body: some View {
        VStack(spacing: NuvyraSpacing.xl) {
            ZStack {
                NuvyraProgressRing(progress: progress, lineWidth: 16, center: "N", caption: "Nuvyra")
                    .frame(width: 210, height: 210)
                Image(systemName: page.systemImage)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(NuvyraColors.accent)
                    .offset(y: 82)
            }
            VStack(spacing: NuvyraSpacing.md) {
                Text(page.title)
                    .font(NuvyraTypography.hero)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                Text(page.subtitle)
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .padding(.horizontal)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, NuvyraSpacing.xl)
        .accessibilityElement(children: .combine)
    }
}
