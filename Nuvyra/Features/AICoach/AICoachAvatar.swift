import SwiftUI

/// Animated wellness orb shown at the top of the coach screen and inside each
/// coach message bubble (in a smaller size). Pulses softly + rotates a glow ring.
struct AICoachAvatar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var glowAngle: Double = 0

    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [NuvyraColors.accent, NuvyraColors.softMint, NuvyraColors.paleLime, NuvyraColors.accent],
                        center: .center
                    )
                )
                .rotationEffect(.degrees(glowAngle))
                .frame(width: size, height: size)
                .blur(radius: size > 40 ? 8 : 4)
                .opacity(0.85)
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: size * 0.78, height: size * 0.78)
                .overlay(
                    Image(systemName: "leaf.fill")
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundStyle(NuvyraColors.accent)
                )
                .scaleEffect(pulse ? 1.06 : 0.96)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse.toggle() }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { glowAngle = 360 }
        }
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        HStack(spacing: 20) {
            AICoachAvatar(size: 80)
            AICoachAvatar(size: 56)
            AICoachAvatar(size: 32)
        }
    }
}
#endif
