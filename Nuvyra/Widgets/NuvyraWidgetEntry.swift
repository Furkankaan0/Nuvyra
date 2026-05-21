import Foundation
import WidgetKit

struct NuvyraWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot

    static let placeholder = NuvyraWidgetEntry(date: Date(), snapshot: .placeholder)
}
