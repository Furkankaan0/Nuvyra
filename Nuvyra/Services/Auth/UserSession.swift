import Foundation

/// Persisted user identity returned from Sign in with Apple.
/// Apple only sends `fullName` / `email` on the **first** sign-in, so we cache
/// them locally — repeated sign-ins only return the `userIdentifier`.
struct UserSession: Codable, Equatable, Hashable {
    let userIdentifier: String
    var fullName: String?
    var email: String?
    var signedInAt: Date

    init(userIdentifier: String, fullName: String? = nil, email: String? = nil, signedInAt: Date = Date()) {
        self.userIdentifier = userIdentifier
        self.fullName = fullName
        self.email = email
        self.signedInAt = signedInAt
    }

    var displayName: String {
        if let name = fullName, !name.isEmpty { return name }
        if let email, !email.isEmpty { return email }
        return "Apple kullanıcısı"
    }

    var maskedIdentifier: String {
        // Apple identifiers are long opaque strings — show a friendly suffix only.
        guard userIdentifier.count > 8 else { return userIdentifier }
        return "•••\(userIdentifier.suffix(6))"
    }
}

/// Authentication lifecycle state surfaced by `AuthManager`.
enum AuthState: Equatable {
    case unknown
    case signedOut
    case signedIn(UserSession)
    case revoked

    var session: UserSession? {
        if case .signedIn(let s) = self { return s }
        return nil
    }

    var isSignedIn: Bool { session != nil }
}

/// User-facing errors raised by Apple sign-in / keychain layers.
enum AuthError: Error, LocalizedError {
    case canceled
    case invalidCredential
    case keychain(OSStatus)
    case unavailable
    case unknown(Error?)

    var errorDescription: String? {
        switch self {
        case .canceled: return "Giriş iptal edildi."
        case .invalidCredential: return "Apple kimlik bilgisi alınamadı."
        case .keychain(let status): return "Güvenli depolamada bir sorun oluştu (\(status))."
        case .unavailable: return "Apple ile giriş şu an kullanılamıyor."
        case .unknown(let underlying): return underlying?.localizedDescription ?? "Bilinmeyen bir hata oluştu."
        }
    }
}
