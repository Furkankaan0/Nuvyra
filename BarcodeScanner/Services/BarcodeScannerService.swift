//
//  BarcodeScannerService.swift
//  Nuvyra - Barcode Scanner
//
//  AVCaptureSession tabanlı production-ready barkod tarayıcı.
//  - EAN-13, EAN-8, UPC-A (EAN-13 13-haneli "0" prefix), UPC-E, QR
//  - Aynı barkodun 2 sn içinde tekrarı yok sayılır
//  - Başarılı taramada UIImpactFeedbackGenerator(.medium)
//  - 1.5 sn boyunca kamera donar (görsel onay)
//

import Foundation
@preconcurrency import AVFoundation
@preconcurrency import UIKit

/// Tarama olaylarını dinleyen delegate.
@MainActor
public protocol BarcodeScannerDelegate: AnyObject {
    /// Yeni bir barkod yakalandığında çağrılır.
    func scanner(_ scanner: BarcodeScannerService, didScan barcode: String)

    /// Permission/runtime hatalarında çağrılır.
    func scanner(_ scanner: BarcodeScannerService, didFailWith error: Error)
}

/// Tarayıcı hataları.
public enum BarcodeScannerError: LocalizedError {
    case cameraUnavailable
    case permissionDenied
    case configurationFailed

    public var errorDescription: String? {
        switch self {
        case .cameraUnavailable:    return "Kamera bulunamadı."
        case .permissionDenied:     return "Kamera izni reddedildi."
        case .configurationFailed:  return "Kamera yapılandırması başarısız."
        }
    }
}

/// AVCaptureSession tabanlı barkod tarayıcı.
@MainActor
public final class BarcodeScannerService: NSObject {

    // MARK: - Configuration

    /// Desteklenen sembolojiler.
    public static let supportedSymbologies: [AVMetadataObject.ObjectType] = [
        .ean13, .ean8, .upce, .qr
        // UPC-A, EAN-13'ün leading "0" prefix'li hali olarak ean13 içinde gelir.
    ]

    // MARK: - Public

    public weak var delegate: BarcodeScannerDelegate?

    /// Önizleme katmanı; UIView'a eklenir.
    public let previewLayer: AVCaptureVideoPreviewLayer

    // MARK: - Private

    private nonisolated(unsafe) let session: AVCaptureSession
    private nonisolated(unsafe) let metadataOutput: AVCaptureMetadataOutput
    private nonisolated(unsafe) let sessionQueue = DispatchQueue(label: "nuvyra.scanner.session")
    private nonisolated(unsafe) let metadataQueue = DispatchQueue(label: "nuvyra.scanner.metadata")
    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    /// Duplicate prevention: barkod → son okuma zamanı.
    private var lastSeen: [String: Date] = [:]
    private let duplicateWindow: TimeInterval = 2.0

    /// 1.5 sn freeze için iç bayrak.
    private var isFrozen: Bool = false
    private let freezeDuration: TimeInterval = 1.5

    // MARK: - Init

    /// Yeni bir tarayıcı oluşturur. AVCaptureSession ve preview layer kurulur.
    public override init() {
        self.session = AVCaptureSession()
        self.metadataOutput = AVCaptureMetadataOutput()
        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
        self.previewLayer.videoGravity = .resizeAspectFill
        super.init()
    }

    deinit {
        // stopRunning() is a synchronous, blocking AVFoundation call (~1-2s).
        // SwiftUI releases StateObjects on the main thread, so running it inline
        // here freezes the UI right after the scanner sheet is dismissed.
        let session = self.session
        DispatchQueue.global(qos: .userInitiated).async {
            if session.isRunning { session.stopRunning() }
        }
    }

    // MARK: - Public API

    /// Kamera iznini ister ve oturumu yapılandırır. Başarılıysa preview canlanır.
    public func prepare() async throws {
        let granted = await Self.requestCameraAuthorization()
        guard granted else {
            throw BarcodeScannerError.permissionDenied
        }

        try await configureSession()

        // Delegate ve metadata turleri ana actor'da set edilir.
        metadataOutput.setMetadataObjectsDelegate(self, queue: metadataQueue)
        let supported = Self.supportedSymbologies.filter {
            metadataOutput.availableMetadataObjectTypes.contains($0)
        }
        metadataOutput.metadataObjectTypes = supported

        // Pre-warm haptic.
        haptic.prepare()
    }

    private func configureSession() async throws {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [session, metadataOutput] in
                do {
                    session.beginConfiguration()
                    defer { session.commitConfiguration() }

                    session.sessionPreset = .high

                    guard let device = AVCaptureDevice.default(
                        .builtInWideAngleCamera, for: .video, position: .back
                    ) else {
                        throw BarcodeScannerError.cameraUnavailable
                    }

                    let input: AVCaptureDeviceInput
                    do {
                        input = try AVCaptureDeviceInput(device: device)
                    } catch {
                        throw BarcodeScannerError.configurationFailed
                    }

                    for existing in session.inputs { session.removeInput(existing) }
                    for existing in session.outputs { session.removeOutput(existing) }

                    guard session.canAddInput(input) else {
                        throw BarcodeScannerError.configurationFailed
                    }
                    session.addInput(input)

                    guard session.canAddOutput(metadataOutput) else {
                        throw BarcodeScannerError.configurationFailed
                    }
                    session.addOutput(metadataOutput)

                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    /// Yakalama oturumunu başlatır.
    public func start() {
        sessionQueue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    /// Oturumu durdurur.
    public func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Donmuş kamerayı manuel olarak çözmek için (örn. kullanıcı bottom-sheet'i kapattığında).
    public func resume() {
        isFrozen = false
        start()
    }

    /// Yetki sorgulama helper'ı.
    public static func requestCameraAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .denied, .restricted: return false
        case .notDetermined:
            return await withCheckedContinuation { cont in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    cont.resume(returning: granted)
                }
            }
        @unknown default: return false
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension BarcodeScannerService: AVCaptureMetadataOutputObjectsDelegate {

    public nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        // İlk geçerli barkodu çıkar
        guard
            let readable = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            let raw = readable.stringValue,
            !raw.isEmpty
        else { return }

        // Main actor'a sıçra (delegate, haptic, freeze burada)
        Task { @MainActor [weak self] in
            self?.handleScanned(raw)
        }
    }

    /// Duplicate filtresi + haptik + freeze + delegate çağrısı.
    private func handleScanned(_ barcode: String) {
        guard !isFrozen else { return }

        let now = Date()
        if let prev = lastSeen[barcode], now.timeIntervalSince(prev) < duplicateWindow {
            return
        }
        lastSeen[barcode] = now

        // Haptik
        haptic.impactOccurred()

        // Görsel freeze
        isFrozen = true
        stop()

        // Delegate'i bilgilendir
        delegate?.scanner(self, didScan: barcode)

        // 1.5 sn sonra otomatik resume (UI bottom sheet açık ise resume() ile manuel kontrol edilir)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(1.5 * 1_000_000_000))
            await MainActor.run {
                guard let self else { return }
                if self.isFrozen {
                    self.isFrozen = false
                    // resume otomatik olmasın diye sadece bayrağı düşürürüz;
                    // start çağrısı VM kontrolünde.
                }
            }
        }
    }
}
