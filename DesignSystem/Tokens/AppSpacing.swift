//
//  AppSpacing.swift
//  Nuvyra Design System
//
//  4pt baz birime dayalı spacing token sistemi. Tüm padding/gap değerleri
//  bu sabitlerden üretilir; tutarlı hiyerarşi sağlar.
//

import SwiftUI

/// Spacing token'ları (4pt grid).
public enum AppSpacing {
    /// 2pt — hairline.
    public static let xxxs: CGFloat = 2
    /// 4pt
    public static let xxs:  CGFloat = 4
    /// 8pt
    public static let xs:   CGFloat = 8
    /// 12pt
    public static let sm:   CGFloat = 12
    /// 16pt — standart kart iç padding.
    public static let md:   CGFloat = 16
    /// 20pt
    public static let lg:   CGFloat = 20
    /// 24pt
    public static let xl:   CGFloat = 24
    /// 32pt — section ayrımı.
    public static let xxl:  CGFloat = 32
    /// 48pt — hero / safe-area ek.
    public static let xxxl: CGFloat = 48

    // MARK: - Page padding

    /// Standart yatay sayfa kenar boşluğu.
    public static let pageHorizontal: CGFloat = 20
    /// Section'lar arası dikey boşluk.
    public static let sectionGap: CGFloat = 28
    /// Kart içi standart padding.
    public static let cardPadding: CGFloat = 18
}

public extension EdgeInsets {
    /// Tüm kenarlara aynı insets uygular (kısayol).
    static func all(_ value: CGFloat) -> EdgeInsets {
        EdgeInsets(top: value, leading: value, bottom: value, trailing: value)
    }
}
