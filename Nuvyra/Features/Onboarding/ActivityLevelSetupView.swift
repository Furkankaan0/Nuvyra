import SwiftUI

/// Onboarding step that captures the user's activity level so the calorie
/// target can be scaled (TDEE = BMR × multiplier).
struct ActivityLevelSetupView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                NuvyraSectionHeader(
                    title: "Aktivite seviyen",
                    subtitle: "En yakın seçimi yap. Bunu istediğin zaman ayarlardan değiştirebilirsin."
                )

                VStack(spacing: NuvyraSpacing.sm) {
                    ForEach(ActivityLevel.allCases) { level in
                        ActivityOptionRow(
                            level: level,
                            isSelected: viewModel.activityLevel == level
                        ) {
                            viewModel.activityLevel = level
                        }
                    }
                }
            }
        }
    }
}

private struct ActivityOptionRow: View {
    @Environment(\.colorScheme) private var scheme
    var level: ActivityLevel
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: NuvyraSpacing.md) {
                Image(systemName: level.systemImage)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isSelected ? .white : NuvyraColors.accent)
                    .frame(width: 38, height: 38)
                    .background(isSelected ? NuvyraColors.accent : NuvyraColors.accent.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: NuvyraSpacing.xs) {
                        Text(level.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(NuvyraColors.primaryText(scheme))
                        Text(String(format: "× %.3f", level.multiplier))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    }
                    Text(level.subtitle)
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
        .accessibilityLabel(level.title)
        .accessibilityHint(level.subtitle)
        .accessibilityValue(isSelected ? "Seçili" : "Seçili değil")
    }
}
