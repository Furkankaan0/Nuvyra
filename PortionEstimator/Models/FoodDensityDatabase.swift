//
//  FoodDensityDatabase.swift
//  Nuvyra - Portion Estimator
//
//  Yemek türlerinin yaklaşık yoğunluk değerlerini (g/cm³) tutan,
//  sabit ve thread-safe bir veri kaynağı.
//

import Foundation

/// Yemek tipine göre ortalama yoğunluk değerlerini sağlayan referans yapı.
/// Tüm değerler g/cm³ cinsindendir ve gözlemsel literatürden derlenmiştir.
public struct FoodDensityDatabase: Sendable {

    // MARK: - Singleton

    /// Uygulama genelinde paylaşılan tek instance.
    public static let shared = FoodDensityDatabase()

    // MARK: - Stored Properties

    /// Yemek anahtarına göre yoğunluk (g/cm³) sözlüğü.
    /// Anahtarlar küçük harfle ve Türkçe diyakritiksiz tutulur.
    private let densities: [String: Double] = [
        // Tahıllar / pilavlar
        "pilav":       0.70,
        "bulgur":      0.75,
        "makarna":     0.65,
        "kuskus":      0.78,

        // Et grubu
        "et":          1.05,
        "tavuk":       1.04,
        "kofte":       1.02,
        "balik":       1.01,
        "kebap":       1.05,

        // Sebze / salata
        "salata":      0.30,
        "sebze":       0.55,
        "domates":     0.62,
        "havuc":       0.61,
        "kabak":       0.50,

        // Çorba / sıvı
        "corba":       1.00,
        "yogurt":      1.03,
        "cacik":       1.02,

        // Hamur işi
        "ekmek":       0.30,
        "borek":       0.45,
        "pide":        0.40,

        // Meyve
        "elma":        0.78,
        "muz":         0.94,
        "uzum":        0.85,

        // Tatlı
        "baklava":     1.10,
        "sutlac":      1.05,
        "kek":         0.45,

        // Genel fallback
        "default":     0.85
    ]

    /// Toleranslı eşleşme için kullanılan eş anlamlı (alias) tablosu.
    private let aliases: [String: String] = [
        "rice":        "pilav",
        "meat":        "et",
        "chicken":     "tavuk",
        "fish":        "balik",
        "soup":        "corba",
        "bread":       "ekmek",
        "yoghurt":     "yogurt",
        "salad":       "salata",
        "pasta":       "makarna",
        "vegetable":   "sebze",
        "vegetables":  "sebze"
    ]

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Verilen yemek anahtarına karşılık gelen yoğunluk değerini döner.
    /// Eşleşme bulunamazsa `default` yoğunluğunu kullanır.
    /// - Parameter foodKey: Sınıflandırma sonucundan gelen yemek adı.
    /// - Returns: g/cm³ cinsinden yoğunluk değeri.
    public func density(for foodKey: String) -> Double {
        let normalized = Self.normalize(foodKey)

        if let direct = densities[normalized] {
            return direct
        }
        if let aliasTarget = aliases[normalized],
           let value = densities[aliasTarget] {
            return value
        }

        // Substring eşleşmesi (örn. "tavuklu pilav" -> "pilav")
        for (key, value) in densities where normalized.contains(key) {
            return value
        }

        return densities["default"] ?? 0.85
    }

    /// Veritabanında o anda tanımlı olan tüm yemek anahtarlarını döner.
    /// - Returns: Alfabetik sıralı yemek anahtarı listesi.
    public func availableKeys() -> [String] {
        densities.keys.sorted()
    }

    /// Belirli bir yemek için ortalama enerji (kcal/g) tahmini sağlar.
    /// Yoğunluk gibi gramajdan kaloriye dönüş için kullanılır.
    /// - Parameter foodKey: Yemek adı.
    /// - Returns: kcal/g cinsinden enerji yoğunluğu.
    public func energyDensity(for foodKey: String) -> Double {
        let normalized = Self.normalize(foodKey)
        switch normalized {
        case "pilav", "bulgur", "makarna", "kuskus": return 1.30
        case "et", "kofte", "kebap":                 return 2.50
        case "tavuk":                                return 1.90
        case "balik":                                return 1.80
        case "salata", "sebze", "domates", "kabak":  return 0.40
        case "corba":                                return 0.55
        case "yogurt", "cacik":                      return 0.65
        case "ekmek", "pide":                        return 2.65
        case "borek":                                return 3.10
        case "baklava":                              return 4.20
        case "sutlac":                               return 1.40
        case "kek":                                  return 3.50
        case "elma", "muz", "uzum":                  return 0.55
        default:                                     return 1.50
        }
    }

    // MARK: - Helpers

    /// Yemek anahtarını normalize eder: küçük harf, Türkçe karakter sadeleştirme,
    /// boşluk trim.
    private static func normalize(_ raw: String) -> String {
        let lower = raw.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let map: [Character: Character] = [
            "ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u"
        ]
        return String(lower.map { map[$0] ?? $0 })
    }
}
