import SwiftUI

/// Layered ambient background — a calm gradient with three soft blobs that
/// sit *behind* glass surfaces and supply the colour material picks up
/// through translucency. Tuned so:
///
/// - The blobs are large + heavily blurred → no visible edges, just a
///   warm vignette feel.
/// - Each blob uses a different brand colour so the eye perceives subtle
///   depth instead of a flat wash.
/// - Reduce-motion friendly — we never animate the layers (they're static
///   blurs; SwiftUI handles them on the compositor).
struct NuvyraBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            NuvyraColors.calmGradient(scheme)
                .ignoresSafeArea()

            // Top-trailing — primary accent halo, behind hero cards.
            blob(
                tint: NuvyraColors.accent,
                opacity: scheme == .dark ? 0.14 : 0.18,
                size: 320
            )
            .offset(x: 130, y: -150)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            // Bottom-leading — soft sand warmth, anchors the lower half.
            blob(
                tint: NuvyraColors.softSand,
                opacity: scheme == .dark ? 0.12 : 0.22,
                size: 260
            )
            .offset(x: -120, y: 180)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            // Center-right — pale lime accent that catches the middle of
            // the scroll, so the page never feels empty between cards.
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

    private func blob(tint: Color, opacity: Double, size: CGFloat) -> some View {
        Circle()
            .fill(tint.opacity(opacity))
            .frame(width: size, height: size)
            .blur(radius: 60)
            .allowsHitTesting(false)
    }
}

#if DEBUG
#Preview("Background only") {
    NuvyraBackground()
}

#Preview("Background + glass") {
    ZStack {
        NuvyraBackground()
        VStack(spacing: NuvyraSpacing.md) {
            NuvyraGlassCard(.prominent) {
                Text("Hero üzerinde glass okunabilirliği")
                    .font(.headline)
            }
            NuvyraGlassCard {
                Text("Regular kart")
            }
        }
        .padding()
    }
}
#endif
