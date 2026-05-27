import SwiftData
import SwiftUI

/// Thin orchestrator for the onboarding flow. Every step view, shared
/// component and bottom toolbar lives under `Features/Onboarding/Components/`.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var dependencies: DependencyContainer
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            NuvyraBackground()
            VStack(spacing: 0) {
                OnboardingProgressHeader(progress: viewModel.progress, stepLabel: viewModel.stepLabel)
                    .padding(.horizontal, NuvyraSpacing.lg)
                    .padding(.top, NuvyraSpacing.md)

                ScrollView(showsIndicators: false) {
                    OnboardingStepContent(viewModel: viewModel)
                        .id(viewModel.currentStep.id)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .padding(.horizontal, NuvyraSpacing.lg)
                        .padding(.top, NuvyraSpacing.lg)
                        .padding(.bottom, 156)
                }
                .scrollDismissesKeyboard(.interactively)
                .animation(reduceMotion ? nil : .smooth(duration: 0.34), value: viewModel.pageIndex)
            }
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingControlBar(
                canGoBack: viewModel.pageIndex > 0,
                primaryTitle: viewModel.primaryButtonTitle,
                primaryIcon: viewModel.primaryButtonIcon,
                isCompleting: viewModel.isCompleting,
                errorMessage: viewModel.errorMessage,
                onBack: {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
                        viewModel.back()
                    }
                },
                onPrimary: {
                    if viewModel.isLastPage {
                        Task { await viewModel.complete(context: modelContext, dependencies: dependencies) }
                    } else {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
                            viewModel.next()
                        }
                    }
                }
            )
        }
        .task { await dependencies.analytics.track(.onboardingStarted, payload: AnalyticsPayload()) }
        .alert("Başlangıç tamamlanamadı", isPresented: errorBinding) {
            Button("Tamam", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Lütfen tekrar dene.")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented { viewModel.errorMessage = nil }
            }
        )
    }
}

#Preview {
    OnboardingView()
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
