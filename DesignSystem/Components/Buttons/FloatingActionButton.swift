//
//  FloatingActionButton.swift
//  Nuvyra Design System
//
//  Soft glow + brand gradient ile FAB. Dashboard'da "yemek ekle" /
//  "barkod tara" gibi birincil eylemleri tetikler.
//

import SwiftUI

public struct FloatingActionButton: View {

    // MARK: - Inputs

    public let icon: String
    public let label: String
    public let action: () -> Void

    @State private var isPulsing: Bool = false

    // MARK: - Init

    /// - Parameters:
    ///   - icon: SF Symbol.
    ///   - label: VoiceOver için açıklama.
    public init(icon: String, label: String, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.action = action
    }

    // MARK: - Body

    public var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            ZStack {
                // Subtle glow ring
                Circle()
                    .fill(AppColors.brandPrimary.opacity(0.18))
                    .frame(width: 78, height: 78)
                    .scaleEffect(isPulsing ? 1.15 : 0.9)
                    .opacity(isPulsing ? 0.0 : 1.0)
                    .animation(
                        .easeOut(duration: 1.6).repeatForever(autoreverses: false),
                        value: isPulsing
                    )

                Circle()
                    .fill(AppColors.primaryGradient)
                    .frame(width: 62, height: 62)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.25), lineWidth: 1)
                    )

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColors.textOnAccent)
            }
        }
        .buttonStyle(NuvyraScalePressStyle())
        .nuvyraFabShadow()
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .onAppear { isPulsing = true }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Light") {
    ZStack {
        NuvyraPageBackground()
        FloatingActionButton(icon: "plus", label: "Yemek ekle") {}
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ZStack {
        NuvyraPageBackground()
        FloatingActionButton(icon: "plus", label: "Yemek ekle") {}
    }
    .preferredColorScheme(.dark)
}
#endif
