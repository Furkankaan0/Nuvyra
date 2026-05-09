//
//  DailySummaryCard.swift
//  Nuvyra Design System
//
//  Dashboard'un üst hero kartı: Bugün tüketilen kalori, kalan kalori,
//  yakılan kalori (Apple Fitness benzeri), üç metrik chip ile.
//

import SwiftUI

public struct DailySummaryCard: View {

    // MARK: - Inputs

    public let consumed: Int
    public let target: Int
    public let burned: Int
    public let waterMl: Int
    public let waterTargetMl: Int
    public let stepCount: Int
    public let stepTarget: Int

    public init(
        consumed: Int,
        target: Int,
        burned: Int,
        waterMl: Int,
        waterTargetMl: Int,
        stepCount: Int,
        stepTarget: Int
    ) {
        self.consumed = consumed
        self.target = target
        self.burned = burned
        self.waterMl = waterMl
        self.waterTargetMl = waterTargetMl
        self.stepCount = stepCount
        self.stepTarget = stepTarget
    }

    // MARK: - Computed

    private var remaining: Int { max(0, target - consumed + burned) }
    private var consumedRatio: Double {
        guard target > 0 else { return 0 }
        return Double(consumed) / Double(target)
    }

    // MARK: - Body

    public var body: some View {
        PremiumCard(cornerRadius: AppRadius.xl, padding: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                heroRow
                Divider().background(AppColors.borderHairline)
                metricRow
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Günlük özet")
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Bugün")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
            }
            Spacer()
            PremiumBadge(label: "Streak 7", icon: "flame.fill", style: .gold)
        }
    }

    private var heroRow: some View {
        HStack(alignment: .center, spacing: AppSpacing.lg) {
            CalorieRingView(
                consumed: consumed,
                target: target,
                burned: burned
            )
            .frame(width: 130, height: 130)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(remaining)")
                    .font(AppTypography.metricHero)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("kcal kaldı")
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
                ProgressLabel(
                    current: consumed, target: target,
                    suffix: " kcal alındı", tint: AppColors.brandPrimary
                )
                ProgressLabel(
                    current: burned, target: 600,
                    suffix: " kcal yakıldı", tint: AppColors.ringMove
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Kalori özeti")
        .accessibilityValue("\(consumed) alındı, \(burned) yakıldı, hedef \(target). Kalan \(remaining) kcal.")
    }

    private var metricRow: some View {
        HStack(spacing: AppSpacing.sm) {
            metricChip(
                icon: "drop.fill",
                tint: AppColors.macroCarbs,
                value: "\(waterMl)",
                unit: "ml",
                progress: Double(waterMl) / Double(max(1, waterTargetMl))
            )
            metricChip(
                icon: "figure.walk",
                tint: AppColors.ringStand,
                value: stepCount.formatted(.number),
                unit: "adım",
                progress: Double(stepCount) / Double(max(1, stepTarget))
            )
            metricChip(
                icon: "heart.fill",
                tint: AppColors.macroProtein,
                value: "72",
                unit: "bpm",
                progress: 0.6
            )
        }
    }

    /// Tekil metrik chip (su, adım, nabız).
    private func metricChip(
        icon: String,
        tint: Color,
        value: String,
        unit: String,
        progress: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Text(unit)
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.textTertiary)
            }
            Text(value)
                .font(AppTypography.metricSmall)
                .foregroundStyle(AppColors.textPrimary)
            Capsule()
                .fill(tint.opacity(0.20))
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(tint)
                            .frame(width: geo.size.width * min(1, max(0, progress)))
                    }
                }
                .frame(height: 4)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppRadius.shape(AppRadius.md)
                .fill(AppColors.backgroundSoft.opacity(0.7))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(unit): \(value)")
    }
}

// MARK: - Helpers

private struct ProgressLabel: View {
    let current: Int
    let target: Int
    let suffix: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            Text("\(current)\(suffix)")
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Light") {
    ZStack {
        NuvyraPageBackground()
        DailySummaryCard(
            consumed: 1842, target: 2400, burned: 412,
            waterMl: 1500, waterTargetMl: 2500,
            stepCount: 6480, stepTarget: 10000
        )
        .padding()
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ZStack {
        NuvyraPageBackground()
        DailySummaryCard(
            consumed: 1842, target: 2400, burned: 412,
            waterMl: 1500, waterTargetMl: 2500,
            stepCount: 6480, stepTarget: 10000
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
#endif
