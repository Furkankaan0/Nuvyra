//
//  PrimaryButton.swift
//  Nuvyra Design System
//
//  Marka gradient'i ile dolgulu ana CTA butonu. Haptik + scale press effect.
//

import SwiftUI

public struct PrimaryButton: View {

    // MARK: - Inputs

    public let title: String
    public let icon: String?
    public let isLoading: Bool
    public let isEnabled: Bool
    public let action: () -> Void

    // MARK: - Init

    /// - Parameters:
    ///   - title: Buton metni.
    ///   - icon: Opsiyonel SF Symbol.
    ///   - isLoading: True iken progress + disable.
    ///   - isEnabled: False iken soluk + dokunmasız.
    public init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    // MARK: - Body

    public var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(AppColors.textOnAccent)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(title)
                    .font(AppTypography.bodyEmphasized)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundStyle(AppColors.textOnAccent)
            .background(AppColors.primaryGradient)
            .clipShape(AppRadius.shape(AppRadius.md))
            .overlay(
                AppRadius.shape(AppRadius.md)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: AppColors.brandPrimary.opacity(0.35), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(NuvyraScalePressStyle())
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1 : 0.55)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Press Style

/// Tüm butonlar için ortak: dokunulduğunda 0.97 scale + opacity 0.95.
public struct NuvyraScalePressStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.85),
                       value: configuration.isPressed)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Light") {
    ZStack {
        NuvyraPageBackground()
        VStack(spacing: 12) {
            PrimaryButton("Kayıt Ol", icon: "arrow.right") {}
            PrimaryButton("Yükleniyor...", isLoading: true) {}
            PrimaryButton("Devre Dışı", isEnabled: false) {}
        }
        .padding()
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ZStack {
        NuvyraPageBackground()
        VStack(spacing: 12) {
            PrimaryButton("Kayıt Ol", icon: "arrow.right") {}
            PrimaryButton("Yükleniyor...", isLoading: true) {}
            PrimaryButton("Devre Dışı", isEnabled: false) {}
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
#endif
