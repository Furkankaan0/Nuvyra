import SwiftUI

struct GoalSetupView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var scheme

    private let goals: [GoalType] = [.loseWeight, .maintain, .walkMore, .eatHealthier]

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                NuvyraSectionHeader(
                    title: "Planını kişiselleştir",
                    subtitle: "Bunu katı bir hedef değil, başlangıç ritmi olarak düşün."
                )

                nameField

                VStack(spacing: NuvyraSpacing.sm) {
                    ForEach(goals) { goal in
                        GoalOptionRow(
                            goal: goal,
                            isSelected: viewModel.selectedGoal == goal
                        ) {
                            viewModel.selectedGoal = goal
                        }
                    }
                }

                TargetPreviewCard(preview: viewModel.targetPreview)
            }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
            Text("Sana nasıl hitap edelim?")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))

            HStack(spacing: NuvyraSpacing.sm) {
                Image(systemName: "person.crop.circle")
                    .foregroundStyle(NuvyraColors.accent)
                TextField("Adın opsiyonel", text: $viewModel.name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .font(.body.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(NuvyraColors.card(scheme).opacity(scheme == .dark ? 0.72 : 0.84), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                    .stroke(NuvyraColors.accent.opacity(0.16))
            )
            .accessibilityLabel("Adın opsiyonel")
        }
    }
}

private struct GoalOptionRow: View {
    @Environment(\.colorScheme) private var scheme
    var goal: GoalType
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: NuvyraSpacing.md) {
                Image(systemName: goal.onboardingSymbol)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isSelected ? .white : NuvyraColors.accent)
                    .frame(width: 38, height: 38)
                    .background(isSelected ? NuvyraColors.accent : NuvyraColors.accent.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                    Text(goal.onboardingSubtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        .lineLimit(2)
                }

                Spacer(minLength: NuvyraSpacing.sm)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? NuvyraColors.accent : NuvyraColors.secondaryText(scheme).opacity(0.52))
            }
            .padding(14)
            .background(
                isSelected ? NuvyraColors.accent.opacity(scheme == .dark ? 0.18 : 0.12) : NuvyraColors.card(scheme).opacity(0.58),
                in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                    .stroke(isSelected ? NuvyraColors.accent.opacity(0.42) : Color.white.opacity(scheme == .dark ? 0.08 : 0.32))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(goal.title)
        .accessibilityHint(goal.onboardingSubtitle)
        .accessibilityValue(isSelected ? "Seçili" : "Seçili değil")
    }
}

private struct TargetPreviewCard: View {
    @Environment(\.colorScheme) private var scheme
    var preview: OnboardingTargetPreview

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
            HStack {
                Label("İlk ritim önerisi", systemImage: "sparkles")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                Spacer()
                Text("Tahmini")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(NuvyraColors.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(NuvyraColors.accent.opacity(0.12), in: Capsule())
            }

            HStack(spacing: NuvyraSpacing.sm) {
                TargetMetric(title: "Kalori", value: "\(preview.calories) kcal")
                TargetMetric(title: "Adım", value: preview.steps)
                TargetMetric(title: "Su", value: preview.water)
            }

            Text(preview.note)
                .font(.caption.weight(.medium))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [NuvyraColors.accent.opacity(0.14), NuvyraColors.paleLime.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
        )
    }
}

private struct TargetMetric: View {
    @Environment(\.colorScheme) private var scheme
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
            Text(value)
                .font(.footnote.weight(.heavy))
                .foregroundStyle(NuvyraColors.primaryText(scheme))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .background(NuvyraColors.card(scheme).opacity(0.58), in: RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous))
    }
}

private extension GoalType {
    var onboardingSubtitle: String {
        switch self {
        case .loseWeight:
            return "Daha yumuşak kalori açığı ve düzenli yürüyüş."
        case .maintain:
            return "Dengeyi koru, su ve öğün ritmini netleştir."
        case .gainHealthy:
            return "Enerjini artırırken sürdürülebilir kal."
        case .walkMore:
            return "Walking-first planla adımı alışkanlığa çevir."
        case .eatHealthier:
            return "Öğün farkındalığını sakin şekilde artır."
        }
    }

    var onboardingSymbol: String {
        switch self {
        case .loseWeight: return "arrow.down.forward.circle.fill"
        case .maintain: return "equal.circle.fill"
        case .gainHealthy: return "plus.circle.fill"
        case .walkMore: return "figure.walk.circle.fill"
        case .eatHealthier: return "leaf.circle.fill"
        }
    }
}
