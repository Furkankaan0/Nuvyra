import SwiftUI

/// Çoklu porsiyon seçici — `FoodItem.servingSizes` listesini chip row olarak
/// render eder, seçilen porsiyona göre quantity stepper ekler.
/// Caller `selectedServing` ve `quantity` bağlama yapar; bu komponent
/// taraması, scaling caller'da `item.values(for:quantity:)` ile yapılır.
struct ServingSizePicker: View {
    let servings: [ServingSize]
    @Binding var selectedServing: ServingSize
    @Binding var quantity: Double

    private var step: Double {
        // 100 g referansları gram stepi, kalan tüm porsiyonlar 0.5 adım.
        selectedServing.grams >= 100 ? 1.0 : 0.5
    }

    private var totalGrams: Double {
        max(0, selectedServing.grams * quantity)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(servings) { serving in
                        Button {
                            selectedServing = serving
                            quantity = 1
                        } label: {
                            servingChip(serving)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }

            HStack {
                Stepper(value: $quantity, in: 0.25...20, step: step) {
                    HStack {
                        Text(quantityLabel)
                            .font(NuvyraTypography.section)
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text("\(Int(totalGrams.rounded())) g")
                            .foregroundStyle(.secondary)
                            .font(NuvyraTypography.caption)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
        }
    }

    private var quantityLabel: String {
        let formatted = quantity == quantity.rounded()
            ? String(Int(quantity))
            : String(format: "%.1f", quantity)
        return "\(formatted) × \(selectedServing.preferredLabel)"
    }

    private func servingChip(_ serving: ServingSize) -> some View {
        let isSelected = serving == selectedServing
        return Text(serving.preferredLabel)
            .font(NuvyraTypography.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? NuvyraColors.accent : Color.primary.opacity(0.06))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isSelected ? Color.clear : Color.primary.opacity(0.10), lineWidth: 1)
            )
    }
}

private struct ServingSizePickerPreviewWrapper: View {
    @State private var serving = ServingSize.onePortion
    @State private var quantity: Double = 1

    var body: some View {
        ServingSizePicker(
            servings: [.hundredGrams, .oneBowl, .onePortion, .oneSlice, .oneTablespoon],
            selectedServing: $serving,
            quantity: $quantity
        )
        .padding()
    }
}

#Preview {
    ServingSizePickerPreviewWrapper()
}
