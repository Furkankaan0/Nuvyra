import SwiftUI

enum NuvyraColor {
    static let lightBackground = Color(hex: 0xF5FBF8)
    static let lightPrimary = Color(hex: 0x1DBA8A)
    static let lightTextPrimary = Color(hex: 0x13231D)
    static let lightSecondaryAccent = Color(hex: 0x7C8CF8)
    static let warning = Color(hex: 0xE76F51)
    static let lightCard = Color.white.opacity(0.82)

    static let darkBackground = Color(hex: 0x0E1525)
    static let darkCard = Color(hex: 0x162136)
    static let darkPrimary = Color(hex: 0x6CC3FF)
    static let darkAccent = Color(hex: 0x95E06C)
    static let darkText = Color(hex: 0xF4F7FB)

    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkBackground : lightBackground
    }

    static func card(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkCard.opacity(0.88) : lightCard
    }

    static func primary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkPrimary : lightPrimary
    }

    static func accent(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkAccent : lightSecondaryAccent
    }

    static func textPrimary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkText : lightTextPrimary
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
