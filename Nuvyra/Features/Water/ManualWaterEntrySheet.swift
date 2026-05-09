import SwiftUI

struct ManualWaterEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Binding var amountText: String
    var errorMessage: String?
    var onSubmit: () async -> Bool

    @FocusState private var amountFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                NuvyraBackground()
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    NuvyraSectionHeader(title: "Manuel ml girişi", subtitle: "Tükettiğin miktarı milimetre cinsinden gir.")

                    HStack {
                        TextField("Örn. 350", text: $amountText)
                            .keyboardType(.numberPad)
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .focused($amountFocused)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, NuvyraSpacing.md)
                            .frame(maxWidth: .infinity)
                            .background(NuvyraColors.card(scheme).opacity(0.85), in: RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous)
                                    .stroke(NuvyraColors.accent.opacity(amountFocused ? 0.45 : 0.16), lineWidth: amountFocused ? 1.4 : 1)
                            )
                        Text("ml")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(NuvyraColors.mutedCoral)
                    }

                    Spacer()

                    NuvyraPrimaryButton(title: "Ekle", systemImage: "plus.circle.fill") {
                        Task {
                            if await onSubmit() { dismiss() }
                        }
                    }
                }
                .padding(NuvyraSpacing.lg)
            }
            .navigationTitle("Manuel ml")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") { dismiss() }
                }
            }
            .onAppear { amountFocused = true }
        }
        .presentationDetents([.medium])
    }
}

#if DEBUG
private struct ManualWaterEntrySheetPreview: View {
    @State private var text = ""
    var body: some View {
        ManualWaterEntrySheet(amountText: $text, errorMessage: nil) { true }
    }
}

#Preview { ManualWaterEntrySheetPreview() }
#endif
