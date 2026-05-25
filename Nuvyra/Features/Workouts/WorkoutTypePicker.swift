import SwiftUI

/// Horizontal chip picker for workout types — mirrors DrinkTypePicker's pattern.
struct WorkoutTypePicker: View {
    @Binding var selection: WorkoutType

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: NuvyraSpacing.xs) {
                ForEach(WorkoutType.allCases) { type in
                    WorkoutTypeChip(type: type, isSelected: selection == type) {
                        selection = type
                    }
                }
            }
            .padding(.horizontal, NuvyraSpacing.xs)
        }
    }
}

struct WorkoutTypeChip: View {
    var type: WorkoutType
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
private struct WorkoutTypePickerPreview: View {
    @State private var sel: WorkoutType = .running
    var body: some View {
        ZStack {
            NuvyraBackground()
            WorkoutTypePicker(selection: $sel).padding()
        }
    }
}

#Preview { WorkoutTypePickerPreview() }
#endif
