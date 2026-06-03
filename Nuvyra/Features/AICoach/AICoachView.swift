import SwiftData
import SwiftUI

struct AICoachView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dependencies: DependencyContainer
    @StateObject private var viewModel = AICoachViewModel()
    @FocusState private var composerFocused: Bool

    var body: some View {
        ZStack {
            background
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    hero
                    SafetyDisclaimerView()
                    insightsSection
                    chatSection
                }
                .padding(NuvyraSpacing.lg)
            }
            .refreshable {
                await viewModel.load(context: modelContext, dependencies: dependencies)
            }
        }
        .navigationTitle(String(localized: "aiCoach.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(context: modelContext, dependencies: dependencies)
        }
    }

    // MARK: - Background
    @ViewBuilder
    private var background: some View {
        NuvyraBackground()
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(NuvyraColors.softMint.opacity(0.18))
                    .frame(width: 240, height: 240)
                    .blur(radius: 60)
                    .offset(x: -80, y: -100)
            }
    }

    // MARK: - Hero
    private var hero: some View {
        HStack(spacing: NuvyraSpacing.md) {
            AICoachAvatar(size: 76)
            VStack(alignment: .leading, spacing: 4) {
                Text("aiCoach.title")
                    .font(NuvyraTypography.hero)
                Text("aiCoach.subtitle")
                    .font(NuvyraTypography.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Insights
    @ViewBuilder
    private var insightsSection: some View {
        NuvyraSectionHeader(
            title: String(localized: "aiCoach.insights.title"),
            subtitle: viewModel.isLoadingInsights ? String(localized: "aiCoach.insights.loading") : nil
        )
        if let error = viewModel.errorMessage, viewModel.insights.isEmpty {
            NuvyraErrorStateView(
                title: String(localized: "ai.insights.error.title"),
                message: error,
                onRetry: {
                    Task { await viewModel.load(context: modelContext, dependencies: dependencies) }
                }
            )
        } else if viewModel.insights.isEmpty, viewModel.isLoadingInsights {
            NuvyraGlassCard {
                HStack(spacing: NuvyraSpacing.sm) {
                    ProgressView()
                    Text("aiCoach.insights.preparing.full")
                        .font(NuvyraTypography.body)
                        .foregroundStyle(.secondary)
                }
            }
        } else if viewModel.insights.isEmpty {
            NuvyraGlassCard {
                Text("aiCoach.insights.empty")
                    .font(NuvyraTypography.body)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(spacing: NuvyraSpacing.sm) {
                ForEach(viewModel.insights) { insight in
                    AICoachInsightCard(insight: insight)
                }
            }
        }
    }

    // MARK: - Chat
    private var chatSection: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
            NuvyraSectionHeader(
                title: String(localized: "aiCoach.chat.title"),
                subtitle: String(localized: "aiCoach.chat.subtitle")
            )
            PremiumFeatureGate(
                title: String(localized: "aiCoach.premium.title"),
                subtitle: String(localized: "aiCoach.premium.subtitle"),
                systemImage: "bubble.left.and.bubble.right.fill"
            ) {
                chatBody
            }
        }
    }

    private var chatBody: some View {
        NuvyraGlassCard(.prominent) {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                if viewModel.hasMessages {
                    chatHistory
                    // Glass-pill quick-reply rail surfaces below the chat
                    // history once the conversation has started. Lets the
                    // user keep momentum without typing.
                    quickReplyRail
                } else {
                    AICoachEmptyState(examples: AICoachExampleQuestion.allCases) { example in
                        Task { await viewModel.send(example: example) }
                    }
                }
                if viewModel.isCoachTyping {
                    CoachTypingIndicator()
                }
                composer
                if let error = viewModel.errorMessage, viewModel.hasMessages {
                    NuvyraErrorStateView(
                        title: String(localized: "ai.chat.error.title"),
                        message: error,
                        style: .compact,
                        onRetry: {
                            Task { await viewModel.retryLastFailedReply() }
                        },
                        onDismiss: {
                            viewModel.errorMessage = nil
                        }
                    )
                }
                SafetyDisclaimerView(style: .compact)
            }
        }
    }

    /// Quick-reply rail — three glass pills that fire pre-baked example
    /// questions. Suppressed while the coach is typing so we don't queue
    /// a second request behind the in-flight one.
    @ViewBuilder
    private var quickReplyRail: some View {
        if !viewModel.isCoachTyping {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NuvyraSpacing.xs) {
                    ForEach(AICoachExampleQuestion.allCases.prefix(4)) { example in
                        Button {
                            Task { await viewModel.send(example: example) }
                        } label: {
                            NuvyraGlassPill(
                                systemImage: "sparkles",
                                title: example.rawValue,
                                tint: NuvyraColors.accent
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(example.rawValue)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var chatHistory: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            ForEach(viewModel.messages) { message in
                AICoachMessageBubble(message: message)
            }
            HStack {
                Spacer()
                Button("aiCoach.chat.clear") {
                    viewModel.clearChat()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(NuvyraColors.accent)
            }
        }
    }

    private var composer: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            TextField("aiCoach.chat.composer.placeholder", text: $viewModel.pendingMessage, axis: .vertical)
                .lineLimit(1...4)
                .focused($composerFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                        .stroke(composerFocused ? NuvyraColors.accent.opacity(0.5) : NuvyraColors.accent.opacity(0.15), lineWidth: 1)
                )
                .submitLabel(.send)
                .onSubmit { Task { await viewModel.sendCurrentMessage() } }

            Button {
                Task { await viewModel.sendCurrentMessage() }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        LinearGradient(
                            colors: viewModel.canSend ? [NuvyraColors.accent, NuvyraColors.softMint] : [Color.gray.opacity(0.5), Color.gray.opacity(0.4)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSend)
            .accessibilityLabel(String(localized: "aiCoach.chat.send"))
        }
    }
}

#Preview {
    NavigationStack { AICoachView() }
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
