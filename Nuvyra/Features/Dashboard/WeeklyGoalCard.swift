import SwiftUI

/// Dashboard card summarising weekly goal completion + earned badges.
/// A header ring shows the overall fraction; a 2×2 grid shows each
/// metric's "days hit this week"; a badge rail shows earned (and the
/// next locked) milestones. Renders nothing until there's at least
/// some progress to show.
/// Equatable so SwiftUI can short-circuit re-renders when the snapshot
/// hasn't moved. Dashboard refreshes happen on every foreground —
/// without this, the diffing engine walks the body each time even if
/// every value is identical, costing layout work for nothing.
struct WeeklyGoalCard: View, Equatable {
    static func == (lhs: WeeklyGoalCard, rhs: WeeklyGoalCard) -> Bool {
        lhs.summary == rhs.summary
    }

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedOverall: Double = 0

    var summary: WeeklyGoalSummary
    /// Fires when the user taps a badge chip. Lets the host present the
    /// detail sheet pre-focused on the tapped badge. No-op default keeps
    /// existing call sites valid.
    var onSelectBadge: (NuvyraBadge) -> Void = { _ in }

    private var hasContent: Bool {
        summary.progress.contains { $0.daysHit > 0 } || summary.badges.contains(where: \.isEarned)
    }

    var body: some View {
        if hasContent {
            NuvyraGlassCard(.prominent) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                    header
                    metricsGrid
                    if summary.badges.contains(where: \.isEarned) {
                        badgeRail
                    }
                }
            }
            .onAppear { animate() }
            .onChange(of: summary.overallFraction) { _, _ in animate() }
            .accessibilityElement(children: .contain)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: NuvyraSpacing.md) {
            ZStack {
                Circle()
                    .stroke(NuvyraColors.accent.opacity(scheme == .dark ? 0.20 : 0.14), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: animatedOverall)
                    .stroke(NuvyraColors.accentGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int((summary.overallFraction * 100).rounded()))%")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 2) {
                Text("dashboard.goals.title")
                    .font(NuvyraTypography.section)
                Text("\(summary.achievedCount)/4 hedef bu hafta tamam")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Metrics grid

    /// The metric count is fixed at four (`steps`, `water`, `calories`,
    /// `protein`), so a `LazyVGrid` is overkill — it forces an extra
    /// measure-then-place layout pass each render. Hand-rolling the 2×2
    /// as VStack-of-HStacks skips that and shaves milliseconds on every
    /// dashboard refresh.
    @ViewBuilder
    private var metricsGrid: some View {
        let items = summary.progress
        VStack(spacing: NuvyraSpacing.sm) {
            HStack(spacing: NuvyraSpacing.sm) {
                if items.indices.contains(0) { metricTile(items[0]) } else { Color.clear }
                if items.indices.contains(1) { metricTile(items[1]) } else { Color.clear }
            }
            HStack(spacing: NuvyraSpacing.sm) {
                if items.indices.contains(2) { metricTile(items[2]) } else { Color.clear }
                if items.indices.contains(3) { metricTile(items[3]) } else { Color.clear }
            }
        }
    }

    private func metricTile(_ item: WeeklyGoalProgress) -> some View {
        let tint = item.isAchieved ? NuvyraColors.accent : NuvyraColors.softSand
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: item.metric.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                Text(item.metric.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if item.isAchieved {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(NuvyraColors.accent)
                }
            }
            Text("\(item.daysHit)/\(item.totalDays) gün")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
            // 7-dot week strip.
            HStack(spacing: 4) {
                ForEach(0..<item.totalDays, id: \.self) { index in
                    Circle()
                        .fill(index < item.daysHit ? tint : NuvyraColors.mutedGray.opacity(0.2))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(NuvyraSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(scheme == .dark ? 0.10 : 0.07), in: RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.metric.title): bu hafta \(item.daysHit) gün hedefte\(item.isAchieved ? ", tamamlandı" : "")")
    }

    // MARK: - Badges

    private var badgeRail: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
            Text("dashboard.goals.badges")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NuvyraSpacing.sm) {
                    ForEach(summary.badges) { badge in
                        badgeChip(badge)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private func badgeChip(_ badge: NuvyraBadge) -> some View {
        let tint = badge.isEarned ? NuvyraColors.accent : NuvyraColors.mutedGray
        return Button { onSelectBadge(badge) } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(badge.isEarned ? tint.opacity(scheme == .dark ? 0.22 : 0.16) : NuvyraColors.mutedGray.opacity(0.12))
                    Image(systemName: badge.systemImage)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(badge.isEarned ? tint : NuvyraColors.mutedGray.opacity(0.6))
                    if !badge.isEarned {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .offset(x: 14, y: 14)
                    }
                }
                .frame(width: 44, height: 44)
                Text(badge.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(badge.isEarned ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(width: 76)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(badge.title), \(badge.isEarned ? "kazanıldı" : "kilitli"). \(badge.detail)")
        .accessibilityHint("Tüm rozetleri görmek için dokun.")
    }

    // MARK: - Animation

    private func animate() {
        guard !reduceMotion else { animatedOverall = summary.overallFraction; return }
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            animatedOverall = summary.overallFraction
        }
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground(.animated)
        ScrollView {
            VStack(spacing: NuvyraSpacing.md) {
                WeeklyGoalCard(summary: .previewSample)
                WeeklyGoalCard(summary: .empty)
            }
            .padding()
        }
    }
}
#endif
