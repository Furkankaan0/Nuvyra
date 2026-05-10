import AVFoundation
import CoreMedia
import Foundation
import QuartzCore

struct FrameRateLimiter {
    let minimumFrameInterval: CFTimeInterval
    private(set) var lastAcceptedFrameTime: CFTimeInterval = -Double.greatestFiniteMagnitude

    init(maxFramesPerSecond: Double) {
        minimumFrameInterval = 1.0 / max(maxFramesPerSecond, 1.0)
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

    private let sessionQueue = DispatchQueue(label: "com.nuvyra.camera.session", qos: .userInitiated)
    private let videoOutputQueue = DispatchQueue(label: "com.nuvyra.camera.frames", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()
    private var isConfigured = false
    private var frameRateLimiter: FrameRateLimiter
    private var pendingSnapshot: ((CMSampleBuffer) -> Void)?

    init(maxFramesPerSecond: Double = 4) {
        frameRateLimiter = FrameRateLimiter(maxFramesPerSecond: maxFramesPerSecond)
        super.init()
    }

    /// Capture the next available video frame as a one-shot snapshot.
    /// `completion` runs on the camera frame queue with the raw sample buffer.
    /// Returns immediately if a snapshot is already pending.
    func captureNextFrame(_ completion: @escaping (CMSampleBuffer) -> Void) {
        videoOutputQueue.async { [weak self] in
            guard let self else { return }
            self.pendingSnapshot = completion
        }
    }

    func cancelPendingSnapshot() {
        videoOutputQueue.async { [weak self] in
            self?.pendingSnapshot = nil
        }
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
            captureSession.sessionPreset = .high

            defer {
                captureSession.commitConfiguration()
            }

            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                configurationError = CameraFeatureError.cameraUnavailable
                return
            }

            do {
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
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
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
}

extension CameraFrameCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Pending snapshot bypasses the FPS limiter so the user gets a fresh frame on shutter tap.
        if let snapshot = pendingSnapshot {
            pendingSnapshot = nil
            autoreleasepool { snapshot(sampleBuffer) }
            return
        }

        guard frameRateLimiter.shouldAcceptFrame(at: CACurrentMediaTime()) else {
            return
        }

        autoreleasepool {
            onFrame?(sampleBuffer)
        }
    }
}
