//
//  SecondaryButton.swift
//  Nuvyra Design System
//
//  Outlined / soft fill ikincil aksiyon butonu.
//

import SwiftUI

public struct SecondaryButton: View {

    // MARK: - Style

    public enum Style {
        case outline
        case soft   // tint dolgusu hafif şeffaf
        case ghost  // sadece metin
    }

    // MARK: - Inputs

    public let title: String
    public let icon: String?
    public let style: Style
    public let isEnabled: Bool
    public let action: () -> Void

    // MARK: - Init

    public init(
        _ title: String,
        icon: String? = nil,
        style: Style = .outline,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
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
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(AppTypography.bodyEmphasized)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(textColor)
            .background(background)
            .overlay(borderShape)
            .clipShape(AppRadius.shape(AppRadius.md))
        }
        .buttonStyle(NuvyraScalePressStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
        .accessibilityLabel(title)
    }

    // MARK: - Visual Variants

    private var textColor: Color {
        switch style {
        case .outline, .ghost: return AppColors.textPrimary
        case .soft:            return AppColors.brandPrimary
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .outline:
            AppColors.surface
        case .soft:
            AppColors.brandPrimary.opacity(0.12)
        case .ghost:
            Color.clear
        }
    }

    @ViewBuilder
    private var borderShape: some View {
        switch style {
        case .outline:
            AppRadius.shape(AppRadius.md)
                .stroke(AppColors.borderSubtle, lineWidth: 1)
        case .soft, .ghost:
            EmptyView()
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Light") {
    ZStack {
        NuvyraPageBackground()
        VStack(spacing: 12) {
            SecondaryButton("Outline", icon: "square.and.pencil", style: .outline) {}
            SecondaryButton("Soft", icon: "sparkles", style: .soft) {}
            SecondaryButton("Ghost", style: .ghost) {}
        }
        .padding()
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ZStack {
        NuvyraPageBackground()
        VStack(spacing: 12) {
            SecondaryButton("Outline", icon: "square.and.pencil", style: .outline) {}
            SecondaryButton("Soft", icon: "sparkles", style: .soft) {}
            SecondaryButton("Ghost", style: .ghost) {}
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
#endif
