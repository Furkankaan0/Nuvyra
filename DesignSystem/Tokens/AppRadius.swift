//
//  AppRadius.swift
//  Nuvyra Design System
//
//  Yuvarlatma değerleri. Premium hisse uygun, "squircle" benzeri büyük
//  corner radii — Apple HIG'in continuous shape kuralına uyumlu.
//

import SwiftUI

/// Köşe yarıçapı token'ları.
public enum AppRadius {
    /// 6pt — küçük chip.
    public static let xs:  CGFloat = 6
    /// 10pt — input field.
    public static let sm:  CGFloat = 10
    /// 14pt — buton.
    public static let md:  CGFloat = 14
    /// 20pt — kart.
    public static let lg:  CGFloat = 20
    /// 28pt — büyük kart / sheet.
    public static let xl:  CGFloat = 28
    /// 36pt — hero hero kart.
    public static let xxl: CGFloat = 36

    // MARK: - Shape factories

    /// Continuous (squircle) RoundedRectangle.
    public static func shape(_ radius: CGFloat) -> some Shape {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}
