import CoreGraphics
import Foundation

struct CameraDetection: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let confidence: Float
    let boundingBox: CGRect

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
