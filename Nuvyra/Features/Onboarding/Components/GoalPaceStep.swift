import SwiftUI

struct GoalPaceStep: View {
    @Binding var selectedPace: GoalPace

    var body: some View {
        PremiumQuestionLayout(
            eyebrow: "Tempo",
            title: "İlerleme hızını seç.",
            subtitle: "Nuvyra kalori ayarını bu tempoya göre yapar. Hızlı tempo bile suçlayıcı dile dönüşmez."
        ) {
            VStack(spacing: NuvyraSpacing.sm) {
                ForEach(GoalPace.allCases) { pace in
                    SelectableOptionCard(
                        title: pace.title,
                        subtitle: pace.subtitle,
                        symbol: pace.onboardingSymbol,
                        isSelected: selectedPace == pace
                    ) {
                        selectedPace = pace
                    }
                }
            }
        }
    }
}
