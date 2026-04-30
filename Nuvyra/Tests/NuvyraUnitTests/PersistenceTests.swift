import SwiftData
import XCTest
@testable import Nuvyra

@MainActor
final class PersistenceTests: XCTestCase {
    /// Two `DailyLog` rows with the same `startOfDay(for: Date())` must
    /// not coexist — `@Attribute(.unique)` should reject the second
    /// insert (or upsert into the existing row, depending on SwiftData
    /// version). Either outcome is acceptable; what we MUST avoid is
    /// ending up with two rows for one calendar day.
    func testDailyLogIsUniquePerCalendarDay() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: NuvyraModelContainer.schema,
            migrationPlan: NuvyraMigrationPlan.self,
            configurations: [configuration]
        )
        let context = container.mainContext

        let day = Calendar.current.startOfDay(for: Date())
        context.insert(DailyLog(date: day, totalCalories: 100, steps: 500))
        try context.save()

        // Try inserting a second row for the same calendar day.
        context.insert(DailyLog(date: day, totalCalories: 200, steps: 1_000))
        // Some SwiftData versions throw on save, others silently merge.
        // Either way, the post-save count must remain 1.
        _ = try? context.save()

        let logs = try context.fetch(FetchDescriptor<DailyLog>())
        XCTAssertEqual(logs.count, 1, "DailyLog must be unique per startOfDay")
    }

    /// Repository-level guarantee: rapid sequential water adds must
    /// accumulate, not overwrite, even though the underlying total is
    /// computed in the same transaction.
    func testRepeatedAddWaterAccumulates() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: NuvyraModelContainer.schema,
            migrationPlan: NuvyraMigrationPlan.self,
            configurations: [configuration]
        )
        let repository = SwiftDataWaterRepository(context: container.mainContext)

        let firstTotal = try repository.addWater(amountMl: 250, date: Date())
        let secondTotal = try repository.addWater(amountMl: 250, date: Date())
        let thirdTotal = try repository.addWater(amountMl: 500, date: Date())

        XCTAssertEqual(firstTotal, 250)
        XCTAssertEqual(secondTotal, 500)
        XCTAssertEqual(thirdTotal, 1_000)
    }

    /// The migration plan loads. Empty stages are fine for V1; the
    /// regression we're guarding against is the container builder
    /// rejecting our `versionedSchema` wiring.
    func testContainerBuildsWithVersionedSchemaAndMigrationPlan() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        XCTAssertNoThrow(
            try ModelContainer(
                for: NuvyraModelContainer.schema,
                migrationPlan: NuvyraMigrationPlan.self,
                configurations: [configuration]
            )
        )
    }
}
