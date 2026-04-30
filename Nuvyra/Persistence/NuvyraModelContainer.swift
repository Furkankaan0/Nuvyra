import Foundation
import SwiftData

enum NuvyraModelContainer {
    /// Single source of truth for the persisted model schema. Always
    /// built from the versioned `SchemaV1` so we have a real migration
    /// story when V2 lands. See `SchemaV1.swift` for the upgrade recipe.
    static let schema = Schema(versionedSchema: SchemaV1.self)

    /// Filename of the on-disk SQLite store. Pinned so we don't lose the
    /// user's history if SwiftData ever changes its default name.
    private static let storeFileName = "Nuvyra.store"

    /// File-protection level for the on-disk SQLite. We deliberately do
    /// NOT use `.complete` — that would lock the database whenever the
    /// device is locked, which would break HealthKit's background
    /// observer fires (the app gets woken from a suspended state with
    /// the screen still locked). `.completeUntilFirstUserAuthentication`
    /// keeps the file encrypted at rest, decrypts after the first
    /// unlock per boot, and stays accessible to background launches —
    /// the right trade-off for a wellness app that holds health data.
    private static let fileProtection: FileProtectionType = .completeUntilFirstUserAuthentication

    /// Set to `true` once the schema is CloudKit-clean (no
    /// `@Attribute(.unique)` on non-id fields, every property has a
    /// storage-level default, every relationship is optional, and the
    /// `iCloud.com.nuvyra.app` CloudKit container is provisioned).
    /// SchemaV1 is **not** CloudKit-clean today — it carries
    /// `@Attribute(.unique)` on `DailyLog.date` and `WalkingLog.date`,
    /// which CloudKit cannot enforce. Flipping this on without a V2
    /// schema audit will hard-crash on first launch.
    private static let isCloudKitReady = false

    @MainActor
    static func live() -> ModelContainer {
        do {
            let configuration = liveConfiguration()
            let container = try ModelContainer(
                for: schema,
                migrationPlan: NuvyraMigrationPlan.self,
                configurations: [configuration]
            )
            applyFileProtectionIfPossible(at: configuration.url)
            return container
        } catch {
            assertionFailure("SwiftData container failed, falling back to in-memory store: \(error)")
            return preview()
        }
    }

    @MainActor
    static func preview() -> ModelContainer {
        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: NuvyraMigrationPlan.self,
                configurations: [configuration]
            )
            SeedData.seedPreview(in: container.mainContext)
            return container
        } catch {
            fatalError("Preview ModelContainer could not be created: \(error)")
        }
    }

    @MainActor
    static func uiTesting() -> ModelContainer {
        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: NuvyraMigrationPlan.self,
                configurations: [configuration]
            )
            SeedData.seedUITesting(in: container.mainContext)
            return container
        } catch {
            fatalError("UI testing ModelContainer could not be created: \(error)")
        }
    }

    // MARK: - Helpers

    /// Builds the on-disk configuration. Routes through CloudKit only
    /// when the schema is CloudKit-clean; otherwise stays local.
    private static func liveConfiguration() -> ModelConfiguration {
        let storeURL = applicationSupportURL().appendingPathComponent(storeFileName)
        if isCloudKitReady {
            return ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .automatic
            )
        }
        return ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
    }

    private static func applicationSupportURL() -> URL {
        let fm = FileManager.default
        let url = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return url
    }

    /// Applies `.completeUntilFirstUserAuthentication` to the SQLite
    /// store and its sidecar files. SwiftData itself does not expose a
    /// file-protection setting, so we reach into the filesystem after
    /// the container is built. Safe to call on every launch — it's a
    /// no-op when the protection class is already correct.
    private static func applyFileProtectionIfPossible(at storeURL: URL?) {
        guard let storeURL else { return }
        let fm = FileManager.default
        let candidates = [
            storeURL,
            storeURL.appendingPathExtension("wal"),
            storeURL.appendingPathExtension("shm")
        ]
        for url in candidates where fm.fileExists(atPath: url.path) {
            try? fm.setAttributes([.protectionKey: fileProtection], ofItemAtPath: url.path)
        }
    }
}
