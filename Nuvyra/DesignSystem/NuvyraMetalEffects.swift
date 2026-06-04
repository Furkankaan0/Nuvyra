import SwiftUI
import UIKit

/// Swift-side wrappers around the stitchable Metal shaders in
/// `Shaders/NuvyraRingShader.metal`.
///
/// Pattern:
///   ```swift
///   Circle().stroke(NuvyraColors.accentGradient, lineWidth: 12)
///       .modifier(NuvyraFluidGlow())
///   ```
///
/// Each modifier:
///   - drives the shader's `time` uniform from a `TimelineView`,
///   - extracts the accent's RGBA so we can ship a single shader and
///     re-tint per call site,
///   - bails out silently under `accessibilityReduceMotion` (the
///     modifier returns the content unchanged rather than painting
///     a frozen frame).
///
/// `colorEffect` (used by `nuvyraFluidGlow`) cannot sample neighbours
/// — perfect for a per-pixel hue shift. `layerEffect` (used by
/// `nuvyraShimmerSweep`) accepts a `maxSampleOffset:` and gives the
/// shader access to the post-rasterised layer, which is what we need
/// to draw the sweep highlight over an arbitrary ring stroke.

// MARK: - Fluid glow

struct NuvyraFluidGlow: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var tint: Color = NuvyraColors.accent

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                let t = Float(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 600))
                let rgba = Self.componentsOf(tint)
                content
                    .colorEffect(
                        ShaderLibrary.nuvyraFluidGlow(
                            .float(t),
                            .float(rgba.r),
                            .float(rgba.g),
                            .float(rgba.b),
                            .float(rgba.a)
                        )
                    )
            }
        }
    }

    /// Extracts the SwiftUI `Color`'s display-P3 components so the
    /// shader can paint a tint that matches the rest of the brand. We
    /// guard against `Color`s that don't bridge cleanly to UIColor by
    /// falling back to the accent.
    static func componentsOf(_ color: Color) -> (r: Float, g: Float, b: Float, a: Float) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        if UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) {
            return (Float(r), Float(g), Float(b), Float(a))
        }
        return (Float(0.10), Float(0.68), Float(0.52), 1)   // accent fallback
    }
}

// MARK: - Shimmer sweep

struct NuvyraMetalShimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Outer radius of the host ring. Required so the shader can apply
    /// a radial gate (only paints the highlight on the ring band).
    var radius: CGFloat

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                let t = Float(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 600))
                content
                    .layerEffect(
                        ShaderLibrary.nuvyraShimmerSweep(
                            .float(t),
                            .float(Float(radius)),
                            .float(Float(radius)),
                            .float(Float(radius))
                        ),
                        maxSampleOffset: .zero
                    )
            }
        }
    }
}

extension View {
    /// Apply the per-pixel sinusoidal hue shift. Safe over any colour
    /// surface; reads best on circle strokes and large glass cards.
    func nuvyraFluidGlow(tint: Color = NuvyraColors.accent) -> some View {
        modifier(NuvyraFluidGlow(tint: tint))
    }

    /// Apply the GPU-driven sweep highlight on a ring stroke. `radius`
    /// must match the host ring's outer radius.
    func nuvyraMetalShimmer(radius: CGFloat) -> some View {
        modifier(NuvyraMetalShimmer(radius: radius))
    }
}

// MARK: - Fluid distortion

struct NuvyraFluidDistortion: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var intensity: CGFloat = 9

    func body(content: Content) -> some View {
        if reduceMotion || intensity <= 0 {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                let t = Float(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 600))
                content.layerEffect(
                    ShaderLibrary.nuvyraFluidDistortion(
                        .float(t),
                        .float(Float(intensity))
                    ),
                    maxSampleOffset: CGSize(width: intensity, height: intensity)
                )
            }
        }
    }
}

extension View {
    /// Applies a real layer-sampling Metal distortion over gradient surfaces.
    /// Keep the intensity low over full-screen backgrounds so text remains calm.
    func nuvyraFluidDistortion(intensity: CGFloat = 9) -> some View {
        modifier(NuvyraFluidDistortion(intensity: intensity))
    }
}
