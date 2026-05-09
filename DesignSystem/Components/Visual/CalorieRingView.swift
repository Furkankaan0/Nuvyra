//
//  CalorieRingView.swift
//  Nuvyra Design System
//
//  Apple Fitness benzeri 3 katmanlı (consume/burn/glow) ring + ortada metric.
//  Animasyonlu açılış + spring update.
//

import SwiftUI

public struct CalorieRingView: View {

    // MARK: - Inputs

    public let consumed: Int
    public let target: Int
    public let burned: Int

    public let lineWidth: CGFloat
    public let showsCenterLabel: Bool

    // MARK: - State

    @State private var animatedConsumed: CGFloat = 0
    @State private var animatedBurned: CGFloat = 0

    // MARK: - Init

    /// - Parameters:
    ///   - consumed: Bugün alınan kcal.
    ///   - target: Günlük hedef.
    ///   - burned: Egzersizle yakılan kcal (ikinci ring).
    ///   - lineWidth: Halka kalınlığı (default 14).
    ///   - showsCenterLabel: Orta yazı görünsün mü.
    public init(
        consumed: Int,
        target: Int,
        burned: Int,
        lineWidth: CGFloat = 14,
        showsCenterLabel: Bool = true
    ) {
        self.consumed = consumed
        self.target = target
        self.burned = burned
        self.lineWidth = lineWidth
        self.showsCenterLabel = showsCenterLabel
    }

    // MARK: - Computed

    private var consumedRatio: CGFloat {
        guard target > 0 else { return 0 }
        return min(1.5, max(0, CGFloat(consumed) / CGFloat(target)))
    }
    private var burnedRatio: CGFloat {
        let goal: CGFloat = 600
        return min(1.5, max(0, CGFloat(burned) / goal))
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Outer track
            Circle()
                .stroke(AppColors.brandPrimary.opacity(0.15), lineWidth: lineWidth)
            // Consumed (outer)
            Circle()
                .trim(from: 0, to: animatedConsumed)
                .stroke(
                    AngularGradient(
                        colors: [
                            AppColors.brandPrimary.opacity(0.85),
                            AppColors.brandPrimary,
                            AppColors.brandPrimary.opacity(0.85)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: AppColors.brandPrimary.opacity(0.45), radius: 8, x: 0, y: 0)

            // Inner track
            Circle()
                .stroke(AppColors.ringMove.opacity(0.15), lineWidth: lineWidth - 4)
                .padding(lineWidth + 4)

            // Burned (inner)
            Circle()
                .trim(from: 0, to: animatedBurned)
                .stroke(
                    AngularGradient(
                        colors: [
                            AppColors.ringMove.opacity(0.85),
                            AppColors.ringMove,
                            AppColors.ringMove.opacity(0.85)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth - 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(lineWidth + 4)
                .shadow(color: AppColors.ringMove.opacity(0.45), radius: 8, x: 0, y: 0)

            if showsCenterLabel {
                centerLabel
            }
        }
        .onAppear { animateIn() }
        .onChange(of: consumed) { _, _ in animateIn() }
        .onChange(of: burned)   { _, _ in animateIn() }
        .accessibilityLabel("Kalori halkaları")
        .accessibilityValue("\(consumed) alındı, hedef \(target). Egzersizle \(burned) kcal yakıldı.")
    }

    private var centerLabel: some View {
        VStack(spacing: 0) {
            Text("\(consumed)")
                .font(AppTypography.metricLarge)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("/ \(target) kcal")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(8)
    }

    // MARK: - Animation

    private func animateIn() {
        animatedConsumed = 0
        animatedBurned = 0
        withAnimation(.spring(response: 0.9, dampingFraction: 0.8)) {
            animatedConsumed = consumedRatio
        }
        withAnimation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.1)) {
            animatedBurned = burnedRatio
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Light") {
    ZStack {
        NuvyraPageBackground()
        CalorieRingView(consumed: 1842, target: 2400, burned: 412)
            .frame(width: 220, height: 220)
            .padding()
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ZStack {
        NuvyraPageBackground()
        CalorieRingView(consumed: 1842, target: 2400, burned: 412)
            .frame(width: 220, height: 220)
            .padding()
    }
    .preferredColorScheme(.dark)
}
#endif
