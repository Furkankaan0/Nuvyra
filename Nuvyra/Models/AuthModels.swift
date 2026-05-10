import Foundation

struct UserSession: Codable, Equatable {
    var userIdentifier: String
    var email: String?
    var fullName: String?
    var firstSignInAt: Date
    var lastSignInAt: Date

    var displayName: String {
        if let trimmed = fullName?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            return trimmed
        }
        if let email, !email.isEmpty {
            return email
        }
        return "Nuvyra Kullanıcısı"
    }

    var maskedEmail: String? {
        guard let email, let atIndex = email.firstIndex(of: "@") else { return email }
        let local = email[..<atIndex]
        let domain = email[atIndex...]
        let masked: String
        if local.count <= 2 {
            masked = String(repeating: "•", count: local.count)
        } else {
            let head = local.prefix(2)
            let dots = String(repeating: "•", count: max(local.count - 2, 1))
            masked = head + dots
        }
        return masked + String(domain)
    }
}

enum AuthState: Equatable {
    case unknown
    case signedOut
    case signedIn(UserSession)

    var isSignedIn: Bool {
        if case .signedIn = self { return true }
        return false
    }

    var session: UserSession? {
        if case .signedIn(let session) = self { return session }
        return nil
    }
}

struct AppleSignInCredential: Equatable {
    var userIdentifier: String
    var email: String?
    var fullName: String?
    var identityToken: String?
    var authorizationCode: String?
}
