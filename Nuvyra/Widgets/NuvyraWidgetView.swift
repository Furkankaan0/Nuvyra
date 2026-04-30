import SwiftUI
import WidgetKit

struct NuvyraWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    var entry: NuvyraWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            small
        default:
            medium
        }
    }

    private var clampedRingProgress: Double {
        min(max(entry.ringProgress, 0), 1)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Nuvyra")
                    .font(.headline.weight(.bold))
                if entry.isPlaceholder {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            NuvyraProgressRing(
                progress: clampedRingProgress,
                lineWidth: 8,
                center: entry.steps.formatted(),
                caption: "/ \(entry.stepGoal.formatted()) adım"
            )
            Text("\(entry.calorieBalance) kcal kaldı")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding()
        .containerBackground(NuvyraColors.calmGradient(scheme), for: .widget)
        .opacity(entry.isPlaceholder ? 0.7 : 1)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            NuvyraProgressRing(
                progress: clampedRingProgress,
                lineWidth: 10,
                center: entry.steps.formatted(),
                caption: "/ \(entry.stepGoal.formatted())"
            )
            .frame(width: 112, height: 112)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("Bugünkü ritmin")
                        .font(.headline.weight(.bold))
                    if entry.isPlaceholder {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Kalori: \(entry.calorieBalance) / \(entry.calorieTarget) kcal kaldı")
                Text("Su: \(entry.waterMl) / \(entry.waterTargetMl) ml")
                Text(entry.insight)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .font(.caption.weight(.semibold))
        }
        .padding()
        .containerBackground(NuvyraColors.calmGradient(scheme), for: .widget)
        .opacity(entry.isPlaceholder ? 0.7 : 1)
    }
}
