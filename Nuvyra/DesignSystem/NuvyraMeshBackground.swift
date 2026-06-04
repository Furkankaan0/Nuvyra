import SwiftUI
import UIKit

/// Slowly-shifting "liquid" background. Two paths under one umbrella:
///
/// - **iOS 18+**: real `MeshGradient`. We animate the 3×3 control-point
///   colours with a single ambient phase (12s loop) so the whole surface
///   gently breathes between brand tints.
/// - **iOS 17**: a `TimelineView` + `Canvas` fallback that paints three
///   colour blobs whose centres orbit on a long, slow trigonometric
///   path. The eye reads it as the same effect at a glance — the iOS 17
///   path is the only thing under most cards that's still moving, so the
///   premium feel survives the SDK gap.
///
/// `accessibilityReduceMotion` short-circuits both paths to a static
/// frame so users who opt out don't get any motion at all.
struct NuvyraMeshBackground: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                meshGradient
            } else {
                canvasFallback
            }
        }
        .ignoresSafeArea()
        .nuvyraFluidDistortion(intensity: scheme == .dark ? 7 : 8)
    }

    // MARK: - iOS 18+ MeshGradient

    @available(iOS 18.0, *)
    private var meshGradient: some View {
        // We drive every colour through `phaseAnimator` so the surface
        // morphs between three palettes (warm / mint / sand) over 12s.
        // `points` (control-point lattice) is fixed — only colours move,
        // which keeps the perceived motion calm.
        TimelineView(.animation(minimumInterval: reduceMotion ? .infinity : 1.0 / 30.0)) { context in
            let phase = reduceMotion
                ? 0.0
                : sin(context.date.timeIntervalSinceReferenceDate * (.pi / 6.0)) * 0.5 + 0.5
            // phase ∈ [0, 1] — used to lerp between two palettes.

            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
                    SIMD2(0.0, 0.5), SIMD2(0.5, 0.5), SIMD2(1.0, 0.5),
                    SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0)
                ],
                colors: palette(phase: phase, scheme: scheme)
            )
            .ignoresSafeArea()
        }
    }

    @available(iOS 18.0, *)
    private func palette(phase: Double, scheme: ColorScheme) -> [Color] {
        // Two palettes (`a` and `b`); we lerp between them.
        let a: [Color] = scheme == .dark
            ? [
                NuvyraColors.darkBackground, NuvyraColors.accent.opacity(0.18), NuvyraColors.darkBackground,
                NuvyraColors.softMint.opacity(0.12), NuvyraColors.darkBackground, NuvyraColors.softSand.opacity(0.10),
                NuvyraColors.darkBackground, NuvyraColors.paleLime.opacity(0.10), NuvyraColors.darkBackground
            ]
            : [
                NuvyraColors.lightBackground, NuvyraColors.softMint.opacity(0.34), NuvyraColors.lightBackground,
                NuvyraColors.accent.opacity(0.20), NuvyraColors.lightBackground, NuvyraColors.softSand.opacity(0.32),
                NuvyraColors.lightBackground, NuvyraColors.paleLime.opacity(0.22), NuvyraColors.lightBackground
            ]
        let b: [Color] = scheme == .dark
            ? [
                NuvyraColors.darkBackground, NuvyraColors.softMint.opacity(0.16), NuvyraColors.darkBackground,
                NuvyraColors.softSand.opacity(0.14), NuvyraColors.darkBackground, NuvyraColors.accent.opacity(0.16),
                NuvyraColors.darkBackground, NuvyraColors.mutedCoral.opacity(0.08), NuvyraColors.darkBackground
            ]
            : [
                NuvyraColors.lightBackground, NuvyraColors.softSand.opacity(0.36), NuvyraColors.lightBackground,
                NuvyraColors.softMint.opacity(0.26), NuvyraColors.lightBackground, NuvyraColors.accent.opacity(0.18),
                NuvyraColors.lightBackground, NuvyraColors.mutedCoral.opacity(0.10), NuvyraColors.lightBackground
            ]
        return zip(a, b).map { lerp(from: $0, to: $1, t: phase) }
    }

    @available(iOS 18.0, *)
    private func lerp(from: Color, to: Color, t: Double) -> Color {
        // SwiftUI doesn't expose a public colour-interpolation API on iOS,
        // so we mix opacities of two Colors against the same neutral
        // backdrop. The result is visually close enough for ambient
        // animation; the eye can't catch the simplification at 30 fps.
        let clamped = max(0, min(1, t))
        return Color(
            uiColor: blended(uiFrom: UIColor(from), uiTo: UIColor(to), t: clamped)
        )
    }

    @available(iOS 18.0, *)
    private func blended(uiFrom: UIColor, uiTo: UIColor, t: Double) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        uiFrom.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiTo.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let amount = CGFloat(t)
        return UIColor(
            red: r1 + (r2 - r1) * amount,
            green: g1 + (g2 - g1) * amount,
            blue: b1 + (b2 - b1) * amount,
            alpha: a1 + (a2 - a1) * amount
        )
    }

    // MARK: - iOS 17 fallback (TimelineView + Canvas)

    private var canvasFallback: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? .infinity : 1.0 / 30.0)) { context in
            Canvas { ctx, size in
                // Static base gradient — same calmGradient the original
                // background uses, painted with a Path so Canvas can
                // composite the moving blobs on top.
                let rect = CGRect(origin: .zero, size: size)
                ctx.fill(
                    Path(rect),
                    with: .linearGradient(
                        Gradient(colors: baseColours),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: size.width, y: size.height)
                    )
                )

                // Three slowly-orbiting tinted blobs. Each one's phase is
                // offset so their peaks never align — the perceived motion
                // stays smooth instead of pulsing.
                let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                drawBlob(in: ctx, size: size, tint: NuvyraColors.accent,
                         radius: size.width * 0.42, phase: t * 0.07, offset: 0)
                drawBlob(in: ctx, size: size, tint: NuvyraColors.softSand,
                         radius: size.width * 0.36, phase: t * 0.05, offset: .pi / 2)
                drawBlob(in: ctx, size: size, tint: NuvyraColors.paleLime,
                         radius: size.width * 0.28, phase: t * 0.04, offset: .pi)
            }
            .blur(radius: 36)
        }
        .ignoresSafeArea()
    }

    private var baseColours: [Color] {
        scheme == .dark
            ? [NuvyraColors.darkBackground, Color(red: 0.10, green: 0.16, blue: 0.14), NuvyraColors.darkBackground]
            : [NuvyraColors.lightBackground, Color(red: 0.91, green: 0.96, blue: 0.90), Color(red: 0.98, green: 0.93, blue: 0.84)]
    }

    private func drawBlob(
        in ctx: GraphicsContext,
        size: CGSize,
        tint: Color,
        radius: CGFloat,
        phase: Double,
        offset: Double
    ) {
        let centre = CGPoint(
            x: size.width / 2 + cos(phase + offset) * size.width * 0.28,
            y: size.height / 2 + sin(phase + offset) * size.height * 0.30
        )
        let blobRect = CGRect(
            x: centre.x - radius,
            y: centre.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        ctx.fill(
            Path(ellipseIn: blobRect),
            with: .color(tint.opacity(scheme == .dark ? 0.18 : 0.22))
        )
    }
}

#if DEBUG
#Preview("Mesh background") {
    ZStack {
        NuvyraMeshBackground()
        VStack {
            NuvyraGlassCard(.prominent) {
                Text("Akan arka plan üzerinde glass okunabilirliği")
                    .font(.headline)
            }
            .padding()
            Spacer()
        }
    }
}
#endif
