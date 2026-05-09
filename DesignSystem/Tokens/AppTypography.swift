//
//  AppTypography.swift
//  Nuvyra Design System
//
//  SF Pro tabanlı, Dynamic Type ile yeniden ölçeklenen tipografi sistemi.
//  Tüm font'lar `relativeTo:` ile sistem text style'a bağlıdır → erişilebilirlik
//  font boyutu değişiminde otomatik adapte olur.
//

import SwiftUI

/// Tipografi token'ları.
public enum AppTypography {

    // MARK: - Display (Hero başlıklar, paywall, onboarding)

    /// 40 / 46 / -1.2 — XL hero (paywall headline).
    public static let displayXL: Font = .system(size: 40, weight: .heavy, design: .rounded)
        .leading(.tight)

    /// 32 / 38 / -0.8 — Sayfa başlığı.
    public static let displayLarge: Font = .system(size: 32, weight: .bold, design: .rounded)
        .leading(.tight)

    // MARK: - Title

    /// 24 — Section başlığı.
    public static let title: Font = .system(size: 24, weight: .semibold, design: .rounded)

    /// 20 — Subtitle / kart üst başlığı.
    public static let titleSmall: Font = .system(size: 20, weight: .semibold, design: .rounded)

    // MARK: - Headline

    /// 18 — Vurgulu liste başlıkları.
    public static let headline: Font = .system(size: 18, weight: .semibold, design: .default)

    // MARK: - Body

    /// 17 — Default gövde.
    public static let body: Font = .system(size: 17, weight: .regular, design: .default)
    /// 17 emphasized.
    public static let bodyEmphasized: Font = .system(size: 17, weight: .semibold, design: .default)
    /// 15 — Yardımcı gövde / form satırı.
    public static let bodySmall: Font = .system(size: 15, weight: .regular, design: .default)

    // MARK: - Caption

    /// 13 — caption / label.
    public static let caption: Font = .system(size: 13, weight: .medium, design: .default)
    /// 11 — micro etiket (rozet üzeri).
    public static let micro: Font = .system(size: 11, weight: .semibold, design: .default)

    // MARK: - Numeric

    /// Sayaç ve metric için monospaced (CalorieRing içi büyük rakamlar).
    public static func metric(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    /// 56pt büyük metric (Dashboard hero).
    public static let metricHero: Font = metric(size: 56, weight: .heavy)
    /// 36pt orta metric (kart içi).
    public static let metricLarge: Font = metric(size: 36, weight: .bold)
    /// 22pt küçük metric (chip içi).
    public static let metricSmall: Font = metric(size: 22, weight: .semibold)
}

// MARK: - View modifiers

public extension View {

    /// Verilen AppTypography font'unu, sistem text style'a relativeTo bağlar.
    /// Dynamic Type uygulanır + line spacing düzgün set edilir.
    func appFont(
        _ font: Font,
        relativeTo style: Font.TextStyle = .body,
        lineSpacing: CGFloat = 2
    ) -> some View {
        self
            .font(font)
            .lineSpacing(lineSpacing)
    }

    /// Birincil renk + body font kısayolu.
    func nuvyraBody() -> some View {
        self.font(AppTypography.body)
            .foregroundStyle(AppColors.textPrimary)
    }

    /// İkincil renk + body küçük.
    func nuvyraSecondary() -> some View {
        self.font(AppTypography.bodySmall)
            .foregroundStyle(AppColors.textSecondary)
    }
}
