import SwiftUI

/// Profile-side BMI / BMR / TDEE card. Shows a horizontal BMI gauge with WHO
/// category buckets plus the metabolic numbers derived from the user's profile.
struct BodyMetricsCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var summary: BodyMetricsSummary
    @State private var animatedBMI: Double = 0

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                header
                bmiGauge
                metabolicRow
                Text("BMI; boy ve kiloya dayalı genel bir göstergedir. Kas-yağ oranı, cinsiyet ve etnik farkları kapsamaz; tıbbi tanı yerine geçmez.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { animate() }
        .onChange(of: summary.bmi) { _, _ in animate() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Vücut metrikleri: BMI \(summary.bmiFormatted), \(summary.category.title), BMR \(summary.bmr), TDEE \(summary.tdee)")
    }

    // MARK: - Header
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Vücut metrikleri")
                    .font(NuvyraTypography.section)
                Text("Boy, kilo ve aktiviteye göre hesaplanan göstergeler")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "function")
                .font(.title3.weight(.bold))
                .foregroundStyle(NuvyraColors.accent)
        }
    }

    // MARK: - BMI gauge
    private var bmiGauge: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("BMI")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(summary.bmiFormatted)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                    .foregroundStyle(categoryColor(summary.category))
                Text(summary.category.title)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(categoryColor(summary.category).opacity(0.15), in: Capsule())
                    .foregroundStyle(categoryColor(summary.category))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    // Multi-band background
                    HStack(spacing: 0) {
                        bandSegment(width: proxy.size.width * (18.5 / 45), color: NuvyraColors.softMint)
                        bandSegment(width: proxy.size.width * ((25 - 18.5) / 45), color: NuvyraColors.accent)
                        bandSegment(width: proxy.size.width * ((30 - 25) / 45), color: NuvyraColors.softSand)
                        bandSegment(width: proxy.size.width * ((35 - 30) / 45), color: NuvyraColors.mutedCoral.opacity(0.78))
                        bandSegment(width: proxy.size.width * ((40 - 35) / 45), color: NuvyraColors.mutedCoral)
                        bandSegment(width: proxy.size.width * ((45 - 40) / 45), color: NuvyraColors.mutedCoral.opacity(0.92))
                    }
                    .frame(height: 10)
                    .clipShape(Capsule())

                    // Indicator
                    Circle()
                        .fill(.white)
                        .overlay(Circle().stroke(categoryColor(summary.category), lineWidth: 3))
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        .offset(x: max(min(proxy.size.width * (animatedBMI / 45), proxy.size.width - 16), 0) - 8, y: -3)
                }
            }
            .frame(height: 16)

            HStack {
                Text("16")
                Spacer()
                Text("18.5")
                Spacer()
                Text("25")
                Spacer()
                Text("30")
                Spacer()
                Text("35")
                Spacer()
                Text("40+")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            Text(summary.category.caption)
                .font(NuvyraTypography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func bandSegment(width: CGFloat, color: Color) -> some View {
        Rectangle()
            .fill(color.opacity(0.85))
            .frame(width: width, height: 10)
    }

    // MARK: - Metabolic numbers
    private var metabolicRow: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            metricCell(
                title: "BMR",
                value: "\(summary.bmr)",
                unit: "kcal",
                caption: "Dinlenme",
                tint: NuvyraColors.accent,
                systemImage: "heart.fill"
            )
            metricCell(
                title: "TDEE",
                value: "\(summary.tdee)",
                unit: "kcal",
                caption: "Aktivite ile",
                tint: NuvyraColors.mutedCoral,
                systemImage: "flame.fill"
            )
        }
    }

    private func metricCell(title: String, value: String, unit: String, caption: String, tint: Color, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2.weight(.heavy))
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(NuvyraSpacing.md)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
    }

    // MARK: - Helpers
    private func categoryColor(_ category: BMICategory) -> Color {
        switch category {
        case .underweight: NuvyraColors.softMint
        case .normal: NuvyraColors.accent
        case .overweight: NuvyraColors.softSand
        case .obese1: NuvyraColors.mutedCoral.opacity(0.78)
        case .obese2, .obese3: NuvyraColors.mutedCoral
        }
    }

    private func animate() {
        guard !reduceMotion else { animatedBMI = summary.bmi; return }
        withAnimation(.spring(response: 0.8, dampingFraction: 0.78)) { animatedBMI = summary.bmi }
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        VStack(spacing: NuvyraSpacing.md) {
            BodyMetricsCard(summary: BodyMetricsSummary(bmi: 23.4, category: .normal, bmr: 1620, tdee: 2230, weightKg: 75, heightCm: 178))
            BodyMetricsCard(summary: BodyMetricsSummary(bmi: 28.2, category: .overweight, bmr: 1820, tdee: 2510, weightKg: 88, heightCm: 176))
        }
        .padding()
    }
}
#endif
