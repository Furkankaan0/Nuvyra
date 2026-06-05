import Foundation
import SwiftData

struct BackupImportSummary {
    let profiles: Int
    let meals: Int
    let waterEntries: Int
    let walkingLogs: Int
    let weightLogs: Int
    let workouts: Int
    let dailyLogs: Int

    var message: String {
        """
        Profil: \(profiles)
        Öğün: \(meals)
        Su kaydı: \(waterEntries)
        Yürüyüş: \(walkingLogs)
        Kilo kaydı: \(weightLogs)
        Antrenman: \(workouts)
        Günlük özet: \(dailyLogs)
        """
    }
}

@MainActor
final class DataBackupService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func exportJSONBackup() throws -> ExportedDataFile {
        let backup = try makeBackupFile()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        let data = try encoder.encode(backup)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Nuvyra-Backup-\(Self.fileStamp()).json")
        try data.write(to: fileURL, options: [.atomic])
        return ExportedDataFile(url: fileURL)
    }

    func importJSONBackup(from url: URL) throws -> BackupImportSummary {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(NuvyraBackupFile.self, from: data)

        guard backup.schemaVersion <= NuvyraBackupFile.currentSchemaVersion else {
            throw BackupError.unsupportedVersion
        }

        let importedProfiles = try upsertProfiles(backup.profiles)
        let importedMeals = try upsertMeals(backup.meals)
        let importedWater = try upsertWaterEntries(backup.waterEntries)
        let importedWalking = try upsertWalkingLogs(backup.walkingLogs)
        let importedWeight = try upsertWeightLogs(backup.weightLogs)
        let importedWorkouts = try upsertWorkouts(backup.workouts)
        let importedDaily = try upsertDailyLogs(backup.dailyLogs)
        try upsertSettings(backup.settings)
        try context.save()

        return BackupImportSummary(
            profiles: importedProfiles,
            meals: importedMeals,
            waterEntries: importedWater,
            walkingLogs: importedWalking,
            weightLogs: importedWeight,
            workouts: importedWorkouts,
            dailyLogs: importedDaily
        )
    }

    private func makeBackupFile() throws -> NuvyraBackupFile {
        NuvyraBackupFile(
            exportedAt: Date(),
            profiles: try context.fetch(FetchDescriptor<UserProfile>()).map(ProfileBackup.init(profile:)),
            meals: try context.fetch(FetchDescriptor<MealEntry>()).map(MealBackup.init(meal:)),
            waterEntries: try context.fetch(FetchDescriptor<WaterEntry>()).map(WaterBackup.init(entry:)),
            walkingLogs: try context.fetch(FetchDescriptor<WalkingLog>()).map(WalkingBackup.init(log:)),
            weightLogs: try context.fetch(FetchDescriptor<WeightLog>()).map(WeightBackup.init(log:)),
            workouts: try context.fetch(FetchDescriptor<WorkoutLog>()).map(WorkoutBackup.init(log:)),
            dailyLogs: try context.fetch(FetchDescriptor<DailyLog>()).map(DailyLogBackup.init(log:)),
            settings: try context.fetch(FetchDescriptor<AppSettings>()).first.map(SettingsBackup.init(settings:))
        )
    }

    private func upsertProfiles(_ records: [ProfileBackup]) throws -> Int {
        var existing = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<UserProfile>()).map { ($0.id, $0) })
        for record in records {
            let profile = existing[record.id] ?? UserProfile(id: record.id)
            record.apply(to: profile)
            if existing[record.id] == nil {
                context.insert(profile)
                existing[record.id] = profile
            }
        }
        return records.count
    }

    private func upsertMeals(_ records: [MealBackup]) throws -> Int {
        var existing = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<MealEntry>()).map { ($0.id, $0) })
        for record in records {
            let meal = existing[record.id] ?? MealEntry(id: record.id, name: record.name, calories: record.calories)
            record.apply(to: meal)
            if existing[record.id] == nil {
                context.insert(meal)
                existing[record.id] = meal
            }
        }
        return records.count
    }

    private func upsertWaterEntries(_ records: [WaterBackup]) throws -> Int {
        var existing = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<WaterEntry>()).map { ($0.id, $0) })
        for record in records {
            let entry = existing[record.id] ?? WaterEntry(id: record.id, amountMl: record.amountMl)
            record.apply(to: entry)
            if existing[record.id] == nil {
                context.insert(entry)
                existing[record.id] = entry
            }
        }
        return records.count
    }

    private func upsertWalkingLogs(_ records: [WalkingBackup]) throws -> Int {
        var existing = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<WalkingLog>()).map { ($0.id, $0) })
        for record in records {
            let log = existing[record.id] ?? WalkingLog(id: record.id, steps: record.steps)
            record.apply(to: log)
            if existing[record.id] == nil {
                context.insert(log)
                existing[record.id] = log
            }
        }
        return records.count
    }

    private func upsertWeightLogs(_ records: [WeightBackup]) throws -> Int {
        var existing = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<WeightLog>()).map { ($0.id, $0) })
        for record in records {
            let log = existing[record.id] ?? WeightLog(id: record.id, weightKg: record.weightKg)
            record.apply(to: log)
            if existing[record.id] == nil {
                context.insert(log)
                existing[record.id] = log
            }
        }
        return records.count
    }

    private func upsertWorkouts(_ records: [WorkoutBackup]) throws -> Int {
        var existing = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<WorkoutLog>()).map { ($0.id, $0) })
        for record in records {
            let log = existing[record.id] ?? WorkoutLog(id: record.id, durationMinutes: record.durationMinutes, caloriesBurned: record.caloriesBurned)
            record.apply(to: log)
            if existing[record.id] == nil {
                context.insert(log)
                existing[record.id] = log
            }
        }
        return records.count
    }

    private func upsertDailyLogs(_ records: [DailyLogBackup]) throws -> Int {
        var existing = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<DailyLog>()).map { ($0.id, $0) })
        for record in records {
            let log = existing[record.id] ?? DailyLog(id: record.id)
            record.apply(to: log)
            if existing[record.id] == nil {
                context.insert(log)
                existing[record.id] = log
            }
        }
        return records.count
    }

    private func upsertSettings(_ record: SettingsBackup?) throws {
        guard let record else { return }
        var existing = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<AppSettings>()).map { ($0.id, $0) })
        let settings = existing[record.id] ?? AppSettings(id: record.id)
        record.apply(to: settings)
        if existing[record.id] == nil {
            context.insert(settings)
            existing[record.id] = settings
        }
    }

    private static func fileStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

