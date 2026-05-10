import AVFoundation
import CoreMedia
import Foundation
import ImageIO
import Vision

@MainActor
final class CameraViewModel: ObservableObject {
    @Published private(set) var authorizationState: CameraAuthorizationState = .notDetermined
    @Published private(set) var detections: [CameraDetection] = []
    @Published private(set) var candidates: [EstimatedMealResult] = []
    @Published private(set) var statusMessage = "Kamera hazırlanıyor."
    @Published private(set) var isRunning = false
    @Published private(set) var isAnalyzing = false
    @Published private(set) var isFrozen = false
    @Published private(set) var capabilityLabel: String

    private let frameCaptureService: CameraFrameCaptureService
    private let visionService: FoodVisionService
    private let labelMapper: FoodLabelMapper
    private let stabilizer: FoodDetectionStabilizer

    var previewSession: AVCaptureSession {
        frameCaptureService.captureSession
    }

    init(
        frameCaptureService: CameraFrameCaptureService = CameraFrameCaptureService(maxFramesPerSecond: 4),
        visionService: FoodVisionService = CompositeFoodVisionService(),
        labelMapper: FoodLabelMapper = FoodLabelMapper(),
        stabilizer: FoodDetectionStabilizer = FoodDetectionStabilizer()
    ) {
        self.frameCaptureService = frameCaptureService
        self.visionService = visionService
        self.labelMapper = labelMapper
        self.stabilizer = stabilizer
        self.capabilityLabel = visionService.capability.humanReadable
        self.authorizationState = frameCaptureService.authorizationState()

        self.frameCaptureService.onFrame = { [weak self] wrapped in
            guard let self else { return }
            Task { @MainActor in self.handleLiveFrame(wrapped) }
        }
    }

    // MARK: - Lifecycle

    func start() async {
        authorizationState = .requestingAccess
        statusMessage = "Kamera izni kontrol ediliyor."

        let granted = await frameCaptureService.requestAccessIfNeeded()
        guard granted else {
            authorizationState = .denied
            statusMessage = "Kamera izni kapalı. Fotoğrafla öğün için Ayarlar'dan izni aç."
            isRunning = false
            return
        }

        authorizationState = .authorized

        do {
            try frameCaptureService.startRunning()
            isRunning = true
            statusMessage = visionService.isReady
                ? "Kamera aktif. Bir öğünü kadraja al ve sabit tut."
                : "Görsel sınıflandırıcı yüklenemedi. Manuel öğün eklemeyi kullanabilirsin."
        } catch {
            authorizationState = .unavailable
            isRunning = false
            statusMessage = error.localizedDescription
        }
    }

    func stop() {
        frameCaptureService.stopRunning()
        frameCaptureService.cancelPendingSnapshot()
        stabilizer.reset()
        isRunning = false
    }

    // MARK: - Live frame pipeline

    private func handleLiveFrame(_ wrapped: SendableSampleBuffer) {
        guard !isFrozen, visionService.isReady else { return }
        Task { [weak self] in
            await self?.analyzeLive(wrapped)
        }
    }

    private func analyzeLive(_ wrapped: SendableSampleBuffer) async {
        do {
            let raw = try await visionService.analyze(wrapped, orientation: .right)
            let stable = stabilizer.ingest(raw).map(\.asCameraDetection)
            guard !isFrozen else { return }
            self.detections = stable
            self.candidates = self.labelMapper.map(stable)
            self.refreshStatus()
        } catch {
            // Silently drop bad frames; status message refresh on next good frame.
        }
    }

    // MARK: - Shutter / freeze mode

    /// Captures the next available frame, runs a focused analysis, and freezes the UI on results.
    func captureSnapshot() {
        guard isRunning, visionService.isReady, !isAnalyzing else { return }
        isAnalyzing = true
        statusMessage = "Kareyi analiz ediyorum..."

        frameCaptureService.captureNextFrame { [weak self] wrapped in
            guard let self else { return }
            Task { await self.analyzeSnapshot(wrapped) }
        }
    }

    private func analyzeSnapshot(_ wrapped: SendableSampleBuffer) async {
        do {
            let raw = try await visionService.analyze(wrapped, orientation: .right)
            let mapped = labelMapper.map(raw)
            self.detections = raw.sorted { $0.confidence > $1.confidence }
            self.candidates = mapped
            self.isFrozen = true
            self.isAnalyzing = false
            self.statusMessage = mapped.isEmpty
                ? "Görüntüden öğün çıkaramadım. Tekrar dene veya manuel ekle."
                : "\(mapped.count) aday hazır. Birini seç ya da yeniden çek."
        } catch {
            self.isAnalyzing = false
            self.statusMessage = "Analiz başarısız oldu. Tekrar dene."
        }
    }

    func resumeLivePreview() {
        isFrozen = false
        candidates = []
        detections = []
        stabilizer.reset()
        statusMessage = "Kamera aktif. Bir öğünü kadraja al."
    }

    // MARK: - Status helper

    private func refreshStatus() {
        if isFrozen { return }
        if let top = candidates.first {
            statusMessage = "\(top.name) — %\(Int((top.confidence * 100).rounded())) güven"
        } else if detections.isEmpty {
            statusMessage = "Bir öğünü kadraja al ve sabit tut."
        }
    }
}

// MARK: - Preview helper

extension CameraViewModel {
    static func preview() -> CameraViewModel {
        let vm = CameraViewModel(
            frameCaptureService: CameraFrameCaptureService(maxFramesPerSecond: 4),
            visionService: MockFoodVisionService()
        )
        let stub = [
            CameraDetection(label: "pizza", confidence: 0.91, boundingBox: CGRect(x: 0.18, y: 0.22, width: 0.62, height: 0.54))
        ]
        vm.detections = stub
        vm.candidates = FoodLabelMapper().map(stub)
        vm.statusMessage = "Pizza — %91 güven"
        return vm
    }
}
