import SwiftUI

/// Always-visible reminder that the coach is informational and not medical advice.
/// Used both inline in cards and as a compact pinned bar on the coach screen.
struct SafetyDisclaimerView: View {
    enum Style { case compact, full }
    var style: Style = .full

    var body: some View {
        switch style {
        case .compact: compactView
        case .full: fullView
        }
    }

    private var compactView: some View {
        HStack(spacing: NuvyraSpacing.xs) {
            Image(systemName: "exclamationmark.shield")
                .font(.caption2.weight(.bold))
                .foregroundStyle(NuvyraColors.accent)
            Text("Bilgilendirme amaçlıdır, tıbbi tavsiye yerine geçmez.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private var fullView: some View {
        NuvyraGlassCard {
            HStack(alignment: .top, spacing: NuvyraSpacing.md) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(NuvyraColors.accent)
                    .frame(width: 40, height: 40)
                    .background(NuvyraColors.accent.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Önemli not")
                        .font(.subheadline.weight(.bold))
                    Text("Bu içerik genel bilgilendirme ve motivasyon amaçlıdır. Tıbbi tanı koymaz, kilo verme garantisi vermez ve doktor ya da diyetisyenin yerine geçmez.")
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        VStack(spacing: NuvyraSpacing.md) {
            SafetyDisclaimerView()
            SafetyDisclaimerView(style: .compact)
        }
        .padding()
    }
}
#endif
