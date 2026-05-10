import SwiftUI

struct ConfirmAddFoodButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var title: String
    var systemImage: String
    var isEnabled: Bool
    var isSaving: Bool
    var action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: systemImage)
                }
                Text(isSaving ? "Kaydediliyor" : title)
                    .font(.headline.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: isEnabled
                        ? [NuvyraColors.accent, NuvyraColors.softMint]
                        : [NuvyraColors.accent.opacity(0.4), NuvyraColors.softMint.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .shadow(color: NuvyraColors.accent.opacity(isEnabled ? 0.32 : 0.0), radius: 12, x: 0, y: 8)
            .scaleEffect(pressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isSaving)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !reduceMotion, !pressed, isEnabled, !isSaving else { return }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { pressed = true }
                }
                .onEnded { _ in
                    guard !reduceMotion else { return }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { pressed = false }
                }
        )
        .accessibilityLabel(title)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        ConfirmAddFoodButton(title: "Öğünü kaydet", systemImage: "checkmark.circle.fill", isEnabled: true, isSaving: false, action: {})
        ConfirmAddFoodButton(title: "Öğünü kaydet", systemImage: "checkmark.circle.fill", isEnabled: false, isSaving: false, action: {})
        ConfirmAddFoodButton(title: "Öğünü kaydet", systemImage: "checkmark.circle.fill", isEnabled: true, isSaving: true, action: {})
    }
    .padding()
    .background(NuvyraBackground())
}
#endif
