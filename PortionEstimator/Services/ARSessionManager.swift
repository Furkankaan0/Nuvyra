//
//  ARSessionManager.swift
//  Nuvyra - Portion Estimator
//
//  ARWorldTrackingConfiguration kurulumu, LiDAR cihaz desteği kontrolü
//  ve ARFrame teslim akışını yöneten servis.
//
//  NOT: Bu sınıf ARSessionDelegate olarak kayıt OLMAZ — delegate rolünü
//  ARContainerView.Coordinator üstlenir ve ilgili olaylar buradaki
//  public `forward...` metotları üzerinden manager'a iletilir.
//

import Foundation
import ARKit
import RealityKit
import Combine

/// AR oturumunun konfigürasyonu, başlatılması/durdurulması ve frame akışı.
@MainActor
public final class ARSessionManager: ObservableObject {

    // MARK: - Published State

    /// Cihazın LiDAR (scene reconstruction) destekleyip desteklemediği.
    @Published public private(set) var supportsLiDAR: Bool

    /// Oturum aktif mi?
    @Published public private(set) var isRunning: Bool = false

    /// Son gelen ARFrame (read-only). Consumer'lar gerektiğinde kopya almalı.
    @Published public private(set) var latestFrame: ARFrame?

    /// Oturum hatası (varsa).
    @Published public private(set) var lastError: String?

    // MARK: - ARView

    /// SwiftUI tarafına geçirilecek ARView referansı.
    public let arView: ARView

    // MARK: - Init

    /// Yeni bir manager oluşturur ve cihaz desteğini kontrol eder.
    public init() {
        self.arView = ARView(
            frame: .zero,
            cameraMode: .ar,
            automaticallyConfigureSession: false
        )
        self.supportsLiDAR = ARWorldTrackingConfiguration
            .supportsSceneReconstruction(.mesh)
    }

    // MARK: - Lifecycle

    /// AR oturumunu başlatır.
    /// LiDAR yoksa `ARSessionError.lidarUnavailable` fırlatır (UI manuel girişe yönlendirir).
    public func start() throws {
        guard supportsLiDAR else {
            throw ARSessionError.lidarUnavailable
        }

        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .meshWithClassification
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic

        // Derinlik semantikleri — sadece destek varsa açılır.
        var semantics: ARConfiguration.FrameSemantics = []
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            semantics.insert(.sceneDepth)
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            semantics.insert(.smoothedSceneDepth)
        }
        config.frameSemantics = semantics

        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        isRunning = true
        lastError = nil
    }

    /// AR oturumunu durdurur ve frame akışını sıfırlar.
    public func stop() {
        arView.session.pause()
        latestFrame = nil
        isRunning = false
    }

    // MARK: - Frame Snapshot

    /// O anki son frame'in immutable bir referansını döner.
    /// Pipeline asenkron çalıştığı için consumer her seferinde snapshot almalıdır.
    public func snapshotCurrentFrame() -> ARFrame? {
        latestFrame
    }

    // MARK: - Coordinator Forwarders

    /// Coordinator'dan gelen yeni ARFrame bildirimi.
    public func forwardFrameUpdate(_ frame: ARFrame) {
        self.latestFrame = frame
    }

    /// Coordinator'dan gelen oturum hatası.
    public func forwardError(_ error: Error) {
        self.lastError = error.localizedDescription
        self.isRunning = false
    }

    /// Coordinator'dan gelen oturum kesintisi.
    public func forwardInterrupted() {
        self.isRunning = false
    }

    /// Coordinator'dan gelen kesinti sonu.
    public func forwardInterruptionEnded() {
        self.isRunning = true
    }
}

// MARK: - Error

/// AR oturumu ile ilgili öngörülebilir hatalar.
public enum ARSessionError: LocalizedError {
    case lidarUnavailable
    case configurationFailed

    public var errorDescription: String? {
        switch self {
        case .lidarUnavailable:
            return "Bu cihazda LiDAR desteği yok. Manuel gram girişine geçildi."
        case .configurationFailed:
            return "AR oturumu başlatılamadı."
        }
    }
}
