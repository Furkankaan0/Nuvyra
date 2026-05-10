import CoreMedia
import CoreML
import Foundation
import ImageIO
import Vision

// MARK: - Public API

enum FoodVisionCapability: Equatable, Sendable {
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

protocol FoodVisionService: Sendable {
    var capability: FoodVisionCapability { get }
    var isReady: Bool { get }
    func analyze(_ sample: SendableSampleBuffer, orientation: CGImagePropertyOrientation) async throws -> [CameraDetection]
}

// MARK: - Bundled custom model (NuvyraFoodDetector)

protocol BundledFoodModelProviding: Sendable {
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

final class BundledFoodVisionService: FoodVisionService, @unchecked Sendable {
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

    func analyze(_ sample: SendableSampleBuffer, orientation: CGImagePropertyOrientation) async throws -> [CameraDetection] {
        let model = try modelLoadResult.get()
        // Synchronous Vision pipeline avoids non-Sendable captures across actor
        // boundaries (Xcode 26 marks VNRequestCompletionHandler as @Sendable).
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .centerCrop
        let handler = VNImageRequestHandler(
            cmSampleBuffer: sample.buffer,
            orientation: orientation,
            options: [:]
        )
        try handler.perform([request])
        return Self.extractDetections(
            from: request.results,
            confidenceThreshold: confidenceThreshold,
            maxResults: maxResults
        )
    }

    private static func extractDetections(
        from results: [VNObservation]?,
        confidenceThreshold: Float,
        maxResults: Int
    ) -> [CameraDetection] {
        guard let results else { return [] }

        if let objectResults = results as? [VNRecognizedObjectObservation] {
            let mapped = objectResults.compactMap { observation -> CameraDetection? in
                guard let bestLabel = observation.labels.first else { return nil }
                return CameraDetection(
                    label: bestLabel.identifier,
                    confidence: bestLabel.confidence,
                    boundingBox: observation.boundingBox
                )
            }
            .filter { $0.confidence >= confidenceThreshold }
            .sorted { $0.confidence > $1.confidence }
            return Array(mapped.prefix(maxResults))
        }

        if let classificationResults = results as? [VNClassificationObservation] {
            let mapped = classificationResults
                .filter { $0.confidence >= confidenceThreshold }
                .prefix(maxResults)
                .map { observation in
                    CameraDetection(
                        label: observation.identifier,
                        confidence: observation.confidence,
                        boundingBox: CGRect(x: 0.12, y: 0.18, width: 0.76, height: 0.64)
                    )
                }
            return Array(mapped)
        }

        return []
    }
}

// MARK: - Apple Vision built-in classifier (fallback)

final class AppleVisionFoodService: FoodVisionService, @unchecked Sendable {
    private let confidenceThreshold: Float
    private let maxResults: Int

    init(confidenceThreshold: Float = 0.18, maxResults: Int = 5) {
        self.confidenceThreshold = confidenceThreshold
        self.maxResults = maxResults
    }

    var capability: FoodVisionCapability { .visionFramework }
    var isReady: Bool { true }

    func analyze(_ sample: SendableSampleBuffer, orientation: CGImagePropertyOrientation) async throws -> [CameraDetection] {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(
            cmSampleBuffer: sample.buffer,
            orientation: orientation,
            options: [:]
        )
        try handler.perform([request])

        let observations = (request.results as? [VNClassificationObservation]) ?? []
        let mapped = observations
            .filter { $0.confidence >= confidenceThreshold }
            .prefix(maxResults * 2)
            .map { observation in
                CameraDetection(
                    label: observation.identifier,
                    confidence: observation.confidence,
                    boundingBox: CGRect(x: 0.10, y: 0.16, width: 0.80, height: 0.68)
                )
            }
        return Array(mapped)
    }
}

// MARK: - Composite (prefers bundled, falls back to Vision framework)

/// Tries the bundled custom model first; falls back to Apple Vision's built-in classifier.
final class CompositeFoodVisionService: FoodVisionService, @unchecked Sendable {
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

    func analyze(_ sample: SendableSampleBuffer, orientation: CGImagePropertyOrientation) async throws -> [CameraDetection] {
        if primary.isReady {
            return try await primary.analyze(sample, orientation: orientation)
        }
        return try await fallback.analyze(sample, orientation: orientation)
    }
}

// MARK: - Mock (preview / tests)

final class MockFoodVisionService: FoodVisionService, @unchecked Sendable {
    var capability: FoodVisionCapability = .visionFramework
    var isReady: Bool = true
    var stub: [CameraDetection]

    init(stub: [CameraDetection] = [
        CameraDetection(label: "pizza", confidence: 0.91, boundingBox: CGRect(x: 0.18, y: 0.22, width: 0.62, height: 0.54))
    ]) {
        self.stub = stub
    }

    func analyze(_ sample: SendableSampleBuffer, orientation: CGImagePropertyOrientation) async throws -> [CameraDetection] {
        stub
    }
}
