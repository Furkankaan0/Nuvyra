import SwiftUI

/// Multi-tier shadow system. Each elevation level is a small list of
/// `ShadowLayer`s that the consumer applies in order; stacking two shadows
/// (one tight + one diffuse) gives the soft "glass on cream" depth iOS
/// system widgets ship with, without losing performance on older devices.
///
/// Usage:
///   ```swift
///   someView.nuvyraShadow(.elevated, scheme: scheme)
///   ```
///
/// The historical `NuvyraShadow.card(_:)` accessor is preserved as a thin
/// alias around `.soft` so call sites that pre-date the tier system keep
/// compiling.
enum NuvyraShadow {

    // MARK: - Tiers

    enum Elevation {
        /// Ambient depth — used inside a glass card to lift secondary text.
        case ambient
        /// Default soft drop shadow used by `NuvyraCard` and most surfaces.
        case soft
        /// Hero/prominent cards. Two layers — one tight, one diffuse.
        case elevated
        /// Sheets, floating action buttons, modal accents.
        case floating
    }

    struct ShadowLayer: Equatable {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    static func layers(_ elevation: Elevation, scheme: ColorScheme) -> [ShadowLayer] {
        switch elevation {
        case .ambient:
            return [
                ShadowLayer(color: Color.black.opacity(scheme == .dark ? 0.18 : 0.04),
                            radius: 6, x: 0, y: 2)
            ]
        case .soft:
            return [
                ShadowLayer(color: Color.black.opacity(scheme == .dark ? 0.32 : 0.08),
                            radius: 18, x: 0, y: 10)
            ]
        case .elevated:
            return [
                // Tight contact shadow — anchors the card to the surface.
                ShadowLayer(color: Color.black.opacity(scheme == .dark ? 0.34 : 0.10),
                            radius: 6, x: 0, y: 2),
                // Diffuse halo — gives the card its premium "floating" feel.
                ShadowLayer(color: Color.black.opacity(scheme == .dark ? 0.28 : 0.07),
                            radius: 24, x: 0, y: 14)
            ]
        case .floating:
            return [
                ShadowLayer(color: Color.black.opacity(scheme == .dark ? 0.38 : 0.12),
                            radius: 10, x: 0, y: 4),
                ShadowLayer(color: Color.black.opacity(scheme == .dark ? 0.32 : 0.09),
                            radius: 32, x: 0, y: 18)
            ]
        }
    }

    // MARK: - Back-compat

    /// Legacy single-shadow API. Returns the colour the old `NuvyraCard` used
    /// (matches the `.soft` tier's primary layer for visual continuity).
    static func card(_ scheme: ColorScheme) -> Color {
        layers(.soft, scheme: scheme).first?.color ?? Color.black.opacity(0.08)
    }
}

/// View modifier that applies every layer of an elevation tier in order.
/// Splitting one drop shadow into two stacked layers (contact + diffuse) is
/// how SwiftUI mimics Apple's system widget depth — the layered call is
/// crucial; one `.shadow(...)` alone reads "flat".
struct NuvyraShadowModifier: ViewModifier {
    let elevation: NuvyraShadow.Elevation
    let scheme: ColorScheme

    func body(content: Content) -> some View {
        NuvyraShadow.layers(elevation, scheme: scheme)
            .reduce(AnyView(content)) { partial, layer in
                AnyView(partial.shadow(color: layer.color, radius: layer.radius, x: layer.x, y: layer.y))
            }
    }
}

extension View {
    /// Apply a tier from `NuvyraShadow.Elevation`. Equivalent to chaining
    /// every `ShadowLayer` returned from `NuvyraShadow.layers(...)`.
    func nuvyraShadow(_ elevation: NuvyraShadow.Elevation, scheme: ColorScheme) -> some View {
        modifier(NuvyraShadowModifier(elevation: elevation, scheme: scheme))
    }
}
