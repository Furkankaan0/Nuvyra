import SwiftUI

/// Restore-purchases CTA. Apple's review guidelines (3.1.1) require this
/// button on every paid app, and reviewers actually tap it — if it does
/// nothing, the build is rejected. The label is kept in the user's
/// language (Turkish primary, English mirrored via accessibility) so the
/// button works for international reviewers too.
struct RestorePurchaseButton: View {
    var isProcessing: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isProcessing {
                    ProgressView()
                        .controlSize(.small)
                }
                Text("Satın alımları geri yükle")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(NuvyraColors.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .disabled(isProcessing)
        .accessibilityIdentifier("restorePurchasesButton")
        .accessibilityLabel("Restore Purchases")
    }
}
