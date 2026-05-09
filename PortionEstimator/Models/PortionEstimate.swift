//
//  PortionEstimate.swift
//  Nuvyra - Portion Estimator
//
//  Hacim, gramaj ve güven aralığı bilgilerini taşıyan domain model.
//

import Foundation

/// Tek bir porsiyon ölçümünün sonucu.
public struct PortionEstimate: Equatable, Sendable {

    /// Tespit edilen yemek etiketi (örn. "pilav").
    public let foodLabel: String

    /// Hesaplanan hacim (cm³).
    public let volumeCm3: Double

    /// Yoğunlukla çarpılarak elde edilen tahmini gramaj (g).
    public let estimatedGrams: Double

    /// ±%15 güven aralığı için alt sınır (g).
    public let lowerGrams: Double

    /// ±%15 güven aralığı için üst sınır (g).
    public let upperGrams: Double

    /// Tahmini enerji (kcal).
    public let estimatedKcal: Double

    /// Ölçüm güvenilirlik seviyesi.
    public let confidence: ConfidenceLevel

    /// Ölçüm zamanı.
    public let timestamp: Date

    // MARK: - Init

    /// Tüm alanları doğrudan alan tam constructor.
    public init(
        foodLabel: String,
        volumeCm3: Double,
        estimatedGrams: Double,
        lowerGrams: Double,
        upperGrams: Double,
        estimatedKcal: Double,
        confidence: ConfidenceLevel,
        timestamp: Date = .now
    ) {
        self.foodLabel = foodLabel
        self.volumeCm3 = volumeCm3
        self.estimatedGrams = estimatedGrams
        self.lowerGrams = lowerGrams
        self.upperGrams = upperGrams
        self.estimatedKcal = estimatedKcal
        self.confidence = confidence
        self.timestamp = timestamp
    }

    // MARK: - Display

    /// UI'da göstermeye hazır birincil özet metin.
    /// Örn: "Tahmini: 185g ± 28g | 267 kcal"
    public var displaySummary: String {
        let g  = Int(estimatedGrams.rounded())
        let dg = Int(((upperGrams - lowerGrams) / 2.0).rounded())
        let kc = Int(estimatedKcal.rounded())
        return "Tahmini: \(g)g ± \(dg)g | \(kc) kcal"
    }
}
