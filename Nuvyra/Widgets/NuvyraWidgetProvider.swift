import WidgetKit

struct NuvyraWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> NuvyraWidgetEntry {
        .preview
    }

    func getSnapshot(in context: Context, completion: @escaping (NuvyraWidgetEntry) -> Void) {
        completion(.preview)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NuvyraWidgetEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1_800)
        completion(Timeline(entries: [.preview], policy: .after(next)))
    }
}
