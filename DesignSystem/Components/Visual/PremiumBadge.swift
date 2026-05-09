//
//  PremiumBadge.swift
//  Nuvyra Design System
//
//  Altın gradient + sparkle ikonlu rozet. Streak, premium üyelik,
//  başarı vurgusu için.
//

import SwiftUI

public struct PremiumBadge: View {

    // MARK: - Style

    public enum Style {
        case gold       // altın
        case mint       // brand mint
        case neutral    // soft surface
    }

    // MARK: - Inputs

    public let label: String
    public let icon: String?
    public let style: Style

    // MARK: - Init

    public init(label: String, icon: String? = "sparkles", style: Style = .gold) {
        self.label = label
        self.icon = icon
        self.style = style
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
            }
            Text(label)
                .font(AppTypography.micro)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(textColor)
        .background(background)
        .clipShape(Capsule(style: .continuous))
        .overlay(
            Capsule().stroke(.white.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: shadowColor.opacity(0.35), radius: 6, x: 0, y: 2)
        .accessibilityElement()
        .accessibilityLabel("\(label) rozeti")
    }

    // MARK: - Variants

    private var textColor: Color {
        switch style {
        case .gold:    return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: "#1A1305") : .white })
        case .mint:    return AppColors.textOnAccent
        case .neutral: return AppColors.textPrimary
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .gold:    AppColors.premiumGradient
        case .mint:    AppColors.primaryGradient
        case .neutral: AppColors.surface
        }
    }

    private var shadowColor: Color {
        switch style {
        case .gold:    return AppColors.brandAccent
        case .mint:    return AppColors.brandPrimary
        case .neutral: return .black
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Light") {
    ZStack {
        NuvyraPageBackground()
        HStack(spacing: 12) {
            PremiumBadge(label: "Premium", icon: "crown.fill", style: .gold)
            PremiumBadge(label: "Streak 7", icon: "flame.fill", style: .mint)
            PremiumBadge(label: "Yeni", icon: nil, style: .neutral)
        }
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ZStack {
        NuvyraPageBackground()
        HStack(spacing: 12) {
            PremiumBadge(label: "Premium", icon: "crown.fill", style: .gold)
            PremiumBadge(label: "Streak 7", icon: "flame.fill", style: .mint)
            PremiumBadge(label: "Yeni", icon: nil, style: .neutral)
        }
    }
    .preferredColorScheme(.dark)
}
#endif
