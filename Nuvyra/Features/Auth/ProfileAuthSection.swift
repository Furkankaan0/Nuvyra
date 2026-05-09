import SwiftUI

struct ProfileAuthSection: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var authManager: AuthManager
    var onSignOut: () -> Void
    var onDelete: () -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        if let session = authManager.state.session {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                NuvyraSectionHeader(title: "Apple hesabı", subtitle: "Verilerin cihazında, hesabın Apple ile bağlı.")
                NuvyraGlassCard {
                    VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                        HStack(spacing: NuvyraSpacing.md) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [NuvyraColors.accent, NuvyraColors.softMint],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 48, height: 48)
                                Image(systemName: "applelogo")
                                    .foregroundStyle(.white)
                                    .font(.title3.weight(.bold))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.displayName)
                                    .font(NuvyraTypography.section)
                                if let masked = session.maskedEmail {
                                    Text(masked)
                                        .font(.caption)
                                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                                }
                            }
                            Spacer()
                        }

                        HStack {
                            Label("Son giriş: \(Self.dateFormatter.string(from: session.lastSignInAt))", systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                            Spacer()
                        }

                        HStack(spacing: NuvyraSpacing.sm) {
                            Button(action: onSignOut) {
                                Label("Çıkış", systemImage: "rectangle.portrait.and.arrow.right")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .foregroundStyle(NuvyraColors.accent)
                                    .background(NuvyraColors.accent.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.plain)

                            Button(role: .destructive, action: onDelete) {
                                Label("Hesabı sil", systemImage: "trash")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .foregroundStyle(NuvyraColors.mutedCoral)
                                    .background(NuvyraColors.mutedCoral.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    ProfileAuthSection(onSignOut: {}, onDelete: {})
        .environmentObject(AuthManager.previewSignedIn())
        .padding()
        .background(NuvyraBackground())
}
#endif
