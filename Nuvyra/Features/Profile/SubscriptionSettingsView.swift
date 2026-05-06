import SwiftData
import SwiftUI

struct SubscriptionSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dependencies: DependencyContainer
    @Query private var states: [SubscriptionState]

    private var state: SubscriptionState {
        states.first ?? dependencies.subscriptionManager.state
    }

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    NuvyraSectionHeader(title: "Abonelik", subtitle: "StoreKit 2 ile App Store üzerinden güvenli yönetilir.")

                    statusCard

                    SettingsSection(title: "Yönetim") {
                        NavigationLink {
                            PremiumView()
                        } label: {
                            SettingsRow(title: "Premium planları", subtitle: "Aylık, yıllık ve ömür boyu seçenekleri gör.", systemImage: "crown.fill")
                        }
                        .buttonStyle(.plain)

                        SettingsDivider()

                        Button {
                            Task { await dependencies.subscriptionManager.restore(repository: dependencies.subscriptionRepository(context: modelContext)) }
                        } label: {
                            SettingsRow(title: "Satın alımları geri yükle", subtitle: "Sandbox/TestFlight satın alımlarını yenile.", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)

                        SettingsDivider()

                        Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                            SettingsRow(title: "Apple aboneliklerini yönet", subtitle: "Apple ID abonelik ayarlarını aç.", systemImage: "creditcard.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(NuvyraSpacing.lg)
            }
        }
        .navigationTitle("Abonelik")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statusCard: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Label(statusTitle, systemImage: state.isPremium ? "checkmark.seal.fill" : "crown")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(state.isPremium ? NuvyraColors.accent : .secondary)

                Text(statusSubtitle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)

                if let productId = state.productId {
                    Text(productId)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.thinMaterial, in: Capsule())
                }
            }
        }
    }

    private var statusTitle: String {
        guard state.isPremium else { return "Free plan" }
        if state.productId == ProductID.premiumLifetime.rawValue {
            return "Ömür boyu Premium"
        }
        return "Premium aktif"
    }

    private var statusSubtitle: String {
        guard state.isPremium else {
            return "Gelişmiş analizler, AI Coach ve premium özellikler için plan seçebilirsin."
        }
        if let expirationDate = state.expirationDate {
            return "Yenileme / bitiş tarihi: \(DateFormatter.nuvyraShortDate.string(from: expirationDate))"
        }
        return "Tek seferlik satın alma veya süresiz entitlement aktif görünüyor."
    }
}
