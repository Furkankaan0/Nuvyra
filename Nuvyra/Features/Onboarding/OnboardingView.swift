import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dependencies: DependencyContainer
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            NuvyraBackground()
            VStack(spacing: NuvyraSpacing.md) {
                TabView(selection: $viewModel.pageIndex) {
                    ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                        VStack(spacing: NuvyraSpacing.lg) {
                            OnboardingPageView(page: page, progress: Double(index + 1) / Double(viewModel.pages.count))
                            if index == viewModel.pages.count - 1 {
                                GoalSetupView(viewModel: viewModel)
                                HealthPermissionView(viewModel: viewModel)
                            }
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: NuvyraSpacing.md) {
                    if viewModel.pageIndex > 0 {
                        NuvyraSecondaryButton(title: "Geri", systemImage: "chevron.left") { viewModel.back() }
                            .frame(width: 126)
                    }
                    NuvyraPrimaryButton(title: viewModel.isLastPage ? "Ritmime başla" : "Devam", systemImage: viewModel.isLastPage ? "checkmark" : "arrow.right") {
                        if viewModel.isLastPage {
                            Task { await viewModel.complete(context: modelContext, dependencies: dependencies) }
                        } else {
                            viewModel.next()
                        }
                    }
                }
                .padding(.horizontal, NuvyraSpacing.lg)
                .padding(.bottom, NuvyraSpacing.lg)
            }
        }
        .task { await dependencies.analytics.track(.onboardingStarted, payload: AnalyticsPayload()) }
    }
}

#Preview {
    OnboardingView()
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
