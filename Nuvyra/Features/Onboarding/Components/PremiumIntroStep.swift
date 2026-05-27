import SwiftUI

struct PremiumIntroStep: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: NuvyraSpacing.xl) {
            PremiumOnboardingHero(
                symbol: "crown.fill",
                value: "Premium",
                caption: "ritim içgörüleri"
            )

            VStack(spacing: NuvyraSpacing.sm) {
                Text("Daha net trendler. Daha sakin koçluk.")
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.primaryText(scheme))

                Text("Premium, günlük takibi baskıya çevirmeden haftalık ritmini daha okunur ve kişisel hale getirir.")
                    .font(.body.weight(.medium))
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .frame(maxWidth: 360)
            }

            NuvyraGlassCard {
                VStack(spacing: NuvyraSpacing.md) {
                    PremiumBullet(title: "Haftalık trendler", subtitle: "Kalori, su ve adım ritmini tek premium özetle gör.", symbol: "chart.line.uptrend.xyaxis")
                    PremiumBullet(title: "Gelişmiş yürüyüş içgörüleri", subtitle: "Düşük günlerde bile uygulanabilir mini toparlanma planları.", symbol: "figure.walk.motion")
                    PremiumBullet(title: "Premium widget deneyimi", subtitle: "Ritmini kilit ekranına ve ana ekrana daha şık taşı.", symbol: "rectangle.on.rectangle")
                }
            }

            Text("Fiyat, deneme ve iptal bilgileri Premium ekranında net şekilde gösterilir.")
                .font(.caption.weight(.medium))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .multilineTextAlignment(.center)
        }
    }
}
