//
//  AppShadow.swift
//  Nuvyra Design System
//
//  Çok katmanlı (stacked) gölge token'ları — derinlik hissi için iki
//  şeffaflığı farklı, blur'u farklı gölgeyi üst üste bindiriyoruz.
//  Apple Fitness ve premium wellness app'lerinde sıkça görülen yaklaşım.
//

import SwiftUI

/// Gölge token tanımı.
public struct ShadowStyle: Sendable {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat

    public init(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }
}

public enum AppShadow {

    // MARK: - Light mode katmanları

    /// Hafif kart gölgesi (alt katman).
    public static let card1: ShadowStyle = .init(
        color: .black.opacity(0.06), radius: 6, x: 0, y: 2
    )
    /// Hafif kart gölgesi (üst katman, daha yumuşak).
    public static let card2: ShadowStyle = .init(
        color: .black.opacity(0.04), radius: 22, x: 0, y: 12
    )

    /// Yükseltilmiş kart (paywall hero, modal).
    public static let elevated1: ShadowStyle = .init(
        color: .black.opacity(0.10), radius: 12, x: 0, y: 4
    )
    public static let elevated2: ShadowStyle = .init(
        color: .black.opacity(0.06), radius: 36, x: 0, y: 20
    )

    /// Floating action button.
    public static let fab1: ShadowStyle = .init(
        color: AppColors.brandPrimary.opacity(0.30), radius: 18, x: 0, y: 8
    )
    public static let fab2: ShadowStyle = .init(
        color: .black.opacity(0.10), radius: 6, x: 0, y: 2
    )

    /// Toast.
    public static let toast: ShadowStyle = .init(
        color: .black.opacity(0.18), radius: 24, x: 0, y: 8
    )
}

// MARK: - View modifiers

public extension View {

    /// Tek bir ShadowStyle uygular.
    func shadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }

    /// İki katmanlı kart gölgesi (default depth).
    func nuvyraCardShadow() -> some View {
        self
            .shadow(AppShadow.card1)
            .shadow(AppShadow.card2)
    }

    /// İki katmanlı yükseltilmiş gölge.
    func nuvyraElevatedShadow() -> some View {
        self
            .shadow(AppShadow.elevated1)
            .shadow(AppShadow.elevated2)
    }

    /// FAB için ışık + yumuşak gölge.
    func nuvyraFabShadow() -> some View {
        self
            .shadow(AppShadow.fab1)
            .shadow(AppShadow.fab2)
    }
}
