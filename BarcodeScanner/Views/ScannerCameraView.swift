//
//  ScannerCameraView.swift
//  Nuvyra - Barcode Scanner
//
//  AVCaptureVideoPreviewLayer'ı SwiftUI ağacında render etmek için ince bir
//  UIViewRepresentable wrapper.
//

import SwiftUI
import AVFoundation

/// AVCaptureVideoPreviewLayer'ı barındıran UIView wrapper.
public struct ScannerCameraView: UIViewRepresentable {

    // MARK: - Inputs

    /// Tarayıcı servisinin preview layer referansı.
    public let previewLayer: AVCaptureVideoPreviewLayer

    public init(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
    }

    // MARK: - UIViewRepresentable

    public func makeUIView(context: Context) -> PreviewContainer {
        let view = PreviewContainer()
        view.backgroundColor = .black
        view.previewLayer = previewLayer
        view.layer.addSublayer(previewLayer)
        return view
    }

    public func updateUIView(_ uiView: PreviewContainer, context: Context) {
        // layer frame uiView.layoutSubviews içinde yönetiliyor.
    }

    // MARK: - Container UIView

    /// `previewLayer`'ı kendi bounds'una sığdıran basit container.
    public final class PreviewContainer: UIView {
        public var previewLayer: AVCaptureVideoPreviewLayer?

        public override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
            // Cihaz dönüşüne göre orientation
            if let conn = previewLayer?.connection, conn.isVideoOrientationSupported {
                let orientation = UIDevice.current.orientation
                switch orientation {
                case .landscapeLeft:  conn.videoOrientation = .landscapeRight
                case .landscapeRight: conn.videoOrientation = .landscapeLeft
                case .portraitUpsideDown: conn.videoOrientation = .portraitUpsideDown
                default:              conn.videoOrientation = .portrait
                }
            }
        }
    }
}
