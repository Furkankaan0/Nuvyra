import AVFoundation
import SwiftUI

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CameraViewModel
    private let onSelect: (EstimatedMealResult) -> Void

    init(
        viewModel: CameraViewModel = CameraViewModel(),
        onSelect: @escaping (EstimatedMealResult) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSelect = onSelect
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(session: viewModel.previewSession)
                .ignoresSafeArea()
                .opacity(viewModel.isFrozen ? 0.65 : 1)
                .accessibilityHidden(true)

            CameraDetectionOverlay(detections: viewModel.detections)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, NuvyraSpacing.lg)
                    .padding(.top, NuvyraSpacing.sm)
                Spacer()
                if viewModel.isFrozen {
                    frozenResultsCard
                        .padding(.horizontal, NuvyraSpacing.lg)
                        .padding(.bottom, NuvyraSpacing.lg)
                } else {
                    liveBottomBar
                        .padding(.horizontal, NuvyraSpacing.lg)
                        .padding(.bottom, NuvyraSpacing.lg)
                }
            }
        }
        .task { await viewModel.start() }
        .onDisappear { Task { @MainActor in viewModel.stop() } }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            iconCircle(systemName: "xmark") { dismiss() }
                .accessibilityLabel("Kamera ekranını kapat")

            VStack(alignment: .leading, spacing: 2) {
                Text("Fotoğrafla öğün")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(viewModel.capabilityLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }

            Spacer()

            if viewModel.isFrozen {
                iconCircle(systemName: "arrow.clockwise") {
                    viewModel.resumeLivePreview()
                }
                .accessibilityLabel("Yeniden çek")
            }
        }
    }

    private func iconCircle(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.18)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Live bottom bar (shutter + status)

    private var liveBottomBar: some View {
        VStack(spacing: NuvyraSpacing.md) {
            statusPill

            if let top = viewModel.candidates.first, !viewModel.isAnalyzing {
                HStack(spacing: 8) {
                    Image(systemName: "viewfinder.circle.fill")
                        .foregroundStyle(NuvyraColors.accent)
                    Text("\(top.name) • \(top.calories) kcal")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("%\(Int((top.confidence * 100).rounded()))")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.16), in: Capsule())
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(NuvyraColors.accent.opacity(0.35))
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            shutterButton
        }
        .animation(.easeOut(duration: 0.25), value: viewModel.candidates.first?.id)
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            if viewModel.isAnalyzing {
                ProgressView().tint(.white).scaleEffect(0.8)
            } else if viewModel.isRunning {
                Circle().fill(NuvyraColors.accent).frame(width: 7, height: 7)
            }
            Text(viewModel.statusMessage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.black.opacity(0.42), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.12)))
    }

    private var shutterButton: some View {
        Button {
            viewModel.captureSnapshot()
        } label: {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 84, height: 84)
                    .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 3))
                Circle()
                    .fill(.white)
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                if viewModel.isAnalyzing {
                    ProgressView().tint(.black).scaleEffect(0.9)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isRunning || viewModel.isAnalyzing)
        .opacity(viewModel.isRunning && !viewModel.isAnalyzing ? 1 : 0.6)
        .accessibilityLabel("Kareyi yakala ve analiz et")
    }

    // MARK: - Frozen results

    private var frozenResultsCard: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            HStack {
                Label("Adaylar", systemImage: "sparkles")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    viewModel.resumeLivePreview()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Yeniden çek")
                    }
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            if viewModel.candidates.isEmpty {
                Text("Bu kareden öğün çıkaramadım. Daha yakından dene veya manuel ekle.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                ForEach(viewModel.candidates) { candidate in
                    candidateRow(candidate)
                }
            }
        }
        .padding(NuvyraSpacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.xl, style: .continuous)
                .stroke(.white.opacity(0.16))
        )
    }

    private func candidateRow(_ candidate: EstimatedMealResult) -> some View {
        Button {
            onSelect(candidate)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(candidate.name)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Text("\(candidate.calories) kcal")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(NuvyraColors.accent)
                }
                HStack(spacing: 6) {
                    Text(candidate.portion)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("•")
                        .foregroundStyle(.white.opacity(0.4))
                        .font(.caption)
                    Text("%\(Int((candidate.confidence * 100).rounded())) güven")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    macroChip("P", value: candidate.protein, tint: NuvyraColors.mutedCoral)
                    macroChip("K", value: candidate.carbs, tint: NuvyraColors.paleLime)
                    macroChip("Y", value: candidate.fat, tint: NuvyraColors.softSand)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                    .stroke(.white.opacity(0.14))
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(candidate.name), \(candidate.calories) kalori, %\(Int((candidate.confidence * 100).rounded())) güven. Eklemek için dokun.")
    }

    private func macroChip(_ label: String, value: Double, tint: Color) -> some View {
        Text("\(label) \(Int(value))g")
            .font(.caption2.weight(.heavy))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .foregroundStyle(.white)
            .background(tint.opacity(0.55), in: Capsule())
    }
}

// MARK: - UIKit preview hosting

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

// MARK: - Detection overlay

private struct CameraDetectionOverlay: View {
    var detections: [CameraDetection]

    var body: some View {
        GeometryReader { proxy in
            ForEach(detections.prefix(2)) { detection in
                let rect = convertVisionRect(detection.boundingBox, in: proxy.size)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(NuvyraColors.accent, lineWidth: 2.5)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .overlay(alignment: .topLeading) {
                        Text("%\(Int((detection.confidence * 100).rounded()))")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(NuvyraColors.accent, in: Capsule())
                            .offset(x: rect.minX, y: max(rect.minY - 24, 12))
                    }
            }
        }
        .accessibilityHidden(true)
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
