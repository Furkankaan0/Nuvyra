//
//  ShimmerView.swift
//  Nuvyra - Barcode Scanner
//
//  Loading state'i için lightweight shimmer (kayar gradient) view modifier.
//

import SwiftUI

/// Bir view'a kayar shimmer efekti ekleyen modifier.
public struct ShimmerModifier: ViewModifier {

    @State private var phase: CGFloat = -1.0
    private let duration: Double

    public init(duration: Double = 1.2) {
        self.duration = duration
    }

    public func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.0),
                        Color.white.opacity(0.55),
                        Color.white.opacity(0.0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(20))
                .offset(x: phase * 350)
                .blendMode(.plusLighter)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

public extension View {
    /// Shimmer efekti uygular.
    func shimmer(duration: Double = 1.2) -> some View {
        modifier(ShimmerModifier(duration: duration))
    }
}

/// Bottom sheet için skeleton placeholder kart.
public struct ProductSkeletonCard: View {

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RoundedRectangle(cornerRadius: 6)
                .fill(.gray.opacity(0.25))
                .frame(width: 180, height: 18)
            RoundedRectangle(cornerRadius: 6)
                .fill(.gray.opacity(0.25))
                .frame(width: 110, height: 14)
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.gray.opacity(0.25))
                        .frame(height: 56)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .shimmer()
    }
}
