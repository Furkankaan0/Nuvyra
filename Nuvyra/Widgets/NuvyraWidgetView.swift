import Foundation
import SwiftUI
import WidgetKit

struct NuvyraWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    var entry: NuvyraWidgetEntry

    private var snapshot: NuvyraWidgetSnapshot { entry.snapshot }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                small.containerBackground(NuvyraColors.calmGradient(scheme), for: .widget)
            case .systemMedium:
                medium.containerBackground(NuvyraColors.calmGradient(scheme), for: .widget)
            case .accessoryCircular:
                // Lock-screen ring — single tap into the rhythm score.
                accessoryCircular.containerBackground(.clear, for: .widget)
            case .accessoryRectangular:
                // Three quick lines (kalori · adım · su) for the lock screen.
                accessoryRectangular.containerBackground(.clear, for: .widget)
            case .accessoryInline:
                // One-line glyph + summary; iOS handles tinting.
                accessoryInline.containerBackground(.clear, for: .widget)
            default:
                medium.containerBackground(NuvyraColors.calmGradient(scheme), for: .widget)
            }
        }
        .foregroundStyle(NuvyraColors.primaryText(scheme))
    }

    // MARK: - Accessory families (iOS 16+)

    /// Circular gauge — shows the rhythm score as a 0–100% ring. Falls back
    /// to "—" when there's no data yet so the lock-screen face never reads
    /// "0%" before the first sync of the day.
    private var accessoryCircular: some View {
        Gauge(value: Double(snapshot.rhythmScore) / 100.0) {
            Image(systemName: "leaf.fill")
        } currentValueLabel: {
            if snapshot.hasLoggedToday {
                Text("\(snapshot.rhythmScore)")
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .minimumScaleFactor(0.7)
            } else {
                Text("—").font(.system(.body, design: .rounded).weight(.bold))
            }
        }
        .gaugeStyle(.accessoryCircular)
        .tint(NuvyraColors.accent)
        .widgetAccentable()
        .accessibilityLabel("Nuvyra ritim skoru \(snapshot.rhythmScore) yüzde")
    }

    /// Rectangular complication — three compact metric rows. Stays under
    /// `accessoryRectangular`'s tight 8-line height by using `.caption2`.
    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "leaf.fill").imageScale(.small)
                Text("Nuvyra")
                    .font(.caption.weight(.bold))
                Spacer(minLength: 0)
                Text("%\(snapshot.rhythmScore)")
                    .font(.caption.weight(.heavy))
                    .monospacedDigit()
            }
            .widgetAccentable()
            accessoryRow(icon: "flame.fill", text: "\(snapshot.calorieBalance) kcal kaldı")
            accessoryRow(icon: "drop.fill", text: shortMl(snapshot.waterMl) + " / " + shortMl(snapshot.waterTargetMl))
            accessoryRow(icon: "figure.walk", text: "\(compact(snapshot.steps)) / \(compact(snapshot.stepTarget))")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityRectangularLabel)
    }

    /// Single-line inline complication. iOS forces a monochrome tint here,
    /// so we keep it text-only with a leading SF Symbol.
    private var accessoryInline: some View {
        // Pattern: "Nuvyra · 1.240 kcal · 6.4k adım"
        let kcal = snapshot.calorieBalance
        let stepsLabel = compact(snapshot.steps)
        return Text("\(Image(systemName: "leaf.fill")) \(kcal) kcal · \(stepsLabel) adım")
            .accessibilityLabel("Nuvyra: \(kcal) kalori kaldı, \(snapshot.steps) adım.")
    }

    private func accessoryRow(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).imageScale(.small)
            Text(text)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var accessibilityRectangularLabel: String {
        "Nuvyra ritmi yüzde \(snapshot.rhythmScore). \(snapshot.calorieBalance) kalori kaldı. \(snapshot.waterMl) mililitre su, \(snapshot.steps) adım."
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 10) {
            header(compact: true)

            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(snapshot.rhythmScore)")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.75)
                Text("%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
            }

            Text(snapshot.hasLoggedToday ? "Bugünkü ritim" : "Gün başlıyor")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            VStack(spacing: 6) {
                progressBar(snapshot.waterProgress, tint: .cyan)
                progressBar(snapshot.stepProgress, tint: NuvyraColors.accent)
                progressBar(snapshot.proteinProgress, tint: NuvyraColors.paleLime)
            }

            HStack(spacing: 6) {
                miniStat(title: "Su", value: shortMl(snapshot.waterMl), tint: .cyan)
                miniStat(title: "Adım", value: compact(snapshot.steps), tint: NuvyraColors.accent)
            }
        }
        .padding(14)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                header(compact: false)

                NuvyraProgressRing(
                    progress: Double(snapshot.rhythmScore) / 100,
                    lineWidth: 9,
                    center: "\(snapshot.rhythmScore)",
                    caption: "ritim"
                )
                .frame(width: 100, height: 100)

                HStack(spacing: 6) {
                    streakChip(icon: "drop.fill", value: "\(snapshot.waterStreakDays)g")
                    streakChip(icon: "fork.knife", value: "\(snapshot.mealStreakDays)g")
                }
            }
            .frame(width: 120, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.firstName)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                metricRow(
                    icon: "flame.fill",
                    title: "Kalori",
                    value: "\(snapshot.calorieBalance) kaldı",
                    progress: snapshot.calorieProgress,
                    tint: NuvyraColors.mutedCoral
                )
                metricRow(
                    icon: "drop.fill",
                    title: "Su",
                    value: "\(snapshot.waterMl) / \(snapshot.waterTargetMl) ml",
                    progress: snapshot.waterProgress,
                    tint: .cyan
                )
                metricRow(
                    icon: "figure.walk",
                    title: "Adım",
                    value: "\(compact(snapshot.steps)) / \(compact(snapshot.stepTarget))",
                    progress: snapshot.stepProgress,
                    tint: NuvyraColors.accent
                )
                metricRow(
                    icon: "bolt.heart.fill",
                    title: "Protein",
                    value: "\(Int(snapshot.proteinGrams.rounded())) / \(snapshot.proteinTargetGrams) g",
                    progress: snapshot.proteinProgress,
                    tint: NuvyraColors.paleLime
                )

                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Güncellendi \(snapshot.updatedAt.formatted(.dateTime.hour().minute()))")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(NuvyraColors.accent)
                Image(systemName: "leaf.fill")
                    .font(.system(size: compact ? 12 : 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: compact ? 24 : 28, height: compact ? 24 : 28)

            VStack(alignment: .leading, spacing: 0) {
                Text("Nuvyra")
                    .font(.caption.weight(.heavy))
                if !compact {
                    Text("Canlı özet")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                }
            }
            .lineLimit(1)
        }
    }

    private func metricRow(icon: String, title: String, value: String, progress: Double, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    Spacer(minLength: 4)
                    Text(value)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                progressBar(progress, tint: tint)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(panelFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(panelStroke, lineWidth: 1)
        )
    }

    private func miniStat(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
            Text(value)
                .font(.caption.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(tint.opacity(scheme == .dark ? 0.18 : 0.13), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func streakChip(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(value)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(NuvyraColors.secondaryText(scheme))
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(panelFill, in: Capsule())
        .overlay(Capsule().stroke(panelStroke, lineWidth: 1))
    }

    private func progressBar(_ progress: Double, tint: Color) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width * CGFloat(min(max(progress, 0), 1))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tint.opacity(scheme == .dark ? 0.18 : 0.20))
                Capsule()
                    .fill(tint)
                    .frame(width: progress > 0 ? max(width, 4) : 0)
            }
        }
        .frame(height: 5)
    }

    private var panelFill: Color {
        scheme == .dark ? Color.white.opacity(0.09) : Color.white.opacity(0.56)
    }

    private var panelStroke: Color {
        scheme == .dark ? Color.white.opacity(0.13) : Color.white.opacity(0.66)
    }

    private func compact(_ value: Int) -> String {
        if value >= 1_000 {
            let number = Double(value) / 1_000
            return number >= 10 ? "\(Int(number.rounded()))K" : String(format: "%.1fK", number)
        }
        return value.formatted()
    }

    private func shortMl(_ value: Int) -> String {
        value >= 1_000 ? String(format: "%.1fL", Double(value) / 1_000) : "\(value)ml"
    }
}
