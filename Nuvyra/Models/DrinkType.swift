import Foundation
import SwiftUI

/// Beverage classification stored on each `WaterEntry`. Adding it lets us
/// separate hidrasyon (sıvı) from kafein takibi and surface a per-drink
/// breakdown without breaking the existing water flow — old rows with
/// `drinkType == nil` are treated as `.water`.
enum DrinkType: String, CaseIterable, Codable, Identifiable, Equatable, Hashable {
    case water
    case coffee
    case tea
    case juice
    case energyDrink
    case soda
    case milk
    case smoothie
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .water: "Su"
        case .coffee: "Kahve"
        case .tea: "Çay"
        case .juice: "Meyve suyu"
        case .energyDrink: "Enerji içeceği"
        case .soda: "Gazlı içecek"
        case .milk: "Süt"
        case .smoothie: "Smoothie"
        case .other: "Diğer"
        }
    }

    var systemImage: String {
        switch self {
        case .water: "drop.fill"
        case .coffee: "cup.and.saucer.fill"
        case .tea: "mug.fill"
        case .juice: "takeoutbag.and.cup.and.straw.fill"
        case .energyDrink: "bolt.fill"
        case .soda: "wineglass.fill"
        case .milk: "cup.and.heat.waves.fill"
        case .smoothie: "leaf.fill"
        case .other: "drop.degreesign"
        }
    }

    var tint: Color {
        switch self {
        case .water: Color(red: 0.20, green: 0.56, blue: 0.95)
        case .coffee: Color(red: 0.55, green: 0.35, blue: 0.20)
        case .tea: Color(red: 0.78, green: 0.55, blue: 0.30)
        case .juice: NuvyraColors.softSand
        case .energyDrink: NuvyraColors.mutedCoral
        case .soda: Color(red: 0.62, green: 0.40, blue: 0.75)
        case .milk: Color(red: 0.92, green: 0.92, blue: 0.95)
        case .smoothie: NuvyraColors.softMint
        case .other: NuvyraColors.mutedGray
        }
    }

    /// Default per-serving size shown in the quick add buttons.
    var defaultAmountMl: Int {
        switch self {
        case .water: 250
        case .coffee: 200
        case .tea: 200
        case .juice: 250
        case .energyDrink: 250
        case .soda: 330
        case .milk: 250
        case .smoothie: 300
        case .other: 200
        }
    }

    /// Conservative caffeine baseline used when the user doesn't specify one.
    /// Numbers are typical Turkish-cup / standart porsiyon değerleri.
    var defaultCaffeinePerServingMg: Int {
        switch self {
        case .water: 0
        case .coffee: 95     // brewed coffee ~95 mg / 200 ml
        case .tea: 40        // black tea ~40 mg / 200 ml
        case .juice: 0
        case .energyDrink: 80
        case .soda: 30
        case .milk: 0
        case .smoothie: 0
        case .other: 0
        }
    }

    /// Counts toward the daily hydration goal? Caffeinated/sugar drinks have a
    /// slightly reduced weight so the user is gently nudged toward water.
    var hydrationFactor: Double {
        switch self {
        case .water: 1.0
        case .tea, .milk, .juice, .smoothie: 0.85
        case .coffee, .soda, .energyDrink: 0.6
        case .other: 0.7
        }
    }
}
