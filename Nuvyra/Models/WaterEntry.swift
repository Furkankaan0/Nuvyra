import Foundation
import SwiftData

@Model
final class WaterEntry: Identifiable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var amountMl: Int

    init(id: UUID = UUID(), date: Date = Date(), amountMl: Int) {
        self.id = id
        self.date = date
        self.amountMl = amountMl
    }
}
