import CoreMedia
import CoreML
import Foundation
import ImageIO
import Vision

protocol ObjectDetectionModelProviding {
    func makeVisionModel() throws -> VNCoreMLModel
}

struct BundledObjectDetectionModelProvider: ObjectDetectionModelProviding {
    var modelName = "NuvyraFoodDetector"

    func makeVisionModel() throws -> VNCoreMLModel {
        guard let compiledModelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
            throw CameraFeatureError.modelNotFound(modelName)
        }

        let model = try MLModel(contentsOf: compiledModelURL)
        return try VNCoreMLModel(for: model)
    }
}

final class CoreMLObjectDetectionService {
    private let modelLoadResult: Result<VNCoreMLModel, Error>

    init(modelProvider: ObjectDetectionModelProviding = BundledObjectDetectionModelProvider()) {
        modelLoadResult = Result { try modelProvider.makeVisionModel() }
    }

    var isModelAvailable: Bool {
        if case .success = modelLoadResult { return true }
        return false
    }

    func detectObjects(
        in sampleBuffer: CMSampleBuffer,
        orientation: CGImagePropertyOrientation = .right
    ) throws -> [CameraDetection] {
        let model = try modelLoadResult.get()
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .centerCrop

        let handler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: orientation,
            options: [:]
        )
        try handler.perform([request])

        if let objectResults = request.results as? [VNRecognizedObjectObservation] {
            return objectResults.compactMap { observation in
                guard let bestLabel = observation.labels.first else { return nil }
                return CameraDetection(
                    label: bestLabel.identifier,
                    confidence: bestLabel.confidence,
                    boundingBox: observation.boundingBox
                )
            }
            .filter { $0.confidence >= 0.35 }
            .sorted { $0.confidence > $1.confidence }
        }

        if let classificationResults = request.results as? [VNClassificationObservation] {
            return classificationResults
                .filter { $0.confidence >= 0.35 }
                .prefix(3)
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
