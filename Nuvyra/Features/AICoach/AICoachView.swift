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
        .navigationTitle("Wellness Koçu")
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
                Text("Wellness Koçu")
                    .font(NuvyraTypography.hero)
                Text("Günlük verilerinden küçük, güvenli öneriler.")
                    .font(NuvyraTypography.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Insights
    @ViewBuilder
    private var insightsSection: some View {
        NuvyraSectionHeader(title: "Bugünkü içgörüler", subtitle: viewModel.isLoadingInsights ? "Hazırlanıyor..." : nil)
        if let error = viewModel.errorMessage, viewModel.insights.isEmpty {
            NuvyraGlassCard {
                Text(error)
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(NuvyraColors.mutedCoral)
            }
        } else if viewModel.insights.isEmpty {
            NuvyraGlassCard {
                Text("Henüz veri yok — öğün, su veya yürüyüş kaydı eklediğinde koç burada konuşmaya başlar.")
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
            NuvyraSectionHeader(title: "Koça sor", subtitle: "Sohbet alanı premium üyelere açıktır")
            PremiumFeatureGate(
                title: "AI sohbet premium",
                subtitle: "Wellness koçuyla sohbet etmek, kişisel öneriler almak için Premium'a geç.",
                systemImage: "bubble.left.and.bubble.right.fill"
            ) {
                chatBody
            }
        }
    }

    private var chatBody: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                if viewModel.hasMessages {
                    chatHistory
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
                    Text(error)
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(NuvyraColors.mutedCoral)
                }
                SafetyDisclaimerView(style: .compact)
            }
        }
    }

    private var chatHistory: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            ForEach(viewModel.messages) { message in
                AICoachMessageBubble(message: message)
            }
            HStack {
                Spacer()
                Button("Sohbeti temizle") {
                    viewModel.clearChat()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(NuvyraColors.accent)
            }
        }
    }

    private var composer: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            TextField("Bir soru yaz...", text: $viewModel.pendingMessage, axis: .vertical)
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
            .accessibilityLabel("Gönder")
        }
    }
}

#Preview {
    NavigationStack { AICoachView() }
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
