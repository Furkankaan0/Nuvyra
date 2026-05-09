//
//  ConfidenceLevel.swift
//  Nuvyra - Portion Estimator
//
//  Ölçüm güvenilirliğini düşük/orta/yüksek olarak sınıflandıran enum.
//

import SwiftUI

/// Hesaplanan ölçümün ne kadar güvenilir olduğunu temsil eder.
public enum ConfidenceLevel: String, CaseIterable, Sendable {
    case low
    case medium
    case high

    // MARK: - Display

    /// Türkçe etiket.
    public var localizedLabel: String {
        switch self {
        case .low:    return "Düşük"
        case .medium: return "Orta"
        case .high:   return "Yüksek"
        }
    }

    /// İndikatör için görsel renk.
    public var tintColor: Color {
        switch self {
        case .low:    return .red
        case .medium: return .orange
        case .high:   return .green
        }
    }

    /// 0...1 arasında dolu bar oranı.
    public var fillRatio: Double {
        switch self {
        case .low:    return 0.33
        case .medium: return 0.66
        case .high:   return 1.00
        }
    }

    // MARK: - Heuristics

    /// Pipeline'dan gelen sinyallere göre güvenilirlik seviyesi türetir.
    /// - Parameters:
    ///   - inlierRatio:    RANSAC sonucundaki inlier oranı (0...1).
    ///   - sampleCount:    Hacim hesabında kullanılan derinlik nokta sayısı.
    ///   - depthValidity:  Geçerli derinlik piksellerinin oranı (0...1).
    /// - Returns: Türetilmiş ConfidenceLevel.
    public static func derive(
        inlierRatio: Double,
        sampleCount: Int,
        depthValidity: Double
    ) -> ConfidenceLevel {
        // Ağırlıklı skor (0...1)
        let score = (inlierRatio * 0.45)
                  + (depthValidity * 0.35)
                  + (min(Double(sampleCount) / 4000.0, 1.0) * 0.20)

        switch score {
        case ..<0.45:  return .low
        case ..<0.75:  return .medium
        default:       return .high
        }
    }
}
