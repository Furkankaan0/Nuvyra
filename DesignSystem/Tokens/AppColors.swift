//
//  AppColors.swift
//  Nuvyra Design System
//
//  Tüm uygulamada kullanılan renk paleti. Light/Dark mode için ayrı
//  hex değerler tanımlanır; UIKit dynamic provider ile çözünür.
//

import SwiftUI
import UIKit

/// Nuvyra renk paleti.
public enum AppColors {

    // MARK: - Brand

    /// Birincil marka rengi — telkin verici, premium yeşil-mint.
    public static let brandPrimary    = dynamic(light: "#0FBE9D", dark: "#1FE3BC")
    /// İkincil aksan — premium gold (badge, sparkle).
    public static let brandAccent     = dynamic(light: "#C8A85B", dark: "#E5C879")
    /// Tatil/destek rengi — soft coral.
    public static let brandCoral      = dynamic(light: "#F08A78", dark: "#FF9D8A")

    // MARK: - Surfaces

    /// En arka plan: hafif gradient temeli.
    public static let backgroundBase  = dynamic(light: "#F6F7F9", dark: "#0A0B0F")
    /// İkincil zemin (kart altları, scroll arka planı).
    public static let backgroundSoft  = dynamic(light: "#EEF1F4", dark: "#101218")
    /// Kart yüzeyi (PremiumCard fill).
    public static let surface         = dynamic(light: "#FFFFFF", dark: "#15171F")
    /// Yükseltilmiş yüzey (üst sheet, popover).
    public static let surfaceElevated = dynamic(light: "#FFFFFF", dark: "#1B1E27")
    /// Glass card overlay rengi (material üstüne tint).
    public static let glassTint       = dynamicAlpha(light: "#FFFFFF", lightAlpha: 0.55,
                                                     dark:  "#FFFFFF", darkAlpha: 0.07)

    // MARK: - Text

    /// Birincil metin.
    public static let textPrimary     = dynamic(light: "#0E1116", dark: "#F2F4F7")
    /// İkincil metin (subtitle, caption).
    public static let textSecondary   = dynamic(light: "#5C6473", dark: "#A2A8B5")
    /// Üçüncül metin (placeholder, etiket).
    public static let textTertiary    = dynamic(light: "#8C95A4", dark: "#6E7585")
    /// Ters metin (renkli buton içi).
    public static let textOnAccent    = dynamic(light: "#FFFFFF", dark: "#0A0B0F")

    // MARK: - Borders

    public static let borderHairline  = dynamicAlpha(light: "#000000", lightAlpha: 0.06,
                                                     dark:  "#FFFFFF", darkAlpha: 0.08)
    public static let borderSubtle    = dynamicAlpha(light: "#000000", lightAlpha: 0.10,
                                                     dark:  "#FFFFFF", darkAlpha: 0.14)

    // MARK: - Semantic

    public static let success         = dynamic(light: "#23A86A", dark: "#42D58D")
    public static let warning         = dynamic(light: "#E8A23A", dark: "#F4BC5E")
    public static let danger          = dynamic(light: "#E4584C", dark: "#FF7367")
    public static let info            = dynamic(light: "#3D8BF2", dark: "#67A6FF")

    // MARK: - Macros

    public static let macroProtein    = dynamic(light: "#E4584C", dark: "#FF7367")
    public static let macroCarbs      = dynamic(light: "#3D8BF2", dark: "#67A6FF")
    public static let macroFat        = dynamic(light: "#E8A23A", dark: "#F4BC5E")
    public static let macroFiber      = dynamic(light: "#8E5BD9", dark: "#B789F0")

    // MARK: - Activity Rings (Apple Fitness benzeri)

    public static let ringMove        = dynamic(light: "#FF3B57", dark: "#FF5470")
    public static let ringExercise    = dynamic(light: "#A8E000", dark: "#C7F050")
    public static let ringStand       = dynamic(light: "#0AB6E0", dark: "#3FCFEF")

    // MARK: - Soft Gradients

    /// Dashboard arka planı — soft mint → mor → şeffaf.
    public static let dashboardGradient = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: dynamic(light: "#E6F8F2", dark: "#0E1A1F"), location: 0.0),
            .init(color: dynamic(light: "#EAEAFD", dark: "#15131F"), location: 0.55),
            .init(color: backgroundBase, location: 1.0)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Premium ekran (paywall, badge) için altın gradient.
    public static let premiumGradient = LinearGradient(
        gradient: Gradient(colors: [
            dynamic(light: "#E5C879", dark: "#F4D88A"),
            dynamic(light: "#C8A85B", dark: "#D6B564"),
            dynamic(light: "#A88641", dark: "#B89352")
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Birincil aksiyon butonu için marka gradyanı.
    public static let primaryGradient = LinearGradient(
        gradient: Gradient(colors: [
            dynamic(light: "#16D2AE", dark: "#1FE3BC"),
            dynamic(light: "#0FBE9D", dark: "#13C49E")
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Macro ring grafik için yumuşak gradient.
    public static let macroRingGradient = AngularGradient(
        gradient: Gradient(colors: [
            macroProtein, macroCarbs, macroFat, macroProtein
        ]),
        center: .center
    )

    // MARK: - Helpers

    /// Light/dark adaptif renk üretici.
    public static func dynamic(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            switch traits.userInterfaceStyle {
            case .dark: return UIColor(hex: dark)
            default:    return UIColor(hex: light)
            }
        })
    }

    /// Adaptif alpha içeren dinamik renk.
    public static func dynamicAlpha(
        light: String, lightAlpha: CGFloat,
        dark: String,  darkAlpha: CGFloat
    ) -> Color {
        Color(uiColor: UIColor { traits in
            switch traits.userInterfaceStyle {
            case .dark: return UIColor(hex: dark).withAlphaComponent(darkAlpha)
            default:    return UIColor(hex: light).withAlphaComponent(lightAlpha)
            }
        })
    }
}

// MARK: - UIColor(hex:)

extension UIColor {
    /// `#RRGGBB` veya `#RRGGBBAA` hex string'inden UIColor üretir.
    public convenience init(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }

        var rgba: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgba)

        let r, g, b, a: CGFloat
        switch hex.count {
        case 6:
            r = CGFloat((rgba & 0xFF0000) >> 16) / 255
            g = CGFloat((rgba & 0x00FF00) >> 8)  / 255
            b = CGFloat( rgba & 0x0000FF)        / 255
            a = 1
        case 8:
            r = CGFloat((rgba & 0xFF000000) >> 24) / 255
            g = CGFloat((rgba & 0x00FF0000) >> 16) / 255
            b = CGFloat((rgba & 0x0000FF00) >> 8)  / 255
            a = CGFloat( rgba & 0x000000FF)        / 255
        default:
            r = 1; g = 0; b = 1; a = 1
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
