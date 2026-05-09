//
//  DesignTokens.swift
//  Nuvyra Design System
//
//  Tüm token'lara tek noktadan erişim için umbrella.
//  `import` yerine `DesignTokens.colors.brandPrimary` gibi bir
//  syntax ile kullanılabilir; ya da doğrudan AppColors/AppSpacing
//  enum'ları kullanılır.
//

import SwiftUI

/// Tasarım sisteminin tek erişim noktası.
public enum DesignTokens {
    public typealias colors      = AppColors
    public typealias typography  = AppTypography
    public typealias spacing     = AppSpacing
    public typealias radius      = AppRadius
    public typealias shadows     = AppShadow

    /// Modülün versiyonu (changelog için).
    public static let version: String = "1.0.0"
}

// MARK: - Page Background

/// Standart sayfa arka planı (soft gradient + base color).
public struct NuvyraPageBackground: View {

    public init() {}

    public var body: some View {
        ZStack {
            AppColors.backgroundBase
            AppColors.dashboardGradient
                .opacity(0.55)
                .blur(radius: 28)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}
