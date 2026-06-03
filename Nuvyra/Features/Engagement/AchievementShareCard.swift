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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var achievement: ShareableAchievement

    /// Drives the confetti burst. Initialised to a sentinel so the first
    /// `.onAppear` flip into the real achievement id triggers one burst.
    /// Subsequent achievement changes also re-fire the celebration.
    @State private var celebrationID: String = "_pending"

    var body: some View {
        NuvyraGlassCard(.prominent) {
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
        // Top-right brand halo — same blur the original card had, kept so
        // dark mode still reads the achievement tint through the glass.
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(achievement.kind.tint.opacity(scheme == .dark ? 0.22 : 0.14))
                .frame(width: 110, height: 110)
                .blur(radius: 18)
                .offset(x: 42, y: -54)
                .allowsHitTesting(false)
        }
        // Calm confetti — fires once on appear, again whenever the
        // achievement id flips (e.g. user crosses two milestones in
        // one day).
        .overlay(
            // Symbol-particle mode picks SF Symbols matched to the kind
            // of achievement (steps → walking, water → drop, etc.) — much
            // richer than the dot field, while still calm enough for the
            // wellness tone.
            NuvyraConfettiBurst(
                trigger: AnyHashable(celebrationID),
                palette: [achievement.kind.tint, NuvyraColors.softMint, NuvyraColors.paleLime, NuvyraColors.softSand],
                style: .symbols(symbolsForAchievement)
            )
        )
        .onAppear {
            // Defer the trigger by one runloop tick so SwiftUI has the
            // card laid out before the Canvas reads its size — otherwise
            // particles can paint outside the eventual frame.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 220_000_000)
                celebrationID = achievement.id
            }
        }
        .onChange(of: achievement.id) { _, newID in
            celebrationID = newID
        }
    }

    /// Per-kind symbol palette. We mix the achievement's own glyph with
    /// a sparkles + heart so the field reads "you earned it" instead of
    /// "the same emoji 22 times".
    private var symbolsForAchievement: [String] {
        switch achievement.kind {
        case .steps: ["figure.walk.circle.fill", "sparkles", "leaf.fill", "star.fill"]
        case .waterStreak, .waterGoal: ["drop.fill", "sparkles", "star.fill", "heart.fill"]
        case .mealStreak: ["fork.knife", "sparkles", "leaf.fill", "heart.fill"]
        }
    }

    private var icon: some View {
        Image(systemName: achievement.kind.systemImage)
            .font(.title2.weight(.bold))
            .foregroundStyle(achievement.kind.tint)
            .frame(width: 52, height: 52)
            .background(achievement.kind.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            // iOS 17+ symbol bounce — fires once on every achievement
            // change. Visually pairs with the confetti burst above.
            .symbolEffect(.bounce, value: achievement.id)
            // Soft halo pulse around the icon while the card is visible
            // so the user keeps catching the celebration at scroll-by.
            .nuvyraGoalGlow(isActive: true, tint: achievement.kind.tint)
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
