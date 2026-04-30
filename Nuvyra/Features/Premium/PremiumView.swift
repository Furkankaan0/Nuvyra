import SwiftData
import SwiftUI

struct PremiumView: View {
    @EnvironmentObject private var dependencies: DependencyContainer

    var body: some View {
        // Re-bind the SubscriptionManager into the child view as
        // @ObservedObject so its inner @Published properties (lastMessage,
        // isAwaitingApproval, entitlement) actually trigger redraws.
        // Reading them through the EnvironmentObject alone wouldn't —
        // DependencyContainer only emits objectWillChange when the
        // manager *reference* changes, not when its fields mutate.
        PremiumContent(manager: dependencies.subscriptionManager)
    }
}

private struct PremiumContent: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dependencies: DependencyContainer
    @ObservedObject var manager: SubscriptionManager
    @StateObject private var viewModel = PremiumViewModel()

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    header
                    pendingApprovalBanner
                    activeSubscriptionBanner
                    features
                    productCards
                    NuvyraPrimaryButton(
                        title: viewModel.isProcessing ? "İşleniyor…" : "Premium'u başlat",
                        systemImage: "crown"
                    ) {
                        Task { await viewModel.purchase(context: modelContext, dependencies: dependencies) }
                    }
                    .disabled(viewModel.isProcessing || manager.entitlement.isActive)
                    .opacity(viewModel.isProcessing ? 0.72 : 1)

                    RestorePurchaseButton(isProcessing: viewModel.isProcessing) {
                        Task { await viewModel.restore(context: modelContext, dependencies: dependencies) }
                    }
                    subscriptionLegal
                }
                .padding(NuvyraSpacing.lg)
            }
        }
        .navigationTitle("Premium")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(dependencies: dependencies) }
        .alert(item: $manager.lastMessage) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.message),
                dismissButton: .default(Text("Tamam"))
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            Text("Nuvyra Premium")
                .font(NuvyraTypography.hero)
            Text("Daha net trendler, premium widget'lar ve kişisel ritim içgörüleri.")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var pendingApprovalBanner: some View {
        if manager.isAwaitingApproval {
            NuvyraDataIssueBanner(
                banner: DataIssueBanner(
                    icon: "person.2.crop.square.stack",
                    title: "Ebeveyn onayı bekleniyor",
                    message: "Aile paylaşımı / Ask-to-Buy nedeniyle bu satın alma onaylanana kadar bekliyor. Onaylandığında premium otomatik olarak açılır.",
                    action: .none
                )
            )
        }
    }

    @ViewBuilder
    private var activeSubscriptionBanner: some View {
        if manager.entitlement.isActive {
            NuvyraGlassCard {
                VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
                    Label("Premium aktif", systemImage: "checkmark.seal.fill")
                        .font(NuvyraTypography.section)
                        .foregroundStyle(NuvyraColors.accent)
                    if let expiration = manager.entitlement.expirationDate {
                        Text("Yenileme: \(expiration.formatted(date: .abbreviated, time: .omitted))")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var features: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                PaywallFeatureRow(title: "Detaylı haftalık trendler")
                PaywallFeatureRow(title: "Premium widget")
                PaywallFeatureRow(title: "Sınırsız favori öğün")
                PaywallFeatureRow(title: "Gelişmiş yürüyüş içgörüleri")
                PaywallFeatureRow(title: "Haftalık sağlık özeti")
                PaywallFeatureRow(title: "Premium tema detayları")
            }
        }
    }

    private var productCards: some View {
        VStack(spacing: NuvyraSpacing.md) {
            ForEach(viewModel.products) { product in
                Button { viewModel.selectedProductID = product.id } label: {
                    NuvyraCard {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
                                HStack {
                                    Text(product.title).font(NuvyraTypography.section)
                                    if product.isYearly {
                                        Text("Öne çıkan")
                                            .font(.caption.weight(.bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(NuvyraColors.paleLime.opacity(0.35), in: Capsule())
                                    }
                                }
                                Text(product.price).font(.title3.weight(.bold))
                                Text(product.features.joined(separator: " • "))
                                    .font(NuvyraTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: product.id == viewModel.selectedProductID ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(NuvyraColors.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var subscriptionLegal: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                Text("Şeffaf abonelik")
                    .font(NuvyraTypography.section)
                Text("Fiyat ve yenileme dönemi App Store ödeme ekranında açıkça görünür. Aboneliği Apple ID ayarlarından yönetebilirsin.")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
                Link("Abonelikleri yönet", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
            }
        }
    }
}

#Preview {
    NavigationStack { PremiumView() }
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
