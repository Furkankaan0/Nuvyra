import Foundation
import WidgetKit

struct NuvyraWidgetEntry: TimelineEntry {
    let date: Date
    let steps: Int
    let calorieBalance: Int
    let waterMl: Int
    let insight: String

    static let preview = NuvyraWidgetEntry(
        date: Date(),
        steps: 5_360,
        calorieBalance: 620,
        waterMl: 1_250,
        insight: "Kısa bir yürüyüş ritmini tamamlamana yardımcı olabilir."
    )
}
