//
//  FoodCategory.swift
//  Nuvyra Core ML
//
//  Modelin etiketlediği yemek sınıfları + insan-okur Türkçe karşılıkları.
//  FoodDensityDatabase anahtarlarıyla birebir uyumludur.
//

import Foundation

/// Modelin döndüreceği sınıflar (Create ML / Turi Create eğitim setine
/// uygun). Yeni etiket eklemek istersen `rawValue`'lerini eğitim setiyle
/// senkronize tut ve `FoodDensityDatabase`'e karşılığını ekle.
public enum FoodCategory: String, CaseIterable, Sendable {

    // Tahıllar
    case pilav, bulgur, makarna, kuskus

    // Et grubu
    case et, tavuk, kofte, balik, kebap

    // Sebze / salata
    case salata, sebze, domates, havuc, kabak

    // Çorba / sıvı
    case corba, yogurt, cacik

    // Hamur işi
    case ekmek, borek, pide

    // Meyve
    case elma, muz, uzum

    // Tatlı
    case baklava, sutlac, kek

    // Diğer
    case `default`

    // MARK: - Localization

    /// UI'da gösterilecek başlık.
    public var displayName: String {
        switch self {
        case .pilav:     return "Pilav"
        case .bulgur:    return "Bulgur"
        case .makarna:   return "Makarna"
        case .kuskus:    return "Kuskus"
        case .et:        return "Et"
        case .tavuk:     return "Tavuk"
        case .kofte:     return "Köfte"
        case .balik:     return "Balık"
        case .kebap:     return "Kebap"
        case .salata:    return "Salata"
        case .sebze:     return "Sebze"
        case .domates:   return "Domates"
        case .havuc:     return "Havuç"
        case .kabak:     return "Kabak"
        case .corba:     return "Çorba"
        case .yogurt:    return "Yoğurt"
        case .cacik:     return "Cacık"
        case .ekmek:     return "Ekmek"
        case .borek:     return "Börek"
        case .pide:      return "Pide"
        case .elma:      return "Elma"
        case .muz:       return "Muz"
        case .uzum:      return "Üzüm"
        case .baklava:   return "Baklava"
        case .sutlac:    return "Sütlaç"
        case .kek:       return "Kek"
        case .default:   return "Genel"
        }
    }

    /// Modelden gelen ham etiketi `FoodCategory`'ye çevirir; bilinmeyen
    /// etiketler için `.default` döner.
    public static func from(rawLabel: String) -> FoodCategory {
        let normalized = rawLabel
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return FoodCategory(rawValue: normalized) ?? .default
    }
}
