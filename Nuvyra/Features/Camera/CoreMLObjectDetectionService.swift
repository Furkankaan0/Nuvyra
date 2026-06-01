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
    /// Reuse'a uygun tek bir request — her frame için yeniden alloc etmek
    /// allocation pressure yaratır ve cache'i ısıtmaz. Frame'ler tek serial
    /// queue'dan (videoOutputQueue) geldiği için VNRequest reuse'u thread-safe.
    private let coreMLRequest: VNCoreMLRequest?
    private let fallbackClassifyRequest = VNClassifyImageRequest()

    init(modelProvider: ObjectDetectionModelProviding = BundledObjectDetectionModelProvider()) {
        let result = Result { try modelProvider.makeVisionModel() }
        modelLoadResult = result
        if case .success(let model) = result {
            let request = VNCoreMLRequest(model: model)
            request.imageCropAndScaleOption = .scaleFit
            coreMLRequest = request
        } else {
            coreMLRequest = nil
        }
    }

    var isModelAvailable: Bool {
        if case .success = modelLoadResult { return true }
        return false
    }

    var usesVisionFallbackClassifier: Bool {
        !isModelAvailable
    }

    func detectObjects(
        in sampleBuffer: CMSampleBuffer,
        orientation: CGImagePropertyOrientation = .right
    ) throws -> [CameraDetection] {
        guard let request = coreMLRequest else {
            return try classifyImage(in: sampleBuffer, orientation: orientation)
        }

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
                    label: VisionLabelTranslator.translate(bestLabel.identifier),
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
                        label: VisionLabelTranslator.translate(observation.identifier),
                        confidence: observation.confidence,
                        boundingBox: CGRect(x: 0.12, y: 0.18, width: 0.76, height: 0.64)
                    )
                }
        }

        return []
    }

    private func classifyImage(
        in sampleBuffer: CMSampleBuffer,
        orientation: CGImagePropertyOrientation
    ) throws -> [CameraDetection] {
        let handler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: orientation,
            options: [:]
        )
        try handler.perform([fallbackClassifyRequest])

        return (fallbackClassifyRequest.results ?? [])
            .filter { $0.confidence >= 0.18 }
            .prefix(3)
            .map { observation in
                CameraDetection(
                    label: VisionLabelTranslator.translate(observation.identifier),
                    confidence: observation.confidence,
                    boundingBox: CGRect(x: 0.14, y: 0.18, width: 0.72, height: 0.64)
                )
            }
    }
}
