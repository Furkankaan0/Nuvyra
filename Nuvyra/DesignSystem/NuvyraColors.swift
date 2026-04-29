import SwiftUI

enum NuvyraColors {
    static let lightBackground = Color(red: 0.965, green: 0.952, blue: 0.925)
    static let lightCard = Color(red: 1.0, green: 0.988, blue: 0.956)
    static let lightText = Color(red: 0.055, green: 0.075, blue: 0.09)
    static let darkBackground = Color(red: 0.075, green: 0.078, blue: 0.082)
    static let darkCard = Color(red: 0.13, green: 0.135, blue: 0.145)
    static let darkText = Color(red: 0.94, green: 0.95, blue: 0.93)
    static let accent = Color(red: 0.10, green: 0.68, blue: 0.52)
    static let softMint = Color(red: 0.48, green: 0.89, blue: 0.73)
    static let softSand = Color(red: 0.88, green: 0.79, blue: 0.64)
    static let mutedCoral = Color(red: 0.88, green: 0.42, blue: 0.36)
    static let paleLime = Color(red: 0.76, green: 0.91, blue: 0.54)
    static let mutedGray = Color(red: 0.48, green: 0.50, blue: 0.52)

    static func background(_ scheme: ColorScheme) -> Color { scheme == .dark ? darkBackground : lightBackground }
    static func card(_ scheme: ColorScheme) -> Color { scheme == .dark ? darkCard : lightCard }
    static func primaryText(_ scheme: ColorScheme) -> Color { scheme == .dark ? darkText : lightText }
    static func secondaryText(_ scheme: ColorScheme) -> Color { scheme == .dark ? Color.white.opacity(0.68) : mutedGray }

    static func calmGradient(_ scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: scheme == .dark
                ? [darkBackground, Color(red: 0.10, green: 0.16, blue: 0.14), darkBackground]
                : [lightBackground, Color(red: 0.91, green: 0.96, blue: 0.90), Color(red: 0.98, green: 0.93, blue: 0.84)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
