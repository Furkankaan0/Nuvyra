import SwiftUI

/// Premium glass streak card. Drives motivation without dramatic copy:
/// shows current streak, last 7 days of completion dots, and the user's
/// personal best in the lookback window.
struct StreakCard: View {
    enum Kind {
        case water, meal, walking, custom(title: String, systemImage: String, tint: Color)

        var title: String {
            switch self {
            case .water: "Su streak'i"
            case .meal: "Beslenme streak'i"
            case .walking: "Yürüyüş streak'i"
            case .custom(let title, _, _): title
            }
        }

        var systemImage: String {
            switch self {
            case .water: "drop.fill"
            case .meal: "fork.knife"
            case .walking: "figure.walk"
            case .custom(_, let image, _): image
            }
        }

        var tint: Color {
            switch self {
            case .water: Color(red: 0.20, green: 0.56, blue: 0.95)
            case .meal: NuvyraColors.accent
            case .walking: NuvyraColors.softMint
            case .custom(_, _, let tint): tint
            }
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedStreak: Double = 0

    var kind: Kind
    var insight: StreakInsight

    private var motivationCopy: String {
        if insight.currentStreak == 0 {
            return insight.todayCompleted
                ? "Bugün tamamladın — yarın da küçük bir adımla devam edebilirsin."
                : "Bugünkü kaydını tamamlayarak yeni bir streak başlatabilirsin."
        }
        if insight.currentStreak >= insight.longestStreak {
            return "Bu, kendi rekoruna ulaştığın streak. Acele etme — sürdürülebilir olan kazanır."
        }
        return "Kişisel rekorun \(insight.longestStreak) gün. Küçük tutarlılık her şeyi değiştirir."
    }

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                header
                streakValue
                weeklyDots
                Text(motivationCopy)
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { animate() }
        .onChange(of: insight.currentStreak) { _, _ in animate() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kind.title): \(insight.currentStreak) gün; en uzun \(insight.longestStreak) gün")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .font(NuvyraTypography.section)
                if insight.longestStreak > 0 {
                    Text("Kişisel rekor: \(insight.longestStreak) gün")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: insight.currentStreak > 0 ? "flame.fill" : "flame")
                .font(.title3.weight(.bold))
                .foregroundStyle(insight.currentStreak > 0 ? kind.tint : .secondary)
        }
    }

    private var streakValue: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(Int(animatedStreak))")
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .foregroundStyle(kind.tint)
                .contentTransition(.numericText())
            Text("gün")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
            Spacer()
            Label(insight.todayCompleted ? "Bugün tamam" : "Bugün eksik",
                  systemImage: insight.todayCompleted ? "checkmark.seal.fill" : "clock")
                .font(.caption.weight(.bold))
                .foregroundStyle(insight.todayCompleted ? kind.tint : NuvyraColors.softSand)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background((insight.todayCompleted ? kind.tint : NuvyraColors.softSand).opacity(0.14), in: Capsule())
        }
    }

    private var weeklyDots: some View {
        HStack(spacing: 6) {
            ForEach(Array(insight.lastSevenDays.enumerated()), id: \.offset) { index, done in
                Circle()
                    .fill(done ? kind.tint : Color.secondary.opacity(0.18))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle().stroke(kind.tint.opacity(done ? 0 : 0.35), lineWidth: 1)
                    )
                    .accessibilityLabel(done ? "Gün \(index + 1) tamam" : "Gün \(index + 1) eksik")
            }
            Spacer()
            Text("Son 7 gün")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func animate() {
        let target = Double(insight.currentStreak)
        guard !reduceMotion else { animatedStreak = target; return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.78)) { animatedStreak = target }
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        VStack(spacing: NuvyraSpacing.md) {
            StreakCard(kind: .water, insight: StreakInsight(currentStreak: 5, longestStreak: 12, todayCompleted: true, lastSevenDays: [true, true, false, true, true, true, true]))
            StreakCard(kind: .meal, insight: StreakInsight(currentStreak: 0, longestStreak: 8, todayCompleted: false, lastSevenDays: [false, true, true, true, false, false, false]))
        }
        .padding()
    }
}
#endif
