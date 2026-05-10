import AuthenticationServices
import Foundation

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var state: AuthState = .unknown
    @Published private(set) var isProcessing: Bool = false
    @Published var errorMessage: String?

    private let appleService: AppleSignInService
    private let keychain: KeychainService
    private let sessionKey: String
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(
        appleService: AppleSignInService,
        keychain: KeychainService,
        sessionKey: String = "user_session"
    ) {
        self.appleService = appleService
        self.keychain = keychain
        self.sessionKey = sessionKey
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    func bootstrap() async {
        guard let session = loadSessionFromKeychain() else {
            state = .signedOut
            return
        }

        let credentialState = await appleService.currentCredentialState(for: session.userIdentifier)
        switch credentialState {
        case .authorized:
            state = .signedIn(session)
        case .revoked, .notFound, .transferred:
            try? keychain.remove(sessionKey)
            state = .signedOut
        @unknown default:
            state = .signedIn(session)
        }
    }

    func handleAuthorization(_ result: Result<ASAuthorization, Error>) async {
        isProcessing = true
        defer { isProcessing = false }
        errorMessage = nil

        do {
            let authorization = try result.get()
            let credential = try appleService.processAuthorization(authorization)
            let session = mergeSession(with: credential)
            try persistSession(session)
            state = .signedIn(session)
        } catch let error as ASAuthorizationError where error.code == .canceled {
            return
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Apple ile oturum açılamadı."
        }
    }

    func signOut() {
        try? keychain.remove(sessionKey)
        state = .signedOut
    }

    /// Account deletion flow placeholder. Apple requires that apps offering Sign in with
    /// Apple also provide an in-app account deletion path. This clears the local session
    /// and the SwiftData store should be wiped by the caller as well.
    func deleteAccount() {
        try? keychain.remove(sessionKey)
        state = .signedOut
    }

    // MARK: - Session helpers

    private func loadSessionFromKeychain() -> UserSession? {
        guard let data = (try? keychain.read(sessionKey)) ?? nil else { return nil }
        return try? decoder.decode(UserSession.self, from: data)
    }

    /// Apple yalnızca ilk girişte email/fullName paylaşır. Sonraki girişlerde bu alanlar
    /// boş gelir; bu yüzden mevcut session'la birleştirip kaybolmamasını sağlıyoruz.
    private func mergeSession(with credential: AppleSignInCredential) -> UserSession {
        let now = Date()
        if let existing = loadSessionFromKeychain(), existing.userIdentifier == credential.userIdentifier {
            return UserSession(
                userIdentifier: existing.userIdentifier,
                email: credential.email ?? existing.email,
                fullName: credential.fullName ?? existing.fullName,
                firstSignInAt: existing.firstSignInAt,
                lastSignInAt: now
            )
        }
        return UserSession(
            userIdentifier: credential.userIdentifier,
            email: credential.email,
            fullName: credential.fullName,
            firstSignInAt: now,
            lastSignInAt: now
        )
    }

    private func persistSession(_ session: UserSession) throws {
        let data = try encoder.encode(session)
        try keychain.save(data, for: sessionKey)
    }
}

extension AuthManager {
    static func previewSignedIn() -> AuthManager {
        let keychain = InMemoryKeychainService()
        let manager = AuthManager(
            appleService: MockAppleSignInService(),
            keychain: keychain
        )
        let session = UserSession(
            userIdentifier: "preview.user.id",
            email: "preview@nuvyra.app",
            fullName: "Nuvyra Önizleme",
            firstSignInAt: Date(),
            lastSignInAt: Date()
        )
        if let data = try? JSONEncoder().encode(session) {
            try? keychain.save(data, for: "user_session")
        }
        manager.state = .signedIn(session)
        return manager
    }

    static func previewSignedOut() -> AuthManager {
        let manager = AuthManager(
            appleService: MockAppleSignInService(),
            keychain: InMemoryKeychainService()
        )
        manager.state = .signedOut
        return manager
    }
}
