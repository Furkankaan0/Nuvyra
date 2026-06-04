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
    @State private var pulse: CGFloat = 1.0
    var isActive: Bool
    var tint: Color = NuvyraColors.accent

    func body(content: Content) -> some View {
        content
            .background(glowLayers)
            .onAppear { startPulseIfNeeded() }
            .onChange(of: isActive) { _, newValue in
                if newValue { startPulseIfNeeded() } else { pulse = 1.0 }
            }
    }

    /// Two-layer halo (inner + outer). Three layers added optical
    /// confusion when stacked with the host ring's own shadow / breath
    /// modifier — the middle ring's pulse phase didn't line up with the
    /// inner one and read as a flicker. Trimming to two keeps the depth
    /// without the conflict.
    @ViewBuilder
    private var glowLayers: some View {
        if isActive {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))
                    .blur(radius: 16)
                    .scaleEffect(pulse * 0.98)
                Circle()
                    .fill(tint.opacity(0.07))
                    .blur(radius: 36)
                    .scaleEffect(pulse * 1.12)
            }
            .allowsHitTesting(false)
        }
    }

    /// Single source of truth for the pulse loop. Idempotent: the
    /// `pulse` state is reset to 1.0 first so re-activations after a
    /// dormant period start from a clean baseline instead of jumping.
    private func startPulseIfNeeded() {
        guard isActive, !reduceMotion else { return }
        pulse = 1.0
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
            pulse = 1.08
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
