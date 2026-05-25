import Foundation
import SwiftData
import SwiftUI

/// User-facing workout categories. Each carries its own icon/tint plus a rough
/// MET (metabolic equivalent) value used to estimate calories when the user
/// doesn't supply one manually. MET sources: 2011 Compendium of Physical Activities.
enum WorkoutType: String, CaseIterable, Codable, Identifiable {
    case running
    case cycling
    case swimming
    case walking
    case hiit
    case gym
    case yoga
    case pilates
    case sports
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .running: "Koşu"
        case .cycling: "Bisiklet"
        case .swimming: "Yüzme"
        case .walking: "Yürüyüş"
        case .hiit: "HIIT"
        case .gym: "Spor salonu"
        case .yoga: "Yoga"
        case .pilates: "Pilates"
        case .sports: "Takım sporu"
        case .other: "Diğer"
        }
    }

    var systemImage: String {
        switch self {
        case .running: "figure.run"
        case .cycling: "figure.outdoor.cycle"
        case .swimming: "figure.pool.swim"
        case .walking: "figure.walk"
        case .hiit: "bolt.fill"
        case .gym: "dumbbell.fill"
        case .yoga: "figure.yoga"
        case .pilates: "figure.pilates"
        case .sports: "soccerball"
        case .other: "figure.mixed.cardio"
        }
    }

    var tint: Color {
        switch self {
        case .running: NuvyraColors.mutedCoral
        case .cycling: NuvyraColors.accent
        case .swimming: Color(red: 0.20, green: 0.56, blue: 0.95)
        case .walking: NuvyraColors.softMint
        case .hiit: NuvyraColors.mutedCoral
        case .gym: NuvyraColors.softSand
        case .yoga: NuvyraColors.paleLime
        case .pilates: NuvyraColors.softMint
        case .sports: NuvyraColors.accent
        case .other: NuvyraColors.mutedGray
        }
    }

    /// Typical MET — used for the calorie estimator when manual calories are 0.
    /// kcal/min ≈ MET × 3.5 × weightKg / 200
    var typicalMET: Double {
        switch self {
        case .running: 9.8
        case .cycling: 7.5
        case .swimming: 8.0
        case .walking: 3.8
        case .hiit: 8.5
        case .gym: 5.5
        case .yoga: 2.5
        case .pilates: 3.0
        case .sports: 7.0
        case .other: 5.0
        }
    }

    var supportsDistance: Bool {
        switch self {
        case .running, .cycling, .swimming, .walking: true
        default: false
        }
    }

    /// Estimate calories for `durationMinutes` at `weightKg`.
    func estimateCalories(durationMinutes: Int, weightKg: Double) -> Int {
        let kcalPerMin = typicalMET * 3.5 * weightKg / 200
        return Int((kcalPerMin * Double(durationMinutes)).rounded())
    }
}

enum WorkoutSource: String, Codable {
    case manual
    case healthKit
}

/// SwiftData record for manually-logged workouts. HealthKit `HKWorkout` rows
/// are surfaced live via `HealthService.todayWorkouts()` and merged in the
/// repository so the user sees one unified feed.
@Model
final class WorkoutLog: Identifiable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var typeRaw: String
    var durationMinutes: Int
    var caloriesBurned: Int
    var distanceKm: Double?
    var note: String?
    var sourceRaw: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        type: WorkoutType = .other,
        durationMinutes: Int,
        caloriesBurned: Int,
        distanceKm: Double? = nil,
        note: String? = nil,
        source: WorkoutSource = .manual,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.typeRaw = type.rawValue
        self.durationMinutes = durationMinutes
        self.caloriesBurned = caloriesBurned
        self.distanceKm = distanceKm
        self.note = note
        self.sourceRaw = source.rawValue
        self.createdAt = createdAt
    }

    var type: WorkoutType {
        get { WorkoutType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var source: WorkoutSource {
        get { WorkoutSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
}

/// In-memory representation of a workout (manual or HealthKit). View-models
/// consume this so they don't need to know about the underlying source.
struct WorkoutEntry: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let type: WorkoutType
    let durationMinutes: Int
    let caloriesBurned: Int
    let distanceKm: Double?
    let note: String?
    let source: WorkoutSource

    init(log: WorkoutLog) {
        self.id = log.id
        self.date = log.date
        self.type = log.type
        self.durationMinutes = log.durationMinutes
        self.caloriesBurned = log.caloriesBurned
        self.distanceKm = log.distanceKm
        self.note = log.note
        self.source = log.source
    }

    init(
        id: UUID = UUID(),
        date: Date,
        type: WorkoutType,
        durationMinutes: Int,
        caloriesBurned: Int,
        distanceKm: Double? = nil,
        note: String? = nil,
        source: WorkoutSource
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.durationMinutes = durationMinutes
        self.caloriesBurned = caloriesBurned
        self.distanceKm = distanceKm
        self.note = note
        self.source = source
    }
}
