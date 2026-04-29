import Foundation
import SwiftData

@Model
final class WalkingLog: Identifiable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var steps: Int
    var activeEnergy: Double
    var distanceKm: Double?
    var goalCompleted: Bool

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        steps: Int,
        activeEnergy: Double = 0,
        distanceKm: Double? = nil,
        goalCompleted: Bool = false
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.steps = steps
        self.activeEnergy = activeEnergy
        self.distanceKm = distanceKm
        self.goalCompleted = goalCompleted
    }
}
