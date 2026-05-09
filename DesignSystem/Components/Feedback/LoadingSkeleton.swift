//
//  LoadingSkeleton.swift
//  Nuvyra Design System
//
//  Premium shimmer placeholder. Built-in: kart, satır, daire, metric.
//

import SwiftUI

// MARK: - Shimmer Modifier

public struct NuvyraShimmer: ViewModifier {

    @State private var phase: CGFloat = -0.8

    public func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .white.opacity(0.0),
                        .white.opacity(0.45),
                        .white.opacity(0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(20))
                .offset(x: phase * 320)
                .blendMode(.plusLighter)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.4
                }
            }
            .accessibilityHidden(true)
    }
}

public extension View {
    /// Premium shimmer efekti uygular.
    func nuvyraShimmer() -> some View { modifier(NuvyraShimmer()) }
}

// MARK: - Skeleton Atoms

public enum LoadingSkeleton {

    /// Tek satır placeholder.
    public static func line(width: CGFloat? = nil, height: CGFloat = 14) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(AppColors.borderSubtle)
            .frame(width: width, height: height)
            .nuvyraShimmer()
    }

    /// Avatar placeholder.
    public static func circle(size: CGFloat = 44) -> some View {
        Circle()
            .fill(AppColors.borderSubtle)
            .frame(width: size, height: size)
            .nuvyraShimmer()
    }

    /// Kart placeholder.
    public static func card(height: CGFloat = 160) -> some View {
        AppRadius.shape(AppRadius.lg)
            .fill(AppColors.borderSubtle)
            .frame(height: height)
            .nuvyraShimmer()
    }
}

/// Tipik bir liste skeleton bloğu (avatar + 2 satır).
public struct ListItemSkeleton: View {
    public init() {}
    public var body: some View {
        HStack(spacing: 12) {
            LoadingSkeleton.circle()
            VStack(alignment: .leading, spacing: 8) {
                LoadingSkeleton.line(width: 180)
                LoadingSkeleton.line(width: 110, height: 10)
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .accessibilityElement()
        .accessibilityLabel("Yükleniyor")
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Light") {
    ZStack {
        NuvyraPageBackground()
        VStack(spacing: 16) {
            LoadingSkeleton.card()
            VStack(spacing: 12) {
                ListItemSkeleton()
                ListItemSkeleton()
                ListItemSkeleton()
            }
        }
        .padding()
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ZStack {
        NuvyraPageBackground()
        VStack(spacing: 16) {
            LoadingSkeleton.card()
            VStack(spacing: 12) {
                ListItemSkeleton()
                ListItemSkeleton()
                ListItemSkeleton()
            }
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
#endif
