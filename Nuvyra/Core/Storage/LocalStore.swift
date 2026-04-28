import Foundation

enum LocalStoreKey: String {
    case userProfile
    case meals
    case waterLogs
    case stepHistory
    case entitlementState
    case notificationSettings
}

enum LocalStoreError: Error {
    case applicationSupportUnavailable
}

actor LocalStore {
    private let directory: URL?
    private var memory: [String: Data]
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directory: URL?, memory: [String: Data] = [:]) {
        self.directory = directory
        self.memory = memory
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    static func live() throws -> LocalStore {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw LocalStoreError.applicationSupportUnavailable
        }
        let directory = base.appendingPathComponent("Nuvyra", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: directory.path)
        return LocalStore(directory: directory)
    }

    static func inMemory(seed: [LocalStoreKey: Data] = [:]) -> LocalStore {
        LocalStore(directory: nil, memory: Dictionary(uniqueKeysWithValues: seed.map { ($0.key.rawValue, $0.value) }))
    }

    func load<T: Decodable>(_ type: T.Type, for key: LocalStoreKey) throws -> T? {
        guard let data = try data(for: key) else { return nil }
        return try decoder.decode(T.self, from: data)
    }

    func save<T: Encodable>(_ value: T, for key: LocalStoreKey) throws {
        let data = try encoder.encode(value)
        try save(data: data, for: key)
    }

    func delete(_ key: LocalStoreKey) throws {
        if let directory {
            let url = fileURL(for: key, in: directory)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } else {
            memory[key.rawValue] = nil
        }
    }

    private func data(for key: LocalStoreKey) throws -> Data? {
        if let directory {
            let url = fileURL(for: key, in: directory)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return try Data(contentsOf: url)
        }
        return memory[key.rawValue]
    }

    private func save(data: Data, for key: LocalStoreKey) throws {
        if let directory {
            let url = fileURL(for: key, in: directory)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } else {
            memory[key.rawValue] = data
        }
    }

    private func fileURL(for key: LocalStoreKey, in directory: URL) -> URL {
        directory.appendingPathComponent("\(key.rawValue).json")
    }
}
