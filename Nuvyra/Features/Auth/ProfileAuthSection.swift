import SwiftUI

/// Profile section showing the current Apple sign-in status, sign-in button and
/// destructive actions (sign out, delete account). Surface this inside
/// `ProfileView` next to the existing sections.
struct ProfileAuthSection: View {
    @StateObject private var auth = AuthManager.shared
    @State private var showingLogin = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        Group {
            switch auth.state {
            case .unknown:
                placeholderCard
            case .signedOut, .revoked:
                signedOutCard
            case .signedIn(let session):
                signedInCard(session: session)
            }
        }
        .task { await auth.restoreSession() }
        .sheet(isPresented: $showingLogin) {
            NavigationStack {
                LoginView(auth: auth, onContinueAsGuest: { showingLogin = false })
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Kapat") { showingLogin = false }
                        }
                    }
            }
        }
        .alert("Hesabı sil", isPresented: $showingDeleteConfirm) {
            Button("Vazgeç", role: .cancel) {}
            Button("Sil", role: .destructive) {
                Task { await auth.deleteAccount() }
            }
        } message: {
            Text("Bu işlem yerel oturumunu temizler. Sunucu tarafı hesap silme akışı yayına girdiğinde otomatik olarak devreye girer.")
        }
    }

    private var placeholderCard: some View {
        NuvyraGlassCard {
            HStack(spacing: NuvyraSpacing.sm) {
                ProgressView()
                Text("Hesap durumu kontrol ediliyor...")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var signedOutCard: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack(spacing: NuvyraSpacing.md) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(NuvyraColors.accent)
                        .frame(width: 44, height: 44)
                        .background(NuvyraColors.accent.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Şu an misafir oturumdasın")
                            .font(.subheadline.weight(.bold))
                        Text("Apple ile giriş yaparak verilerini cihazlar arasında güvenle taşıyabilirsin.")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                NuvyraPrimaryButton(title: "Apple ile giriş yap", systemImage: "applelogo") {
                    showingLogin = true
                }
                if let error = auth.errorMessage {
                    Text(error)
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(NuvyraColors.mutedCoral)
                }
            }
        }
    }

    private func signedInCard(session: UserSession) -> some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack(spacing: NuvyraSpacing.md) {
                    Image(systemName: "person.crop.circle.fill.badge.checkmark")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(colors: [NuvyraColors.accent, NuvyraColors.softMint], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: Circle()
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.displayName)
                            .font(.subheadline.weight(.bold))
                        if let email = session.email {
                            Text(email)
                                .font(NuvyraTypography.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Text("Kimlik: \(session.maskedIdentifier)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: NuvyraSpacing.sm) {
                    NuvyraSecondaryButton(title: "Çıkış yap", systemImage: "rectangle.portrait.and.arrow.right") {
                        auth.signOut()
                    }
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Hesabı sil", systemImage: "trash")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(NuvyraColors.mutedCoral)
                            .background(NuvyraColors.mutedCoral.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Text("Verilerin cihazında kalır. Hesap silme sunucuya bağlandığında geri alınamaz hale gelir.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#if DEBUG
#Preview("Signed out") {
    ZStack {
        NuvyraBackground()
        ProfileAuthSection().padding()
    }
}
#endif
