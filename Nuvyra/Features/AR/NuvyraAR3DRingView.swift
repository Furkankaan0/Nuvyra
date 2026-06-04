import RealityKit
import SwiftUI
import UIKit

/// RealityKit-backed 3D rhythm ring. Lives outside the AR camera path
/// on purpose — Nuvyra uses RealityKit as a **renderer**, not an AR
/// session. A torus mesh sits on a non-AR `RealityView` and rotates
/// continuously with the accent gradient as a procedural material.
///
/// Why no `ARView` / `WorldTrackingConfiguration`?
///   - Privacy: world tracking would force a camera-usage prompt we
///     don't need.
///   - Cost: a non-AR `RealityView` is single-pass; world tracking
///     keeps the camera + AR session running.
///   - UX: the 3D ring is a celebration moment, not a "look around
///     the room" feature.
///
/// The view is opt-in — Dashboard surfaces it via a "3D moda geç"
/// button on the rhythm hero card. Renders nothing under
/// `accessibilityReduceMotion` and instead surfaces the calm static
/// SwiftUI ring already shown on the dashboard.
struct NuvyraAR3DRingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    /// 0–1 progress driving the ring fill and rotation speed.
    var progress: Double

    var body: some View {
        ZStack {
            NuvyraBackground(.animated)
            VStack(spacing: NuvyraSpacing.lg) {
                Spacer()
                if reduceMotion {
                    staticRing
                } else {
                    realityScene
                }
                Spacer()
                hint
                NuvyraSecondaryButton(title: "Kapat", systemImage: "xmark") {
                    dismiss()
                }
                .padding(.horizontal, NuvyraSpacing.lg)
                .padding(.bottom, NuvyraSpacing.lg)
            }
        }
    }

    // MARK: - Scene

    private var realityScene: some View {
        RealityView { content in
            let scene = makeScene()
            content.add(scene)
        } update: { content in
            // RealityView gives us the live scene back on update — we
            // refresh the ring's scale to match the progress value so
            // changes from the host view animate smoothly.
            content.entities.first(where: { $0.name == "rhythm-ring" })?
                .transform.scale = SIMD3(repeating: Float(0.8 + progress * 0.4))
        }
        .frame(width: 320, height: 320)
        .background(.clear)
        .accessibilityLabel("Üç boyutlu ritim halkası")
    }

    /// Fallback shown when reduceMotion is on — a single static SwiftUI
    /// ring that mirrors the dashboard hero's look so the user sees a
    /// recognisable surface rather than a black box.
    private var staticRing: some View {
        ZStack {
            Circle()
                .stroke(NuvyraColors.accent.opacity(0.16), lineWidth: 16)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(NuvyraColors.accentGradient, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 240, height: 240)
    }

    private var hint: some View {
        VStack(spacing: 6) {
            Text("Bugünkü ritim")
                .font(NuvyraTypography.section)
            Text("\(Int(progress * 100))%")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundStyle(NuvyraColors.accentGradient)
                .contentTransition(.numericText())
        }
    }

    // MARK: - Scene composition

    /// Builds the root entity + ambient lighting + the rotating torus.
    /// Kept on the main actor because `RealityView` runs its scene on
    /// the main thread and the helper writes back into the scene graph.
    @MainActor
    private func makeScene() -> Entity {
        let root = Entity()
        root.name = "rhythm-root"

        // Ring — a torus made from an extruded ring path. RealityKit's
        // `MeshResource.generateBox` doesn't ship a built-in torus, so
        // we approximate with a thin cylinder ring.
        let ring = Entity()
        ring.name = "rhythm-ring"
        let major: Float = 0.18
        let minor: Float = 0.018
        let segmentCount = 56
        for index in 0..<segmentCount {
            let angle = Float(index) / Float(segmentCount) * .pi * 2
            let mesh = MeshResource.generateBox(size: SIMD3(minor * 2, minor * 2, minor * 2))
            let model = ModelEntity(
                mesh: mesh,
                materials: [Self.ringMaterial(for: Float(index) / Float(segmentCount))]
            )
            model.position = SIMD3(cos(angle) * major, sin(angle) * major, 0)
            ring.addChild(model)
        }
        // Slow rotation so the ring catches the light from every angle.
        ring.components.set(SpinComponent(speed: Float(0.4 + progress * 0.8)))
        root.addChild(ring)

        // Single directional light — gives the segments a brand-warm
        // highlight without going theatrical.
        let light = DirectionalLightComponent(
            color: .white,
            intensity: 2_000,
            isRealWorldProxy: false
        )
        let lightEntity = Entity()
        lightEntity.components.set(light)
        lightEntity.look(at: .zero, from: SIMD3(0.4, 0.4, 0.6), relativeTo: nil)
        root.addChild(lightEntity)

        // Spin system kicks in once we register it on the scene.
        SpinSystem.registerSystem()

        return root
    }

    /// Linear gradient of accent → mint along the ring index. RealityKit
    /// materials are constructed from `Material.Color` (UIColor on
    /// iOS), so we sample the SwiftUI gradient at the segment's `t`.
    @MainActor
    private static func ringMaterial(for t: Float) -> SimpleMaterial {
        let start = UIColor(NuvyraColors.accent)
        let end = UIColor(NuvyraColors.softMint)
        let blended = blend(start: start, end: end, t: t)
        var material = SimpleMaterial(color: blended, isMetallic: false)
        material.roughness = 0.35
        return material
    }

    private static func blend(start: UIColor, end: UIColor, t: Float) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 1
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 1
        start.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        end.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let amount = CGFloat(t)
        return UIColor(
            red: r1 + (r2 - r1) * amount,
            green: g1 + (g2 - g1) * amount,
            blue: b1 + (b2 - b1) * amount,
            alpha: a1 + (a2 - a1) * amount
        )
    }
}

// MARK: - Spin system

/// Per-frame component + system pair that rotates any entity it's
/// attached to. Drops back to the main actor when it mutates state so
/// it can play with `@MainActor`-bound RealityKit APIs safely.
private struct SpinComponent: Component {
    var speed: Float
}

private final class SpinSystem: System {
    static let query = EntityQuery(where: .has(SpinComponent.self))

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)
        for entity in context.scene.performQuery(Self.query) {
            guard let spin = entity.components[SpinComponent.self] else { continue }
            entity.transform.rotation *= simd_quatf(
                angle: spin.speed * deltaTime,
                axis: SIMD3(0, 1, 0.2)
            )
        }
    }
}

#if DEBUG
#Preview {
    NuvyraAR3DRingView(progress: 0.74)
}
#endif