enum BackupError: LocalizedError {
    case unsupportedVersion

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion:
            "Bu yedek dosyası Nuvyra'nın daha yeni bir sürümüyle oluşturulmuş. Uygulamayı güncelledikten sonra tekrar dene."
        }
    }
}

private struct NuvyraBackupFile: Codable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int = 1
    var exportedAt: Date
    var appName: String = "Nuvyra"
    var privacyNote: String = "Bu dosya kişisel wellness verileri içerebilir. Güvenmediğin kişilerle paylaşma."
    var profiles: [ProfileBackup]
    var meals: [MealBackup]
    var waterEntries: [WaterBackup]
    var walkingLogs: [WalkingBackup]
    var weightLogs: [WeightBackup]
    var workouts: [WorkoutBackup]
    var dailyLogs: [DailyLogBackup]
    var settings: SettingsBackup?
}

private struct ProfileBackup: Codable {
    var id: UUID
    var name: String
    var age: Int
    var gender: Gender?
    var heightCm: Double
    var weightKg: Double
    var targetWeightKg: Double?
    var dailyCalorieTarget: Int
    var dailyProteinTargetGrams: Int
    var dailyCarbsTargetGrams: Int
    var dailyFatTargetGrams: Int
    var dailyFiberTargetGrams: Int
    var dailySodiumTargetMg: Int
    var dailySugarTargetGrams: Int
    var dailySaturatedFatTargetGrams: Int
    var dailyCaffeineLimitMg: Int
    var dailyStepTarget: Int
    var dailyWaterTargetMl: Int
    var goalType: GoalType
    var activityLevel: ActivityLevel
    var goalPace: GoalPace?
    var createdAt: Date
    var updatedAt: Date

    init(profile: UserProfile) {
        self.id = profile.id
        self.name = profile.name
        self.age = profile.age
        self.gender = profile.gender
        self.heightCm = profile.heightCm
        self.weightKg = profile.weightKg
        self.targetWeightKg = profile.targetWeightKg
        self.dailyCalorieTarget = profile.dailyCalorieTarget
        self.dailyProteinTargetGrams = profile.dailyProteinTargetGrams
        self.dailyCarbsTargetGrams = profile.dailyCarbsTargetGrams
        self.dailyFatTargetGrams = profile.dailyFatTargetGrams
        self.dailyFiberTargetGrams = profile.dailyFiberTargetGrams
        self.dailySodiumTargetMg = profile.dailySodiumTargetMg
        self.dailySugarTargetGrams = profile.dailySugarTargetGrams
        self.dailySaturatedFatTargetGrams = profile.dailySaturatedFatTargetGrams
        self.dailyCaffeineLimitMg = profile.dailyCaffeineLimitMg
        self.dailyStepTarget = profile.dailyStepTarget
        self.dailyWaterTargetMl = profile.dailyWaterTargetMl
        self.goalType = profile.goalType
        self.activityLevel = profile.activityLevel
        self.goalPace = profile.goalPace
        self.createdAt = profile.createdAt
        self.updatedAt = profile.updatedAt
    }

