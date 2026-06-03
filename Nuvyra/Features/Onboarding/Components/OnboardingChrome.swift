import SwiftUI

/// Top header — Nuvyra wordmark, step label and the segmented progress
/// indicator. Premium tasarım: wordmark soluk gradient, sağda step chip,
/// altında dot/segment indicator + ince animated gradient bar.
struct OnboardingProgressHeader: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var progress: Double
    var stepLabel: String
    /// 1-based. 0 verilirse stepLabel'dan parse'a düşer — geriye uyumluluk.
    var currentStep: Int = 0
    /// Toplam adım sayısı. 0 verilirse dot indicator render edilmez.
    var totalSteps: Int = 0

    private var clampedProgress: Double { min(max(progress, 0), 1) }

    var body: some View {
        VStack(spacing: NuvyraSpacing.md) {
            HStack(spacing: NuvyraSpacing.sm) {
                wordmark
                Spacer()
                stepChip
            }

            if totalSteps > 0 {
                segmentedIndicator
            }

            progressBar
        }
    }

    // MARK: - Subviews

    private var wordmark: some View {
        HStack(spacing: 6) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(LinearGradient(
                    colors: [NuvyraColors.accent, NuvyraColors.softMint],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Text("Nuvyra")
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .foregroundStyle(NuvyraColors.primaryText(scheme))
        }
    }

    private var stepChip: some View {
        HStack(spacing: 5) {
            Text(stepLabel)
                .font(.footnote.weight(.bold))
                .foregroundStyle(NuvyraColors.accent)
                .contentTransition(.numericText())
            Text("Adım")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(NuvyraColors.accent.opacity(scheme == .dark ? 0.16 : 0.10))
        )
        .overlay(
            Capsule()
                .stroke(NuvyraColors.accent.opacity(0.22), lineWidth: 1)
        )
    }

    /// Toplam step kadar küçük çubuk; tamamlanan dolu, mevcut accent, kalan soluk.
    private var segmentedIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { index in
                let isCompleted = index < currentStep - 1
                let isCurrent = index == currentStep - 1
                Capsule()
                    .fill(segmentColor(isCompleted: isCompleted, isCurrent: isCurrent))
                    .frame(height: 4)
                    .scaleEffect(y: isCurrent ? 1.55 : 1.0, anchor: .center)
                    .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.75), value: currentStep)
            }
        }
        .accessibilityHidden(true)
    }

    private func segmentColor(isCompleted: Bool, isCurrent: Bool) -> AnyShapeStyle {
        if isCurrent {
            return AnyShapeStyle(LinearGradient(
                colors: [NuvyraColors.accent, NuvyraColors.softMint],
                startPoint: .leading,
                endPoint: .trailing
            ))
        }
        if isCompleted {
            return AnyShapeStyle(NuvyraColors.accent.opacity(0.72))
        }
        return AnyShapeStyle(NuvyraColors.accent.opacity(scheme == .dark ? 0.18 : 0.14))
    }

    /// İnce arka-plan progress çubuğu — segmented indicator yokken tek başına
    /// kullanıma uygun; yanında olduğunda subtle reinforcement sağlar.
    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(NuvyraColors.accent.opacity(scheme == .dark ? 0.10 : 0.07))
                Capsule()
                    .fill(LinearGradient(
                        colors: [NuvyraColors.accent, NuvyraColors.softMint, NuvyraColors.paleLime],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: max(0, proxy.size.width * clampedProgress))
                    .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.85), value: clampedProgress)
            }
        }
        .frame(height: totalSteps > 0 ? 3 : 7)
        .accessibilityLabel("Onboarding ilerlemesi yüzde \(Int(clampedProgress * 100))")
    }
}

/// Bottom toolbar — back/primary actions, optional skip link, medical
/// disclaimer. Errors are surfaced via the parent's `.alert` instead of an
/// inline toast so the user never sees the same message twice.
struct OnboardingControlBar: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var canGoBack: Bool
    var primaryTitle: String
    var primaryIcon: String
    var isCompleting: Bool
    /// Optional "Şimdi değil" / "Şimdi değil, dashboard'a geç" link rendered
    /// below the primary button. Only the current step decides if a skip is
    /// allowed (e.g. health / premium); other steps pass nil and the link
    /// is hidden.
    var secondaryTitle: String? = nil
    var onBack: () -> Void
    var onPrimary: () -> Void
    var onSecondary: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: NuvyraSpacing.sm) {
            HStack(spacing: NuvyraSpacing.md) {
                if canGoBack {
                    NuvyraSecondaryButton(title: String(localized: "onboarding.back"), systemImage: "chevron.left", action: onBack)
                        .frame(width: 118)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .accessibilityIdentifier("onboarding.back")
                }

                NuvyraPrimaryButton(
                    title: primaryTitle,
                    systemImage: primaryIcon,
                    isLoading: isCompleting,
                    action: onPrimary
                )
                .accessibilityIdentifier("onboarding.primary")
            }

            if let secondaryTitle, let onSecondary, !isCompleting {
                Button(action: onSecondary) {
                    Text(secondaryTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        .underline()
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
                .accessibilityIdentifier("onboarding.secondary")
                .accessibilityHint("Bu adımı şimdi değil olarak işaretle.")
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
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: secondaryTitle != nil)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isCompleting)
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
