import SwiftUI

// MARK: - Press tilt button style

/// 3D press affordance for tappable cards. On tap-down the label scales
/// slightly *and* rotates around its center to fake a perspective dip —
/// the same micro-feedback Apple Pay / TikTok cards use. ReduceMotion
/// collapses to a single subtle opacity change.
///
/// Usage:
///   ```swift
///   Button { … } label: { card }
///       .buttonStyle(.nuvyraPressTilt)
///   ```
///
/// Designed to wrap cards inside a `NavigationLink` or `Button`, replacing
/// the bare `.plain` style we use everywhere today. Existing call sites
/// keep compiling because `.plain` is still valid — opt in per surface.
struct NuvyraPressTiltStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Maximum tilt angle (degrees) on tap-down. 6° reads as "premium card
    /// press" without becoming a parlor trick — anything above 8° starts
    /// to feel like a toy.
    var maxTilt: Double = 6

    /// Maximum scale-down on tap. iOS HIG's reference for cards is 0.97;
    /// we lean a touch tighter (0.965) so the tilt's edge depth reads.
    var minScale: CGFloat = 0.965

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .scaleEffect(reduceMotion ? 1.0 : (pressed ? minScale : 1.0))
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : (pressed ? maxTilt : 0)),
                axis: (x: 1, y: 0, z: 0),
                anchor: .center,
                anchorZ: 0,
                perspective: 0.8
            )
            .opacity(pressed ? 0.96 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.7),
                value: pressed
            )
    }
}

extension ButtonStyle where Self == NuvyraPressTiltStyle {
    /// Default-tuned `.nuvyraPressTilt`. Most call sites use this shorthand.
    static var nuvyraPressTilt: NuvyraPressTiltStyle { NuvyraPressTiltStyle() }
}

// MARK: - Scroll-bound parallax tilt

/// Reads each card's vertical position inside the scroll view and rotates
/// it slightly along the X axis as it crosses the centre line. The effect
/// is subtle on purpose — cards passing the top fold dip *away*, the one
/// in the middle is flat, cards entering from the bottom tilt *toward*
/// the user. Reads as ambient depth, never as motion sickness.
///
/// Requires iOS 17's `.scrollTransition(_:transition:)`. ReduceMotion
/// disables the rotation entirely so the card sits flat.
extension View {
    /// - parameter maxDegrees: peak tilt at the top/bottom of the visible
    ///   strip. 4° feels right for hero cards on iPhone-sized screens.
    func nuvyraScrollTilt(maxDegrees: Double = 4) -> some View {
        modifier(NuvyraScrollTiltModifier(maxDegrees: maxDegrees))
    }
}

private struct NuvyraScrollTiltModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var maxDegrees: Double

    func body(content: Content) -> some View {
        // `.scrollTransition` runs during the scroll, passing the
        // ScrollTransitionPhase that says where we are relative to the
        // visible bounds. We map that to a small rotation3DEffect.
        content.scrollTransition(.interactive, axis: .vertical) { view, phase in
            let value = phase.value  // -1 (top fold) → 0 (centre) → 1 (bottom fold)
            let degrees = reduceMotion ? 0 : Double(value) * maxDegrees
            return view
                .rotation3DEffect(
                    .degrees(degrees),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .center,
                    perspective: 0.6
                )
                // A whisper of opacity falloff at the very top/bottom so
                // cards feel like they're slipping behind the safe area
                // instead of getting hard-clipped.
                .opacity(reduceMotion ? 1 : (1 - abs(Double(value)) * 0.05))
        }
    }
}

// MARK: - Combined tilt button style (press + ambient hover)

/// Sugar that pairs press tilt with a static visual lift modifier so a
/// non-`Button` view can still feel tappable. Use when you can't switch
/// the call site to a Button (e.g. a List row), but want the tilt
/// affordance on appear.
struct NuvyraTappableCardModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1.0 : (pressed ? 0.97 : 1.0))
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : (pressed ? 5 : 0)),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.7
            )
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: pressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressed = true }
                    .onEnded { _ in pressed = false }
            )
    }
}

extension View {
    /// Reads as "this card is tappable" without forcing the call site to be
    /// a Button. Hooks a press gesture and runs the same tilt+scale as
    /// `.buttonStyle(.nuvyraPressTilt)`.
    func nuvyraTappable() -> some View {
        modifier(NuvyraTappableCardModifier())
    }
}

#if DEBUG
#Preview("Tilt") {
    ZStack {
        NuvyraBackground()
        ScrollView {
            VStack(spacing: NuvyraSpacing.md) {
                ForEach(0..<6) { idx in
                    Button {} label: {
                        NuvyraGlassCard(.prominent) {
                            HStack {
                                Image(systemName: "leaf.fill")
                                    .foregroundStyle(NuvyraColors.accent)
                                Text("Card #\(idx + 1)")
                                    .font(NuvyraTypography.section)
                            }
                        }
                    }
                    .buttonStyle(.nuvyraPressTilt)
                    .nuvyraScrollTilt()
                }
            }
            .padding()
        }
    }
}
#endif
