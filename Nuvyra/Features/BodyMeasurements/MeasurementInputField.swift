import SwiftUI

/// Optional-valued numeric pill used in the add-measurement sheet. Empty (`nil`)
/// means "skip this field for today"; the binding accepts a Double? so the
/// repository can apply a partial update without overwriting prior data.
struct MeasurementInputField: View {
    @Environment(\.colorScheme) private var scheme
    @FocusState private var focused: Bool
    @State private var draft: String = ""

    var icon: String
    var title: String
    var unit: String
    var tint: Color = NuvyraColors.accent
    var placeholder: String = "—"
    @Binding var value: Double?
    var range: ClosedRange<Double> = 0...300

    var body: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    TextField(placeholder, text: $draft)
                        .keyboardType(.decimalPad)
                        .focused($focused)
                        .font(.headline.weight(.heavy))
                        .submitLabel(.done)
                        .onChange(of: draft) { _, newValue in commit(text: newValue) }
                    Text(unit)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if value != nil {
                Button {
                    value = nil
                    draft = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(title) alanını temizle")
            }
        }
        .padding(.horizontal, NuvyraSpacing.md)
        .padding(.vertical, NuvyraSpacing.sm)
        .background(NuvyraColors.card(scheme).opacity(0.7), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                .stroke(focused ? tint.opacity(0.55) : tint.opacity(0.12), lineWidth: focused ? 1.5 : 1)
        )
        .animation(.easeInOut(duration: 0.18), value: focused)
        .onAppear {
            if let v = value { draft = v.cleanFormatted }
        }
        .onChange(of: value) { _, newValue in
            // External resets (e.g. clear button) should also sync the draft.
            if newValue == nil { draft = "" }
        }
    }

    private func commit(text: String) {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        if normalized.isEmpty {
            value = nil
            return
        }
        guard let parsed = Double(normalized) else { return }
        let clamped = min(max(parsed, range.lowerBound), range.upperBound)
        value = clamped
    }
}

#if DEBUG
private struct MeasurementInputFieldPreview: View {
    @State private var waist: Double? = 82.0
    @State private var hip: Double? = nil
    var body: some View {
        ZStack {
            NuvyraBackground()
            VStack(spacing: NuvyraSpacing.sm) {
                MeasurementInputField(icon: "ruler", title: "Bel", unit: "cm", value: $waist, range: 30...200)
                MeasurementInputField(icon: "ruler", title: "Kalça", unit: "cm", value: $hip, range: 30...200)
            }
            .padding()
        }
    }
}

#Preview {
    MeasurementInputFieldPreview()
}
#endif