    func apply(to profile: UserProfile) {
        profile.name = name
        profile.age = age
        profile.gender = gender
        profile.heightCm = heightCm
        profile.weightKg = weightKg
        profile.targetWeightKg = targetWeightKg
        profile.dailyCalorieTarget = dailyCalorieTarget
        profile.dailyProteinTargetGrams = dailyProteinTargetGrams
        profile.dailyCarbsTargetGrams = dailyCarbsTargetGrams
        profile.dailyFatTargetGrams = dailyFatTargetGrams
        profile.dailyFiberTargetGrams = dailyFiberTargetGrams
        profile.dailySodiumTargetMg = dailySodiumTargetMg
        profile.dailySugarTargetGrams = dailySugarTargetGrams
        profile.dailySaturatedFatTargetGrams = dailySaturatedFatTargetGrams
        profile.dailyCaffeineLimitMg = dailyCaffeineLimitMg
        profile.dailyStepTarget = dailyStepTarget
        profile.dailyWaterTargetMl = dailyWaterTargetMl
        profile.goalType = goalType
        profile.activityLevel = activityLevel
        profile.goalPace = goalPace
        profile.createdAt = createdAt
        profile.updatedAt = updatedAt
    }
}

private struct MealBackup: Codable {
    var id: UUID
    var date: Date
    var mealType: MealType
    var name: String
    var calories: Int
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var portionDescription: String
    var isFavorite: Bool
    var isVerifiedTurkishFood: Bool
    var isEstimated: Bool
    var createdAt: Date
    var fiberGrams: Double?
    var sodiumMg: Double?
    var sugarGrams: Double?
    var saturatedFatGrams: Double?
    var photoData: Data?

    init(meal: MealEntry) {
        self.id = meal.id
        self.date = meal.date
        self.mealType = meal.mealType
        self.name = meal.name
        self.calories = meal.calories
        self.protein = meal.protein
        self.carbs = meal.carbs
        self.fat = meal.fat
        self.portionDescription = meal.portionDescription
        self.isFavorite = meal.isFavorite
        self.isVerifiedTurkishFood = meal.isVerifiedTurkishFood
        self.isEstimated = meal.isEstimated
        self.createdAt = meal.createdAt
        self.fiberGrams = meal.fiberGrams
        self.sodiumMg = meal.sodiumMg
        self.sugarGrams = meal.sugarGrams
        self.saturatedFatGrams = meal.saturatedFatGrams
        self.photoData = meal.photoData
    }

    func apply(to meal: MealEntry) {
        meal.date = date
        meal.mealType = mealType
        meal.name = name
        meal.calories = calories
        meal.protein = protein
        meal.carbs = carbs
        meal.fat = fat
        meal.portionDescription = portionDescription
        meal.isFavorite = isFavorite
        meal.isVerifiedTurkishFood = isVerifiedTurkishFood
        meal.isEstimated = isEstimated
        meal.createdAt = createdAt
        meal.fiberGrams = fiberGrams
        meal.sodiumMg = sodiumMg
        meal.sugarGrams = sugarGrams
        meal.saturatedFatGrams = saturatedFatGrams
        meal.photoData = photoData
    }
}

private struct WaterBackup: Codable {
    var id: UUID
    var date: Date
    var amountMl: Int
    var drinkTypeRaw: String?
    var caffeineMg: Double?

    init(entry: WaterEntry) {
        self.id = entry.id
        self.date = entry.date
        self.amountMl = entry.amountMl
        self.drinkTypeRaw = entry.drinkTypeRaw
        self.caffeineMg = entry.caffeineMg
    }

    func apply(to entry: WaterEntry) {
        entry.date = date
        entry.amountMl = amountMl
        entry.drinkTypeRaw = drinkTypeRaw
        entry.caffeineMg = caffeineMg
    }
}

private struct WalkingBackup: Codable {
    var id: UUID
    var date: Date
    var steps: Int
    var activeEnergy: Double
    var distanceKm: Double?
    var goalCompleted: Bool

    init(log: WalkingLog) {
        self.id = log.id
        self.date = log.date
        self.steps = log.steps
        self.activeEnergy = log.activeEnergy
        self.distanceKm = log.distanceKm
        self.goalCompleted = log.goalCompleted
    }

    func apply(to log: WalkingLog) {
        log.date = date
        log.steps = steps
        log.activeEnergy = activeEnergy
        log.distanceKm = distanceKm
        log.goalCompleted = goalCompleted
    }
}

