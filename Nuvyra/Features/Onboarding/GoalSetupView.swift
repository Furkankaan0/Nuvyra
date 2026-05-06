import SwiftUI

struct GoalSetupView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var scheme

    private let goals: [GoalType] = [.loseWeight, .maintain, .gainMuscle, .healthyLiving, .stayFit]

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                NuvyraSectionHeader(
                    title: "Planını kişiselleştir",
                    subtitle: "Bunu katı bir hedef değil, başlangıç ritmi olarak düşün."
                )

                VStack(spacing: NuvyraSpacing.sm) {
                    ForEach(goals) { goal in
                        Button {
                            viewModel.selectGoal(goal)
                        } label: {
                            HStack(spacing: NuvyraSpacing.md) {
                                Image(systemName: goal.legacyOnboardingSymbol)
                                    .foregroundStyle(viewModel.selectedGoal == goal ? .white : NuvyraColors.accent)
                                    .frame(width: 38, height: 38)
                                    .background(viewModel.selectedGoal == goal ? NuvyraColors.accent : NuvyraColors.accent.opacity(0.12), in: Circle())

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(goal.title)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                                    Text(goal.legacyOnboardingSubtitle)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                                }

                                Spacer()

                                Image(systemName: viewModel.selectedGoal == goal ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(viewModel.selectedGoal == goal ? NuvyraColors.accent : NuvyraColors.secondaryText(scheme).opacity(0.5))
                            }
                            .padding(14)
                            .background(NuvyraColors.card(scheme).opacity(0.62), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private extension GoalType {
    var legacyOnboardingSubtitle: String {
        switch self {
        case .loseWeight:
            "Nazik kalori açığı, yüksek protein ve gerçekçi adım hedefi."
        case .maintain:
            "Enerji dengesini koruyan sakin günlük ritim."
        case .gainHealthy:
            "Daha yüksek enerji hedefiyle sağlıklı kilo artışı."
        case .gainMuscle:
            "Protein odağı yüksek, kontrollü kalori fazlası."
        case .walkMore:
            "Walking-first planla adımı alışkanlığa çevir."
        case .eatHealthier:
            "Öğün farkındalığını sade ve sürdürülebilir artır."
        case .healthyLiving:
            "Beslenme, su ve hareket dengesini bütünsel kur."
        case .stayFit:
            "Formunu korurken adım ve makro ritmini netleştir."
        }
    }

    var legacyOnboardingSymbol: String {
        switch self {
        case .loseWeight: "arrow.down.forward.circle.fill"
        case .maintain: "equal.circle.fill"
        case .gainHealthy: "plus.circle.fill"
        case .gainMuscle: "dumbbell.fill"
        case .walkMore: "figure.walk.circle.fill"
        case .eatHealthier: "leaf.circle.fill"
        case .healthyLiving: "heart.circle.fill"
        case .stayFit: "sparkles"
        }
    }
}
