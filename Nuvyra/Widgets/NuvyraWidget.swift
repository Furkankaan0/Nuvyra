import SwiftUI
import WidgetKit

@main
struct NuvyraWidgetBundle: WidgetBundle {
    var body: some Widget {
        NuvyraWidget()
        WalkingLiveActivityWidget()
        NuvyraWalkingLiveActivityWidget()
    }
}

struct NuvyraWidget: Widget {
    let kind = NuvyraWidgetSnapshotStore.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NuvyraWidgetProvider()) { entry in
            NuvyraWidgetView(entry: entry)
        }
        .configurationDisplayName("Nuvyra Ritmi")
        .description("Kalori, adım, su ve protein ritmini tek bakışta gör.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            // iOS 16+ Lock Screen accessory families. Each one renders a
            // bespoke layout in NuvyraWidgetView via @Environment(\.widgetFamily).
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
        .contentMarginsDisabled()
    }
}
