import AVFoundation
import SwiftUI
import UIKit

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CameraViewModel
    private let onSelectDetection: (CameraDetection) -> Void

    init(
        viewModel: CameraViewModel = CameraViewModel(),
        onSelectDetection: @escaping (CameraDetection) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSelectDetection = onSelectDetection
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(session: viewModel.previewSession)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            CameraDetectionOverlay(detections: viewModel.detections)
                .allowsHitTesting(false)

            VStack(spacing: NuvyraSpacing.md) {
                topBar
                Spacer()
                resultCard
            }
            .padding(NuvyraSpacing.lg)
        }
        .task { await viewModel.start() }
        .onDisappear { Task { @MainActor in viewModel.stop() } }
    }

    private var topBar: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.35), in: Circle())
            }
            .accessibilityLabel("Kamera ekranını kapat")

            VStack(alignment: .leading, spacing: 2) {
                Text("Fotoğrafla öğün")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text(statusTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
            }
            Spacer()
        }
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            HStack {
                Label("Canlı tahmin", systemImage: "viewfinder")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text(viewModel.isRunning ? "4 FPS" : "Beklemede")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.16), in: Capsule())
            }

            Text(viewModel.statusMessage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.authorizationState == .denied {
                Text("Nuvyra sağlık verilerini reklam hedefleme için kullanmaz. Kamera izni yalnızca seçtiğin öğünü analiz etmek içindir.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
            }

            ForEach(viewModel.detections.prefix(3)) { detection in
                Button {
                    onSelectDetection(detection)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(detection.label)
                                .font(.subheadline.weight(.bold))
                            Text("Tahmini değer • %\(detection.confidencePercent) güven")
                                .font(.caption.weight(.medium))
                                .opacity(0.72)
                        }
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .font(.title3.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
                }
                .accessibilityLabel("\(detection.label), yüzde \(detection.confidencePercent) olasılıkla tahmini öğün olarak kullan")
            }
        }
        .padding(NuvyraSpacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.xl, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
    }

    private var statusTitle: String {
        switch viewModel.authorizationState {
        case .authorized:
            return "Cihaz içi Vision analizi"
        case .requestingAccess:
            return "İzin bekleniyor"
        case .denied:
            return "Kamera izni kapalı"
        case .notDetermined:
            return "Hazırlanıyor"
        case .unavailable:
            return "Kamera kullanılamıyor"
        }
    }
}

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

private struct CameraDetectionOverlay: View {
    var detections: [CameraDetection]

    var body: some View {
        GeometryReader { proxy in
            ForEach(detections) { detection in
                let rect = convertVisionRect(detection.boundingBox, in: proxy.size)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(NuvyraColors.accent, lineWidth: 3)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .overlay(alignment: .topLeading) {
                        Text("\(detection.label) %\(detection.confidencePercent)")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(NuvyraColors.accent, in: Capsule())
                            .offset(x: rect.minX, y: max(rect.minY - 30, 12))
                    }
            }
        }
    }

    private func convertVisionRect(_ boundingBox: CGRect, in size: CGSize) -> CGRect {
        CGRect(
            x: boundingBox.minX * size.width,
            y: (1 - boundingBox.maxY) * size.height,
            width: boundingBox.width * size.width,
            height: boundingBox.height * size.height
        )
    }
}

#Preview {
    CameraView(viewModel: .preview())
}
