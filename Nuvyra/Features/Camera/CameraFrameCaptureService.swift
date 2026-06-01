import AVFoundation
import CoreMedia
import Foundation
import QuartzCore

struct FrameRateLimiter {
    private(set) var minimumFrameInterval: CFTimeInterval
    private(set) var lastAcceptedFrameTime: CFTimeInterval = -Double.greatestFiniteMagnitude

    init(maxFramesPerSecond: Double) {
        minimumFrameInterval = 1.0 / max(maxFramesPerSecond, 1.0)
    }

    mutating func updateMaxFramesPerSecond(_ fps: Double) {
        minimumFrameInterval = 1.0 / max(fps, 1.0)
    }

    mutating func shouldAcceptFrame(at timestamp: CFTimeInterval) -> Bool {
        guard timestamp - lastAcceptedFrameTime >= minimumFrameInterval else {
            return false
        }

        lastAcceptedFrameTime = timestamp
        return true
    }
}

final class CameraFrameCaptureService: NSObject {
    let captureSession = AVCaptureSession()
    var onFrame: ((CMSampleBuffer) -> Void)?
    /// Session run-time interruption / restoration callbacks (call → media services lost etc.)
    var onInterruption: ((Bool) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.nuvyra.camera.session", qos: .userInitiated)
    private let videoOutputQueue = DispatchQueue(label: "com.nuvyra.camera.frames", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()
    private var isConfigured = false
    private let baseFramesPerSecond: Double
    private var frameRateLimiter: FrameRateLimiter
    private var notificationObservers: [NSObjectProtocol] = []

    init(maxFramesPerSecond: Double = 4) {
        baseFramesPerSecond = maxFramesPerSecond
        frameRateLimiter = FrameRateLimiter(maxFramesPerSecond: maxFramesPerSecond)
        super.init()
        registerSessionNotifications()
    }

    /// Cihaz ısındığında veya Low Power Mode aktifken FPS'i düşürmek için kullanılır.
    /// `nil` verilirse init'teki baseline FPS'e döner.
    func setMaxFramesPerSecond(_ fps: Double?) {
        let target = fps ?? baseFramesPerSecond
        videoOutputQueue.async { [weak self] in
            self?.frameRateLimiter.updateMaxFramesPerSecond(target)
        }
    }

    deinit {
        // AVCaptureSession.stopRunning() blocks the caller (~1-2s). Releasing
        // this service on the main thread (SwiftUI default) would freeze the
        // UI when the camera screen is dismissed.
        let session = captureSession
        let output = videoOutput
        let observers = notificationObservers
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        DispatchQueue.global(qos: .userInitiated).async {
            output.setSampleBufferDelegate(nil, queue: nil)
            if session.isRunning { session.stopRunning() }
        }
    }

    private func registerSessionNotifications() {
        let center = NotificationCenter.default
        let interrupted = center.addObserver(
            forName: .AVCaptureSessionWasInterrupted,
            object: captureSession,
            queue: .main
        ) { [weak self] _ in
            self?.onInterruption?(true)
        }
        let restored = center.addObserver(
            forName: .AVCaptureSessionInterruptionEnded,
            object: captureSession,
            queue: .main
        ) { [weak self] _ in
            self?.onInterruption?(false)
        }
        notificationObservers = [interrupted, restored]
    }

    func authorizationState() -> CameraAuthorizationState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .unavailable
        }
    }

    func requestAccessIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func startRunning() throws {
        try configureSessionIfNeeded()
        sessionQueue.async { [weak self] in
            guard let self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
        }
    }

    func stopRunning() {
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
        }
    }

    private func configureSessionIfNeeded() throws {
        var configurationError: Error?

        sessionQueue.sync {
            guard !isConfigured else { return }

            captureSession.beginConfiguration()
            // Model girdisi 224/416 boyutunda; 1080p+ preset gereksiz yere CPU/ISP
            // gücü tüketir ve termal yük yaratır. 720p hem Vision hem energy için
            // optimum noktada — düşük cihazlarda otomatik düşer (sessionPreset
            // canSetSessionPreset üzerinden kontrol edilir).
            if captureSession.canSetSessionPreset(.hd1280x720) {
                captureSession.sessionPreset = .hd1280x720
            } else if captureSession.canSetSessionPreset(.vga640x480) {
                captureSession.sessionPreset = .vga640x480
            } else {
                captureSession.sessionPreset = .high
            }

            defer {
                captureSession.commitConfiguration()
            }

            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                configurationError = CameraFeatureError.cameraUnavailable
                return
            }

            do {
                try Self.tuneDeviceForCloseRangeFood(camera)
                let input = try AVCaptureDeviceInput(device: camera)
                guard captureSession.canAddInput(input) else {
                    configurationError = CameraFeatureError.cannotAddInput
                    return
                }
                captureSession.addInput(input)
            } catch {
                configurationError = error
                return
            }

            videoOutput.alwaysDiscardsLateVideoFrames = true
            // Kameranın native çıktısı YUV — Vision otomatik dönüşümü kabul eder ve
            // 32BGRA'ya kıyasla belirgin daha az watt tüketir.
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ]
            videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)

            guard captureSession.canAddOutput(videoOutput) else {
                configurationError = CameraFeatureError.cannotAddOutput
                return
            }
            captureSession.addOutput(videoOutput)

            if let connection = videoOutput.connection(with: .video), connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }

            isConfigured = true
        }

        if let configurationError {
            throw configurationError
        }
    }

    /// Tabak / yakın çekim için odak ve pozlama parametrelerini ayarlar.
    /// Yemek tipik olarak 15–40 cm mesafede kadrajlanır; default `.continuousAutoFocus`
    /// uzak kadrajı gözetir ve yakın nesnelerde sık sık blur'a düşer.
    private static func tuneDeviceForCloseRangeFood(_ device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        if device.isAutoFocusRangeRestrictionSupported {
            device.autoFocusRangeRestriction = .near
        }
        if device.isSmoothAutoFocusSupported {
            device.isSmoothAutoFocusEnabled = true
        }
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
        if device.isLowLightBoostSupported {
            device.automaticallyEnablesLowLightBoostWhenAvailable = true
        }
    }
}

extension CameraFrameCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard frameRateLimiter.shouldAcceptFrame(at: CACurrentMediaTime()) else {
            return
        }

        autoreleasepool {
            onFrame?(sampleBuffer)
        }
    }
}
