import SwiftData
import SwiftUI

struct PremiumView: View {
    var body: some View {
        PaywallView()
    }
}

struct PaywallView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var dependencies: DependencyContainer
    @StateObject private var viewModel = PremiumViewModel()

    private var selectedProduct: PremiumProduct {
        viewModel.selectedProduct ?? viewModel.products.first ?? PremiumProduct.fallback[0]
    }

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    hero
                    if let offer = highlightedTrialOffer { trialBanner(offer: offer) }
                    featureList
                    planCards
                    purchaseSection
                    legalSection
                }
                .padding(NuvyraSpacing.lg)
            }
        }
        .navigationTitle("Premium")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(dependencies: dependencies) }
        .alert("Premium işlemi tamamlanamadı", isPresented: errorBinding) {
            Button("Tamam", role: .cancel) { dependencies.subscriptionManager.errorMessage = nil }
        } message: {
            Text(dependencies.subscriptionManager.errorMessage ?? "Lütfen tekrar dene.")
        }
    }

    /// Picks the most prominent offer to surface in the banner. Prefers the
    /// selected plan; falls back to the yearly plan; finally any recurring plan.
    private var highlightedTrialOffer: IntroductoryOffer? {
        if let offer = viewModel.selectedProduct?.introductoryOffer { return offer }
        if let yearly = viewModel.products.first(where: { $0.productID == .premiumYearly })?.introductoryOffer { return yearly }
        return viewModel.products.first(where: { $0.introductoryOffer != nil })?.introductoryOffer
    }

    private func trialBanner(offer: IntroductoryOffer) -> some View {
        HStack(alignment: .center, spacing: NuvyraSpacing.md) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [NuvyraColors.accent, NuvyraColors.softMint], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                Image(systemName: "gift.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(offer.badge)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                Text(trialSubtitle(for: offer))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous)
                .stroke(LinearGradient(colors: [NuvyraColors.accent.opacity(0.55), NuvyraColors.softMint.opacity(0.45)], startPoint: .leading, endPoint: .trailing), lineWidth: 1.2)
        )
        .shadow(color: NuvyraColors.accent.opacity(0.18), radius: 14, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Deneme bilgisi: \(offer.badge)")
    }

    private func trialSubtitle(for offer: IntroductoryOffer) -> String {
        let recurringPrice = viewModel.selectedProduct?.price ?? viewModel.products.first(where: { $0.productID == .premiumYearly })?.price ?? ""
        switch offer.mode {
        case .freeTrial:
            if recurringPrice.isEmpty {
                return "Sonrasında dilediğin zaman Apple ID ayarlarından iptal edebilirsin."
            }
            return "Deneme bitince \(recurringPrice). İstediğin zaman iptal edebilirsin."
        case .payAsYouGo:
            return "İndirimli giriş süresi, sonrasında normal abonelik fiyatına geçer."
        case .payUpFront:
            return "Tek seferlik indirimli giriş ücreti; sonrasında normal abonelik devam eder."
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: scheme == .dark
                            ? [Color(red: 0.08, green: 0.11, blue: 0.13), Color(red: 0.03, green: 0.24, blue: 0.18), Color(red: 0.16, green: 0.14, blue: 0.08)]
                            : [Color(red: 1.0, green: 0.96, blue: 0.86), Color(red: 0.84, green: 0.97, blue: 0.90), Color(red: 0.94, green: 0.88, blue: 0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(NuvyraColors.softMint.opacity(0.30))
                        .frame(width: 220, height: 220)
                        .blur(radius: 42)
                        .offset(x: 78, y: -84)
                }

            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Label("Nuvyra Premium", systemImage: "crown.fill")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(NuvyraColors.accent)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())

                Text("Ritmini daha derin, daha sakin oku.")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .minimumScaleFactor(0.76)

                Text("Sınırsız kayıt, gelişmiş analizler, AI Coach ve Apple Health içgörüleri tek premium deneyimde.")
                    .font(.body.weight(.medium))
                    .lineSpacing(3)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
            }
            .padding(24)
        }
        .frame(minHeight: 300)
        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
        .shadow(color: NuvyraShadow.card(scheme), radius: 28, x: 0, y: 20)
        .accessibilityElement(children: .combine)
    }

    private var featureList: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Text("Premium ile açılanlar")
                    .font(NuvyraTypography.section)
                    .foregroundStyle(NuvyraColors.primaryText(scheme))

                ForEach(PremiumProduct.premiumFeatures, id: \.self) { feature in
                    PaywallFeatureRow(title: feature)
                }
            }
        }
    }

    private var planCards: some View {
        VStack(spacing: NuvyraSpacing.md) {
            if viewModel.isLoading || dependencies.subscriptionManager.isLoadingProducts {
                NuvyraGlassCard {
                    HStack(spacing: NuvyraSpacing.md) {
                        ProgressView()
                        Text("App Store paketleri yükleniyor")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(NuvyraColors.primaryText(scheme))
                    }
                }
            }

            ForEach(viewModel.products) { product in
                PlanCard(product: product, isSelected: viewModel.selectedProductID == product.id) {
                    viewModel.selectedProductID = product.id
                }
            }
        }
    }

    private var purchaseSection: some View {
        VStack(spacing: NuvyraSpacing.sm) {
            NuvyraPrimaryButton(
                title: dependencies.subscriptionManager.isPurchasing ? "App Store bekleniyor" : purchaseButtonTitle,
                systemImage: selectedProduct.isLifetime ? "sparkles" : "crown"
            ) {
                Task { await viewModel.purchase(context: modelContext, dependencies: dependencies) }
            }
            .disabled(dependencies.subscriptionManager.isPurchasing || dependencies.subscriptionManager.isRestoring)
            .opacity(dependencies.subscriptionManager.isPurchasing ? 0.72 : 1)

            RestorePurchaseButton {
                Task { await viewModel.restore(context: modelContext, dependencies: dependencies) }
            }
            .disabled(dependencies.subscriptionManager.isRestoring)

            if dependencies.subscriptionManager.isPremium {
                Label("Premium aktif", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NuvyraColors.accent)
                    .padding(.top, NuvyraSpacing.xs)
            }
        }
    }

    private var purchaseButtonTitle: String {
        selectedProduct.isLifetime
            ? "Ömür boyu Premium'u al"
            : "\(selectedProduct.title) başlat"
    }

    private var legalSection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                Text("Şeffaf satın alma")
                    .font(NuvyraTypography.section)
                Text("Fiyat ve yenileme dönemi App Store ödeme ekranında açıkça görünür. Abonelikleri Apple ID ayarlarından yönetebilir veya iptal edebilirsin.")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: NuvyraSpacing.md) {
                    Link("Kullanım şartları", destination: URL(string: "https://nuvyra.app/terms")!)
                    Link("Gizlilik", destination: URL(string: "https://nuvyra.app/privacy")!)
                    Link("Abonelikleri yönet", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(NuvyraColors.accent)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { dependencies.subscriptionManager.errorMessage != nil },
            set: { isPresented in
                if !isPresented { dependencies.subscriptionManager.errorMessage = nil }
            }
        )
    }
}

#Preview {
    NavigationStack { PremiumView() }
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
