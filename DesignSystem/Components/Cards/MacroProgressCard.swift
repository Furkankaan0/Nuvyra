//
//  MacroProgressCard.swift
//  Nuvyra Design System
//
//  Tek bir makro besin için progress kartı: ikon + isim + gram + soft bar.
//  Dashboard'da Protein/Karb/Yağ üçlüsü olarak yan yana kullanılır.
//

import SwiftUI

public struct MacroProgressCard: View {

    // MARK: - Inputs

    public let title: String
    public let consumed: Double
    public let target: Double
    public let unit: String
    public let tint: Color
    public let icon: String

    // MARK: - State

    @State private var animatedProgress: CGFloat = 0

    /// Hedefe oran (0...1).
    private var progress: CGFloat {
        guard target > 0 else { return 0 }
        return min(1, max(0, CGFloat(consumed / target)))
    }

    // MARK: - Init

    /// - Parameters:
    ///   - title: Makro adı (Protein, Karb, Yağ vb).
    ///   - consumed: Bugün tüketilen değer.
    ///   - target: Günlük hedef.
    ///   - unit: Birim (default "g").
    ///   - tint: Bar/ikon rengi.
    ///   - icon: SF Symbol adı.
    public init(
        title: String,
        consumed: Double,
        target: Double,
        unit: String = "g",
        tint: Color,
        icon: String
    ) {
        self.title = title
        self.consumed = consumed
        self.target = target
        self.unit = unit
        self.tint = tint
        self.icon = icon
    }

    // MARK: - Body

    public var body: some View {
        PremiumCard(cornerRadius: AppRadius.lg, padding: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                    Text(title)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer(minLength: 0)
                }

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(Int(consumed.rounded()))")
                        .font(AppTypography.metricSmall)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("/ \(Int(target.rounded())) \(unit)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }

                progressBar
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) ilerlemesi")
        .accessibilityValue("\(Int(consumed.rounded())) / \(Int(target.rounded())) \(unit)")
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.1)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                animatedProgress = newValue
            }
        }
    }

    // MARK: - Subviews

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tint.opacity(0.18))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.7), tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, geo.size.width * animatedProgress))
                    .shadow(color: tint.opacity(0.45), radius: 6, x: 0, y: 2)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Light") {
    ZStack {
        NuvyraPageBackground()
        HStack(spacing: 12) {
            MacroProgressCard(title: "Protein", consumed: 78, target: 120,
                              tint: AppColors.macroProtein, icon: "fish.fill")
            MacroProgressCard(title: "Karb",     consumed: 145, target: 220,
                              tint: AppColors.macroCarbs, icon: "leaf.fill")
            MacroProgressCard(title: "Yağ",      consumed: 42,  target: 70,
                              tint: AppColors.macroFat, icon: "drop.fill")
        }
        .padding()
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ZStack {
        NuvyraPageBackground()
        HStack(spacing: 12) {
            MacroProgressCard(title: "Protein", consumed: 78, target: 120,
                              tint: AppColors.macroProtein, icon: "fish.fill")
            MacroProgressCard(title: "Karb",     consumed: 145, target: 220,
                              tint: AppColors.macroCarbs, icon: "leaf.fill")
            MacroProgressCard(title: "Yağ",      consumed: 42,  target: 70,
                              tint: AppColors.macroFat, icon: "drop.fill")
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
#endif
