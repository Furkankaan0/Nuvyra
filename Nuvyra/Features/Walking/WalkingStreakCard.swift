import Charts
import SwiftUI

/// Compact walking summary card. Single .prominent glass surface that
/// stacks:
///   • streak + 7-day average glass pills,
///   • a 7-day completion bar with an accent gradient sparkline overlay
///     so the eye reads "current trend" before reading the number.
///
/// Designed to slot directly under the StepGoalCard hero on the Walking
/// screen — same visual hierarchy, smaller footprint.
struct WalkingStreakCard: View {
    @Environment(\.colorScheme) private var scheme

    var streak: Int
    var averageSteps: Int
    var completionRate: Double
    /// Last-7-day step series the sparkline draws. Pass an empty array to
    /// suppress the chart silently (we don't render a flat line).
    var recentSteps: [Int] = []

    var body: some View {
        NuvyraGlassCard(.prominent) {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                header
                pillRail
                completionRow
                if !recentSteps.isEmpty {
                    sparkline
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Yürüyüş ritmin")
                    .font(NuvyraTypography.section)
                Text("Son 7 günün özeti")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "figure.walk.motion")
                .font(.title3.weight(.bold))
                .foregroundStyle(NuvyraColors.accent)
        }
    }

    // MARK: - Pill rail

    private var pillRail: some View {
        HStack(spacing: NuvyraSpacing.xs) {
            NuvyraGlassPill(
                systemImage: "flame.fill",
                title: "\(streak) günlük streak",
                tint: streak > 0 ? NuvyraColors.mutedCoral : NuvyraColors.mutedGray
            )
            NuvyraGlassPill(
                systemImage: "chart.bar.fill",
                title: "ø \(averageSteps.formatted())",
                tint: NuvyraColors.accent
            )
        }
    }

    // MARK: - Completion row

    private var completionRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Hedef tamamlama")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("%\(Int((completionRate * 100).rounded()))")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(NuvyraColors.accent)
                    .contentTransition(.numericText())
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(NuvyraColors.accent.opacity(scheme == .dark ? 0.16 : 0.10))
                    Capsule()
                        .fill(NuvyraColors.accentGradient)
                        .frame(width: proxy.size.width * CGFloat(min(max(completionRate, 0), 1)))
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Sparkline

    private var sparkline: some View {
        Chart {
            ForEach(Array(recentSteps.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Gün", index),
                    y: .value("Adım", value)
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .foregroundStyle(NuvyraColors.accentGradient)

                AreaMark(
                    x: .value("Gün", index),
                    y: .value("Adım", value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            NuvyraColors.accent.opacity(scheme == .dark ? 0.32 : 0.22),
                            NuvyraColors.accent.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .frame(height: 48)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .accessibilityHidden(true)
    }

    private var accessibilityLabel: String {
        "Yürüyüş ritmi: \(streak) günlük streak, ortalama \(averageSteps) adım. Hedef tamamlama yüzde \(Int(completionRate * 100))."
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        VStack(spacing: NuvyraSpacing.md) {
            WalkingStreakCard(
                streak: 5,
                averageSteps: 7_320,
                completionRate: 0.72,
                recentSteps: [5_400, 7_900, 4_200, 8_700, 6_300, 9_100, 7_200]
            )
            WalkingStreakCard(
                streak: 0,
                averageSteps: 0,
                completionRate: 0,
                recentSteps: []
            )
        }
        .padding()
    }
}
#endif
