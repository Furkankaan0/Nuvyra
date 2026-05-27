import SwiftUI

struct PersonalizedSummaryStep: View {
    @Environment(\.colorScheme) private var scheme
    let targets: CalculatedNutritionTargets
    let input: NutritionGoalCalculationInput

    var body: some View {
        VStack(spacing: NuvyraSpacing.lg) {
            PremiumOnboardingHero(
                symbol: "checkmark.seal.fill",
                value: "\(targets.dailyCalories)",
                caption: "kcal / gün"
            )

            VStack(spacing: NuvyraSpacing.sm) {
                Text("Harika. Günlük ritmin hazır.")
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.primaryText(scheme))

                Text("Nuvyra bu planı Mifflin-St Jeor BMR, aktivite katsayısı ve seçtiğin hedef temposuna göre oluşturdu.")
                    .font(.body.weight(.medium))
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .frame(maxWidth: 360)
            }

            NuvyraGlassCard {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    Label("Kişisel hedeflerin", systemImage: "sparkles")
                        .font(NuvyraTypography.section)
                        .foregroundStyle(NuvyraColors.primaryText(scheme))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: NuvyraSpacing.sm) {
                        SummaryMetricCard(title: "Kalori", value: "\(targets.dailyCalories)", unit: "kcal", symbol: "flame.fill", tint: NuvyraColors.mutedCoral)
                        SummaryMetricCard(title: "Protein", value: "\(targets.proteinGrams)", unit: "g", symbol: "bolt.heart.fill", tint: NuvyraColors.accent)
                        SummaryMetricCard(title: "Karbonhidrat", value: "\(targets.carbsGrams)", unit: "g", symbol: "leaf.fill", tint: NuvyraColors.softMint)
                        SummaryMetricCard(title: "Yağ", value: "\(targets.fatGrams)", unit: "g", symbol: "drop.fill", tint: NuvyraColors.softSand)
                        SummaryMetricCard(title: "Su", value: targets.waterLitersText, unit: "", symbol: "drop.circle.fill", tint: NuvyraColors.softMint)
                        SummaryMetricCard(title: "Adım", value: targets.stepTarget.formatted(.number.grouping(.automatic)), unit: "", symbol: "figure.walk", tint: NuvyraColors.paleLime)
                    }

                    Text("Bu değerler wellness hedefidir; tıbbi tanı veya tedavi önerisi değildir. Sağlık durumun veya özel beslenme ihtiyacın varsa profesyonel destek al.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                }
            }

            SoftNoticeCard(
                title: "Enerji temeli",
                subtitle: "BMR \(targets.bmr) kcal, aktivite sonrası yaklaşık TDEE \(targets.tdee) kcal. Nuvyra hedefini buradan kişiselleştirdi.",
                symbol: "function"
            )
        }
    }
}
