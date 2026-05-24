import SwiftUI

/// Horizontal scroll of drink chips. Drives both the quick add buttons and the
/// manual entry sheet — pick a type, the amount/caffeine defaults follow.
struct DrinkTypePicker: View {
    @Binding var selection: DrinkType

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: NuvyraSpacing.xs) {
                ForEach(DrinkType.allCases) { type in
                    DrinkTypeChip(type: type, isSelected: selection == type) {
                        selection = type
                    }
                }
            }
            .padding(.horizontal, NuvyraSpacing.xs)
        }
    }
}

struct DrinkTypeChip: View {
    @Environment(\.colorScheme) private var scheme
    var type: DrinkType
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.systemImage)
                    .font(.subheadline.weight(.bold))
                Text(type.title)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? .white : type.tint)
            .background(
                isSelected ? type.tint : type.tint.opacity(0.14),
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(type.tint.opacity(isSelected ? 0 : 0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.title)
        .accessibilityValue(isSelected ? "Seçili" : "Seçili değil")
    }
}

#if DEBUG
private struct DrinkTypePickerPreview: View {
    @State private var selection: DrinkType = .water
    var body: some View {
        ZStack {
            NuvyraBackground()
            VStack(spacing: NuvyraSpacing.md) {
                DrinkTypePicker(selection: $selection)
                Text("Seçili: \(selection.title)")
                    .font(.subheadline.weight(.semibold))
            }
            .padding()
        }
    }
}

#Preview { DrinkTypePickerPreview() }
#endif
