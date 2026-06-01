import AVFoundation
import Combine
import Foundation
import SwiftUI
import Vision

final class CameraViewModel: ObservableObject {
    /// Detection seçildiğinde besin değerleri çözümleme akışının state makinesi.
    /// SwiftUI tarafı doğrudan `pickState` üzerinden sheet'in içeriğini sürer.
    enum DetectionPickState: Equatable {
        case loading(label: String)
        case loaded(label: String, result: EstimatedMealResult)
        case failed(label: String, message: String)

        var label: String {
            switch self {
            case .loading(let label), .loaded(let label, _), .failed(let label, _):
                return label
            }
        }
    }

    /// Host tarafından (NutritionView) inject edilen tahmin servisi.
    /// Ham label string → makro tahmini. Test ve preview için optional bırakıldı;
    /// nil ise sheet "tahmin servisi yapılandırılmamış" hatasıyla açılır.
    typealias DetectionResolver = (String) async -> Result<EstimatedMealResult, Error>

    @Published private(set) var authorizationState: CameraAuthorizationState = .notDetermined
    @Published private(set) var detections: [CameraDetection] = []
    @Published private(set) var statusMessage = "Kamera hazirlaniyor."
    @Published private(set) var isRunning = false
    @Published private(set) var isInterrupted = false
    @Published var pickState: DetectionPickState?

    /// Host view tarafından `.task` içinde set edilir.
    var resolver: DetectionResolver?

    private let frameCaptureService: CameraFrameCaptureService
    private let objectDetector: CoreMLObjectDetectionService

    /// EMA tabanlı bbox tracking — her label için son birkaç frame'in pürüzsüz
    /// bbox/confidence ortalamasını tutar. Aşırı titreyen tahminleri kullanıcıya
    /// göstermez.
    private var detectionTracker = DetectionTracker(
        smoothingFactor: 0.55,
        staleAfterMissedFrames: 4
    )
    private var lastPublishedStatusKey: String?
    private var thermalObserver: NSObjectProtocol?
    private var powerObserver: NSObjectProtocol?
    private var currentFPSCap: Double?

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
        self.frameCaptureService.onInterruption = { [weak self] interrupted in
            // Notification queue main olduğu için doğrudan @Published'a yazabiliriz.
            self?.isInterrupted = interrupted
            if interrupted {
                self?.statusMessage = "Kamera kesintiye uğradı (telefon araması ya da başka uygulama). Geri dönünce devam edilecek."
            }
        }
        registerSystemPressureObservers()
    }

    deinit {
        if let thermalObserver { NotificationCenter.default.removeObserver(thermalObserver) }
        if let powerObserver { NotificationCenter.default.removeObserver(powerObserver) }
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
            applyCurrentSystemPressure()
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

    // MARK: - Detection picking

    /// Kullanıcı sonuç kartında bir detection'a dokununca çağrılır.
    /// Sheet'i `.loading` ile açar, resolver'ı çalıştırır, sonuç/hata ile
    /// state'i günceller. Kamera oturumu açık kalır — kullanıcı vazgeçerse
    /// arka planda taramaya devam ediyor olur.
    @MainActor
    func pickDetection(_ detection: CameraDetection) {
        let label = detection.label
        pickState = .loading(label: label)

        guard let resolver else {
            pickState = .failed(label: label, message: "Tahmin servisi yapılandırılmamış.")
            return
        }

        Task { [weak self] in
            let outcome = await resolver(label)
            await MainActor.run {
                guard let self else { return }
                // Kullanıcı arada sheet'i kapatmış olabilir — stale sonuç
                // açılmasın diye state'i kontrol et.
                guard let current = self.pickState, current.label == label else { return }
                switch outcome {
                case .success(let estimate):
                    self.pickState = .loaded(label: label, result: estimate)
                case .failure(let error):
                    self.pickState = .failed(label: label, message: error.localizedDescription)
                }
            }
        }
    }

    /// Sheet'in "Tekrar dene" butonu.
    @MainActor
    func retryPick() {
        guard let label = pickState?.label else { return }
        pickDetection(CameraDetection(label: label, confidence: 1, boundingBox: .zero))
    }

    @MainActor
    func cancelPick() {
        pickState = nil
    }

    /// SwiftUI tarafında `.onChange(of: scenePhase)` ile çağrılır — background'a
    /// geçildiğinde kamera durur, foreground'a geri gelince yeniden başlar.
    @MainActor
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if !isRunning, authorizationState == .authorized {
                Task { await start() }
            }
        case .inactive, .background:
            if isRunning { stop() }
        @unknown default:
            break
        }
    }

    private func processFrame(_ sampleBuffer: CMSampleBuffer) {
        do {
            let raw = try objectDetector.detectObjects(in: sampleBuffer)
            let smoothed = detectionTracker.ingest(raw)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.publish(detections: smoothed)
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.publishStatusIfChanged(
                    key: "analysis-failed",
                    message: "Goruntu analiz edilemedi. Kamerayi biraz daha sabit tut."
                )
            }
        }
    }

    /// Caller her zaman `DispatchQueue.main.async`'in içinden çağırır — main
    /// thread garanti. `@MainActor` annotation'ı bilerek YOK; class non-isolated
    /// olduğu için non-isolated context'ten (processFrame'in main dispatch'i)
    /// doğrudan çağrılması gerekiyor, aksi halde Swift module emit hatası verir.
    private func publish(detections smoothed: [CameraDetection]) {
        // Detection array'i sürekli yeni UUID üretmiyor — yalnızca anlamlı değişimde
        // güncelle (UUID dahil değişen referansları engellemek SwiftUI re-render
        // baskısını azaltır).
        if smoothed != detections {
            detections = smoothed
        }

        if let top = smoothed.first {
            publishStatusIfChanged(
                key: "result-\(top.label)-\(top.confidencePercent)",
                message: "\(top.label): %\(top.confidencePercent) olasilik"
            )
        } else if objectDetector.usesVisionFallbackClassifier {
            publishStatusIfChanged(
                key: "fallback-empty",
                message: "Vision fallback aktif. Ogunu daha aydinlik ve yakin kadraja al."
            )
        } else {
            publishStatusIfChanged(
                key: "empty",
                message: "Kadraja bir ogun aldiginda tahmin burada gorunur."
            )
        }
    }

    /// Main thread'de çağrılır (publish'ten veya processFrame catch'inden).
    /// `@MainActor` yok — aynı sebep, class non-isolated.
    private func publishStatusIfChanged(key: String, message: String) {
        guard lastPublishedStatusKey != key else { return }
        lastPublishedStatusKey = key
        statusMessage = message
    }

    // MARK: - System pressure (thermal + low power)

    private func registerSystemPressureObservers() {
        let center = NotificationCenter.default
        thermalObserver = center.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyCurrentSystemPressure()
        }
        powerObserver = center.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyCurrentSystemPressure()
        }
    }

    /// Thermal state + Low Power Mode'a göre FPS cap'i ayarlar.
    /// Ağır termal yük altında inference enerjisi UI'yi öldürür, bu yüzden
    /// kullanılabilir kalmak için FPS düşürmek doğru karar.
    private func applyCurrentSystemPressure() {
        let thermal = ProcessInfo.processInfo.thermalState
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let cap: Double?
        switch thermal {
        case .nominal, .fair:
            cap = lowPower ? 2 : nil
        case .serious:
            cap = 2
        case .critical:
            cap = 1
        @unknown default:
            cap = nil
        }
        guard cap != currentFPSCap else { return }
        currentFPSCap = cap
        frameCaptureService.setMaxFramesPerSecond(cap)
    }
}

