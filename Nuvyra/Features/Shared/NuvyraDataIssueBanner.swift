import SwiftUI
import UIKit

/// Inline banner used by the dashboard / walking screens to surface
/// HealthKit or CoreMotion permission and connectivity issues. Replaces
/// the previous behaviour of silently hiding errors and showing 0 steps.
struct NuvyraDataIssueBanner: View {
    @Environment(\.colorScheme) private var scheme
    let banner: DataIssueBanner
    var onRetry: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: NuvyraSpacing.sm) {
            Image(systemName: banner.icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(NuvyraColors.mutedCoral)
                .frame(width: 36, height: 36)
                .background(NuvyraColors.mutedCoral.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(banner.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                Text(banner.message)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .fixedSize(horizontal: false, vertical: true)

                if banner.action != .none {
                    Button(action: handleAction) {
                        HStack(spacing: 4) {
                            Text(actionTitle)
                            Image(systemName: actionSymbol)
                        }
                        .font(.footnote.weight(.heavy))
                        .foregroundStyle(NuvyraColors.accent)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                    .accessibilityLabel(actionTitle)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                .fill(NuvyraColors.card(scheme).opacity(scheme == .dark ? 0.6 : 0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                .stroke(NuvyraColors.mutedCoral.opacity(0.32))
        )
    }

    private var actionTitle: String {
        switch banner.action {
        case .retry: return "Tekrar dene"
        case .openSettings: return "Ayarları aç"
        case .none: return ""
        }
    }

    private var actionSymbol: String {
        switch banner.action {
        case .retry: return "arrow.clockwise"
        case .openSettings: return "arrow.up.right.square"
        case .none: return ""
        }
    }

    private func handleAction() {
        switch banner.action {
        case .retry:
            onRetry?()
        case .openSettings:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        case .none:
            break
        }
    }
}
