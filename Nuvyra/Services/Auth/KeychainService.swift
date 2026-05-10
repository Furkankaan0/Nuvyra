import Foundation
import Security

protocol KeychainService {
    func save(_ data: Data, for key: String) throws
    func read(_ key: String) throws -> Data?
    func remove(_ key: String) throws
}

enum KeychainError: Error, LocalizedError {
    case unhandled(OSStatus)
    case encoding
    case decoding

    var errorDescription: String? {
        switch self {
        case .unhandled(let status): return "Keychain hatası (\(status))"
        case .encoding: return "Veri Keychain için kodlanamadı."
        case .decoding: return "Keychain verisi çözülemedi."
        }
    }
}

final class LiveKeychainService: KeychainService {
    private let service: String

    init(service: String = "com.nuvyra.app.auth") {
        self.service = service
    }

    func save(_ data: Data, for key: String) throws {
        let baseQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]

        let updateAttrs: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemUpdate(baseQuery as CFDictionary, updateAttrs as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery.merge(updateAttrs) { _, new in new }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unhandled(addStatus) }
        } else if status != errSecSuccess {
            throw KeychainError.unhandled(status)
        }
    }

    func read(_ key: String) throws -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandled(status)
        }
    }

    func remove(_ key: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
    }
}

final class InMemoryKeychainService: KeychainService {
    private var storage: [String: Data] = [:]
    private let queue = DispatchQueue(label: "com.nuvyra.mock.keychain")

    func save(_ data: Data, for key: String) throws {
        queue.sync { storage[key] = data }
    }

    func read(_ key: String) throws -> Data? {
        queue.sync { storage[key] }
    }

    func remove(_ key: String) throws {
        queue.sync { _ = storage.removeValue(forKey: key) }
    }
}
