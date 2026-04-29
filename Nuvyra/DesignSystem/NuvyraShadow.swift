import SwiftUI

enum NuvyraShadow {
    static func card(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.32) : Color.black.opacity(0.08)
    }
}
