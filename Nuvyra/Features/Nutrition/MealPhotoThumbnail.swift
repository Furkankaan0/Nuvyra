import SwiftUI
import UIKit

struct MealPhotoThumbnail: View {
    var data: Data?
    var fallbackSystemImage: String
    var size: CGFloat
    var cornerRadius: CGFloat = NuvyraRadius.md

    var body: some View {
        Group {
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: fallbackSystemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(NuvyraColors.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(NuvyraColors.accent.opacity(0.12))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(uiImage == nil ? 0 : 0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(uiImage == nil ? 0 : 0.12), radius: 12, y: 6)
        .accessibilityHidden(true)
    }

    private var uiImage: UIImage? {
        guard let data else { return nil }
        return UIImage(data: data)
    }
}

