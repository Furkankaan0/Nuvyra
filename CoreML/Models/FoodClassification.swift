//
//  FoodClassification.swift
//  Nuvyra Core ML
//
//  FoodClassifier'ın döndürdüğü tek bir tahmin sonucu + sıralı liste.
//

import Foundation
import CoreGraphics

/// Tek bir sınıflandırma tahmini.
public struct FoodPrediction: Equatable, Sendable {

    /// Modelin çıkış etiketi.
    public let category: FoodCategory

    /// 0...1 arası güven (softmax çıkışı).
    public let confidence: Float

    /// Opsiyonel bounding box (saliency varsa). Vision normalize (0...1).
    public let boundingBox: CGRect?

    public init(
        category: FoodCategory,
        confidence: Float,
        boundingBox: CGRect? = nil
    ) {
        self.category = category
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

/// Tüm sıralı tahminler (top-K) ile birlikte en yüksek skoru.
public struct FoodClassificationResult: Sendable {

    public let topPrediction: FoodPrediction
    public let candidates: [FoodPrediction]

    public init(topPrediction: FoodPrediction, candidates: [FoodPrediction]) {
        self.topPrediction = topPrediction
        self.candidates = candidates
    }

    /// İlk K tahmin.
    public func top(_ k: Int) -> [FoodPrediction] {
        Array(candidates.prefix(k))
    }
}

/// Core ML akışında öngörülebilir hatalar.
public enum FoodClassifierError: LocalizedError, Sendable {
    case modelNotLoaded
    case modelFileMissing(String)
    case visionRequestFailed(String)
    case lowConfidence(Float)

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Sınıflandırıcı henüz yüklenmedi."
        case .modelFileMissing(let name):
            return "Model dosyası bulunamadı: \(name)"
        case .visionRequestFailed(let msg):
            return "Vision isteği başarısız: \(msg)"
        case .lowConfidence(let c):
            return "Düşük güvenli tahmin: \(Int(c * 100))%."
        }
    }
}
