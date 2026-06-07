import SwiftUI

/// Bottom sheet that expands the weekly-goal badge rail into a full
/// browseable grid. Every badge shows up — earned ones tinted, locked
/// ones greyed with their unlock condition spelled out. A summary
/// counter at the top frames progress without scoring the user.
struct BadgeDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    var summary: WeeklyGoalSummary
    /// Badge id that should pop forward on present — corresponds to the
    /// chip the user tapped. Used to scroll/anchor + add a subtle
    /// emphasis ring. Optional.
    var focusedBadgeID: String?

    private var earnedCount: Int { summary.badges.filter(\.isEarned).count }
    private var lockedCount: Int { summary.badges.count - earnedCount }

    private let columns = [
        GridItem(.flexible(), spacing: NuvyraSpacing.md),
        GridItem(.flexible(), spacing: NuvyraSpacing.md)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                NuvyraBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                        summaryHeader
                        grid
                        footerHint
                    }
                    .padding(NuvyraSpacing.lg)
                }
            }
            .navigationTitle("Rozetlerin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }

    // MARK: - Header

    private var summaryHeader: some View {
        NuvyraGlassCard(.prominent) {
            HStack(spacing: NuvyraSpacing.md) {
                ZStack {
                    Circle()
                        .stroke(NuvyraColors.accent.opacity(scheme == .dark ? 0.20 : 0.14), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: Double(earnedCount) / Double(max(summary.badges.count, 1)))
                        .stroke(NuvyraColors.accentGradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(earnedCount)")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                        Text("/\(summary.badges.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 70, height: 70)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Yolculuğunun izi")
                        .font(NuvyraTypography.section)
                    Text("\(earnedCount) kazanıldı · \(lockedCount) hedefte")
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Grid

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: NuvyraSpacing.md) {
            ForEach(summary.badges) { badge in
                tile(for: badge)
            }
        }
    }

    private func tile(for badge: NuvyraBadge) -> some View {
        let tint = badge.isEarned ? NuvyraColors.accent : NuvyraColors.mutedGray
        let isFocused = focusedBadgeID == badge.id
        return VStack(spacing: NuvyraSpacing.sm) {
            ZStack {
                Circle()
                    .fill(badge.isEarned ? tint.opacity(scheme == .dark ? 0.22 : 0.16) : NuvyraColors.mutedGray.opacity(0.10))
                Circle()
                    .stroke(isFocused ? NuvyraColors.accent : .clear, lineWidth: 2)
                Image(systemName: badge.systemImage)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(badge.isEarned ? tint : NuvyraColors.mutedGray.opacity(0.55))
                if !badge.isEarned {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(4)
                        .background(.ultraThinMaterial, in: Circle())
                        .offset(x: 22, y: 22)
                }
            }
            .frame(width: 72, height: 72)
            .nuvyraGoalGlow(isActive: badge.isEarned && isFocused)

            VStack(spacing: 4) {
                Text(badge.title)
                    .font(.subheadline.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(badge.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(NuvyraSpacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                .fill(badge.isEarned ? tint.opacity(scheme == .dark ? 0.10 : 0.07) : NuvyraColors.mutedGray.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                .stroke(NuvyraColors.glassStroke(scheme), lineWidth: 0.6)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(badge.title), \(badge.isEarned ? "kazanıldı" : "kilitli"). \(badge.detail)")
    }

    // MARK: - Footer

    private var footerHint: some View {
        Text("Rozetler kayıtlarından türetilir — başka bir cihaza geçince geçmişinden geri kazanılır.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

#if DEBUG
#Preview {
    BadgeDetailSheet(summary: .previewSample, focusedBadgeID: "badge.streak.7")
}
#endif
