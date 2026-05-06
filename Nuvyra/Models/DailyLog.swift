import Foundation
import SwiftData

@Model
final class DailyLog: Identifiable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var totalCalories: Int
    var caloriesBurned: Int
    var steps: Int
    var waterMl: Int
    var streakCompleted: Bool
    var mood: Mood?
    var note: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        totalCalories: Int = 0,
        caloriesBurned: Int = 0,
        steps: Int = 0,
        waterMl: Int = 0,
        streakCompleted: Bool = false,
        mood: Mood? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.totalCalories = totalCalories
        self.caloriesBurned = caloriesBurned
        self.steps = steps
        self.waterMl = waterMl
        self.streakCompleted = streakCompleted
        self.mood = mood
        self.note = note
    }
}
