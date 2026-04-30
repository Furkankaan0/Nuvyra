import Foundation
import SwiftData

/// Versioned schema for the v1.0 App Store release.
///
/// Bumping the schema is the *only* way to change a SwiftData model
/// safely without crashing existing installs:
///
///   1. Copy each `@Model` class out of the global namespace into a
///      `SchemaV2` enum (alongside the new fields you want to add).
///   2. Bump `versionIdentifier` to `(1, 1, 0)` for additive changes or
///      `(2, 0, 0)` for breaking changes.
///   3. Add a `MigrationStage.lightweight(...)` (or `.custom(...)`) to
///      `NuvyraMigrationPlan.stages` describing how V1 → V2 maps.
///   4. Update `NuvyraModelContainer` to point at `SchemaV2.self`.
///
/// Before this file existed, the container built a raw `Schema([...])`
/// with no version, so any future model change would hard-crash on
/// launch. We now have a real migration story even before the first
/// breaking change ships.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            UserProfile.self,
            DailyLog.self,
            MealEntry.self,
            WaterEntry.self,
            WalkingLog.self,
            NutritionGoal.self,
            SubscriptionState.self,
            AppSettings.self
        ]
    }
}

/// Migration plan for the persistent store.
///
/// Today there is only V1 (so this is effectively a no-op), but having
/// the plan in place means we can drop in a V2 stage without rebuilding
/// the container code or risking an existing-install crash.
enum NuvyraMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
