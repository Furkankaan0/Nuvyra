import SwiftUI

/// Empty state shown before the user sends their first chat message. Surfaces
/// a few pre-baked example questions so first-time users have a way in.
struct AICoachEmptyState: View {
    var examples: [AICoachExampleQuestion]
    var onSelect: (AICoachExampleQuestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
            HStack(spacing: NuvyraSpacing.sm) {
                AICoachAvatar(size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bir soru yaz veya örneklerden seç")
                        .font(.subheadline.weight(.semibold))
                    Text("Kişisel veriler bu cihazda kalır.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            VStack(spacing: NuvyraSpacing.xs) {
                ForEach(examples) { example in
                    Button { onSelect(example) } label: {
                        HStack {
                            Text(example.rawValue)
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(NuvyraColors.accent)
                        }
                        .padding(.horizontal, NuvyraSpacing.md)
                        .padding(.vertical, NuvyraSpacing.sm)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                                .stroke(NuvyraColors.accent.opacity(0.18), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(example.rawValue)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        AICoachEmptyState(examples: AICoachExampleQuestion.allCases) { _ in }
            .padding()
    }
}
#endif
