import SwiftUI

struct AICoachTypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(NuvyraColors.accent.opacity(phase == index ? 0.95 : 0.35))
                    .frame(width: 7, height: 7)
                    .scaleEffect(phase == index ? 1.15 : 0.9)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(NuvyraColors.accent.opacity(0.15)))
        .onAppear {
            guard !reduceMotion else { return }
            startAnimation()
        }
        .accessibilityLabel("AI Coach yazıyor")
    }

    private func startAnimation() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 280_000_000)
                withAnimation(.easeInOut(duration: 0.25)) {
                    phase = (phase + 1) % 3
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    AICoachTypingIndicator()
        .padding()
        .background(NuvyraBackground())
}
#endif
