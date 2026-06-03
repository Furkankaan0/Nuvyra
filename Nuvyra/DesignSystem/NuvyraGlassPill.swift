import SwiftUI

/// Capsule-shaped glass pill — the smallest member of the Liquid Glass
/// family. Used for status badges, change-direction chips, time-of-day
/// indicators and any spot where a "floating tiny" affordance reads
/// better than a flat label.
///
/// Two ergonomic init's:
///   - `NuvyraGlassPill(systemImage: "leaf.fill", title: "Nuvyra")`
///     for label + symbol
///   - `NuvyraGlassPill(content: { … })` when you need fully custom
///     content (mixed text styles, multiple symbols, etc.)
struct NuvyraGlassPill<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    var tint: Color
    var content: Content

    init(tint: Color = NuvyraColors.accent, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        let shape = Capsule(style: .continuous)
        return content
            .font(.caption.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(shape.fill(.ultraThinMaterial))
            .background(shape.fill(tint.opacity(scheme == .dark ? 0.18 : 0.12)))
            .overlay(shape.stroke(NuvyraColors.glassStroke(scheme), lineWidth: 0.6))
            .overlay(
                shape
                    .strokeBorder(NuvyraColors.specularHighlight(scheme), lineWidth: 1)
                    .mask(
                        LinearGradient(
                            colors: [Color.black, Color.black.opacity(0)],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .allowsHitTesting(false)
            )
            .nuvyraShadow(.ambient, scheme: scheme)
    }
}

/// Convenience init — common label + symbol shape used 90% of the time.
extension NuvyraGlassPill where Content == AnyView {
    init(systemImage: String? = nil, title: String, tint: Color = NuvyraColors.accent) {
        self.tint = tint
        self.content = AnyView(
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        )
    }
}

#if DEBUG
#Preview("Glass pills") {
    ZStack {
        NuvyraBackground()
        VStack(spacing: NuvyraSpacing.md) {
            HStack {
                NuvyraGlassPill(systemImage: "leaf.fill", title: "Sakin")
                NuvyraGlassPill(systemImage: "arrow.up", title: "%18", tint: NuvyraColors.accent)
                NuvyraGlassPill(systemImage: "arrow.down", title: "%6", tint: NuvyraColors.mutedCoral)
                NuvyraGlassPill(title: "Bugün", tint: NuvyraColors.softSand)
            }
            HStack {
                NuvyraGlassPill(tint: NuvyraColors.softMint) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Yaklaşık")
                            .font(.caption2.weight(.bold))
                    }
                }
            }
        }
        .padding()
    }
}
#endif
