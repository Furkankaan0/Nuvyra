import CoreGraphics
import Foundation

struct CameraDetection: Identifiable, Equatable {
    /// Stabilize ID by default to the label hash so that across frames the same
    /// detected object keeps the same SwiftUI identity (avoids ForEach reseating).
    /// Tracker layer may override with a UUID per-track.
    let id: AnyHashable
    let label: String
    let confidence: Float
    let boundingBox: CGRect

    init(
        id: AnyHashable? = nil,
        label: String,
        confidence: Float,
        boundingBox: CGRect
    ) {
        self.id = id ?? AnyHashable(label)
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
    }

    var confidencePercent: Int {
        Int((confidence * 100).rounded())
    }
}

enum CameraAuthorizationState: Equatable {
    case notDetermined
    case requestingAccess
    case authorized
    case denied
    case unavailable
}

enum CameraFeatureError: LocalizedError {
    case cameraUnavailable
    case cannotAddInput
    case cannotAddOutput
    case modelNotFound(String)

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "Kamera şu anda kullanılamıyor."
        case .cannotAddInput:
            return "Kamera girişi başlatılamadı."
        case .cannotAddOutput:
            return "Kamera görüntü akışı hazırlanamadı."
        case .modelNotFound(let modelName):
            return "\(modelName) Core ML modeli uygulama paketinde bulunamadı."
        }
    }
}

/// Canlı kamera detection'ı için makro tahmini üretirken oluşabilecek hatalar.
/// `CameraView`'in sonuç sheet'i bu mesajları kullanıcıya gösterir.
enum CameraEstimationError: LocalizedError {
    case emptyLabel
    case noEstimate(label: String)

    var errorDescription: String? {
        switch self {
        case .emptyLabel:
            return "Seçilen tahmin için etiket boş."
        case .noEstimate(let label):
            return "\"\(label)\" için besin değeri tahmini üretilemedi. Daha net bir kadrajla tekrar dene."
        }
    }
}
