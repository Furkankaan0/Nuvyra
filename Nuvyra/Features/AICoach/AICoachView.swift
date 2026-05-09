import SwiftData
import SwiftUI

struct AICoachView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var dependencies: DependencyContainer
    @StateObject private var viewModel = AICoachViewModel()
    @State private var presentPaywall = false
    @State private var showingDisclaimer = false

    var body: some View {
        NavigationStack {
            ZStack {
                NuvyraBackground()
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                            heroHeader
                            SafetyDisclaimerView(compact: true)
                                .onTapGesture { showingDisclaimer = true }
                            insightsSection
                            chatSection
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(.horizontal, NuvyraSpacing.lg)
                        .padding(.top, NuvyraSpacing.md)
                        .padding(.bottom, NuvyraSpacing.xxl)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }

                VStack {
                    Spacer()
                    if !viewModel.hasReachedFreeLimit(isPremium: dependencies.subscriptionManager.isPremium) {
                        AICoachComposer(
                            text: $viewModel.inputText,
                            isSending: viewModel.isSending,
                            canSend: viewModel.canSend,
                            onSend: send
                        )
                        .padding(.horizontal, NuvyraSpacing.lg)
                        .padding(.bottom, NuvyraSpacing.sm)
                    }
                }
            }
            .navigationTitle("AI Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingDisclaimer = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(NuvyraColors.accent)
                    }
                    .accessibilityLabel("AI Coach hakkında")
                }
            }
            .task { await viewModel.bootstrap(context: modelContext, dependencies: dependencies) }
            .sheet(isPresented: $showingDisclaimer) {
                NavigationStack {
                    ZStack {
                        NuvyraBackground()
                        ScrollView {
                            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                                SafetyDisclaimerView(compact: false)
                                Text("AI Coach hangi verileri kullanır?")
                                    .font(NuvyraTypography.section)
                                Text("AI Coach yalnızca cihazında tuttuğun beslenme, su, adım ve hedef verilerini bağlamsal olarak değerlendirir. Hiçbir veri pazarlama amacıyla satılmaz veya paylaşılmaz.")
                                    .foregroundStyle(.secondary)
                                Text("Acil durumlar için doktor veya 112'yi ara.")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(NuvyraColors.mutedCoral)
                            }
                            .padding(NuvyraSpacing.lg)
                        }
                    }
                    .navigationTitle("Bilgi")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Tamam") { showingDisclaimer = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $presentPaywall) {
                NavigationStack { PremiumView() }
            }
        }
    }

    private var heroHeader: some View {
        HStack(alignment: .center, spacing: NuvyraSpacing.md) {
            AICoachOrb(size: 72, isActive: viewModel.isSending)
                .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text("Nuvyra Coach")
                    .font(NuvyraTypography.hero)
                Text("Bugünkü ritmin için kişisel rehber.")
                    .font(NuvyraTypography.body)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
            }
            Spacer()
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            NuvyraSectionHeader(title: "Bugünün içgörüleri", subtitle: "Verilerine göre hazırlanan kısa yorumlar.")
            if viewModel.isLoadingInsights && viewModel.insights.isEmpty {
                LoadingPlaceholder()
            } else if viewModel.insights.isEmpty {
                Text("Veri toplandıkça içgörüler burada görünür.")
                    .font(NuvyraTypography.body)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
            } else {
                ForEach(viewModel.insights) { insight in
                    AICoachInsightCard(insight: insight)
                }
            }
        }
    }

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            NuvyraSectionHeader(title: "Sohbet", subtitle: "Soruların ve AI Coach yanıtları.")

            AICoachExampleQuestions(questions: AICoachExampleQuestions.defaults) { example in
                viewModel.selectExample(example)
            }

            if viewModel.messages.isEmpty {
                EmptyChatState()
            } else {
                VStack(spacing: NuvyraSpacing.sm) {
                    ForEach(viewModel.messages) { message in
                        AICoachMessageBubble(message: message)
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NuvyraColors.mutedCoral)
            }

            if viewModel.hasReachedFreeLimit(isPremium: dependencies.subscriptionManager.isPremium) {
                FreeQuotaPaywallCard {
                    presentPaywall = true
                }
            } else if !dependencies.subscriptionManager.isPremium {
                FreeQuotaIndicator(remaining: viewModel.remainingFreeQuota(isPremium: false), limit: viewModel.freeQuotaLimit)
            }
        }
    }

    private func send() {
        Task {
            await viewModel.send(
                dependencies: dependencies,
                isPremium: dependencies.subscriptionManager.isPremium
            )
        }
    }
}

private struct LoadingPlaceholder: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                    .fill(NuvyraColors.card(scheme).opacity(0.6))
                    .frame(height: 90)
                    .shimmer()
            }
        }
    }
}

private struct EmptyChatState: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: NuvyraSpacing.sm) {
            AICoachOrb(size: 64)
                .frame(width: 64, height: 64)
            Text("Henüz konuşmadık")
                .font(NuvyraTypography.section)
            Text("Yukarıdaki örnek sorulardan birini seç ya da kendi sorunu yaz. Yanıtlar bilgilendirme amaçlıdır.")
                .font(.caption)
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(NuvyraSpacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous)
                .stroke(NuvyraColors.accent.opacity(0.14))
        )
        .accessibilityElement(children: .combine)
    }
}

private struct FreeQuotaIndicator: View {
    @Environment(\.colorScheme) private var scheme
    var remaining: Int
    var limit: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkle")
                .foregroundStyle(NuvyraColors.accent)
            Text("Bu seansta kalan ücretsiz soru: \(remaining) / \(limit)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(NuvyraColors.accent.opacity(0.08), in: Capsule())
    }
}

private struct FreeQuotaPaywallCard: View {
    @Environment(\.colorScheme) private var scheme
    var onUpgrade: () -> Void

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(NuvyraColors.softSand)
                    Text("Soru limitine ulaştın")
                        .font(NuvyraTypography.section)
                }
                Text("AI Coach ile sınırsız soru sormak için Premium'a geç. İçgörüler her zaman ücretsiz kalır.")
                    .font(NuvyraTypography.body)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                NuvyraPrimaryButton(title: "Premium'u keşfet", systemImage: "sparkles", action: onUpgrade)
            }
        }
    }
}

private struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.35), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(20))
                .offset(x: phase * 250)
                .blendMode(.plusLighter)
            )
            .clipped()
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

private extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

#if DEBUG
#Preview {
    AICoachView()
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
#endif
