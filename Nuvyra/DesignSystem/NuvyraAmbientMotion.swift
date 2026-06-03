import SwiftUI

// MARK: - Breath modifier

/// Slow, looping "this surface is alive" pulse. The eye reads it as
/// breath: a 3.2s ease-in-out cycle between scale 1.0 and ~1.025. Used
/// behind the rhythm-score ring on the Dashboard hero and inside any
/// other heroes that should feel calm but not static.
///
/// `accessibilityReduceMotion` collapses the modifier to a no-op so users
/// who opt out never see the surface move.
struct NuvyraBreathModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 1.0

    /// Maximum scale at the peak of the cycle. 1.025 is the most we can
    /// take without crashing into layout edges on hero-sized rings.
    var amount: CGFloat = 1.025

    /// Full cycle duration. 3.2s keeps the pulse on the calm side of
    /// human resting breath — anything faster reads as "loading".
    var duration: Double = 3.2

    func body(content: Content) -> some View {
        content
            .scaleEffect(phase)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    phase = amount
                }
            }
    }
}

extension View {
    /// Ambient breath. Pass `amount`/`duration` to tune.
    func nuvyraBreath(amount: CGFloat = 1.025, duration: Double = 3.2) -> some View {
        modifier(NuvyraBreathModifier(amount: amount, duration: duration))
    }
}

// MARK: - Goal-reached radial glow

/// Soft accent halo that turns on when a numeric goal has been hit
/// (calorie ring full, streak milestone, rhythm score ≥ 80, etc.). Three
/// stacked overlays — the inner one closest to the ring stroke gives the
/// "the ring itself is glowing" effect, the outer two paint the ambient
/// halo on top of the card material.
///
/// We *also* pop the ring on transition: when `isActive` flips from false
/// to true the modifier scales the content up briefly and then settles —
/// the eye reads it as "yes, you hit it" without any haptic.
struct NuvyraGoalGlowModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var popScale: CGFloat = 1.0
    @State private var pulse: CGFloat = 1.0
    var isActive: Bool
    var tint: Color = NuvyraColors.accent

    func body(content: Content) -> some View {
        content
            .scaleEffect(popScale)
            .background(glowLayers)
            .onChange(of: isActive) { _, newValue in
                guard newValue, !reduceMotion else { return }
                playPop()
            }
            .onAppear {
                guard isActive, !reduceMotion else { return }
                // Pulse the glow gently while the goal stays reached so
                // the user keeps catching it at scroll.
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    pulse = 1.08
                }
            }
    }

    @ViewBuilder
    private var glowLayers: some View {
        if isActive {
            ZStack {
                // Inner halo — sits right at the ring stroke.
                Circle()
                    .fill(tint.opacity(0.18))
                    .blur(radius: 14)
                    .scaleEffect(pulse * 0.94)
                // Mid halo — gives the "depth" to the glow.
                Circle()
                    .fill(tint.opacity(0.10))
                    .blur(radius: 28)
                    .scaleEffect(pulse * 1.06)
                // Outer halo — barely visible, anchors the effect to the
                // card so it doesn't look like a bug.
                Circle()
                    .fill(tint.opacity(0.05))
                    .blur(radius: 48)
                    .scaleEffect(pulse * 1.20)
            }
            .allowsHitTesting(false)
        }
    }

    /// One-shot scale pop on activation. Spring physics — same response
    /// shape the press tilt uses so the family feels coherent.
    private func playPop() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.62)) {
            popScale = 1.08
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                popScale = 1.0
            }
            // Kick the pulse loop now that the pop has settled.
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                pulse = 1.08
            }
        }
    }
}

extension View {
    /// Adds a soft accent halo + one-shot scale pop when `isActive`
    /// flips on. Designed for the dashboard rhythm hero ring, calorie
    /// ring, step ring — any circular "goal complete" affordance.
    func nuvyraGoalGlow(isActive: Bool, tint: Color = NuvyraColors.accent) -> some View {
        modifier(NuvyraGoalGlowModifier(isActive: isActive, tint: tint))
    }
}

#if DEBUG
#Preview("Breath + Glow") {
    struct DemoView: View {
        @State private var goalActive = false
        var body: some View {
            ZStack {
                NuvyraBackground(.animated)
                VStack(spacing: NuvyraSpacing.xl) {
                    Circle()
                        .stroke(NuvyraColors.accentGradient, lineWidth: 14)
                        .frame(width: 160, height: 160)
                        .nuvyraBreath()
                        .nuvyraGoalGlow(isActive: goalActive)

                    Toggle("Goal reached", isOn: $goalActive)
                        .padding()
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding()
            }
        }
    }
    return DemoView()
}
#endif
