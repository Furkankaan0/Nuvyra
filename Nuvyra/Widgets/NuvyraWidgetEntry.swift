import Foundation
import WidgetKit

struct NuvyraWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: NuvyraWidgetSnapshot

    static let preview = NuvyraWidgetEntry(
        date: Date(),
        snapshot: .preview
    )
}
