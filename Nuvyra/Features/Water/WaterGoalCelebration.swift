import SwiftUI

/// Lightweight droplet "burst" overlay shown for ~1.5s when the user crosses
/// the daily water goal. No external dependencies — pure SwiftUI animation.
struct WaterGoalCelebration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false
    var onComplete: () -> Void

    private let droplets: [Droplet] = (0..<18).map { _ in Droplet() }

    var body: some View {
        ZStack {
            Color.black.opacity(0.18).ignoresSafeArea()
            ZStack {
                ForEach(droplets) { drop in
                    Image(systemName: "drop.fill")
                        .font(.title3)
                        .foregroundStyle(drop.color)
                        .offset(
                            x: animate ? drop.endX : drop.startX,
                            y: animate ? drop.endY : drop.startY
                        )
                        .opacity(animate ? 0 : 1)
                        .rotationEffect(.degrees(animate ? drop.rotation : 0))
                        .animation(
                            reduceMotion ? nil : .easeOut(duration: 1.2).delay(drop.delay),
                            value: animate
                        )
                }
                VStack(spacing: NuvyraSpacing.xs) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [NuvyraColors.accent, NuvyraColors.softMint], startPoint: .top, endPoint: .bottom))
                        .scaleEffect(animate ? 1.1 : 0.5)
                        .opacity(animate ? 1 : 0)
                    Text("Hedef tamam!")
                        .font(NuvyraTypography.title)
                        .foregroundStyle(.white)
                        .opacity(animate ? 1 : 0)
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous))
                .shadow(color: NuvyraColors.accent.opacity(0.3), radius: 14, y: 8)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.55)) {
                animate = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                onComplete()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Su hedefi tamamlandı")
    }
}

private struct Droplet: Identifiable {
    let id = UUID()
    let startX: CGFloat = .random(in: -10...10)
    let startY: CGFloat = .random(in: -10...10)
    let endX: CGFloat = .random(in: -160...160)
    let endY: CGFloat = .random(in: -260...(-40))
    let rotation: Double = .random(in: -90...90)
    let delay: Double = .random(in: 0...0.2)
    let color: Color = [
        Color(red: 0.20, green: 0.56, blue: 0.95),
        Color(red: 0.45, green: 0.86, blue: 0.96),
        NuvyraColors.accent,
        NuvyraColors.softMint
    ].randomElement() ?? NuvyraColors.accent
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        WaterGoalCelebration {}
    }
}
#endif
