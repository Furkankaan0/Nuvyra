import SwiftUI

/// Dashboard card that surfaces multi-day behavioural patterns detected
/// by `TrendInsightEngine`. Renders nothing when the engine finds no
/// pattern worth mentioning — better silence than filler. Each insight
/// is a glass row with a tinted medallion, headline and detail.
struct TrendInsightCard: View, Equatable {
    @Environment(\.colorScheme) private var scheme
    var insights: [TrendInsight]

    static func == (lhs: TrendInsightCard, rhs: TrendInsightCard) -> Bool {
        lhs.insights == rhs.insights
    }

    var body: some View {
        if !insights.isEmpty {
            NuvyraGlassCard(.prominent) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                    header
                    ForEach(insights) { insight in
                        row(for: insight)
                    }
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("dashboard.trend.title")
                    .font(NuvyraTypography.section)
                Text("dashboard.trend.subtitle")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "wand.and.stars")
                .font(.title3.weight(.bold))
                .foregroundStyle(NuvyraColors.accent)
                .nuvyraAmbientIcon()
        }
    }

    private func row(for insight: TrendInsight) -> some View {
        let tint = tintFor(insight.tone)
        return HStack(alignment: .top, spacing: NuvyraSpacing.md) {
            ZStack {
                Circle().fill(.ultraThinMaterial)
                Circle().fill(tint.opacity(scheme == .dark ? 0.22 : 0.16))
                Circle().stroke(NuvyraColors.glassStroke(scheme), lineWidth: 0.6)
                Image(systemName: insight.systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(insight.headline)
                    .font(.subheadline.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(insight.detail)
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(NuvyraSpacing.sm)
        .background(tint.opacity(scheme == .dark ? 0.08 : 0.06), in: RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.headline). \(insight.detail)")
    }

    private func tintFor(_ tone: TrendInsight.Tone) -> Color {
        switch tone {
        case .encouraging: NuvyraColors.accent
        case .nudge: NuvyraColors.softSand
        case .neutral: NuvyraColors.mutedGray
        }
    }
}

extension TrendInsight {
    static let previewSamples: [TrendInsight] = [
        TrendInsight(
            id: "steps.streak",
            headline: "5 gündür adım hedefini tutturuyorsun",
            detail: "Bu tür sakin tutarlılık, tek seferlik büyük çıkışlardan daha kalıcıdır.",
            tone: .encouraging,
            systemImage: "figure.walk.motion"
        ),
        TrendInsight(
            id: "protein.shortfall",
            headline: "3 gündür protein hedefinin altındasın",
            detail: "Yoğurt, mercimek veya yumurta gibi küçük eklemeler ortalamanı nazikçe yukarı çeker.",
            tone: .nudge,
            systemImage: "bolt.heart"
        )
    ]
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground(.animated)
        VStack(spacing: NuvyraSpacing.md) {
            TrendInsightCard(insights: TrendInsight.previewSamples)
            TrendInsightCard(insights: [])
        }
        .padding()
    }
}
#endif
