//
//  ErrorStateView.swift
//  Nuvyra Design System
//
//  Hata ekranı: kırmızımsı ikon disk + mesaj + retry CTA.
//

import SwiftUI

public struct ErrorStateView: View {

    // MARK: - Inputs

    public let title: String
    public let message: String
    public let retryTitle: String
    public let onRetry: () -> Void

    // MARK: - Init

    /// - Parameters:
    ///   - title: Hata başlığı.
    ///   - message: Detay açıklama.
    ///   - retryTitle: Retry butonu metni.
    public init(
        title: String = "Bir şeyler ters gitti",
        message: String,
        retryTitle: String = "Tekrar Dene",
        onRetry: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.retryTitle = retryTitle
        self.onRetry = onRetry
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: AppSpacing.md) {
            iconDisk
            VStack(spacing: 6) {
                Text(title)
                    .font(AppTypography.titleSmall)
                    .foregroundStyle(AppColors.textPrimary)
                Text(message)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            HStack(spacing: 12) {
                SecondaryButton("Vazgeç", style: .ghost) {}
                PrimaryButton(retryTitle, icon: "arrow.clockwise", action: onRetry)
                    .frame(maxWidth: 200)
            }
            .padding(.top, 4)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: - Icon

    private var iconDisk: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppColors.danger.opacity(0.30),
                            AppColors.danger.opacity(0.05),
                            .clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
            Circle()
                .fill(AppColors.surface)
                .frame(width: 92, height: 92)
                .nuvyraCardShadow()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(AppColors.danger)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Light") {
    ZStack {
        NuvyraPageBackground()
        ErrorStateView(
            message: "Sunucuya bağlanılamadı. İnternet bağlantını kontrol edip tekrar dene.",
            onRetry: {}
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ZStack {
        NuvyraPageBackground()
        ErrorStateView(
            message: "Sunucuya bağlanılamadı. İnternet bağlantını kontrol edip tekrar dene.",
            onRetry: {}
        )
    }
    .preferredColorScheme(.dark)
}
#endif