// MARK: - DetectionTracker

/// Etiket başına bbox/confidence için exponential moving average tutar.
/// Bir label birkaç frame görünmezse otomatik düşer; bu sayede UI titrek olmaz.
private struct DetectionTracker {
    struct Track {
        var label: String
        var confidence: Float
        var boundingBox: CGRect
        var missedFrames: Int
        var stableID: UUID
    }

    let smoothingFactor: CGFloat
    let staleAfterMissedFrames: Int
    private var tracks: [String: Track] = [:]

    /// Explicit init — synthesized memberwise init `tracks`'in `private` olması
    /// nedeniyle struct dışından (CameraViewModel.detectionTracker init'i)
    /// erişilemez hale geliyordu ve module emit hatası veriyordu.
    init(smoothingFactor: CGFloat, staleAfterMissedFrames: Int) {
        self.smoothingFactor = smoothingFactor
        self.staleAfterMissedFrames = staleAfterMissedFrames
    }

    mutating func ingest(_ raw: [CameraDetection]) -> [CameraDetection] {
        var seenLabels = Set<String>()

        for detection in raw {
            seenLabels.insert(detection.label)
            if var existing = tracks[detection.label] {
                existing.boundingBox = smooth(existing.boundingBox, detection.boundingBox)
                existing.confidence = smooth(existing.confidence, detection.confidence)
                existing.missedFrames = 0
                tracks[detection.label] = existing
            } else {
                tracks[detection.label] = Track(
                    label: detection.label,
                    confidence: detection.confidence,
                    boundingBox: detection.boundingBox,
                    missedFrames: 0,
                    stableID: UUID()
                )
            }
        }

        for key in tracks.keys where !seenLabels.contains(key) {
            tracks[key]?.missedFrames += 1
            if (tracks[key]?.missedFrames ?? 0) >= staleAfterMissedFrames {
                tracks.removeValue(forKey: key)
            }
        }

        return tracks.values
            .sorted { $0.confidence > $1.confidence }
            .map {
                CameraDetection(
                    id: AnyHashable($0.stableID),
                    label: $0.label,
                    confidence: $0.confidence,
                    boundingBox: $0.boundingBox
                )
            }
    }

    private func smooth(_ previous: CGRect, _ next: CGRect) -> CGRect {
        CGRect(
            x: smooth(previous.minX, next.minX),
            y: smooth(previous.minY, next.minY),
            width: smooth(previous.width, next.width),
            height: smooth(previous.height, next.height)
        )
    }

    private func smooth(_ previous: CGFloat, _ next: CGFloat) -> CGFloat {
        previous * (1 - smoothingFactor) + next * smoothingFactor
    }

    private func smooth(_ previous: Float, _ next: Float) -> Float {
        previous * Float(1 - smoothingFactor) + next * Float(smoothingFactor)
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
