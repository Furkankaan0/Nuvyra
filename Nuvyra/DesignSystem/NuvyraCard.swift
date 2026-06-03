import SwiftUI

/// Solid-fill card surface. Glass cards (`NuvyraGlassCard`) are the
/// preferred container for hero-ish content; this one stays around for
/// list rows and dense data tables where the translucent look adds
/// readability cost instead of premium feel.
struct NuvyraCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous)
        return content
            .padding(NuvyraSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NuvyraColors.card(scheme), in: shape)
            // Subtle gradient hairline — same one glass cards use — so the
            // solid card still feels like part of the Liquid Glass family.
            .overlay(
                shape.stroke(NuvyraColors.glassStroke(scheme), lineWidth: 0.5)
            )
            .nuvyraShadow(.soft, scheme: scheme)
            .accessibilityElement(children: .contain)
    }
}
