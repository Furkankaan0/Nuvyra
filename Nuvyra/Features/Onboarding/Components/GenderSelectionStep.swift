import SwiftUI

struct GenderSelectionStep: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var selectedGender: Gender

    private let options: [Gender] = [.male, .female, .preferNotToSay]

    var body: some View {
        PremiumQuestionLayout(
            eyebrow: "Profil",
            title: "Sana en uygun hesaplama için cinsiyet seç.",
            subtitle: "Bu bilgi yalnızca BMR hesaplamasını kişiselleştirmek için kullanılır."
        ) {
            VStack(spacing: NuvyraSpacing.sm) {
                ForEach(options) { gender in
                    SelectableOptionCard(
                        title: gender.title,
                        subtitle: gender == .preferNotToSay ? "Nötr formül kullanılır." : "Mifflin-St Jeor formülü bu seçime göre ayarlanır.",
                        symbol: gender.onboardingSymbol,
                        isSelected: selectedGender == gender
                    ) {
                        selectedGender = gender
                    }
                }
            }

            Text("İstersen daha sonra Profil ekranından değiştirebilirsin.")
                .font(.caption.weight(.medium))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .padding(.horizontal, 2)
        }
    }
}
