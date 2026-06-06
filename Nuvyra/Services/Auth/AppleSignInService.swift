import AuthenticationServices
import Foundation
import UIKit

/// Wraps `ASAuthorizationAppleIDProvider` behind an async API and a small
/// protocol so the UI / `AuthManager` can be tested with a mock.
@MainActor
protocol AppleSignInService {
    func signIn() async throws -> UserSession
    func credentialState(for userIdentifier: String) async -> ASAuthorizationAppleIDProvider.CredentialState
}

@MainActor
final class LiveAppleSignInService: NSObject, AppleSignInService {
    private var currentContinuation: CheckedContinuation<UserSession, Error>?

    func signIn() async throws -> UserSession {
        try await withCheckedThrowingContinuation { continuation in
            self.currentContinuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func credentialState(for userIdentifier: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userIdentifier) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }

    private func resume(with result: Result<UserSession, Error>) {
        let continuation = currentContinuation
        currentContinuation = nil
        switch result {
        case .success(let session): continuation?.resume(returning: session)
        case .failure(let error): continuation?.resume(throwing: error)
        }
    }
}

extension LiveAppleSignInService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            Task { @MainActor in self.resume(with: .failure(AuthError.invalidCredential)) }
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
        Task { @MainActor in self.resume(with: .success(session)) }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let authError: AuthError
        if let asError = error as? ASAuthorizationError {
            switch asError.code {
            case .canceled: authError = .canceled
            case .invalidResponse, .notHandled, .failed: authError = .invalidCredential
            default: authError = .unknown(error)
            }
        } else {
            authError = .unknown(error)
        }
        Task { @MainActor in self.resume(with: .failure(authError)) }
    }
}

extension LiveAppleSignInService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            // First foreground key window across connected scenes; falls back to a fresh window.
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
        }
    }
}

/// Deterministic mock used by Previews and unit tests.
@MainActor
final class MockAppleSignInService: AppleSignInService {
    var sessionToReturn: UserSession = UserSession(userIdentifier: "mock.user.id", fullName: "Furkan Demo", email: "demo@nuvyra.app")
    var credentialState: ASAuthorizationAppleIDProvider.CredentialState = .authorized

    func signIn() async throws -> UserSession { sessionToReturn }
    func credentialState(for userIdentifier: String) async -> ASAuthorizationAppleIDProvider.CredentialState { credentialState }
}
