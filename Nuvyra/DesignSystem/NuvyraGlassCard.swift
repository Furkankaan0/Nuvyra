import SwiftUI

struct NuvyraGlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(NuvyraSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous).stroke(Color.white.opacity(scheme == .dark ? 0.08 : 0.42)))
            .shadow(color: NuvyraShadow.card(scheme), radius: 18, x: 0, y: 10)
    }
}
