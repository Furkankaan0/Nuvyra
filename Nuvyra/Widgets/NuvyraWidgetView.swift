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

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nuvyra")
                .font(.headline.weight(.bold))
            Spacer()
            NuvyraProgressRing(progress: Double(entry.steps) / 7_500, lineWidth: 8, center: entry.steps.formatted(), caption: "adım")
            Text("\(entry.calorieBalance) kcal kaldı")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding()
        .containerBackground(NuvyraColors.calmGradient(scheme), for: .widget)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            NuvyraProgressRing(progress: Double(entry.steps) / 7_500, lineWidth: 10, center: entry.steps.formatted(), caption: "adım")
                .frame(width: 112, height: 112)
            VStack(alignment: .leading, spacing: 8) {
                Text("Bugünkü ritmin")
                    .font(.headline.weight(.bold))
                Text("Kalori: \(entry.calorieBalance) kcal kaldı")
                Text("Su: \(entry.waterMl) ml")
                Text(entry.insight)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .font(.caption.weight(.semibold))
        }
        .padding()
        .containerBackground(NuvyraColors.calmGradient(scheme), for: .widget)
    }
}
