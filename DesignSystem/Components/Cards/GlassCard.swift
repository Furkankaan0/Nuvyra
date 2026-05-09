//
//  GlassCard.swift
//  Nuvyra Design System
//
//  Frosted glass kart — .ultraThinMaterial üzerine soft tint, üst highlight
//  çizgisi ve hafif gölge. Apple Fitness ve premium dashboard'larda
//  görülen "frosted depth" hissini verir.
//

import SwiftUI

/// Frosted glass material tabanlı kart.
public struct GlassCard<Content: View>: View {

    // MARK: - Inputs

    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let strength: GlassStrength
    private let content: Content

    /// Glass yoğunluğu.
    public enum GlassStrength {
        case ultraThin
        case thin
        case regular

        fileprivate var material: Material {
            switch self {
            case .ultraThin: return .ultraThinMaterial
            case .thin:      return .thinMaterial
            case .regular:   return .regularMaterial
            }
        }
    }

    // MARK: - Init

    /// - Parameters:
    ///   - strength: Glass yoğunluğu (default .ultraThin).
    ///   - cornerRadius: Köşe yarıçapı.
    ///   - padding: İç padding.
    public init(
        strength: GlassStrength = .ultraThin,
        cornerRadius: CGFloat = AppRadius.lg,
        padding: CGFloat = AppSpacing.cardPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.strength = strength
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    // MARK: - Body

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AppRadius.shape(cornerRadius)
                    .fill(strength.material)
            )
            .background(
                AppRadius.shape(cornerRadius)
                    .fill(AppColors.glassTint)
            )
            .overlay(
                AppRadius.shape(cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.45),
                                .white.opacity(0.05),
                                .white.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    .blendMode(.plusLighter)
            )
            .clipShape(AppRadius.shape(cornerRadius))
            .shadow(AppShadow.card1)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Light") {
    ZStack {
        AppColors.dashboardGradient.ignoresSafeArea()
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Bugün")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Text("1.842 kcal")
                    .font(AppTypography.metricLarge)
                    .foregroundStyle(AppColors.textPrimary)
            }
        }
        .padding()
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ZStack {
        AppColors.dashboardGradient.ignoresSafeArea()
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Bugün")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Text("1.842 kcal")
                    .font(AppTypography.metricLarge)
                    .foregroundStyle(AppColors.textPrimary)
            }
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
#endif
