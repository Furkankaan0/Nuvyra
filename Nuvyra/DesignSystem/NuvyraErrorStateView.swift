import SwiftUI

/// Calm-tone error surface used across feature loaders. `style: .full` uses
/// the full illustrated placeholder; `style: .compact` collapses into a
/// single-row glass strip for inline error messaging.
struct NuvyraErrorStateView: View {
    @Environment(\.colorScheme) private var scheme

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
        Group {
            switch style {
            case .full: fullContent
            case .compact: compactContent
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }

    // MARK: - Full

    private var fullContent: some View {
        NuvyraGlassCard {
            NuvyraIllustratedPlaceholder(
                systemImage: systemImage,
                title: title,
                subtitle: message,
                tint: NuvyraColors.mutedCoral,
                bullets: []
            ) {
                actions
            }
        }
    }

    // MARK: - Compact

    private var compactContent: some View {
        HStack(alignment: .top, spacing: NuvyraSpacing.sm) {
            // Tiny glass medallion — same shape language as the full state
            // but at row-height so it slots into any list / sheet.
            ZStack {
                Circle().fill(.ultraThinMaterial)
                Circle().fill(NuvyraColors.mutedCoral.opacity(scheme == .dark ? 0.22 : 0.16))
                Circle().stroke(NuvyraColors.glassStroke(scheme), lineWidth: 0.6)
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NuvyraColors.mutedCoral)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(message)
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                actions
            }
        }
        .padding(.vertical, NuvyraSpacing.xs)
    }

    // MARK: - Shared actions

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

#if DEBUG
#Preview("Full") {
    ZStack {
        NuvyraBackground()
        NuvyraErrorStateView(
            message: "Sunucuya bağlanılamadı. İnternet bağlantını kontrol edip tekrar dene.",
            onRetry: {}
        )
        .padding()
    }
}

#Preview("Compact") {
    NuvyraErrorStateView(
        message: "Yanıt alınamadı.",
        style: .compact,
        onRetry: {},
        onDismiss: {}
    )
    .padding()
}
#endif
