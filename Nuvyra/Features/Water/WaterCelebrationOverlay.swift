import SwiftUI

struct WaterCelebrationOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    var onDismiss: () -> Void
    @State private var sealScale: CGFloat = 0.4
    @State private var ringScale: CGFloat = 0.4
    @State private var ringOpacity: CGFloat = 1
    @State private var visible = false

    private var tint: Color { Color(red: 0.30, green: 0.70, blue: 0.95) }

    var body: some View {
        ZStack {
            Color.black.opacity(visible ? 0.32 : 0)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: NuvyraSpacing.md) {
                ZStack {
                    Circle()
                        .stroke(tint.opacity(0.6), lineWidth: 3)
                        .frame(width: 200, height: 200)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [tint, tint.opacity(0.6), .clear],
                                center: .center,
                                startRadius: 4,
                                endRadius: 90
                            )
                        )
                        .frame(width: 180, height: 180)
                        .blur(radius: 12)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 84, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: tint.opacity(0.6), radius: 12)
                        .scaleEffect(sealScale)
                }

                VStack(spacing: 4) {
                    Text("Hedefe ulaştın!")
                        .font(.system(.title, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)
                    Text("Bugünkü su hedefini tamamladın. Akşam küçük yudumlarla devam etmek yeterli.")
                        .multilineTextAlignment(.center)
                        .font(NuvyraTypography.body)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, NuvyraSpacing.lg)

                Button(action: onDismiss) {
                    Text("Devam et")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(NuvyraSpacing.lg)
            .opacity(visible ? 1 : 0)
        }
        .onAppear { animateIn() }
        .accessibilityAddTraits(.isModal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Su hedefini tamamladın")
    }

    private func animateIn() {
        if reduceMotion {
            sealScale = 1
            ringScale = 1
            ringOpacity = 0
            visible = true
            return
        }
        withAnimation(.easeOut(duration: 0.25)) { visible = true }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) { sealScale = 1 }
        withAnimation(.easeOut(duration: 0.9).delay(0.05)) {
            ringScale = 1.6
            ringOpacity = 0
        }
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        WaterCelebrationOverlay(onDismiss: {})
    }
}
#endif
