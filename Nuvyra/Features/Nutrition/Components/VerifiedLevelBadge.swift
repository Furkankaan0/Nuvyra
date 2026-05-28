import SwiftUI

/// Yaklaşık / doğrulanmış / kullanıcı tarafından eklendi rozeti.
/// `VerifiedLevel.shouldShowApproximateBadge` true ise dikkat çekici renkte;
/// doğrulanmış data için minimal yeşil. Kullanıcı asla yanlış kesinlik
/// hissine kapılmamalı — bu rozet o sözleşmenin görünür hali.
struct VerifiedLevelBadge: View {
    let level: VerifiedLevel
    var confidence: Double? = nil

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbolName)
                .font(.system(size: 11, weight: .semibold))
            VStack(alignment: .leading, spacing: 0) {
                Text(level.displayLabelTR)
                    .font(NuvyraTypography.caption)
                    .fontWeight(.semibold)
                if let confidence {
                    Text("güven \(Int(confidence * 100))%")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.16))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(tint.opacity(0.45), lineWidth: 1)
        )
        .foregroundStyle(tint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(level.displayLabelTR)\(confidence.map { ", güven yüzde \(Int($0 * 100))" } ?? "")")
    }

    private var symbolName: String {
        switch level {
        case .verified: "checkmark.seal.fill"
        case .approximate: "exclamationmark.triangle.fill"
        case .userCreated: "person.fill.checkmark"
        case .unverified: "questionmark.circle.fill"
        }
    }

    private var tint: Color {
        switch level {
        case .verified: NuvyraColors.accent
        case .approximate: Color(red: 0.85, green: 0.62, blue: 0.20)
        case .userCreated: Color(red: 0.55, green: 0.40, blue: 0.85)
        case .unverified: NuvyraColors.mutedCoral
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        VerifiedLevelBadge(level: .verified, confidence: 0.92)
        VerifiedLevelBadge(level: .approximate, confidence: 0.6)
        VerifiedLevelBadge(level: .userCreated, confidence: 0.9)
        VerifiedLevelBadge(level: .unverified)
    }
    .padding()
}
