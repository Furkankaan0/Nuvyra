import Combine
import AVFoundation
import Foundation
import Vision

final class CameraViewModel: ObservableObject {
    @Published private(set) var authorizationState: CameraAuthorizationState = .notDetermined
    @Published private(set) var detections: [CameraDetection] = []
    @Published private(set) var statusMessage = "Kamera hazırlanıyor."
    @Published private(set) var isRunning = false

    private let frameCaptureService: CameraFrameCaptureService
    private let objectDetector: CoreMLObjectDetectionService
    private var didPublishModelMissingState = false

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
            statusMessage = "Kamera izni kapalı. Fotoğrafla öğün tanıma için Ayarlar'dan kamera iznini açabilirsin."
            isRunning = false
            return
        }

        authorizationState = .authorized

        do {
            try frameCaptureService.startRunning()
            isRunning = true
            statusMessage = objectDetector.isModelAvailable
                ? "Kamera aktif. Öğünü kadraja al."
                : "Core ML modeli eklenmedi. NuvyraFoodDetector.mlmodel eklendiğinde canlı tahmin başlayacak."
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
        guard objectDetector.isModelAvailable else {
            publishModelMissingStateIfNeeded()
            return
        }

        do {
            let results = try objectDetector.detectObjects(in: sampleBuffer)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.detections = results
                self.statusMessage = results.first.map {
                    "\($0.label): %\($0.confidencePercent) olasılık"
                } ?? "Kadraja bir öğün aldığında tahmin burada görünür."
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.statusMessage = "Görüntü analiz edilemedi. Kamerayı biraz daha sabit tut."
            }
        }
    }

    private func publishModelMissingStateIfNeeded() {
        guard !didPublishModelMissingState else { return }
        didPublishModelMissingState = true
        DispatchQueue.main.async { [weak self] in
            self?.detections = []
            self?.statusMessage = "Core ML modeli bekleniyor. Model eklendiğinde kareler VNCoreMLRequest ile analiz edilecek."
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
        viewModel.statusMessage = "Elma: %90 olasılık"
        return viewModel
    }
}

private struct PreviewObjectDetectionModelProvider: ObjectDetectionModelProviding {
    func makeVisionModel() throws -> VNCoreMLModel {
        throw CameraFeatureError.modelNotFound("Preview")
    }
}