private struct WeightBackup: Codable {
    var id: UUID
    var date: Date
    var weightKg: Double
    var source: String
    var note: String?
    var createdAt: Date
    var waistCm: Double?
    var hipCm: Double?
    var chestCm: Double?
    var shoulderCm: Double?
    var neckCm: Double?
    /// JSON key intentionally kept as `bicepCm` so historic backups remain
    /// importable after the model rename. Swift property maps to `log.bicepsCm`
    /// internally — the Codable wire format does not change.
    var bicepCm: Double?
    var thighCm: Double?
    var bodyFatPercent: Double?

    init(log: WeightLog) {
        self.id = log.id
        self.date = log.date
        self.weightKg = log.weightKg
        self.source = log.source
        self.note = log.note
        self.createdAt = log.createdAt
        self.waistCm = log.waistCm
        self.hipCm = log.hipCm
        self.chestCm = log.chestCm
        self.shoulderCm = log.shoulderCm
        self.neckCm = log.neckCm
        self.bicepCm = log.bicepsCm
        self.thighCm = log.thighCm
        self.bodyFatPercent = log.bodyFatPercent
    }

    func apply(to log: WeightLog) {
        log.date = date
        log.weightKg = weightKg
        log.source = source
        log.note = note
        log.createdAt = createdAt
        log.waistCm = waistCm
        log.hipCm = hipCm
        log.chestCm = chestCm
        log.shoulderCm = shoulderCm
        log.neckCm = neckCm
        log.bicepsCm = bicepCm
        log.thighCm = thighCm
        log.bodyFatPercent = bodyFatPercent
    }
}

private struct WorkoutBackup: Codable {
    var id: UUID
    var date: Date
    var typeRaw: String
    var durationMinutes: Int
    var caloriesBurned: Int
    var distanceKm: Double?
    var note: String?
    var sourceRaw: String
    var createdAt: Date

    init(log: WorkoutLog) {
        self.id = log.id
        self.date = log.date
        self.typeRaw = log.typeRaw
        self.durationMinutes = log.durationMinutes
        self.caloriesBurned = log.caloriesBurned
        self.distanceKm = log.distanceKm
        self.note = log.note
        self.sourceRaw = log.sourceRaw
        self.createdAt = log.createdAt
    }

    func apply(to log: WorkoutLog) {
        log.date = date
        log.typeRaw = typeRaw
        log.durationMinutes = durationMinutes
        log.caloriesBurned = caloriesBurned
        log.distanceKm = distanceKm
        log.note = note
        log.sourceRaw = sourceRaw
        log.createdAt = createdAt
    }
}

private struct DailyLogBackup: Codable {
    var id: UUID
    var date: Date
    var totalCalories: Int
    var caloriesBurned: Int
    var steps: Int
    var waterMl: Int
    var streakCompleted: Bool
    var mood: Mood?
    var note: String?

    init(log: DailyLog) {
        self.id = log.id
        self.date = log.date
        self.totalCalories = log.totalCalories
        self.caloriesBurned = log.caloriesBurned
        self.steps = log.steps
        self.waterMl = log.waterMl
        self.streakCompleted = log.streakCompleted
        self.mood = log.mood
        self.note = log.note
    }

    func apply(to log: DailyLog) {
        log.date = date
        log.totalCalories = totalCalories
        log.caloriesBurned = caloriesBurned
        log.steps = steps
        log.waterMl = waterMl
        log.streakCompleted = streakCompleted
        log.mood = mood
        log.note = note
    }
}

private struct SettingsBackup: Codable {
    var id: UUID
    var hasCompletedOnboarding: Bool
    var notificationsEnabled: Bool
    var healthPermissionAsked: Bool
    var reducedInsightCopy: Bool
    var didCompleteDayOneTour: Bool
    var vitalsPermissionToastShown: Bool?
    var createdAt: Date
    var updatedAt: Date

    init(settings: AppSettings) {
        self.id = settings.id
        self.hasCompletedOnboarding = settings.hasCompletedOnboarding
        self.notificationsEnabled = settings.notificationsEnabled
        self.healthPermissionAsked = settings.healthPermissionAsked
        self.reducedInsightCopy = settings.reducedInsightCopy
        self.didCompleteDayOneTour = settings.didCompleteDayOneTour
        self.vitalsPermissionToastShown = settings.vitalsPermissionToastShown
        self.createdAt = settings.createdAt
        self.updatedAt = settings.updatedAt
    }

    func apply(to settings: AppSettings) {
        settings.hasCompletedOnboarding = hasCompletedOnboarding
        settings.notificationsEnabled = notificationsEnabled
        settings.healthPermissionAsked = healthPermissionAsked
        settings.reducedInsightCopy = reducedInsightCopy
        settings.didCompleteDayOneTour = didCompleteDayOneTour
        settings.vitalsPermissionToastShown = vitalsPermissionToastShown ?? false
        settings.createdAt = createdAt
        settings.updatedAt = updatedAt
    }
}
