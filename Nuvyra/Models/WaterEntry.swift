import Foundation
import SwiftData

@Model
final class WaterEntry: Identifiable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var amountMl: Int

    /// Raw value of `DrinkType`. Stored as `String?` so SwiftData applies a
    /// lightweight migration on existing stores (old rows = nil = water).
    var drinkTypeRaw: String?
    var caffeineMg: Double?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        amountMl: Int,
        drinkType: DrinkType? = nil,
        caffeineMg: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.amountMl = amountMl
        self.drinkTypeRaw = drinkType?.rawValue
        self.caffeineMg = caffeineMg
    }

    /// Convenience accessor — `nil` raw value is treated as plain water so
    /// pre-v1.3 rows roll up correctly.
    var drinkType: DrinkType {
        get { drinkTypeRaw.flatMap(DrinkType.init(rawValue:)) ?? .water }
        set { drinkTypeRaw = newValue.rawValue }
    }

    /// Litres counted toward the daily hydration goal — applies the drink-type
    /// hydration factor (coffee/soda contribute less than water).
    var hydrationMl: Int {
        Int((Double(amountMl) * drinkType.hydrationFactor).rounded())
    }
}
