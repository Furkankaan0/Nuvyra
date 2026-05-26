import SwiftUI

struct PlanCard: View {
    @Environment(\.colorScheme) private var scheme
    let product: PremiumProduct
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: NuvyraSpacing.xs) {
                            Text(product.title)
                                .font(.headline.weight(.heavy))
                                .foregroundStyle(NuvyraColors.primaryText(scheme))

                            if let badge = product.badge {
                                Text(badge)
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(product.isLifetime ? NuvyraColors.primaryText(scheme) : .white)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(product.isLifetime ? NuvyraColors.paleLime.opacity(0.72) : NuvyraColors.accent, in: Capsule())
                            }
                        }

                        Text(product.price)
                            .font(.system(.title2, design: .rounded).weight(.heavy))
                            .foregroundStyle(NuvyraColors.primaryText(scheme))

                        if let offer = product.introductoryOffer {
                            Label(offer.badge, systemImage: offer.mode == .freeTrial ? "gift.fill" : "tag.fill")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(
                                    LinearGradient(colors: [NuvyraColors.accent, NuvyraColors.softMint], startPoint: .leading, endPoint: .trailing),
                                    in: Capsule()
                                )
                                .shadow(color: NuvyraColors.accent.opacity(0.28), radius: 6, y: 3)
                                .accessibilityLabel(offer.badge)
                        }
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(isSelected ? NuvyraColors.accent : NuvyraColors.secondaryText(scheme).opacity(0.45))
                }

                Text(product.renewalDescription)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous)
                    .stroke(isSelected ? NuvyraColors.accent.opacity(0.54) : Color.white.opacity(scheme == .dark ? 0.08 : 0.34), lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: isSelected ? NuvyraColors.accent.opacity(0.16) : NuvyraShadow.card(scheme), radius: isSelected ? 22 : 14, x: 0, y: 12)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(product.title), \(product.price)")
        .accessibilityHint(product.renewalDescription)
        .accessibilityValue(isSelected ? "Seçili" : "Seçili değil")
    }

    private var cardBackground: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        NuvyraColors.accent.opacity(scheme == .dark ? 0.24 : 0.13),
                        NuvyraColors.softMint.opacity(scheme == .dark ? 0.16 : 0.10),
                        NuvyraColors.card(scheme).opacity(0.82)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(NuvyraColors.card(scheme).opacity(scheme == .dark ? 0.64 : 0.82))
    }
}
