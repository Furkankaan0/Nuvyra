import Foundation
import Security

/// Tiny wrapper around the iOS keychain for storing the encoded `UserSession`.
/// Pure Foundation/Security — no third-party deps. Synchronous because keychain
/// access is fast and called rarely.
struct KeychainStore {
    let service: String
    let account: String

    static let session = KeychainStore(service: "com.nuvyra.app.auth", account: "user-session")

    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    func save(_ data: Data) throws {
        var query = self.query
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            let attributes: [String: Any] = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else { throw AuthError.keychain(updateStatus) }
        case errSecItemNotFound:
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw AuthError.keychain(addStatus) }
        default:
            throw AuthError.keychain(status)
        }
    }

    func load() throws -> Data? {
        var query = self.query
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess: return item as? Data
        case errSecItemNotFound: return nil
        default: throw AuthError.keychain(status)
        }
    }

    func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthError.keychain(status)
        }
    }
}

extension KeychainStore {
    func saveSession(_ session: UserSession) throws {
        let data = try JSONEncoder().encode(session)
        try save(data)
    }

    func loadSession() throws -> UserSession? {
        guard let data = try load() else { return nil }
        return try JSONDecoder().decode(UserSession.self, from: data)
    }

    func clearSession() throws {
        try delete()
    }
}
