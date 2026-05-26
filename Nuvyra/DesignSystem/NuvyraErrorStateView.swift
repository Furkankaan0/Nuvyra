import SwiftUI

struct NuvyraErrorStateView: View {
    enum Style {
        case full
        case compact
    }

    var title: String = String(localized: "error.generic.title")
    var message: String
    var retryTitle: String = String(localized: "error.retry")
    var systemImage: String = "exclamationmark.triangle.fill"
    var style: Style = .full
    var onRetry: (() -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        NuvyraGlassCard {
            if style == .compact {
                compactContent
            } else {
                fullContent
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }

    private var fullContent: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
            icon
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(NuvyraTypography.section)
                Text(message)
                    .font(NuvyraTypography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            actions
        }
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            HStack(alignment: .top, spacing: NuvyraSpacing.sm) {
                Image(systemName: systemImage)
                    .foregroundStyle(NuvyraColors.mutedCoral)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                    Text(message)
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            actions
        }
    }

    private var icon: some View {
        Image(systemName: systemImage)
            .font(.title2.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(NuvyraColors.mutedCoral, in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
    }

    @ViewBuilder
    private var actions: some View {
        if onRetry != nil || onDismiss != nil {
            HStack(spacing: NuvyraSpacing.sm) {
                if let onRetry {
                    NuvyraSecondaryButton(title: retryTitle, systemImage: "arrow.clockwise", action: onRetry)
                }
                if let onDismiss {
                    Button(String(localized: "error.dismiss"), action: onDismiss)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 2)
        }
    }
}

#Preview {
    NuvyraErrorStateView(
        message: "Sunucuya bağlanılamadı. İnternet bağlantını kontrol edip tekrar dene.",
        onRetry: {}
    )
    .padding()
}
