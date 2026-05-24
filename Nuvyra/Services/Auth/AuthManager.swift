import Combine
import AuthenticationServices
import Foundation

/// App-wide authentication state holder. Persists `UserSession` in the keychain
/// and exposes a small async API for SwiftUI views.
@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var state: AuthState = .unknown
    @Published var errorMessage: String?
    @Published var isWorking = false

    private let signInService: AppleSignInService
    private let keychain: KeychainStore

    /// Shared instance used by `LoginView` / `ProfileAuthSection`. Avoids
    /// touching `DependencyContainer` so the rest of the app stays untouched.
    nonisolated(unsafe) static let shared: AuthManager = AuthManager()

    init(signInService: AppleSignInService? = nil, keychain: KeychainStore = .session) {
        self.signInService = signInService ?? LiveAppleSignInService()
        self.keychain = keychain
    }

    // MARK: - Lifecycle
    /// Call from `LoginView.task` and `ProfileAuthSection.task`. Restores any
    /// existing session and verifies Apple still considers it valid.
    func restoreSession() async {
        do {
            guard let cached = try keychain.loadSession() else {
                state = .signedOut
                return
            }
            let credentialState = await signInService.credentialState(for: cached.userIdentifier)
            switch credentialState {
            case .authorized:
                state = .signedIn(cached)
            case .revoked, .notFound:
                try? keychain.clearSession()
                state = .revoked
            case .transferred:
                state = .signedIn(cached)
            @unknown default:
                state = .signedOut
            }
        } catch {
            errorMessage = (error as? AuthError)?.errorDescription
            state = .signedOut
        }
    }

    // MARK: - Sign in / out

    /// Programmatic sign-in for hosts that don't use the SwiftUI
    /// `SignInWithAppleButton` (e.g. menu items, deep links). The login screen
    /// uses the button directly + `handle(result:)` below.
    func signInWithApple() async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            let fresh = try await signInService.signIn()
            persist(session: fresh)
        } catch let authError as AuthError {
            if case .canceled = authError { return }
            errorMessage = authError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Forward the SwiftUI `SignInWithAppleButton.onCompletion` result here.
    /// Avoids running two parallel Apple flows.
    func handle(result: Result<ASAuthorization, Error>) {
        errorMessage = nil
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = AuthError.invalidCredential.errorDescription
                return
            }
            let formatter = PersonNameComponentsFormatter()
            formatter.style = .default
            let fullName: String? = credential.fullName.map { formatter.string(from: $0) }
            let session = UserSession(
                userIdentifier: credential.user,
                fullName: fullName?.isEmpty == false ? fullName : nil,
                email: credential.email
            )
            persist(session: session)
        case .failure(let error):
            if let asError = error as? ASAuthorizationError, asError.code == .canceled { return }
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func persist(session fresh: UserSession) {
        // Apple only sends name/email the first time; merge into any cached
        // session so subsequent sign-ins keep the human-readable name.
        let cached = try? keychain.loadSession()
        let merged = UserSession(
            userIdentifier: fresh.userIdentifier,
            fullName: fresh.fullName ?? cached?.fullName,
            email: fresh.email ?? cached?.email,
            signedInAt: Date()
        )
        do {
            try keychain.saveSession(merged)
            state = .signedIn(merged)
        } catch {
            errorMessage = (error as? AuthError)?.errorDescription ?? error.localizedDescription
        }
    }

    func signOut() {
        do {
            try keychain.clearSession()
        } catch {
            errorMessage = (error as? AuthError)?.errorDescription
        }
        state = .signedOut
    }

    /// Placeholder for App Store-compliant account deletion. Today it only
    /// clears local credentials; a real server-side delete should hook in here.
    /// **Important**: real deletion would also need to call
    /// `ASAuthorizationAppleIDProvider().revokeToken(...)` once a backend
    /// supplies the authorization code.
    func deleteAccount() async {
        signOut()
        errorMessage = nil
        // Hook for backend deletion request goes here.
    }
}
