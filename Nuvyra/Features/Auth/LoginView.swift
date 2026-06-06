import AuthenticationServices
import SwiftUI

/// Premium standalone login screen. Apple's official `SignInWithAppleButton`
/// drives auth; "Misafir devam et" lets the user skip.
struct LoginView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var auth: AuthManager
    var onContinueAsGuest: (() -> Void)?

    @MainActor
    init(auth: AuthManager? = nil, onContinueAsGuest: (() -> Void)? = nil) {
        _auth = ObservedObject(wrappedValue: auth ?? AuthManager.shared)
        self.onContinueAsGuest = onContinueAsGuest
    }

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: NuvyraSpacing.xl) {
                    Spacer(minLength: NuvyraSpacing.lg)
                    logoHeader
                    valueProps
                    Spacer(minLength: 0)
                    actions
                    disclaimer
                }
                .padding(.horizontal, NuvyraSpacing.lg)
                .padding(.vertical, NuvyraSpacing.lg)
                .frame(maxWidth: .infinity, minHeight: 640, alignment: .top)
            }
        }
        .task { await auth.restoreSession() }
        .onChange(of: auth.state) { _, newState in
            if newState.isSignedIn { dismiss() }
        }
    }

    private var logoHeader: some View {
        VStack(spacing: NuvyraSpacing.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [NuvyraColors.accent, NuvyraColors.softMint], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 96, height: 96)
                    .shadow(color: NuvyraColors.accent.opacity(0.35), radius: 18, y: 10)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text("Nuvyra")
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
            Text("Sakin, kişisel ve gizliliğe saygılı wellness ritmin.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 320)
        }
    }

    private var valueProps: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                bullet(symbol: "lock.shield.fill", title: "Verilerin sende kalır", body: "Apple ile giriş email gizlemeyi destekler; veriler cihazında saklanır.")
                bullet(symbol: "sparkles", title: "Tek dokunuşla devam", body: "Şifre yok, kayıt formu yok; Face ID veya Touch ID yeter.")
                bullet(symbol: "person.crop.circle.badge.checkmark", title: "İstediğinde çık", body: "Profil ekranından çıkış yapabilir ya da hesabı silebilirsin.")
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: NuvyraSpacing.sm) {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                auth.handle(result: result)
            }
            .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
            .frame(height: 52)
            .accessibilityLabel("Apple ile giriş yap")

            if let onContinueAsGuest {
                Button(action: {
                    onContinueAsGuest()
                    dismiss()
                }) {
                    Text("Misafir devam et")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NuvyraColors.accent)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }

            if let error = auth.errorMessage {
                Text(error)
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(NuvyraColors.mutedCoral)
                    .multilineTextAlignment(.center)
            }

            if auth.isWorking {
                ProgressView().padding(.top, 4)
            }
        }
    }

    private var disclaimer: some View {
        Text("Devam ederek Kullanım Şartları ve Gizlilik Politikası'nı kabul ediyorsun.")
            .font(.caption2)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .padding(.top, NuvyraSpacing.xs)
    }

    private func bullet(symbol: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: NuvyraSpacing.md) {
            Image(systemName: symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(NuvyraColors.accent)
                .frame(width: 32, height: 32)
                .background(NuvyraColors.accent.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(body)
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#if DEBUG
#Preview("Login") {
    LoginView(auth: AuthManager(signInService: MockAppleSignInService()), onContinueAsGuest: {})
}
#endif
