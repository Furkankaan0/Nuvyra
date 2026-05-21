import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var authManager: AuthManager
    @State private var orbActive = false

    var body: some View {
        ZStack {
            NuvyraColors.calmGradient(scheme).ignoresSafeArea()
            backgroundDecor

            VStack {
                Spacer()
                logoBlock
                Spacer()
                bottomCard
            }
            .padding(.horizontal, NuvyraSpacing.lg)
            .padding(.bottom, NuvyraSpacing.xl)
        }
        .preferredColorScheme(nil)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                orbActive = true
            }
        }
    }

    private var backgroundDecor: some View {
        ZStack {
            Circle()
                .fill(NuvyraColors.accent.opacity(scheme == .dark ? 0.20 : 0.24))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: -120, y: -200)
            Circle()
                .fill(NuvyraColors.softMint.opacity(0.32))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: 140, y: 240)
        }
        .accessibilityHidden(true)
    }

    private var logoBlock: some View {
        VStack(spacing: NuvyraSpacing.md) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [NuvyraColors.softMint, NuvyraColors.accent.opacity(0.7), .clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: 80
                        )
                    )
                    .frame(width: 144, height: 144)
                    .scaleEffect(orbActive ? 1.05 : 0.98)
                    .blur(radius: orbActive ? 6 : 2)

                Circle()
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.85), .clear, NuvyraColors.softMint.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 2
                    )
                    .frame(width: 110, height: 110)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(.white)
                    .shadow(color: NuvyraColors.accent.opacity(0.6), radius: 10)
            }

            VStack(spacing: 6) {
                Text("Nuvyra")
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                Text("Bugünkü ritmin için kişisel rehber")
                    .font(NuvyraTypography.body)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var bottomCard: some View {
        VStack(spacing: NuvyraSpacing.md) {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                Label("Apple ile güvenli giriş", systemImage: "lock.shield.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NuvyraColors.accent)
                Text("Verilerin yalnızca cihazında saklanır. E-posta ve adın seninle kalır; pazarlama amacıyla kullanılmaz.")
                    .font(.caption)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    Task { await authManager.handleAuthorization(result) }
                }
            )
            .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
            .frame(height: 52)
            .clipShape(Capsule())
            .accessibilityLabel("Apple ile oturum aç")
            .opacity(authManager.isProcessing ? 0.5 : 1)
            .disabled(authManager.isProcessing)
            .overlay(alignment: .center) {
                if authManager.isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(scheme == .dark ? .black : .white)
                }
            }

            if let errorMessage = authManager.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NuvyraColors.mutedCoral)
                    .multilineTextAlignment(.center)
            }

            Text("Devam ederek [Kullanım Şartları](https://nuvyra.app/terms) ve [Gizlilik](https://nuvyra.app/privacy) notlarını kabul edersin.")
                .font(.caption2)
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .multilineTextAlignment(.center)
                .tint(NuvyraColors.accent)
        }
        .padding(NuvyraSpacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.xl, style: .continuous)
                .stroke(.white.opacity(scheme == .dark ? 0.1 : 0.4))
        )
        .shadow(color: NuvyraShadow.card(scheme), radius: 20, x: 0, y: 12)
    }

}

#if DEBUG
#Preview("Idle") {
    LoginView()
        .environmentObject(AuthManager.previewSignedOut())
}
#endif
