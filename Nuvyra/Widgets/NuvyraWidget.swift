import SwiftUI
import WidgetKit

@main
struct NuvyraWidgetBundle: WidgetBundle {
    var body: some Widget {
        NuvyraWidget()
        WalkingLiveActivityWidget()
    }
}

struct NuvyraWidget: Widget {
    let kind = "NuvyraWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NuvyraWidgetProvider()) { entry in
            NuvyraWidgetView(entry: entry)
        }
        .configurationDisplayName("Nuvyra Ritmi")
        .description("Kalori, adım ve su ritmini tek bakışta gör.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
