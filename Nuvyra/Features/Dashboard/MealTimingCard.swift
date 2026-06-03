import SwiftUI

/// Dashboard card summarising today's meal rhythm: a calm headline produced
/// by `MealTimingEngine`, an optional detail line, and a four-slot timeline
/// (breakfast → lunch → snack → dinner) with completed slots tinted in accent.
struct MealTimingCard: View {
    @Environment(\.colorScheme) private var scheme

    var insight: MealTimingInsight
    /// CTA — Dashboard wires this to "open AddMeal sheet for the suggested slot".
    var onLogMeal: ((MealType) -> Void)?

    private var heroTint: Color {
        switch insight.severity {
        case .calm: NuvyraColors.accent
        case .nudge: NuvyraColors.softSand
        }
    }

    var body: some View {
        NuvyraGlassCard(.prominent) {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                header
                Text(insight.headline)
                    .font(NuvyraTypography.body.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = insight.detail {
                    Text(detail)
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                slotTimeline
                if let cta = suggestedCTA {
                    Button {
                        onLogMeal?(cta.meal)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: cta.meal.systemImage)
                            Text(cta.label)
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, NuvyraSpacing.md)
                        .padding(.vertical, 8)
                        .background(NuvyraColors.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(cta.label)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("meal.timing.title")
                    .font(NuvyraTypography.section)
                Text("meal.timing.subtitle")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "clock.badge.checkmark.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(heroTint)
                .nuvyraAmbientIcon()
        }
    }

    private var slotTimeline: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            ForEach(insight.slotStatuses) { status in
                slotChip(status: status)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func slotChip(status: MealSlotStatus) -> some View {
        let tint: Color = status.logged ? NuvyraColors.accent : NuvyraColors.mutedGray
        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(tint.opacity(status.logged ? 0.18 : 0.08))
                Image(systemName: status.logged ? "checkmark" : status.meal.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 36, height: 36)
            Text(status.meal.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(status.logged ? .primary : .secondary)
            if let loggedAt = status.loggedAt, status.logged {
                Text(loggedAt, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.6))
            }
        }
    }

    // MARK: - Suggested CTA

    private struct SuggestedCTA {
        let meal: MealType
        let label: String
    }

    /// Pick the most useful "log this" suggestion based on what's missing.
    /// Order mirrors the engine's rule priority so the CTA reinforces the
    /// headline instead of pointing somewhere unrelated.
    private var suggestedCTA: SuggestedCTA? {
        guard insight.hasAnyMeal else {
            return SuggestedCTA(meal: .breakfast, label: "Kahvaltıyı kaydet")
        }
        if let missing = firstMissingSlot() {
            return SuggestedCTA(meal: missing, label: "\(missing.title) ekle")
        }
        return nil
    }

    private func firstMissingSlot() -> MealType? {
        for kind in [MealType.breakfast, .lunch, .dinner] {
            if let status = insight.slotStatuses.first(where: { $0.meal == kind }), !status.logged {
                return kind
            }
        }
        return nil
    }

    // MARK: - Accessibility

    private var accessibilityText: String {
        let logged = insight.slotStatuses.filter(\.logged).map { $0.meal.title }
        let loggedPart = logged.isEmpty ? "henüz kayıt yok" : "tamamlanan: \(logged.joined(separator: ", "))"
        return "Öğün ritmi: \(insight.headline) \(loggedPart)."
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        ScrollView {
            VStack(spacing: NuvyraSpacing.md) {
                MealTimingCard(insight: .previewSample)
                MealTimingCard(insight: .empty)
                MealTimingCard(insight: MealTimingInsight(
                    headline: "Bugünkü öğün düzenin sakin görünüyor.",
                    detail: "Kahvaltı, öğle ve akşam dengede — devam etmek tek başına anlamlı bir tercih.",
                    severity: .calm,
                    slotStatuses: MealType.allCases.map { MealSlotStatus(meal: $0, logged: $0 != .snack, loggedAt: Date()) },
                    hasAnyMeal: true
                ))
            }
            .padding()
        }
    }
}
#endif
