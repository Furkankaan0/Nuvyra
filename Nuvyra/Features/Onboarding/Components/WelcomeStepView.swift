import SwiftUI

struct WelcomeStepView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: NuvyraSpacing.xl) {
            PremiumOnboardingHero(
                symbol: "leaf.circle.fill",
                value: "N",
                caption: "kişisel ritim"
            )

            VStack(spacing: NuvyraSpacing.md) {
                Text("Nuvyra'ya hoş geldin")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .minimumScaleFactor(0.72)

                Text("Sert diyet listeleri yerine beslenme, su ve yürüyüş ritmini sana uygun bir wellness planına dönüştürelim.")
                    .font(.title3.weight(.medium))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .frame(maxWidth: 360)
            }

            NuvyraGlassCard {
                VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                    PremiumBullet(title: "Kişisel hedefler", subtitle: "Kalori, protein, karbonhidrat, yağ, su ve adım hedeflerin otomatik hesaplanır.", symbol: "sparkles")
                    PremiumBullet(title: "Wellness dili", subtitle: "Nuvyra suçluluk değil, sürdürülebilir ritim kurar.", symbol: "heart.text.square")
                    PremiumBullet(title: "Privacy-first", subtitle: "Sağlık verisi yalnızca izin verdiğin ölçüde ve uygulama içi içgörüler için kullanılır.", symbol: "lock.shield")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}
