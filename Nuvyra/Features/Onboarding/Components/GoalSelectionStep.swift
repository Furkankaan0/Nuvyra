import SwiftUI

struct GoalSelectionStep: View {
    let selectedGoal: GoalType
    let onSelect: (GoalType) -> Void

    private let goals: [GoalType] = [.loseWeight, .maintain, .gainMuscle, .healthyLiving, .stayFit]

    var body: some View {
        PremiumQuestionLayout(
            eyebrow: "Hedef",
            title: "Nuvyra'yı ne için kullanmak istiyorsun?",
            subtitle: "Hedefin kalori dengesini, protein oranını ve adım önerisini belirler."
        ) {
            VStack(spacing: NuvyraSpacing.sm) {
                ForEach(goals) { goal in
                    SelectableOptionCard(
                        title: goal.title,
                        subtitle: goal.onboardingSubtitle,
                        symbol: goal.onboardingSymbol,
                        isSelected: selectedGoal == goal
                    ) {
                        onSelect(goal)
                    }
                }
            }
        }
    }
}
