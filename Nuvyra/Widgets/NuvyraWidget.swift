import SwiftUI
import WidgetKit

@main
struct NuvyraWidgetBundle: WidgetBundle {
    var body: some Widget {
        NuvyraRhythmWidget()
        NuvyraWaterWidget()
        NuvyraStepsWidget()
        WalkingLiveActivityWidget()
        NuvyraWalkingLiveActivityWidget()
    }
}

struct NuvyraRhythmWidget: Widget {
    // Keep legacy kind so previously-pinned widgets upgrade silently to the new design.
    let kind = "NuvyraWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NuvyraWidgetProvider()) { entry in
            NuvyraRhythmWidgetView(entry: entry)
        }
        .configurationDisplayName("Nuvyra Ritmi")
        .description("Kalori, adım, su ve makro hedeflerini tek bakışta gör.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
        .contentMarginsDisabled()
    }
}

struct NuvyraWaterWidget: Widget {
    let kind = "NuvyraWaterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NuvyraWidgetProvider()) { entry in
            NuvyraWaterWidgetView(entry: entry)
        }
        .configurationDisplayName("Nuvyra Su")
        .description("Günlük hidrasyon ritmini ve hedefe kalan miktarı göster.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular
        ])
        .contentMarginsDisabled()
    }
}

struct NuvyraStepsWidget: Widget {
    let kind = "NuvyraStepsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NuvyraWidgetProvider()) { entry in
            NuvyraStepsWidgetView(entry: entry)
        }
        .configurationDisplayName("Nuvyra Adım")
        .description("Adım hedefini ve kat ettiğin mesafeyi takip et.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular
        ])
        .contentMarginsDisabled()
    }
}
