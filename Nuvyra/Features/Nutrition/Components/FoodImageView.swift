import SwiftUI

/// Reusable thumbnail/hero görseli. Open Food Facts ürün fotoğrafı,
/// USDA boş (nil → placeholder), kullanıcı manuel girdisi nil olur.
/// `AsyncImage` `URLSession.shared` üzerinden geldiği için `NuvyraImageCache`
/// configure ettiyse otomatik disk cache'i kullanır.
struct FoodImageView: View {
    enum Style {
        case thumbnail   // 40 — küçük liste avatarı
        case small       // 64 — search row leading
        case medium      // 96
        case hero        // 200 — detail view header

        var size: CGFloat {
            switch self {
            case .thumbnail: 40
            case .small: 64
            case .medium: 96
            case .hero: 200
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .thumbnail: 10
            case .small: 12
            case .medium: 16
            case .hero: 24
            }
        }

        var iconFontSize: CGFloat {
            switch self {
            case .thumbnail: 16
            case .small: 22
            case .medium: 32
            case .hero: 56
            }
        }
    }

    let url: URL?
    let style: Style
    var fallbackSystemImage: String = "fork.knife.circle.fill"

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.25))) { phase in
                    switch phase {
                    case .empty:
                        loadingView
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    case .failure:
                        placeholderView
                    @unknown default:
                        placeholderView
                    }
                }
            } else {
                placeholderView
            }
        }
        .frame(width: style.size, height: style.size)
        .background(NuvyraColors.softMint.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .accessibilityHidden(true)
    }

    private var placeholderView: some View {
        Image(systemName: fallbackSystemImage)
            .font(.system(size: style.iconFontSize, weight: .medium))
            .foregroundStyle(NuvyraColors.accent.opacity(0.55))
    }

    private var loadingView: some View {
        ProgressView()
            .controlSize(style == .hero ? .large : .regular)
            .tint(NuvyraColors.accent)
    }
}

#Preview {
    HStack(spacing: 16) {
        FoodImageView(url: nil, style: .thumbnail)
        FoodImageView(url: nil, style: .small)
        FoodImageView(url: nil, style: .medium)
    }
    .padding()
}
