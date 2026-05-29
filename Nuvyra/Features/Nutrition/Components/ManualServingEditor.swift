import SwiftUI

/// Phase 11 — Kullanıcının kendi yarattığı besinler için çoklu porsiyon
/// editörü. "100 g" referansı her zaman implicit (üst seviyede
/// `FoodItem.userCreated` ekler) — burada kullanıcı kültürel porsiyonları
/// tanımlar (1 dilim = 30 g, 1 kase = 240 g vb.). Editör binding üzerinden
/// `[ServingSize]` döner.
struct ManualServingEditor: View {
    @Binding var servings: [ServingSize]
    var maxCount: Int = 3

    @State private var draftLabel: String = ""
    @State private var draftGrams: Double = 100

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            if servings.isEmpty {
                emptyHint
            } else {
                ForEach(servings) { serving in
                    servingRow(serving)
                }
            }

            if servings.count < maxCount {
                Divider()
                addForm
            }
        }
    }

    private var emptyHint: some View {
        Label("Henüz porsiyon eklemedin. Örn: 1 dilim, 1 kase, 1 porsiyon.", systemImage: "info.circle")
            .font(NuvyraTypography.caption)
            .foregroundStyle(.secondary)
    }

    private func servingRow(_ serving: ServingSize) -> some View {
        HStack(spacing: NuvyraSpacing.sm) {
            Image(systemName: serving.isDefault ? "star.fill" : "circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(serving.isDefault ? Color.yellow : Color.secondary.opacity(0.5))
                .onTapGesture { toggleDefault(for: serving) }
                .accessibilityLabel(serving.isDefault ? "Varsayılan porsiyon" : "Varsayılan yap")

            VStack(alignment: .leading, spacing: 1) {
                Text(serving.preferredLabel)
                    .font(.subheadline.weight(.semibold))
                Text("\(Int(serving.grams.rounded())) g")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                remove(serving)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(NuvyraColors.mutedCoral)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Porsiyonu kaldır")
        }
        .padding(.vertical, 4)
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            HStack(spacing: NuvyraSpacing.sm) {
                TextField("Etiket (örn. 1 dilim)", text: $draftLabel)
                    .textInputAutocapitalization(.never)
                    .font(.subheadline)
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack(spacing: 4) {
                    Stepper("\(Int(draftGrams.rounded())) g", value: $draftGrams, in: 1...2_000, step: 5)
                        .labelsHidden()
                    Text("\(Int(draftGrams.rounded())) g")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .frame(minWidth: 56, alignment: .trailing)
                }
            }

            Button {
                appendDraft()
            } label: {
                Label("Porsiyon ekle", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(canAddDraft ? NuvyraColors.accent : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canAddDraft)
        }
    }

    private var canAddDraft: Bool {
        !draftLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draftGrams > 0
    }

    // MARK: - Mutations

    private func appendDraft() {
        let label = draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return }
        let isFirst = servings.isEmpty
        let newServing = ServingSize(
            label: label,
            labelTR: label,
            grams: draftGrams,
            isDefault: isFirst
        )
        servings.append(newServing)
        draftLabel = ""
        draftGrams = 100
    }

    private func remove(_ serving: ServingSize) {
        servings.removeAll { $0.id == serving.id }
        // İlk eleman varsayılan etiketini koruyacak şekilde garanti et.
        if let first = servings.first, !servings.contains(where: { $0.isDefault }) {
            replace(first, with: ServingSize(id: first.id, label: first.label, labelTR: first.labelTR, grams: first.grams, isDefault: true))
        }
    }

    private func toggleDefault(for serving: ServingSize) {
        servings = servings.map { current in
            ServingSize(
                id: current.id,
                label: current.label,
                labelTR: current.labelTR,
                grams: current.grams,
                isDefault: current.id == serving.id
            )
        }
    }

    private func replace(_ old: ServingSize, with new: ServingSize) {
        guard let index = servings.firstIndex(where: { $0.id == old.id }) else { return }
        servings[index] = new
    }
}

private struct ManualServingEditorPreviewWrapper: View {
    @State private var servings: [ServingSize] = [
        ServingSize(label: "1 slice", labelTR: "1 dilim", grams: 30, isDefault: true),
        ServingSize(label: "1 plate", labelTR: "1 tabak", grams: 200)
    ]

    var body: some View {
        ManualServingEditor(servings: $servings)
            .padding()
    }
}

#Preview {
    ManualServingEditorPreviewWrapper()
}
