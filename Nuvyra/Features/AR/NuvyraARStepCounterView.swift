import ARKit
import RealityKit
import SwiftUI
import UIKit

struct NuvyraARStepCounterView: View {
    @Environment(\.dismiss) private var dismiss
    var steps: Int
    var goal: Int

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(steps) / Double(goal), 1)
    }

    var body: some View {
        ZStack(alignment: .top) {
            if ARWorldTrackingConfiguration.isSupported {
                ARStepCounterRepresentable(steps: steps, goal: goal, progress: progress)
                    .ignoresSafeArea()
            } else {
                fallback
            }

            topBar
                .padding(.horizontal, NuvyraSpacing.lg)
                .padding(.top, NuvyraSpacing.lg)
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("AR adım sayacı")
                    .font(.headline.weight(.bold))
                Text("\(steps.formatted()) / \(goal.formatted()) adım")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("AR adım sayacını kapat")
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
    }

    private var fallback: some View {
        ZStack {
            NuvyraBackground(.animated)
            NuvyraProgressRing(
                progress: progress,
                center: "\(Int((progress * 100).rounded()))%",
                caption: "adım hedefi"
            )
            .frame(width: 220, height: 220)
        }
    }
}

private struct ARStepCounterRepresentable: UIViewRepresentable {
    var steps: Int
    var goal: Int
    var progress: Double

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        view.environment.sceneUnderstanding.options = [.occlusion]

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        let anchor = AnchorEntity(.camera)
        anchor.name = "nuvyra-ar-step-anchor"
        anchor.addChild(makeTextEntity())
        view.scene.addAnchor(anchor)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        guard
            let anchor = uiView.scene.anchors.first(where: { $0.name == "nuvyra-ar-step-anchor" }),
            let text = anchor.children.first(where: { $0.name == "nuvyra-ar-step-text" }) as? ModelEntity
        else {
            return
        }
        text.model = makeTextEntity().model
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
        uiView.session.pause()
    }

    private func makeTextEntity() -> ModelEntity {
        let percent = Int((progress * 100).rounded())
        let label = "\(steps.formatted())\n\(percent)%"
        let mesh = MeshResource.generateText(
            label,
            extrusionDepth: 0.006,
            font: .systemFont(ofSize: 0.065, weight: .heavy),
            containerFrame: CGRect(x: -0.28, y: -0.08, width: 0.56, height: 0.18),
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        var material = SimpleMaterial(color: UIColor(NuvyraColors.accent), isMetallic: false)
        material.roughness = 0.28
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "nuvyra-ar-step-text"
        entity.position = SIMD3<Float>(-0.28, -0.08, -0.72)
        return entity
    }
}

#if DEBUG
#Preview {
    NuvyraARStepCounterView(steps: 5_420, goal: 7_500)
}
#endif
