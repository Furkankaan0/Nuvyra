import SwiftUI

/// Top header — Nuvyra wordmark, step label and the multi-tone progress bar.
struct OnboardingProgressHeader: View {
    @Environment(\.colorScheme) private var scheme
    var progress: Double
    var stepLabel: String

    private var clampedProgress: Double { min(max(progress, 0), 1) }

    var body: some View {
        VStack(spacing: NuvyraSpacing.sm) {
            HStack {
                Text("Nuvyra")
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                Spacer()
                Text(stepLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(NuvyraColors.card(scheme).opacity(0.72), in: Capsule())
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(NuvyraColors.accent.opacity(scheme == .dark ? 0.18 : 0.12))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [NuvyraColors.accent, NuvyraColors.softMint, NuvyraColors.paleLime],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * clampedProgress)
                }
            }
            .frame(height: 7)
            .accessibilityLabel("Onboarding ilerlemesi yüzde \(Int(clampedProgress * 100))")
        }
    }
}

/// Bottom toolbar — error toast + back/primary actions + medical disclaimer.
struct OnboardingControlBar: View {
    @Environment(\.colorScheme) private var scheme
    var canGoBack: Bool
    var primaryTitle: String
    var primaryIcon: String
    var isCompleting: Bool
    var errorMessage: String?
    var onBack: () -> Void
    var onPrimary: () -> Void

    var body: some View {
        VStack(spacing: NuvyraSpacing.sm) {
            if let errorMessage {
                Text(errorMessage)
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(NuvyraColors.mutedCoral)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: NuvyraSpacing.md) {
                if canGoBack {
                    NuvyraSecondaryButton(title: "Geri", systemImage: "chevron.left", action: onBack)
                        .frame(width: 118)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                NuvyraPrimaryButton(title: primaryTitle, systemImage: primaryIcon, action: onPrimary)
                    .disabled(isCompleting)
                    .opacity(isCompleting ? 0.72 : 1)
            }

            Text("Nuvyra wellness uygulamasıdır; tıbbi tanı veya tedavi tavsiyesi vermez.")
                .font(.caption2.weight(.medium))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .multilineTextAlignment(.center)
                .padding(.top, NuvyraSpacing.xs)
        }
        .padding(.horizontal, NuvyraSpacing.lg)
        .padding(.top, NuvyraSpacing.md)
        .padding(.bottom, NuvyraSpacing.md)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(scheme == .dark ? 0.08 : 0.42))
                .frame(height: 1)
        }
    }
}

/// Switch over `viewModel.currentStep` and render the right step body.
/// Lifted out of `OnboardingView` so the orchestrator stays thin.
struct OnboardingStepContent: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        Group {
            switch viewModel.currentStep {
            case .welcome:
                WelcomeStepView()
            case .gender:
                GenderSelectionStep(selectedGender: $viewModel.selectedGender)
            case .age:
                NumberPickerStep(
                    eyebrow: "Profil",
                    title: "Yaşını seç.",
                    subtitle: "Nuvyra günlük enerji hedefini yaşına göre daha gerçekçi ayarlar.",
                    value: $viewModel.age,
                    range: 13...100,
                    unit: "yaş",
                    symbol: "calendar"
                )
            case .height:
                NumberPickerStep(
                    eyebrow: "Vücut ölçüsü",
                    title: "Boyunu seç.",
                    subtitle: "BMR ve günlük su hedefini hesaplarken santimetre bazlı ölçüm kullanırız.",
                    value: $viewModel.heightCm,
                    range: 130...220,
                    unit: "cm",
                    symbol: "ruler"
                )
            case .weight:
                NumberPickerStep(
                    eyebrow: "Vücut ölçüsü",
                    title: "Kilonu seç.",
                    subtitle: "Kalori, makro ve su hedeflerinin temelini bu değer oluşturur.",
                    value: $viewModel.weightKg,
                    range: 35...220,
                    unit: "kg",
                    symbol: "scalemass"
                )
            case .activity:
                ActivityLevelStep(selectedActivityLevel: $viewModel.activityLevel)
            case .goal:
                GoalSelectionStep(selectedGoal: viewModel.selectedGoal) { goal in
                    viewModel.selectGoal(goal)
                }
            case .pace:
                GoalPaceStep(selectedPace: $viewModel.goalPace)
            case .goalWeight:
                GoalWeightStep(
                    usesGoalWeight: $viewModel.usesGoalWeight,
                    targetWeightKg: $viewModel.targetWeightKg,
                    currentWeightKg: viewModel.weightKg
                )
            case .summary:
                PersonalizedSummaryStep(targets: viewModel.targets, input: viewModel.calculationInput)
            case .health:
                HealthSetupStep(viewModel: viewModel)
            case .premium:
                PremiumIntroStep()
            }
        }
    }
}
