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
            // Cihaz dönüşüne göre rotation angle (videoOrientation iOS 17'de deprecated)
            if let conn = previewLayer?.connection {
                let orientation = UIDevice.current.orientation
                let angle: CGFloat
                switch orientation {
                case .landscapeLeft:       angle = 0    // landscapeRight video
                case .landscapeRight:      angle = 180  // landscapeLeft video
                case .portraitUpsideDown:   angle = 270
                default:                   angle = 90   // portrait
                }
                if conn.isVideoRotationAngleSupported(angle) {
                    conn.videoRotationAngle = angle
                }
            }
        }
    }
}
