import SwiftUI

struct RestorePurchaseButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Satın alımları geri yükle", systemImage: "arrow.clockwise")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NuvyraColors.accent)
        }
        .buttonStyle(.plain)
            .accessibilityLabel("Restore Purchases")
    }
}
