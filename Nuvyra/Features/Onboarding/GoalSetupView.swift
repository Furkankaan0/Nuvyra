import SwiftUI

struct GoalSetupView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
            TextField("Adın", text: $viewModel.name)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Adın")

            NuvyraSectionHeader(title: "Hedef seçimi", subtitle: "Hedefini daha sonra Ayarlar'dan değiştirebilirsin.")
            ForEach([GoalType.loseWeight, .maintain, .walkMore, .eatHealthier]) { goal in
                NuvyraChip(title: goal.title, isSelected: viewModel.selectedGoal == goal) {
                    viewModel.selectedGoal = goal
                }
            }
        }
        .padding(.horizontal, NuvyraSpacing.lg)
    }
}
