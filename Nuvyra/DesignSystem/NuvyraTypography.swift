import SwiftUI

enum NuvyraTypography {
    private static let roundedFontName = "SF Pro Rounded"

    static let hero = Font.custom(roundedFontName, size: 34, relativeTo: .largeTitle)
        .weight(.bold)
    static let title = Font.custom(roundedFontName, size: 22, relativeTo: .title2)
        .weight(.bold)
    static let section = Font.custom(roundedFontName, size: 17, relativeTo: .headline)
        .weight(.semibold)
    static let body = Font.custom(roundedFontName, size: 17, relativeTo: .body)
    static let caption = Font.custom(roundedFontName, size: 12, relativeTo: .caption)
    static let metric = metricFont(size: 38, relativeTo: .largeTitle)

    static func metricFont(size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        Font.custom(roundedFontName, size: size, relativeTo: style)
            .weight(.heavy)
            .monospacedDigit()
    }
}
