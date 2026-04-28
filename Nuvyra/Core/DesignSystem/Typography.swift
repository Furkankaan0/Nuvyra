import SwiftUI

enum NuvyraTypography {
    static func hero() -> Font { .system(size: 36, weight: .bold, design: .rounded) }
    static func title() -> Font { .system(.title2, design: .rounded).weight(.bold) }
    static func sectionTitle() -> Font { .system(.headline, design: .rounded).weight(.semibold) }
    static func body() -> Font { .system(.body, design: .rounded) }
    static func caption() -> Font { .system(.caption, design: .rounded) }
    static func metric() -> Font { .system(size: 34, weight: .heavy, design: .rounded) }
}
