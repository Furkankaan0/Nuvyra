import AVFoundation
import Combine
import Foundation
import Vision

final class CameraViewModel: ObservableObject {
    @Published private(set) var authorizationState: CameraAuthorizationState = .notDetermined
    @Published private(set) var detections: [CameraDetection] = []
    @Published private(set) var statusMessage = "Kamera hazirlaniyor."
    @Published private(set) var isRunning = false

    private let frameCaptureService: CameraFrameCaptureService
    private let objectDetector: CoreMLObjectDetectionService

    var previewSession: AVCaptureSession {
        frameCaptureService.captureSession
    }

    init(
        frameCaptureService: CameraFrameCaptureService = CameraFrameCaptureService(maxFramesPerSecond: 4),
        objectDetector: CoreMLObjectDetectionService = CoreMLObjectDetectionService()
    ) {
        self.frameCaptureService = frameCaptureService
        self.objectDetector = objectDetector
        authorizationState = frameCaptureService.authorizationState()
        self.frameCaptureService.onFrame = { [weak self] sampleBuffer in
            self?.processFrame(sampleBuffer)
        }
    }

    @MainActor
    func start() async {
        authorizationState = .requestingAccess
        statusMessage = "Kamera izni kontrol ediliyor."

        let granted = await frameCaptureService.requestAccessIfNeeded()
        guard granted else {
            authorizationState = .denied
            statusMessage = "Kamera izni kapali. Fotografli ogun tanima icin Ayarlar'dan kamera iznini acabilirsin."
            isRunning = false
            return
        }

        authorizationState = .authorized

        do {
            try frameCaptureService.startRunning()
            isRunning = true
            statusMessage = objectDetector.isModelAvailable
                ? "Kamera aktif. Ogunu kadraja al."
                : "Kamera aktif. Core ML modeli yokken Vision fallback ile tahmini etiket olusturuluyor."
        } catch {
            authorizationState = .unavailable
            isRunning = false
            statusMessage = error.localizedDescription
        }
    }

    @MainActor
    func stop() {
        frameCaptureService.stopRunning()
        isRunning = false
    }

    private func processFrame(_ sampleBuffer: CMSampleBuffer) {
        do {
            let results = try objectDetector.detectObjects(in: sampleBuffer)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.detections = results
                self.statusMessage = results.first.map {
                    "\($0.label): %\($0.confidencePercent) olasilik"
                } ?? (self.objectDetector.usesVisionFallbackClassifier
                    ? "Vision fallback aktif. Ogunu daha aydinlik ve yakin kadraja al."
                    : "Kadraja bir ogun aldiginda tahmin burada gorunur.")
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.statusMessage = "Goruntu analiz edilemedi. Kamerayi biraz daha sabit tut."
            }
        }
    }
}

extension CameraViewModel {
    static func preview() -> CameraViewModel {
        let viewModel = CameraViewModel(
            frameCaptureService: CameraFrameCaptureService(maxFramesPerSecond: 4),
            objectDetector: CoreMLObjectDetectionService(modelProvider: PreviewObjectDetectionModelProvider())
        )
        viewModel.detections = [
            CameraDetection(
                label: "Elma",
                confidence: 0.90,
                boundingBox: CGRect(x: 0.18, y: 0.24, width: 0.42, height: 0.38)
            )
        ]
        viewModel.statusMessage = "Elma: %90 olasilik"
        return viewModel
    }
}

private struct PreviewObjectDetectionModelProvider: ObjectDetectionModelProviding {
    func makeVisionModel() throws -> VNCoreMLModel {
        throw CameraFeatureError.modelNotFound("Preview")
    }
}
