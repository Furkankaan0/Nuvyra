import SwiftUI

struct WelcomeStepView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        VStack(spacing: NuvyraSpacing.xl) {
            PremiumOnboardingHero(
                symbol: "leaf.circle.fill",
                value: "N",
                caption: "kişisel ritim"
            )
            .scaleEffect(hasAppeared ? 1.0 : 0.92)
            .opacity(hasAppeared ? 1 : 0)

            VStack(spacing: NuvyraSpacing.md) {
                Text("Nuvyra'ya hoş geldin")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(titleGradient)
                    .minimumScaleFactor(0.72)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 14)

                Text("Sert diyet listeleri yerine beslenme, su ve yürüyüş ritmini sana uygun bir wellness planına dönüştürelim.")
                    .font(.title3.weight(.medium))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .frame(maxWidth: 360)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 12)
            }

            NuvyraGlassCard {
                VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                    PremiumBullet(title: "Kişisel hedefler", subtitle: "Kalori, protein, karbonhidrat, yağ, su ve adım hedeflerin otomatik hesaplanır.", symbol: "sparkles")
                    PremiumBullet(title: "Wellness dili", subtitle: "Nuvyra suçluluk değil, sürdürülebilir ritim kurar.", symbol: "heart.text.square")
                    PremiumBullet(title: "Privacy-first", subtitle: "Sağlık verisi yalnızca izin verdiğin ölçüde ve uygulama içi içgörüler için kullanılır.", symbol: "lock.shield")
                }
            }
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 18)
        }
        .accessibilityElement(children: .contain)
        .onAppear {
            guard !hasAppeared else { return }
            if reduceMotion {
                hasAppeared = true
                return
            }
            withAnimation(.spring(response: 0.68, dampingFraction: 0.78).delay(0.05)) {
                hasAppeared = true
            }
        }
    }

    /// Wordmark + heading için yumuşak accent gradient. Dark mode'da bir tık
    /// daha aydınlık tonlar, light mode'da daha doygun.
    private var titleGradient: LinearGradient {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(red: 0.95, green: 0.97, blue: 0.93), NuvyraColors.softMint, NuvyraColors.accent.opacity(0.92)]
                : [NuvyraColors.primaryText(scheme), NuvyraColors.accent, NuvyraColors.accent.opacity(0.82)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
