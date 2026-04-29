import SwiftUI

struct NuvyraCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(NuvyraSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NuvyraColors.card(scheme), in: RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous))
            .shadow(color: NuvyraShadow.card(scheme), radius: 20, x: 0, y: 12)
            .accessibilityElement(children: .contain)
    }
}
