//
//  GramEstimationService.swift
//  Nuvyra - Portion Estimator
//
//  Hacim + yoğunluk + güven aralığı bileşenlerini birleştirip
//  PortionEstimate üreten servis.
//

import Foundation

/// Hacim ve yemek etiketinden gramaj/kalori tahmini üreten servis.
public struct GramEstimationService: Sendable {

    // MARK: - Tunables

    /// ±%15 güven aralığı.
    public static let confidenceMargin: Double = 0.15

    // MARK: - Public API

    /// Verilen hacim, yemek etiketi ve sinyal kalitelerine göre PortionEstimate üretir.
    ///
    /// - Parameters:
    ///   - volumeCm3:     cm³ cinsinden hesaplanan hacim.
    ///   - foodLabel:     Tespit edilen yemek etiketi.
    ///   - inlierRatio:   RANSAC inlier oranı.
    ///   - sampleCount:   Düzlem üstü nokta sayısı.
    ///   - depthValidity: Bbox içi geçerli derinlik pikseli oranı.
    /// - Returns: Hesaplanmış PortionEstimate.
    public static func estimate(
        volumeCm3: Double,
        foodLabel: String,
        inlierRatio: Double,
        sampleCount: Int,
        depthValidity: Double
    ) -> PortionEstimate {

        let db = FoodDensityDatabase.shared
        let density = db.density(for: foodLabel)              // g/cm³
        let energy  = db.energyDensity(for: foodLabel)        // kcal/g

        let grams  = max(0, volumeCm3 * density)
        let lower  = grams * (1.0 - confidenceMargin)
        let upper  = grams * (1.0 + confidenceMargin)
        let kcal   = grams * energy

        let confidence = ConfidenceLevel.derive(
            inlierRatio: inlierRatio,
            sampleCount: sampleCount,
            depthValidity: depthValidity
        )

        return PortionEstimate(
            foodLabel: foodLabel,
            volumeCm3: volumeCm3,
            estimatedGrams: grams,
            lowerGrams: lower,
            upperGrams: upper,
            estimatedKcal: kcal,
            confidence: confidence
        )
    }

    /// Manuel girilen gram değerinden, hacmi tersine türeterek estimate üretir.
    /// LiDAR fallback akışında kullanılır.
    /// - Parameters:
    ///   - grams:     Kullanıcının girdiği gram değeri.
    ///   - foodLabel: Yemek etiketi (boşsa "default").
    /// - Returns: PortionEstimate (confidence: .medium varsayılır).
    public static func manualEstimate(
        grams: Double,
        foodLabel: String
    ) -> PortionEstimate {
        let db = FoodDensityDatabase.shared
        let density = db.density(for: foodLabel)
        let energy  = db.energyDensity(for: foodLabel)
        let volume  = density > 0 ? grams / density : 0
        let lower   = grams * (1.0 - confidenceMargin)
        let upper   = grams * (1.0 + confidenceMargin)

        return PortionEstimate(
            foodLabel: foodLabel.isEmpty ? "default" : foodLabel,
            volumeCm3: volume,
            estimatedGrams: grams,
            lowerGrams: lower,
            upperGrams: upper,
            estimatedKcal: grams * energy,
            confidence: .medium
        )
    }
}
