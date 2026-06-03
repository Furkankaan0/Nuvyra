import SwiftUI

/// "Light sweep" overlay for circular surfaces. An `AngularGradient` whose
/// rotation phase loops continuously — the eye reads it as a Metal-shader
/// shimmer over a ring stroke, but without the asset cost of an actual
/// `.metal` shader source file (which would need to ship in the project
/// bundle and forces every build to compile its IR).
///
/// Designed to overlay an existing ring such as the one inside
/// `DashboardRhythmHero`. The modifier:
/// - paints a translucent rotating angular gradient,
/// - clips it to the same ring stroke width as the caller,
/// - composites it on top of the host ring with `.blendMode(.softLight)`
///   so the brand accent doesn't bleach, just shimmers,
/// - stops cleanly under `accessibilityReduceMotion`.
struct NuvyraShimmerRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0

    /// Stroke width — match it to the host ring exactly. The shimmer
    /// renders inside the same stroke band so the ring keeps a single
    /// optical width.
    var lineWidth: CGFloat = 12

    /// Full revolution period. 6s reads as "premium" — anything faster
    /// turns it into a loading hint, which we don't want here.
    var duration: Double = 6

    /// Highlight tint. Leave at the accent so the shimmer reads as part
    /// of the same gradient the host ring uses.
    var tint: Color = NuvyraColors.accent

    var body: some View {
        Circle()
            .stroke(sweepGradient, lineWidth: lineWidth)
            .rotationEffect(.degrees(rotation))
            .blendMode(.softLight)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }

    /// Angular gradient with a narrow bright window. Two clear stops, two
    /// transparent stops — the window slides around the ring instead of
    /// pulsing the whole loop simultaneously.
    private var sweepGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: Color.white.opacity(0), location: 0.00),
                .init(color: tint.opacity(0.55), location: 0.18),
                .init(color: Color.white.opacity(0.82), location: 0.22),
                .init(color: tint.opacity(0.55), location: 0.26),
                .init(color: Color.white.opacity(0), location: 0.45),
                .init(color: Color.white.opacity(0), location: 1.00)
            ]),
            center: .center
        )
    }
}

extension View {
    /// Wrap a circular surface with the shimmer overlay. Apply *after*
    /// the host ring is drawn so the sweep composites on top.
    ///
    /// ```swift
    /// Circle().stroke(NuvyraColors.accentGradient, lineWidth: 12)
    ///     .nuvyraShimmer(lineWidth: 12)
    /// ```
    func nuvyraShimmer(lineWidth: CGFloat = 12, duration: Double = 6, tint: Color = NuvyraColors.accent) -> some View {
        overlay(NuvyraShimmerRing(lineWidth: lineWidth, duration: duration, tint: tint))
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground(.animated)
        Circle()
            .stroke(NuvyraColors.accentGradient, lineWidth: 14)
            .frame(width: 220, height: 220)
            .nuvyraShimmer(lineWidth: 14)
    }
}
#endif
