import Charts
import SwiftUI

/// Dashboard card surfacing body-weight trend. Renders only when at least one
/// `WeightLog` exists, so first-time users with no measurements don't see an
/// empty chart. Copy is intentionally calm: "trend" / "fark" instead of
/// "gain" / "loss" — Nuvyra never frames weight as a moral metric.
struct WeightTrendCard: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var summary: WeightTrendSummary
    var targetWeightKg: Double?

    /// Tap action — the Dashboard routes this to BodyMeasurements / weight-log
    /// entry. Optional so previews can render without a sink.
    var onAddMeasurement: (() -> Void)?

    /// Should the card be rendered at all? Hides itself silently for users
    /// who haven't recorded a measurement yet — the empty-state CTA lives in
    /// the Body Measurements screen, not here.
    var shouldRender: Bool { summary.latestWeightKg != nil }

    @ViewBuilder
    var body: some View {
        if shouldRender {
            NuvyraGlassCard(.prominent) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                    header
                    heroRow
                    if summary.logs.count >= 2 {
                        chart
                    } else {
                        singlePointHint
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("weight.trend.title")
                    .font(NuvyraTypography.section)
                Text(headerSubtitle)
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                onAddMeasurement?()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(NuvyraColors.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Yeni ölçüm ekle")
        }
    }

    private var heroRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(latestDisplay)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                Text("weight.trend.last.measurement")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            sevenDayDeltaChip
            if let targetWeightKg {
                targetChip(target: targetWeightKg)
            }
        }
    }

    @ViewBuilder
    private var chart: some View {
        Chart {
            ForEach(summary.logs, id: \.id) { log in
                LineMark(
                    x: .value("Gün", log.date, unit: .day),
                    y: .value("Kilogram", log.weightKg)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(NuvyraColors.accent)
                .symbol(.circle)
                .symbolSize(28)

                AreaMark(
                    x: .value("Gün", log.date, unit: .day),
                    y: .value("Kilogram", log.weightKg)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [NuvyraColors.accent.opacity(0.22), NuvyraColors.accent.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            }

            if let targetWeightKg {
                RuleMark(y: .value("Hedef", targetWeightKg))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(NuvyraColors.mutedGray)
                    .annotation(position: .topTrailing, alignment: .trailing) {
                        Text("Hedef \(formatKg(targetWeightKg))")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    }
            }
        }
        .frame(height: 140)
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(NuvyraColors.mutedGray.opacity(0.25))
                AxisValueLabel().font(.caption2)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                AxisGridLine().foregroundStyle(NuvyraColors.mutedGray.opacity(0.18))
                AxisValueLabel(format: .dateTime.day().month(.abbreviated)).font(.caption2)
            }
        }
        .accessibilityHidden(true)
    }

    private var singlePointHint: some View {
        Text("weight.trend.empty")
            .font(NuvyraTypography.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, NuvyraSpacing.xs)
    }

    @ViewBuilder
    private var sevenDayDeltaChip: some View {
        let delta = sevenDayDelta
        let absKg = abs(delta)
        let arrow: String
        let tint: Color
        if absKg < 0.1 {
            arrow = "–"
            tint = NuvyraColors.mutedGray
        } else if delta > 0 {
            arrow = "↑"
            tint = NuvyraColors.mutedCoral
        } else {
            arrow = "↓"
            tint = NuvyraColors.accent
        }
        VStack(alignment: .trailing, spacing: 4) {
            NuvyraGlassPill(tint: tint) {
                HStack(spacing: 4) {
                    Text(arrow).font(.caption.weight(.bold))
                    Text(absKg < 0.1 ? "Sabit" : "\(formatKg(absKg))")
                        .font(.caption.weight(.bold))
                }
            }
            Text("weight.trend.seven.day")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func targetChip(target: Double) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Hedef")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(formatKg(target))
                .font(.caption.weight(.heavy))
                .foregroundStyle(NuvyraColors.accent)
        }
    }

    // MARK: - Computed

    /// 7-day delta = latest - "what we recorded ~7 days ago". Falls back to
    /// `summary.deltaKg` (which covers the whole window) if we don't have a
    /// row near the 7-day mark.
    private var sevenDayDelta: Double {
        guard let latest = summary.logs.last else { return 0 }
        let cutoff = Calendar.nuvyra.date(byAdding: .day, value: -7, to: latest.date) ?? latest.date
        if let reference = summary.logs.last(where: { $0.date <= cutoff }) {
            return latest.weightKg - reference.weightKg
        }
        return summary.deltaKg
    }

    private var latestDisplay: String {
        guard let kg = summary.latestWeightKg else { return "—" }
        return formatKg(kg)
    }

    private var headerSubtitle: String {
        if let date = summary.logs.last?.date {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "tr_TR")
            formatter.dateFormat = "d MMMM"
            return "Son: \(formatter.string(from: date))"
        }
        return "Ölçüm bekleniyor"
    }

    private func formatKg(_ value: Double) -> String {
        String(format: "%.1f kg", value)
    }

    private var accessibilityLabel: String {
        let latest = summary.latestWeightKg.map { String(format: "%.1f kilogram", $0) } ?? "ölçüm yok"
        let delta = sevenDayDelta
        let direction: String
        if abs(delta) < 0.1 {
            direction = "son 7 günde sabit"
        } else if delta > 0 {
            direction = "son 7 günde \(String(format: "%.1f", abs(delta))) kilogram yükselmiş"
        } else {
            direction = "son 7 günde \(String(format: "%.1f", abs(delta))) kilogram düşmüş"
        }
        return "Vücut ritmi: \(latest), \(direction)."
    }
}

#if DEBUG
#Preview("With data") {
    ZStack {
        NuvyraBackground()
        VStack(spacing: NuvyraSpacing.md) {
            WeightTrendCard(
                summary: WeightTrendSummary(
                    logs: Array(
                        (0..<14).map { offset in
                            WeightLog(
                                date: Calendar.nuvyra.date(byAdding: .day, value: -offset, to: Date()) ?? Date(),
                                weightKg: 78.0 - Double(offset) * 0.12 + (offset.isMultiple(of: 3) ? 0.3 : 0)
                            )
                        }.reversed()
                    ),
                    latestWeightKg: 78.0,
                    deltaKg: -1.4,
                    projectedGoalDate: nil
                ),
                targetWeightKg: 74.0
            )
            WeightTrendCard(
                summary: WeightTrendSummary(
                    logs: [WeightLog(date: Date(), weightKg: 76.4)],
                    latestWeightKg: 76.4,
                    deltaKg: 0,
                    projectedGoalDate: nil
                ),
                targetWeightKg: 74.0
            )
            WeightTrendCard(summary: .empty, targetWeightKg: 74.0)
        }
        .padding()
    }
}
#endif
