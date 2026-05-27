import SwiftUI

struct ActivityLevelStep: View {
    @Binding var selectedActivityLevel: ActivityLevel

    var body: some View {
        PremiumQuestionLayout(
            eyebrow: "Günlük hareket",
            title: "Aktivite seviyeni seç.",
            subtitle: "Nuvyra TDEE hesaplamasında bu katsayıyı kullanır ve adım hedefini buna göre nazikçe ayarlar."
        ) {
            VStack(spacing: NuvyraSpacing.sm) {
                ForEach(ActivityLevel.allCases) { level in
                    SelectableOptionCard(
                        title: level.title,
                        subtitle: level.subtitle,
                        symbol: level.onboardingSymbol,
                        trailingText: "x\(String(format: "%.2f", level.multiplier))",
                        isSelected: selectedActivityLevel == level
                    ) {
                        selectedActivityLevel = level
                    }
                }
            }
        }
    }
}
