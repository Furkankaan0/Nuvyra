import SwiftUI

struct NuvyraBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NuvyraColors.calmGradient(scheme)
            .ignoresSafeArea()
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(NuvyraColors.accent.opacity(scheme == .dark ? 0.12 : 0.16))
                    .frame(width: 280, height: 280)
                    .blur(radius: 48)
                    .offset(x: 120, y: -130)
            }
    }
}
