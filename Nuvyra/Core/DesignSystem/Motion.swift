import SwiftUI

enum NuvyraMotion {
    static func gentle(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.86)
    }

    static func revealDelay(index: Int, reduceMotion: Bool) -> Double {
        reduceMotion ? 0 : Double(index) * 0.045
    }
}
