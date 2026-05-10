import SwiftUI

struct AICoachOrb: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var size: CGFloat = 80
    var isActive: Bool = false
    @State private var pulse = false
    @State private var hueRotate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            NuvyraColors.softMint.opacity(0.9),
                            NuvyraColors.accent.opacity(0.55),
                            .clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: size * 0.55
                    )
                )
                .frame(width: size, height: size)
                .blur(radius: pulse ? 6 : 2)
                .scaleEffect(pulse ? 1.08 : 0.94)

            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.8), .clear, NuvyraColors.softMint.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: size * 0.75, height: size * 0.75)
                .rotationEffect(.degrees(hueRotate ? 360 : 0))

            Image(systemName: "sparkles")
                .font(.system(size: size * 0.32, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: NuvyraColors.accent.opacity(0.6), radius: 6)
        }
        .onAppear { startAnimation() }
        .onChange(of: isActive) { _, _ in startAnimation() }
        .accessibilityHidden(true)
    }

    private func startAnimation() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: isActive ? 0.8 : 1.6).repeatForever(autoreverses: true)) {
            pulse = true
        }
        withAnimation(.linear(duration: isActive ? 4 : 8).repeatForever(autoreverses: false)) {
            hueRotate = true
        }
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 24) {
        AICoachOrb(size: 80, isActive: false)
        AICoachOrb(size: 60, isActive: true)
    }
    .padding()
    .background(NuvyraBackground())
}
#endif
