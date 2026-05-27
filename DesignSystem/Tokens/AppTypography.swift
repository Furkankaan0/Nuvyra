import SwiftUI

public enum AppTypography {
    private static let roundedFontName = "SF Pro Rounded"
    private static let defaultFontName = "SF Pro"

    // MARK: - Display

    public static let displayXL: Font = .custom(roundedFontName, size: 40, relativeTo: .largeTitle)
        .weight(.heavy)
        .leading(.tight)

    public static let displayLarge: Font = .custom(roundedFontName, size: 32, relativeTo: .largeTitle)
        .weight(.bold)
        .leading(.tight)

    // MARK: - Title

    public static let title: Font = .custom(roundedFontName, size: 24, relativeTo: .title)
        .weight(.semibold)

    public static let titleSmall: Font = .custom(roundedFontName, size: 20, relativeTo: .title3)
        .weight(.semibold)

    // MARK: - Headline

    public static let headline: Font = .custom(defaultFontName, size: 18, relativeTo: .headline)
        .weight(.semibold)

    // MARK: - Body

    public static let body: Font = .custom(defaultFontName, size: 17, relativeTo: .body)

    public static let bodyEmphasized: Font = .custom(defaultFontName, size: 17, relativeTo: .body)
        .weight(.semibold)

    public static let bodySmall: Font = .custom(defaultFontName, size: 15, relativeTo: .subheadline)

    // MARK: - Caption

    public static let caption: Font = .custom(defaultFontName, size: 13, relativeTo: .caption)
        .weight(.medium)

    public static let micro: Font = .custom(defaultFontName, size: 11, relativeTo: .caption2)
        .weight(.semibold)

    // MARK: - Numeric

    public static func metric(
        size: CGFloat,
        weight: Font.Weight = .bold,
        relativeTo style: Font.TextStyle = .largeTitle
    ) -> Font {
        .custom(roundedFontName, size: size, relativeTo: style)
            .weight(weight)
            .monospacedDigit()
    }

    public static let metricHero: Font = metric(size: 56, weight: .heavy, relativeTo: .largeTitle)
    public static let metricLarge: Font = metric(size: 36, weight: .bold, relativeTo: .title)
    public static let metricSmall: Font = metric(size: 22, weight: .semibold, relativeTo: .title3)
}

// MARK: - View modifiers

public extension View {
    func appFont(
        _ font: Font,
        relativeTo style: Font.TextStyle = .body,
        lineSpacing: CGFloat = 2
    ) -> some View {
        self
            .font(font)
            .lineSpacing(lineSpacing)
    }

    func nuvyraBody() -> some View {
        self.font(AppTypography.body)
            .foregroundStyle(AppColors.textPrimary)
    }

    func nuvyraSecondary() -> some View {
        self.font(AppTypography.bodySmall)
            .foregroundStyle(AppColors.textSecondary)
    }
}
