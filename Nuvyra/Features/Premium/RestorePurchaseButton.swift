import SwiftUI

struct RestorePurchaseButton: View {
    var action: () -> Void

    var body: some View {
        Button("Restore Purchases", action: action)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(NuvyraColors.accent)
            .accessibilityLabel("Restore Purchases")
    }
}
