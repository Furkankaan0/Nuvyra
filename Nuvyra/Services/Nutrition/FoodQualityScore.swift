import Foundation
import SwiftUI

/// Simple, transparent 0–100 quality score for a day's nutrition rollup.
/// Wellness-positive framing: gains for hitting fiber, gentle penalties for going
/// over sodium / sugar / saturated-fat ceilings. **No** medical claim; this is
/// purely a relative coaching signal.
enum FoodQualityScore {
    static func score(totals: NutritionValues, target: MacroTarget) -> Int {
        var score: Double = 100

        // Fiber: reward proximity to target (full credit at >= target, partial credit otherwise).
        let fiberRatio = target.fiberGrams > 0 ? totals.fiber / Double(target.fiberGrams) : 1
        if fiberRatio < 1 {
            score -= (1 - min(max(fiberRatio, 0), 1)) * 25
        }

        // Sodium ceiling: linear penalty up to 2x target.
        let sodiumRatio = target.sodiumMg > 0 ? totals.sodium / Double(target.sodiumMg) : 0
        if sodiumRatio > 1 {
            score -= min((sodiumRatio - 1), 1) * 25
        }

        // Sugar ceiling.
        let sugarRatio = target.sugarGrams > 0 ? totals.sugar / Double(target.sugarGrams) : 0
        if sugarRatio > 1 {
            score -= min((sugarRatio - 1), 1) * 25
        }

        // Saturated fat ceiling.
        let satRatio = target.saturatedFatGrams > 0 ? totals.saturatedFat / Double(target.saturatedFatGrams) : 0
        if satRatio > 1 {
            score -= min((satRatio - 1), 1) * 25
        }

        return Int(max(min(score, 100), 0).rounded())
    }

    static func grade(_ score: Int) -> Grade {
        switch score {
        case 85...: .excellent
        case 70..<85: .good
        case 50..<70: .fair
        default: .needsAttention
        }
    }
}

extension FoodQualityScore {
    enum Grade {
        case excellent, good, fair, needsAttention

        var title: String {
            switch self {
            case .excellent: "Mükemmel"
            case .good: "İyi"
            case .fair: "Orta"
            case .needsAttention: "Geliştirilebilir"
            }
        }

        var caption: String {
            switch self {
            case .excellent: "Lif, sodyum ve şeker dengesi tamam"
            case .good: "Çoğu hedefini yakalıyorsun"
            case .fair: "Birkaç alanı dengelemek faydalı olur"
            case .needsAttention: "Lif artırmak, sodyum/şeker azaltmak yardımcı olur"
            }
        }

        var tint: Color {
            switch self {
            case .excellent: NuvyraColors.accent
            case .good: NuvyraColors.softMint
            case .fair: NuvyraColors.softSand
            case .needsAttention: NuvyraColors.mutedCoral
            }
        }
    }
}
