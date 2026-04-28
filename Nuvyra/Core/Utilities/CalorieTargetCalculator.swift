import Foundation

struct CalorieTargetCalculator {
    func target(for profile: UserProfile) -> CalorieTarget {
        let bmr = basalMetabolicRate(profile: profile)
        let activityMultiplier: Double = switch profile.activityLevel {
        case .low: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        }
        let maintenance = bmr * activityMultiplier
        let adjusted: Double = switch profile.goal {
        case .loseWeight: maintenance - 350
        case .eatMoreRegularly: maintenance - 100
        case .walkMore: maintenance
        case .maintainWeight: maintenance
        case .buildHealthRhythm: maintenance - 150
        }
        let recommended = max(Int(adjusted.rounded(toNearest: 50)), 1_350)
        return CalorieTarget(lowerBound: recommended - 150, upperBound: recommended + 150, recommended: recommended)
    }

    private func basalMetabolicRate(profile: UserProfile) -> Double {
        let base = 10 * profile.weightKilograms + 6.25 * Double(profile.heightCentimeters) - 5 * Double(profile.age)
        switch profile.gender {
        case .female: return base - 161
        case .male: return base + 5
        case .other, .preferNotToSay: return base - 78
        }
    }
}

private extension Double {
    func rounded(toNearest step: Double) -> Double {
        (self / step).rounded() * step
    }
}
