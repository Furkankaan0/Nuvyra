//
//  NuvyraRingShader.metal
//
//  Stitchable SwiftUI shaders. iOS 17's `Shader(function:arguments:)`
//  loads these by name from the default Metal library that Xcode
//  compiles at build time. Each function is declared `[[stitchable]]`
//  so SwiftUI's runtime can chain it after the SwiftUI rasteriser.
//
//  Functions exposed:
//   - nuvyraFluidGlow    — distorts each pixel along a slow sin-wave
//                          field then tints by accent, used as a
//                          .colorEffect on hero rings.
//   - nuvyraShimmerSweep — radial-angle gated highlight; lighter than
//                          the existing AngularGradient path, runs at
//                          GPU instead of SwiftUI compositor.
//
//  `nuvyraFluidGlow` is a cheap colorEffect; the sweep/background
//  functions sample the SwiftUI layer once and stay bounded by the
//  maxSampleOffset supplied from Swift.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// MARK: - Fluid glow

/// Soft sinusoidal hue shift around the accent colour. The `time`
/// argument is driven by SwiftUI via `Shader(arguments: [.float(time)])`
/// — pass `Date().timeIntervalSinceReferenceDate` from the call site.
///
/// Inputs:
///   - position : pixel in view-local coordinates
///   - color    : the SwiftUI-rendered colour underneath the shader
///   - time     : seconds elapsed (passed in as float)
///   - accent.r/g/b/a : accent tint (passed in as four floats)
[[stitchable]] half4 nuvyraFluidGlow(
    float2 position,
    half4 color,
    float time,
    float accentR,
    float accentG,
    float accentB,
    float accentA
) {
    // Two orthogonal sin waves create the fluid shimmer. Wavelength
    // is generous (220 pt) so the effect reads as "breathing" rather
    // than "scrolling stripes". Phase offsets so the X and Y waves
    // don't pulse on the same beat.
    const float wavelength = 220.0;
    const float speed = 0.6;
    float u = position.x / wavelength + time * speed;
    float v = position.y / wavelength + time * speed * 0.7;
    float waveX = sin(u * 6.2831853) * 0.5 + 0.5;   // [0, 1]
    float waveY = cos(v * 6.2831853) * 0.5 + 0.5;
    float mix = (waveX * 0.6 + waveY * 0.4);         // [0, 1]

    // Blend the SwiftUI-rendered colour toward the accent by `mix`.
    half3 accent = half3(half(accentR), half(accentG), half(accentB));
    half3 tinted = color.rgb * (1.0h - half(mix) * 0.5h) + accent * half(mix) * 0.5h;
    return half4(tinted, color.a * half(accentA));
}

// MARK: - Shimmer sweep

/// Returns a transparent half4 except for a narrow angular window that
/// rotates around the centre of the view. Apply on top of an existing
/// ring stroke as a layer effect.
///
/// Inputs:
///   - position : pixel in view-local coordinates
///   - color    : the underlying colour
///   - time     : seconds elapsed
///   - centerX/Y : centre of the host view in local coords
///   - radius   : ring outer radius for falloff
[[stitchable]] half4 nuvyraShimmerSweep(
    float2 position,
    SwiftUI::Layer layer,
    float time,
    float centerX,
    float centerY,
    float radius
) {
    half4 color = layer.sample(position);
    float2 toCenter = position - float2(centerX, centerY);
    float angle = atan2(toCenter.y, toCenter.x);         // [-π, π]
    float dist = length(toCenter);

    // Sweep window — a narrow Gaussian of angular distance from the
    // current sweep phase.
    const float angularSpeed = 1.05;                     // rad/s
    float phase = fmod(time * angularSpeed, 6.2831853);  // wrap into [0, 2π)
    float delta = abs(fmod(angle - phase + 6.2831853 * 3.0, 6.2831853) - 3.14159265);
    float falloff = exp(-pow(delta * 6.0, 2.0));         // Gaussian, σ ≈ 0.17 rad

    // Radial gate so the highlight stays on the ring band (~±10% of
    // the radius). Avoids painting the whole disc.
    float radialGate = exp(-pow((dist - radius) / (radius * 0.10), 2.0));

    half intensity = half(falloff * radialGate);
    half3 white = half3(1.0h, 1.0h, 1.0h);
    half3 blended = color.rgb + (white - color.rgb) * intensity * 0.65h;
    return half4(blended, color.a * intensity);
}

// MARK: - Fluid background distortion

/// Samples the SwiftUI layer through a low-frequency vector field.
/// Apply as `.layerEffect` over gradients/backgrounds, not text.
[[stitchable]] half4 nuvyraFluidDistortion(
    float2 position,
    SwiftUI::Layer layer,
    float time,
    float intensity
) {
    float waveA = sin((position.y * 0.018) + time * 0.55);
    float waveB = cos((position.x * 0.014) - time * 0.38);
    float waveC = sin((position.x + position.y) * 0.010 + time * 0.24);
    float2 offset = float2(
        (waveA + waveC * 0.45) * intensity,
        (waveB - waveC * 0.35) * intensity
    );
    return layer.sample(position + offset);
}
