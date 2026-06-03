import SwiftUI

/// Layered ambient background. Two visual modes that share the same
/// "behind every screen" role:
///
/// - `.layered` (default) — calm gradient + three large, blurred,
///   *static* blobs. The original Nuvyra background; zero motion cost,
///   safe everywhere.
/// - `.animated` — `NuvyraMeshBackground` underneath, which uses
///   `MeshGradient` on iOS 18+ and a TimelineView+Canvas blob path on
///   iOS 17. Adds a slow ambient flow.
///
/// `accessibilityReduceMotion` is forwarded to the mesh path so users
/// who opt out get a still surface even when `.animated` is requested.
struct NuvyraBackground: View {
    @Environment(\.colorScheme) private var scheme

    enum Style {
        case layered
        case animated
    }

    var style: Style

    init(_ style: Style = .layered) {
        self.style = style
    }

    var body: some View {
        switch style {
        case .layered: layeredBody
        case .animated: animatedBody
        }
    }

    // MARK: - Static layered path

    private var layeredBody: some View {
        ZStack {
            NuvyraColors.calmGradient(scheme)
                .ignoresSafeArea()

            blob(
                tint: NuvyraColors.accent,
                opacity: scheme == .dark ? 0.14 : 0.18,
                size: 320
            )
            .offset(x: 130, y: -150)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            blob(
                tint: NuvyraColors.softSand,
                opacity: scheme == .dark ? 0.12 : 0.22,
                size: 260
            )
            .offset(x: -120, y: 180)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            blob(
                tint: NuvyraColors.paleLime,
                opacity: scheme == .dark ? 0.08 : 0.14,
                size: 220
            )
            .offset(x: 140, y: 60)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .ignoresSafeArea()
    }

    // MARK: - Animated mesh path

    private var animatedBody: some View {
        NuvyraMeshBackground()
    }

    private func blob(tint: Color, opacity: Double, size: CGFloat) -> some View {
        Circle()
            .fill(tint.opacity(opacity))
            .frame(width: size, height: size)
            .blur(radius: 60)
            .allowsHitTesting(false)
    }
}

#if DEBUG
#Preview("Layered (default)") {
    NuvyraBackground()
}

#Preview("Animated") {
    NuvyraBackground(.animated)
}

#Preview("Animated + glass") {
    ZStack {
        NuvyraBackground(.animated)
        VStack(spacing: NuvyraSpacing.md) {
            NuvyraGlassCard(.prominent) {
                Text("Hero glass over animated mesh").font(.headline)
            }
            NuvyraGlassCard {
                Text("Regular glass over animated mesh")
            }
        }
        .padding()
    }
}
#endif
