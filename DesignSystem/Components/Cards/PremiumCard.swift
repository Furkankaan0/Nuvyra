//
//  PremiumCard.swift
//  Nuvyra Design System
//
//  Yuvarlatılmış, derinlik hissi veren ana kart container'ı.
//  Çok katmanlı gölge + ince border + opsiyonel gradient overlay.
//

import SwiftUI

/// Genel amaçlı premium kart.
public struct PremiumCard<Content: View>: View {

    // MARK: - Inputs

    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let showsHighlight: Bool
    private let content: Content

    // MARK: - Init

    /// - Parameters:
    ///   - cornerRadius: Köşe yarıçapı (default `AppRadius.lg`).
    ///   - padding: İç padding (default `AppSpacing.cardPadding`).
    ///   - showsHighlight: Üst kenarda hafif highlight çizgi (cam efekti).
    public init(
        cornerRadius: CGFloat = AppRadius.lg,
        padding: CGFloat = AppSpacing.cardPadding,
        showsHighlight: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.showsHighlight = showsHighlight
        self.content = content()
    }

    // MARK: - Body

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AppRadius.shape(cornerRadius)
                    .fill(AppColors.surface)
            )
            .overlay(highlightOverlay)
            .overlay(
                AppRadius.shape(cornerRadius)
                    .stroke(AppColors.borderHairline, lineWidth: 1)
            )
            .nuvyraCardShadow()
    }

    @ViewBuilder
    private var highlightOverlay: some View {
        if showsHighlight {
            AppRadius.shape(cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.35),
                            .white.opacity(0.0),
                            .white.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Light") {
    ZStack {
        NuvyraPageBackground()
        PremiumCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Premium Card")
                    .font(AppTypography.titleSmall)
                    .foregroundStyle(AppColors.textPrimary)
                Text("Yumuşak köşeler, çok katmanlı gölge ve ince highlight ile derinlik hissi.")
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding()
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ZStack {
        NuvyraPageBackground()
        PremiumCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Premium Card")
                    .font(AppTypography.titleSmall)
                    .foregroundStyle(AppColors.textPrimary)
                Text("Yumuşak köşeler, çok katmanlı gölge ve ince highlight ile derinlik hissi.")
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
#endif
