import SwiftUI

struct ShareableAchievement: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case steps
        case waterStreak
        case mealStreak
        case waterGoal

        var systemImage: String {
            switch self {
            case .steps: "figure.walk.circle.fill"
            case .waterStreak: "drop.circle.fill"
            case .mealStreak: "fork.knife.circle.fill"
            case .waterGoal: "sparkles"
            }
        }

        var tint: Color {
            switch self {
            case .steps: NuvyraColors.softMint
            case .waterStreak: NuvyraColors.accent
            case .mealStreak: NuvyraColors.softSand
            case .waterGoal: NuvyraColors.paleLime
            }
        }
    }

    var id: String { kind.rawValue }
    let kind: Kind
    let title: String
    let subtitle: String
    let metric: String
    let shareText: String
}

struct AchievementShareCard: View {
    @Environment(\.colorScheme) private var scheme
    var achievement: ShareableAchievement

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack(alignment: .top, spacing: NuvyraSpacing.md) {
                    icon
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Paylaşılabilir başarı")
                            .font(NuvyraTypography.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(achievement.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(NuvyraColors.primaryText(scheme))
                        Text(achievement.subtitle)
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Text(achievement.metric)
                        .font(.system(.title2, design: .rounded).weight(.black))
                        .foregroundStyle(achievement.kind.tint)
                        .contentTransition(.numericText())
                }

                ShareLink(item: achievement.shareText) {
                    HStack(spacing: NuvyraSpacing.sm) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Başarı kartını paylaş")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(
                            colors: [NuvyraColors.accent, achievement.kind.tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                }
                .accessibilityLabel("Başarı kartını paylaş")
            }
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(achievement.kind.tint.opacity(scheme == .dark ? 0.22 : 0.14))
                .frame(width: 110, height: 110)
                .blur(radius: 18)
                .offset(x: 42, y: -54)
                .allowsHitTesting(false)
        }
    }

    private var icon: some View {
        Image(systemName: achievement.kind.systemImage)
            .font(.title2.weight(.bold))
            .foregroundStyle(achievement.kind.tint)
            .frame(width: 52, height: 52)
            .background(achievement.kind.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Achievement share") {
    ZStack {
        NuvyraBackground()
        AchievementShareCard(
            achievement: ShareableAchievement(
                kind: .steps,
                title: "Bugünkü yürüyüş ritmi tamam",
                subtitle: "Hedefini sakin ve sürdürülebilir şekilde tamamladın.",
                metric: "8.240",
                shareText: "Bugün Nuvyra ile 8.240 adım hedefimi tamamladım."
            )
        )
        .padding()
    }
}
#endif
