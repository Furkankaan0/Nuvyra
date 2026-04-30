import WidgetKit

struct NuvyraWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> NuvyraWidgetEntry {
        .preview
    }

    func getSnapshot(in context: Context, completion: @escaping (NuvyraWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.preview)
            return
        }
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NuvyraWidgetEntry>) -> Void) {
        let entry = loadEntry()
        // 30-minute fallback refresh. The main app additionally calls
        // `WidgetCenter.shared.reloadAllTimelines()` whenever the user
        // logs a meal, water, or steps update — so this only kicks in
        // when the app hasn't been opened.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            ?? Date().addingTimeInterval(1_800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    // MARK: - Helpers

    /// Reads the latest snapshot from the App Group. Falls back to the
    /// preview entry only when there is genuinely no data — that should
    /// only happen on first install before the user opens the app once.
    private func loadEntry() -> NuvyraWidgetEntry {
        guard let snapshot = WidgetSnapshotStore.read() else {
            return .preview
        }
        // If the snapshot is from a previous day we keep showing it but
        // mark it as a placeholder so the view can dim/age it. We don't
        // synthesise a fresh "0 steps" entry — that would lie about the
        // user's actual day.
        let isStale = snapshot.dayKey != NuvyraWidgetSnapshot.dayKey(for: Date())
        return NuvyraWidgetEntry(snapshot: snapshot, isPlaceholder: isStale)
    }
}
