import SwiftUI

/// 2-column compact view of the latest weekly goal snapshot the iPhone
/// pushed via `updateApplicationContext`. Each tile is a tiny progress
/// ring + a `daysHit/totalDays` label so the user can glance at the
/// week's shape from a watch face hand-off.
struct WatchWeeklyGoalGrid: View {
    let snapshot: WatchWeeklyGoalSnapshot

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Hafta", systemImage: "target")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(snapshot.achievedCount)/\(snapshot.totalGoals)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(snapshot.metrics) { metric in
                    tile(for: metric)
                }
            }

            if let topBadge = snapshot.badges.first(where: \.isEarned) {
                Label(topBadge.title, systemImage: "checkmark.seal.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.cyan)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func tile(for metric: WatchWeeklyGoalSnapshot.Metric) -> some View {
        let tint: Color = metric.isAchieved ? .cyan : .orange
        return HStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.22), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: metric.fraction)
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: metric.systemImage)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(metric.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("\(metric.daysHit)/\(metric.totalDays)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(metric.title): \(metric.daysHit) gün hedefte")
    }
}

#if DEBUG
#Preview {
    WatchWeeklyGoalGrid(snapshot: WatchWeeklyGoalSnapshot(applicationContext: [
        "type": "goals.snapshot",
        "overallFraction": 0.7,
        "achievedCount": 2,
        "totalGoals": 4,
        "metrics": [
            ["key": "steps", "daysHit": 6, "totalDays": 7],
            ["key": "water", "daysHit": 5, "totalDays": 7],
            ["key": "calories", "daysHit": 4, "totalDays": 7],
            ["key": "protein", "daysHit": 3, "totalDays": 7]
        ],
        "badges": [
            ["id": "badge.streak.7", "title": "7 gün ritim", "isEarned": true]
        ]
    ])!)
}
#endif
