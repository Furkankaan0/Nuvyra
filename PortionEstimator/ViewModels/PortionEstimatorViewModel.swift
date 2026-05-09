//
//  PortionEstimatorViewModel.swift
//  Nuvyra - Portion Estimator
//
//  MVVM ViewModel: AR oturumu + Vision + Depth + RANSAC + Volume + Gram
//  pipeline'ını orkestre eder. Tüm UI state @MainActor üzerinde tutulur.
//

import Foundation
import Combine
import ARKit
import simd
import Vision

/// Pipeline'ın o anki durumu.
public enum EstimatorState: Equatable, Sendable {
    case idle
    case scanning
    case detecting
    case computing
    case ready(PortionEstimate)
    case manualFallback
    case failed(String)
}

/// Yemek hacim tahmin akışını yöneten ana ViewModel.
@MainActor
public final class PortionEstimatorViewModel: ObservableObject {

    // MARK: - Published State

    /// Pipeline durumu.
    @Published public private(set) var state: EstimatorState = .idle

    /// Son üretilen tahmin (UI bilgi kartı).
    @Published public private(set) var currentEstimate: PortionEstimate?

    /// Görselleştirme için son bbox (Vision normalize, alt-sol orijin).
    @Published public private(set) var lastBoundingBox: CGRect?

    /// Tabak düzlemi inlier sayısı (debug HUD).
    @Published public private(set) var planeInlierCount: Int = 0

    /// Cihaz LiDAR destekliyor mu?
    public var supportsLiDAR: Bool { sessionManager.supportsLiDAR }

    /// AR oturumu yöneticisi (View tarafı bunu okur).
    public let sessionManager: ARSessionManager

    // MARK: - Dependencies

    private let detector: FoodDetector
    private var pipelineTask: Task<Void, Never>?

    // MARK: - Throttling

    /// Pipeline'ı saniyede ~2 kez çalıştır (CPU/ısı).
    private let processingInterval: TimeInterval = 0.5
    private var lastProcessedAt: Date = .distantPast

    // MARK: - Init

    /// Yeni bir ViewModel oluşturur.
    /// - Parameters:
    ///   - sessionManager: Hazır bir ARSessionManager (opsiyonel, default yeni).
    ///   - detector:       Hazır bir FoodDetector (opsiyonel, default yeni).
    public init(
        sessionManager: ARSessionManager = ARSessionManager(),
        detector: FoodDetector = FoodDetector()
    ) {
        self.sessionManager = sessionManager
        self.detector = detector
    }

    deinit {
        pipelineTask?.cancel()
    }

    // MARK: - Lifecycle

    /// Pipeline'ı başlatır. LiDAR yoksa manuel fallback durumuna geçer.
    public func start() {
        guard supportsLiDAR else {
            state = .manualFallback
            return
        }

        do {
            try sessionManager.start()
            state = .scanning
            startPipelineLoop()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Pipeline'ı ve AR oturumunu durdurur.
    public func stop() {
        pipelineTask?.cancel()
        pipelineTask = nil
        sessionManager.stop()
        state = .idle
    }

    /// Manuel fallback kullanılırken çağrılır.
    /// - Parameters:
    ///   - grams:    Kullanıcının girdiği gram.
    ///   - foodKey:  Yemek etiketi.
    public func submitManualEntry(grams: Double, foodKey: String) {
        let estimate = GramEstimationService.manualEstimate(
            grams: grams,
            foodLabel: foodKey
        )
        currentEstimate = estimate
        state = .ready(estimate)
    }

    // MARK: - Pipeline Loop

    /// Throttled bir şekilde her 0.5 sn'de bir snapshot alıp pipeline'ı koşar.
    private func startPipelineLoop() {
        pipelineTask?.cancel()
        pipelineTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let now = Date()
                if now.timeIntervalSince(self.lastProcessedAt) >= self.processingInterval,
                   let frame = self.sessionManager.snapshotCurrentFrame() {
                    self.lastProcessedAt = now
                    await self.processFrame(frame)
                }
                try? await Task.sleep(nanoseconds: 80_000_000) // ~80 ms
            }
        }
    }

    // MARK: - Single Frame Processing

    /// Tek bir ARFrame için: Vision → Depth → RANSAC → Volume → Gram.
    private func processFrame(_ frame: ARFrame) async {
        state = .detecting

        // 1) Yemek tespiti
        let detection: FoodDetection?
        do {
            detection = try await detector.detect(in: frame.capturedImage)
        } catch {
            state = .failed("Tespit hatası: \(error.localizedDescription)")
            return
        }

        guard let detection else {
            state = .scanning
            return
        }

        lastBoundingBox = detection.boundingBox
        state = .computing

        // 2) Derinlik nokta bulutu (heavy CPU; thread'e taşı)
        let bbox = detection.boundingBox
        let camIntrinsics = frame.camera.intrinsics

        let pipeline = await Task.detached(priority: .userInitiated) {
            () -> (volume: VolumeResult,
                   plane: Plane3D?,
                   pointCount: Int,
                   validity: Double,
                   bboxPx: Double) in

            let (points, validity) = DepthProcessor.extractPoints(
                frame: frame,
                boundingBox: bbox,
                useSmoothed: true
            )

            guard points.count >= 30 else {
                return (
                    VolumeResult(volumeCm3: 0, abovePlaneCount: 0, averageHeightMeters: 0),
                    nil, points.count, validity, 0
                )
            }

            // RANSAC
            guard let plane = RANSACPlaneDetector.fit(
                points: points,
                iterations: 200,
                distanceThreshold: 0.005
            ) else {
                return (
                    VolumeResult(volumeCm3: 0, abovePlaneCount: 0, averageHeightMeters: 0),
                    nil, points.count, validity, 0
                )
            }

            // Ortalama Z (metrik dönüşümler için)
            let avgZ = points.reduce(Float(0)) { $0 + $1.position.z } / Float(points.count)

            // Bbox alanı (depth-pixel cinsinden)
            let depthMap = frame.smoothedSceneDepth?.depthMap ?? frame.sceneDepth?.depthMap
            let dW = depthMap.map { CVPixelBufferGetWidth($0) } ?? 256
            let dH = depthMap.map { CVPixelBufferGetHeight($0) } ?? 192
            let bboxAreaPx = Double(bbox.width)
                           * Double(bbox.height)
                           * Double(dW)
                           * Double(dH)

            let volume = VolumeCalculator.calculate(
                points: points,
                plane: plane,
                averageDepthZ: avgZ,
                intrinsics: camIntrinsics,
                boundingBoxAreaPx: bboxAreaPx
            )

            return (volume, plane, points.count, validity, bboxAreaPx)
        }.value

        guard pipeline.volume.volumeCm3 > 0, let plane = pipeline.plane else {
            state = .scanning
            return
        }

        planeInlierCount = plane.inliers.count

        // 3) Gram & güven aralığı
        let estimate = GramEstimationService.estimate(
            volumeCm3: pipeline.volume.volumeCm3,
            foodLabel: detection.label,
            inlierRatio: plane.inlierRatio,
            sampleCount: pipeline.volume.abovePlaneCount,
            depthValidity: pipeline.validity
        )

        currentEstimate = estimate
        state = .ready(estimate)
    }
}
