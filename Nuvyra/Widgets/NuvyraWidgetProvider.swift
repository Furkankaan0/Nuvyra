import WidgetKit

struct NuvyraWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> NuvyraWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (NuvyraWidgetEntry) -> Void) {
        let snapshot = context.isPreview ? WidgetSnapshot.placeholder : WidgetSnapshotStore.read()
        completion(NuvyraWidgetEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NuvyraWidgetEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore.read()
        let now = Date()

        // Generate a short rolling timeline so the widget can render time-sensitive
        // copy even between background app refreshes. Each entry shares the same
        // numeric data; only the entry `date` changes so the system rotates them.
        var entries: [NuvyraWidgetEntry] = []
        for offsetMinutes in stride(from: 0, through: 60, by: 30) {
            let date = Calendar.current.date(byAdding: .minute, value: offsetMinutes, to: now) ?? now
            entries.append(NuvyraWidgetEntry(date: date, snapshot: snapshot))
        }

        // Reload aggressively if data is stale (>2h old) — likely the app has been
        // in the background and we want a fresher snapshot soon.
        let staleness = now.timeIntervalSince(snapshot.generatedAt)
        let nextRefresh: Date
        if staleness > 60 * 60 * 2 {
            nextRefresh = now.addingTimeInterval(60 * 15)
        } else {
            nextRefresh = now.addingTimeInterval(60 * 30)
        }

        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
    }
}
