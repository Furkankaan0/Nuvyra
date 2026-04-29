import SwiftUI

struct NuvyraPrimaryButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var title: String
    var systemImage: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: NuvyraSpacing.sm) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(.headline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(
                LinearGradient(colors: [NuvyraColors.accent, NuvyraColors.softMint], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: reduceMotion)
        .accessibilityLabel(title)
    }
}

struct NuvyraSecondaryButton: View {
    var title: String
    var systemImage: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: NuvyraSpacing.sm) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(.headline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(NuvyraColors.accent)
            .background(NuvyraColors.accent.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct NuvyraChip: View {
    @Environment(\.colorScheme) private var scheme
    var title: String
    var isSelected: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(isSelected ? .white : NuvyraColors.primaryText(scheme))
                .background(isSelected ? NuvyraColors.accent : NuvyraColors.card(scheme), in: Capsule())
                .overlay(Capsule().stroke(NuvyraColors.accent.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
