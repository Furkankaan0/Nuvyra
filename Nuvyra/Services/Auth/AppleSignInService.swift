import AuthenticationServices
import Foundation

protocol AppleSignInService {
    func processAuthorization(_ authorization: ASAuthorization) throws -> AppleSignInCredential
    func currentCredentialState(for userIdentifier: String) async -> ASAuthorizationAppleIDProvider.CredentialState
}

enum AppleSignInError: Error, LocalizedError {
    case invalidCredentialType
    case missingUserIdentifier

    var errorDescription: String? {
        switch self {
        case .invalidCredentialType: return "Apple oturum açma yanıtı beklenen formatta değil."
        case .missingUserIdentifier: return "Apple kullanıcı kimliği alınamadı."
        }
    }
}

final class LiveAppleSignInService: AppleSignInService {
    func processAuthorization(_ authorization: ASAuthorization) throws -> AppleSignInCredential {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AppleSignInError.invalidCredentialType
        }
        guard !credential.user.isEmpty else {
            throw AppleSignInError.missingUserIdentifier
        }
        let fullName = Self.composeFullName(credential.fullName)
        let identityToken = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        let authCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        return AppleSignInCredential(
            userIdentifier: credential.user,
            email: credential.email,
            fullName: fullName,
            identityToken: identityToken,
            authorizationCode: authCode
        )
    }

    func currentCredentialState(for userIdentifier: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userIdentifier) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }

    private static func composeFullName(_ components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .default
        let result = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}

final class MockAppleSignInService: AppleSignInService {
    var stubCredential: AppleSignInCredential
    var credentialState: ASAuthorizationAppleIDProvider.CredentialState

    init(
        stubCredential: AppleSignInCredential = AppleSignInCredential(
            userIdentifier: "preview.user.id",
            email: "preview@nuvyra.app",
            fullName: "Nuvyra Önizleme",
            identityToken: nil,
            authorizationCode: nil
        ),
        credentialState: ASAuthorizationAppleIDProvider.CredentialState = .authorized
    ) {
        self.stubCredential = stubCredential
        self.credentialState = credentialState
    }

    func processAuthorization(_ authorization: ASAuthorization) throws -> AppleSignInCredential {
        stubCredential
    }

    func currentCredentialState(for userIdentifier: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        credentialState
    }
}
