import SwiftData
import SwiftUI

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

                TabView(selection: $viewModel.pageIndex) {
                    ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: NuvyraSpacing.lg) {
                                OnboardingPageView(page: page, progress: Double(index + 1) / Double(viewModel.pages.count))
                                if index == viewModel.pages.count - 1 {
                                    GoalSetupView(viewModel: viewModel)
                                    HealthPermissionView(viewModel: viewModel)
                                } else {
                                    OnboardingHighlightsCard(items: page.highlights)
                                }
                            }
                            .padding(.horizontal, NuvyraSpacing.lg)
                            .padding(.top, NuvyraSpacing.md)
                            .padding(.bottom, 150)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: viewModel.pageIndex)
            }
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingControlBar(
                canGoBack: viewModel.pageIndex > 0,
                isLastPage: viewModel.isLastPage,
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

private struct OnboardingProgressHeader: View {
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

private struct OnboardingHighlightsCard: View {
    @Environment(\.colorScheme) private var scheme
    var items: [String]

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Text("Nuvyra yaklaşımı")
                    .font(NuvyraTypography.section)
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: NuvyraSpacing.sm) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(NuvyraColors.accent)
                        Text(item)
                            .font(NuvyraTypography.body)
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

private struct OnboardingControlBar: View {
    @Environment(\.colorScheme) private var scheme
    var canGoBack: Bool
    var isLastPage: Bool
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

                NuvyraPrimaryButton(
                    title: isLastPage ? (isCompleting ? "Hazırlanıyor" : "Ritmime başla") : "Devam",
                    systemImage: isLastPage ? "checkmark" : "arrow.right",
                    action: onPrimary
                )
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

#Preview {
    OnboardingView()
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
