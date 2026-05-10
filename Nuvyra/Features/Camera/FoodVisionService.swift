import CoreMedia
import CoreML
import Foundation
import ImageIO
import Vision

// MARK: - Public API

enum FoodVisionCapability: Equatable {
    case bundledModel(String)   // Custom Core ML model present in app bundle
    case visionFramework        // Apple's built-in image classifier (fallback)
    case unavailable

    var humanReadable: String {
        switch self {
        case .bundledModel(let name): return "Cihaz içi \(name) modeli"
        case .visionFramework: return "Apple Vision sınıflandırıcı"
        case .unavailable: return "Görsel tahmin kullanılamıyor"
        }
    }
}

protocol FoodVisionService {
    var capability: FoodVisionCapability { get }
    var isReady: Bool { get }
    func analyze(_ sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) async throws -> [CameraDetection]
}

// MARK: - Bundled custom model (NuvyraFoodDetector)

protocol BundledFoodModelProviding {
    var modelName: String { get }
    func makeVisionModel() throws -> VNCoreMLModel
}

struct DefaultBundledFoodModelProvider: BundledFoodModelProviding {
    var modelName = "NuvyraFoodDetector"

    func makeVisionModel() throws -> VNCoreMLModel {
        guard let compiledModelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
            throw CameraFeatureError.modelNotFound(modelName)
        }
        let model = try MLModel(contentsOf: compiledModelURL)
        return try VNCoreMLModel(for: model)
    }
}

final class BundledFoodVisionService: FoodVisionService {
    private let provider: BundledFoodModelProviding
    private let modelLoadResult: Result<VNCoreMLModel, Error>
    private let confidenceThreshold: Float
    private let maxResults: Int

    init(
        provider: BundledFoodModelProviding = DefaultBundledFoodModelProvider(),
        confidenceThreshold: Float = 0.30,
        maxResults: Int = 5
    ) {
        self.provider = provider
        self.confidenceThreshold = confidenceThreshold
        self.maxResults = maxResults
        self.modelLoadResult = Result { try provider.makeVisionModel() }
    }

    var capability: FoodVisionCapability {
        switch modelLoadResult {
        case .success: return .bundledModel(provider.modelName)
        case .failure: return .unavailable
        }
    }

    var isReady: Bool {
        if case .success = modelLoadResult { return true }
        return false
    }

    func analyze(_ sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) async throws -> [CameraDetection] {
        let model = try modelLoadResult.get()
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let detections = Self.extractDetections(
                    from: request.results,
                    confidenceThreshold: self.confidenceThreshold,
                    maxResults: self.maxResults
                )
                continuation.resume(returning: detections)
            }
            request.imageCropAndScaleOption = .centerCrop

            let handler = VNImageRequestHandler(
                cmSampleBuffer: sampleBuffer,
                orientation: orientation,
                options: [:]
            )

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func extractDetections(
        from results: [VNObservation]?,
        confidenceThreshold: Float,
        maxResults: Int
    ) -> [CameraDetection] {
        guard let results else { return [] }

        if let objectResults = results as? [VNRecognizedObjectObservation] {
            return objectResults.compactMap { observation in
                guard let bestLabel = observation.labels.first else { return nil }
                return CameraDetection(
                    label: bestLabel.identifier,
                    confidence: bestLabel.confidence,
                    boundingBox: observation.boundingBox
                )
            }
            .filter { $0.confidence >= confidenceThreshold }
            .sorted { $0.confidence > $1.confidence }
            .prefix(maxResults)
            .map { $0 }
        }

        if let classificationResults = results as? [VNClassificationObservation] {
            return classificationResults
                .filter { $0.confidence >= confidenceThreshold }
                .prefix(maxResults)
                .map { observation in
                    CameraDetection(
                        label: observation.identifier,
                        confidence: observation.confidence,
                        boundingBox: CGRect(x: 0.12, y: 0.18, width: 0.76, height: 0.64)
                    )
                }
        }

        return []
    }
}

// MARK: - Apple Vision built-in classifier (fallback)

final class AppleVisionFoodService: FoodVisionService {
    private let confidenceThreshold: Float
    private let maxResults: Int

    init(confidenceThreshold: Float = 0.18, maxResults: Int = 5) {
        self.confidenceThreshold = confidenceThreshold
        self.maxResults = maxResults
    }

    var capability: FoodVisionCapability { .visionFramework }
    var isReady: Bool { true } // Always available on iOS 13+

    func analyze(_ sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) async throws -> [CameraDetection] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNClassificationObservation]) ?? []
                let detections = observations
                    .filter { $0.confidence >= self.confidenceThreshold }
                    .prefix(self.maxResults * 2) // wider net before mapping
                    .map { observation in
                        CameraDetection(
                            label: observation.identifier,
                            confidence: observation.confidence,
                            boundingBox: CGRect(x: 0.10, y: 0.16, width: 0.80, height: 0.68)
                        )
                    }
                continuation.resume(returning: Array(detections))
            }

            let handler = VNImageRequestHandler(
                cmSampleBuffer: sampleBuffer,
                orientation: orientation,
                options: [:]
            )

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - Composite (prefers bundled, falls back to Vision framework)

/// Tries the bundled custom model first; falls back to Apple Vision's built-in classifier.
/// This is the recommended default — works without any model file present, and silently
/// upgrades to the custom model when one is added to the bundle.
final class CompositeFoodVisionService: FoodVisionService {
    private let primary: FoodVisionService
    private let fallback: FoodVisionService

    init(
        primary: FoodVisionService = BundledFoodVisionService(),
        fallback: FoodVisionService = AppleVisionFoodService()
    ) {
        self.primary = primary
        self.fallback = fallback
    }

    var capability: FoodVisionCapability {
        primary.isReady ? primary.capability : fallback.capability
    }

    var isReady: Bool { primary.isReady || fallback.isReady }

    func analyze(_ sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) async throws -> [CameraDetection] {
        if primary.isReady {
            return try await primary.analyze(sampleBuffer, orientation: orientation)
        }
        return try await fallback.analyze(sampleBuffer, orientation: orientation)
    }
}

// MARK: - Mock (preview / tests)

final class MockFoodVisionService: FoodVisionService {
    var capability: FoodVisionCapability = .visionFramework
    var isReady: Bool = true
    var stub: [CameraDetection]

    init(stub: [CameraDetection] = [
        CameraDetection(label: "pizza", confidence: 0.91, boundingBox: CGRect(x: 0.18, y: 0.22, width: 0.62, height: 0.54))
    ]) {
        self.stub = stub
    }

    func analyze(_ sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) async throws -> [CameraDetection] {
        stub
    }
}
