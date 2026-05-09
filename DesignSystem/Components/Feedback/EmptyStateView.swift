//
//  EmptyStateView.swift
//  Nuvyra Design System
//
//  Boş liste / sıfır veri ekranı. Soft gradient ikon disk + başlık + alt
//  açıklama + opsiyonel CTA.
//

import SwiftUI

public struct EmptyStateView: View {

    // MARK: - Inputs

    public let icon: String
    public let title: String
    public let subtitle: String
    public let actionTitle: String?
    public let action: (() -> Void)?

    // MARK: - Init

    /// - Parameters:
    ///   - icon: SF Symbol.
    ///   - title: Ana başlık.
    ///   - subtitle: Yardımcı metin.
    ///   - actionTitle: Opsiyonel CTA başlığı.
    ///   - action: CTA aksiyonu.
    public init(
        icon: String,
        title: String,
        subtitle: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: AppSpacing.md) {
            iconDisk
            VStack(spacing: 6) {
                Text(title)
                    .font(AppTypography.titleSmall)
                    .foregroundStyle(AppColors.textPrimary)
                Text(subtitle)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            if let actionTitle, let action {
                PrimaryButton(actionTitle, icon: "plus", action: action)
                    .frame(maxWidth: 240)
                    .padding(.top, 4)
            }
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }

    // MARK: - Icon

    private var iconDisk: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppColors.brandPrimary.opacity(0.30),
                            AppColors.brandPrimary.opacity(0.05),
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
            Image(systemName: icon)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(AppColors.brandPrimary)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Light") {
    ZStack {
        NuvyraPageBackground()
        EmptyStateView(
            icon: "fork.knife",
            title: "Henüz öğün yok",
            subtitle: "İlk öğününü ekle, Nuvyra senin için günlük makro ve kalori hedeflerini ayarlamaya başlasın.",
            actionTitle: "Öğün Ekle",
            action: {}
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ZStack {
        NuvyraPageBackground()
        EmptyStateView(
            icon: "fork.knife",
            title: "Henüz öğün yok",
            subtitle: "İlk öğününü ekle, Nuvyra senin için günlük makro ve kalori hedeflerini ayarlamaya başlasın.",
            actionTitle: "Öğün Ekle",
            action: {}
        )
    }
    .preferredColorScheme(.dark)
}
#endif
