import SwiftData
import SwiftUI

struct PremiumView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dependencies: DependencyContainer
    @StateObject private var viewModel = PremiumViewModel()

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    header
                    features
                    productCards
                    NuvyraPrimaryButton(title: "Premium'u başlat", systemImage: "crown") {
                        Task { await viewModel.purchase(context: modelContext, dependencies: dependencies) }
                    }
                    RestorePurchaseButton {
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
