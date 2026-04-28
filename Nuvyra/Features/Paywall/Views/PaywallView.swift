import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = PaywallViewModel()

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    header
                    featureList
                    productPicker
                    purchaseArea
                    legalArea
                }
                .padding(NuvyraSpacing.lg)
            }
        }
        .navigationTitle("Premium")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(appState: appState) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            Text("Nuvyra Premium")
                .font(NuvyraTypography.hero())
            Text("Daha kişisel haftalık özetler, sınırsız fotoğraflı kayıt ve adaptif yürüyüş planı.")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var featureList: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                NuvyraPaywallFeatureRow(title: "Sınırsız fotoğraflı öğün kaydı")
                NuvyraPaywallFeatureRow(title: "Gelişmiş kalori ve makro görünümü")
                NuvyraPaywallFeatureRow(title: "Adaptif yürüyüş planı")
                NuvyraPaywallFeatureRow(title: "Haftalık koç özeti")
                NuvyraPaywallFeatureRow(title: "Gelişmiş hatırlatmalar")
            }
        }
    }

    private var productPicker: some View {
        VStack(spacing: NuvyraSpacing.sm) {
            ForEach(viewModel.products) { product in
                Button {
                    viewModel.selectedProductID = product.id
                } label: {
                    NuvyraGlassCard {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(product.title)
                                    .font(.headline.weight(.semibold))
                                Text("\(product.priceDisplay) / \(product.period.title)")
                                    .font(.title3.weight(.bold))
                                Text(product.features.prefix(2).joined(separator: " • "))
                                    .font(NuvyraTypography.caption())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: viewModel.selectedProductID == product.id ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(NuvyraColor.lightPrimary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var purchaseArea: some View {
        VStack(spacing: NuvyraSpacing.sm) {
            NuvyraPrimaryButton(title: "Aboneliği başlat", systemImage: "sparkles", isLoading: viewModel.isLoading) {
                Task { await viewModel.purchase(appState: appState) }
            }
            NuvyraSecondaryButton(title: "Restore Purchases", systemImage: "arrow.clockwise") {
                Task { await viewModel.restore(appState: appState) }
            }
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(NuvyraTypography.caption())
                    .foregroundStyle(NuvyraColor.warning)
            }
        }
    }

    private var legalArea: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                Text("Şeffaf abonelik")
                    .font(NuvyraTypography.sectionTitle())
                Text("Satın alma Apple tarafından işlenir. Deneme varsa, deneme sonrası fiyat ve yenileme dönemi App Store ödeme ekranında net şekilde gösterilir. Aboneliği Apple ID ayarlarından istediğin zaman iptal edebilirsin.")
                    .font(NuvyraTypography.caption())
                    .foregroundStyle(.secondary)
                HStack {
                    Link("Kullanım Şartları", destination: URL(string: "https://example.com/nuvyra/terms")!)
                    Link("Gizlilik", destination: URL(string: "https://example.com/nuvyra/privacy")!)
                }
                .font(.caption.weight(.semibold))
            }
        }
    }
}

#Preview {
    NavigationStack { PaywallView() }
        .environmentObject(AppState.preview())
}

