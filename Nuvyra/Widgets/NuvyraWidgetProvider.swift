import Foundation
import WidgetKit

struct NuvyraWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> NuvyraWidgetEntry {
        .preview
    }

    func getSnapshot(in context: Context, completion: @escaping (NuvyraWidgetEntry) -> Void) {
        let snapshot = context.isPreview ? .preview : NuvyraWidgetSnapshotStore.current()
        completion(NuvyraWidgetEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NuvyraWidgetEntry>) -> Void) {
        let now = Date()
        let snapshot = NuvyraWidgetSnapshotStore.current()
        let entry = NuvyraWidgetEntry(date: now, snapshot: snapshot)
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}
