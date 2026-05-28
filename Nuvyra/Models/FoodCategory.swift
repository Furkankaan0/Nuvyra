import Foundation

enum FoodCategory: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case vegetable
    case fruit
    case grain
    case legume
    case dairy
    case meat
    case poultry
    case fish
    case egg
    case nutSeed
    case oilFat
    case sauceCondiment
    case spiceHerb
    case beverage
    case alcohol
    case snack
    case sweet
    case bakedGood
    case prepared
    case fastFood
    case localTurkish
    case protein
    case supplement
    case dietary
    case babyFood
    case other

    var id: String { rawValue }

    var displayLabelTR: String {
        switch self {
        case .vegetable: "Sebze"
        case .fruit: "Meyve"
        case .grain: "Tahıl"
        case .legume: "Bakliyat"
        case .dairy: "Süt Ürünleri"
        case .meat: "Et"
        case .poultry: "Kümes Hayvanı"
        case .fish: "Balık & Deniz Ürünleri"
        case .egg: "Yumurta"
        case .nutSeed: "Kuruyemiş & Tohum"
        case .oilFat: "Yağ"
        case .sauceCondiment: "Sos & Çeşni"
        case .spiceHerb: "Baharat & Ot"
        case .beverage: "İçecek"
        case .alcohol: "Alkollü İçecek"
        case .snack: "Atıştırmalık"
        case .sweet: "Tatlı"
        case .bakedGood: "Fırın Ürünleri"
        case .prepared: "Hazır Yemek"
        case .fastFood: "Fast Food"
        case .localTurkish: "Türk Mutfağı"
        case .protein: "Protein Ürünleri"
        case .supplement: "Takviye"
        case .dietary: "Diyet Ürünleri"
        case .babyFood: "Bebek Maması"
        case .other: "Diğer"
        }
    }

    var displayLabelEN: String {
        switch self {
        case .vegetable: "Vegetable"
        case .fruit: "Fruit"
        case .grain: "Grain"
        case .legume: "Legume"
        case .dairy: "Dairy"
        case .meat: "Meat"
        case .poultry: "Poultry"
        case .fish: "Fish & Seafood"
        case .egg: "Egg"
        case .nutSeed: "Nut & Seed"
        case .oilFat: "Oil & Fat"
        case .sauceCondiment: "Sauce & Condiment"
        case .spiceHerb: "Spice & Herb"
        case .beverage: "Beverage"
        case .alcohol: "Alcoholic Beverage"
        case .snack: "Snack"
        case .sweet: "Sweet"
        case .bakedGood: "Baked Good"
        case .prepared: "Prepared Meal"
        case .fastFood: "Fast Food"
        case .localTurkish: "Turkish Cuisine"
        case .protein: "Protein Product"
        case .supplement: "Supplement"
        case .dietary: "Dietary"
        case .babyFood: "Baby Food"
        case .other: "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .vegetable: "carrot.fill"
        case .fruit: "applelogo"
        case .grain: "leaf.fill"
        case .legume: "circle.grid.3x3.fill"
        case .dairy: "drop.fill"
        case .meat, .poultry: "fork.knife"
        case .fish: "fish.fill"
        case .egg: "oval.fill"
        case .nutSeed: "circle.hexagongrid.fill"
        case .oilFat: "drop.triangle.fill"
        case .sauceCondiment: "drop.halffull"
        case .spiceHerb: "leaf"
        case .beverage: "cup.and.saucer.fill"
        case .alcohol: "wineglass.fill"
        case .snack: "bag.fill"
        case .sweet: "birthday.cake.fill"
        case .bakedGood: "takeoutbag.and.cup.and.straw.fill"
        case .prepared: "tray.fill"
        case .fastFood: "takeoutbag.and.cup.and.straw"
        case .localTurkish: "star.fill"
        case .protein: "dumbbell.fill"
        case .supplement: "pills.fill"
        case .dietary: "heart.fill"
        case .babyFood: "figure.and.child.holdinghands"
        case .other: "square.grid.2x2"
        }
    }
}
