import SwiftUI

struct AICoachComposer: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var text: String
    var isSending: Bool
    var canSend: Bool
    var onSend: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: NuvyraSpacing.sm) {
            TextField("AI Coach'a sor…", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(NuvyraColors.card(scheme).opacity(0.9), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                        .stroke(NuvyraColors.accent.opacity(isFocused ? 0.45 : 0.16), lineWidth: isFocused ? 1.4 : 1)
                )
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit { if canSend, !isSending { onSend() } }

            Button(action: onSend) {
                Image(systemName: isSending ? "hourglass" : "paperplane.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: canSend && !isSending
                                ? [NuvyraColors.accent, NuvyraColors.softMint]
                                : [NuvyraColors.accent.opacity(0.4), NuvyraColors.softMint.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .shadow(color: NuvyraColors.accent.opacity(canSend ? 0.32 : 0.0), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!canSend || isSending)
            .accessibilityLabel("Mesajı gönder")
        }
        .padding(NuvyraSpacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous)
                .stroke(NuvyraColors.accent.opacity(0.10))
        )
    }
}

#if DEBUG
private struct ComposerPreview: View {
    @State private var text = ""
    var body: some View {
        AICoachComposer(text: $text, isSending: false, canSend: !text.isEmpty, onSend: {})
            .padding()
            .background(NuvyraBackground())
    }
}

#Preview { ComposerPreview() }
#endif
