import SwiftUI

/// Large gradient confirm button. Goes dim when disabled and shows a spinner while saving.
struct ConfirmAddFoodButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false

    var title: String
    var systemImage: String = "checkmark"
    var isLoading: Bool = false
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button {
            guard isEnabled, !isLoading else { return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.55)) {
                pressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.75)) {
                    pressed = false
                }
                action()
            }
        } label: {
            HStack(spacing: NuvyraSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.headline.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: isEnabled
                        ? [NuvyraColors.accent, NuvyraColors.softMint]
                        : [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: isEnabled ? NuvyraColors.accent.opacity(0.35) : .clear, radius: 14, x: 0, y: 8)
            .scaleEffect(pressed ? 0.97 : 1.0)
            .opacity(isEnabled ? 1 : 0.65)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(title)
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        VStack(spacing: NuvyraSpacing.md) {
            ConfirmAddFoodButton(title: "Kaydet", action: {})
            ConfirmAddFoodButton(title: "Kaydediliyor", isLoading: true, action: {})
            ConfirmAddFoodButton(title: "Doldur", isEnabled: false, action: {})
        }
        .padding()
    }
}
#endif
