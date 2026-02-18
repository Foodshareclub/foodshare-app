//
//  SecureStorage.swift
//  FoodShare
//
//  Encrypted storage wrapper using Keychain and AES-256-GCM.
//  Provides secure at-rest encryption for sensitive data like audit logs.
//
//  Usage:
//  ```swift
//  let storage = SecureStorage.shared
//  try await storage.store(data, forKey: "audit_events")
//  let retrieved = try await storage.retrieve(forKey: "audit_events")
//  ```
//


#if !SKIP
#if !SKIP
import CryptoKit
#endif
import Foundation
#if !SKIP
import Security
#endif

// MARK: - Secure Storage Error

enum SecureStorageError: LocalizedError {
    case keyGenerationFailed
    case keyNotFound
    case keychainError(OSStatus)
    case encryptionFailed(String)
    case decryptionFailed(String)
    case dataCorrupted
    case invalidData
    case directoryAccessFailed

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            "Failed to generate encryption key"
        case .keyNotFound:
            "Encryption key not found in Keychain"
        case let .keychainError(status):
            "Keychain error: \(status)"
        case let .encryptionFailed(reason):
            "Encryption failed: \(reason)"
        case let .decryptionFailed(reason):
            "Decryption failed: \(reason)"
        case .dataCorrupted:
            "Stored data is corrupted"
        case .invalidData:
            "Invalid data format"
        case .directoryAccessFailed:
            "Failed to access application support directory"
        }
    }
}

// MARK: - Secure Storage

/// Actor-based secure storage using AES-256-GCM encryption with Keychain-stored keys
actor SecureStorage {

    // MARK: - Singleton

    static let shared = SecureStorage()

    // MARK: - Constants

    private enum Constants {
        static let service = "com.flutterflow.foodshare.securestorage"
        static let encryptionKeyAccount = "encryption_key_v1"
        static let keySize = 32 // 256 bits for AES-256
        static let nonceSize = 12 // 96 bits for GCM
        static let tagSize = 16 // 128 bits for GCM authentication tag
    }

    // MARK: - Properties

    private var cachedKey: SymmetricKey?
    private let fileManager = FileManager.default
    private let logger = AppLogger.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Securely stores data with AES-256-GCM encryption
    /// - Parameters:
    ///   - data: The data to encrypt and store
    ///   - key: Storage key identifier
    func store(_ data: Data, forKey key: String) async throws {
        let encryptionKey = try await getOrCreateEncryptionKey()
        let encryptedData = try encrypt(data, using: encryptionKey)

        let url = try storageURL(for: key)
        try encryptedData.write(to: url, options: [.atomic, .completeFileProtection])

        await logger.debug("Stored \(data.count) bytes encrypted for key: \(key)")
    }

    /// Retrieves and decrypts data
    /// - Parameter key: Storage key identifier
    /// - Returns: Decrypted data, or nil if not found
    func retrieve(forKey key: String) async throws -> Data? {
        let url = try storageURL(for: key)

        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        let encryptedData = try Data(contentsOf: url)
        let encryptionKey = try await getOrCreateEncryptionKey()

        return try decrypt(encryptedData, using: encryptionKey)
    }

    /// Removes stored data
    /// - Parameter key: Storage key identifier
    func remove(forKey key: String) async throws {
        let url = try storageURL(for: key)

        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
            await logger.debug("Removed secure storage for key: \(key)")
        }
    }

    /// Checks if data exists for key
    /// - Parameter key: Storage key identifier
    func exists(forKey key: String) async throws -> Bool {
        let url = try storageURL(for: key)
        return fileManager.fileExists(atPath: url.path)
    }

    /// Stores a Codable object with encryption
    /// - Parameters:
    ///   - value: The Codable value to store
    ///   - key: Storage key identifier
    func store(_ value: some Codable, forKey key: String) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        try await store(data, forKey: key)
    }

    /// Retrieves and decodes a Codable object
    /// - Parameters:
    ///   - type: The type to decode to
    ///   - key: Storage key identifier
    /// - Returns: Decoded value, or nil if not found
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) async throws -> T? {
        guard let data = try await retrieve(forKey: key) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    /// Rotates the encryption key (re-encrypts all data with new key)
    func rotateEncryptionKey() async throws {
        await logger.info("Starting encryption key rotation")

        // List all encrypted files
        let directory = try secureStorageDirectory()
        let files = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
        )

        // Get current key and decrypt all data
        let oldKey = try await getOrCreateEncryptionKey()
        var decryptedData: [(URL, Data)] = []

        for file in files where file.pathExtension == "encrypted" {
            let encrypted = try Data(contentsOf: file)
            let decrypted = try decrypt(encrypted, using: oldKey)
            decryptedData.append((file, decrypted))
        }

        // Generate new key
        let newKey = try generateNewEncryptionKey()
        try storeKeyInKeychain(newKey)
        cachedKey = newKey

        // Re-encrypt all data with new key
        for (url, data) in decryptedData {
            let reencrypted = try encrypt(data, using: newKey)
            try reencrypted.write(to: url, options: [.atomic, .completeFileProtection])
        }

        await logger.info("Encryption key rotation completed. Re-encrypted \(files.count) files.")
    }

    /// Clears all secure storage and removes the encryption key
    func clearAll() async throws {
        let directory = try secureStorageDirectory()

        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }

        try deleteKeyFromKeychain()
        cachedKey = nil

        await logger.info("Cleared all secure storage")
    }

    // MARK: - Encryption/Decryption

    private func encrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)

            guard let combined = sealedBox.combined else {
                throw SecureStorageError.encryptionFailed("Failed to combine sealed box")
            }

            return combined
        } catch let error as SecureStorageError {
            throw error
        } catch {
            throw SecureStorageError.encryptionFailed(error.localizedDescription)
        }
    }

    private func decrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch let error as SecureStorageError {
            throw error
        } catch {
            throw SecureStorageError.decryptionFailed(error.localizedDescription)
        }
    }

    // MARK: - Key Management

    private func getOrCreateEncryptionKey() async throws -> SymmetricKey {
        // Return cached key if available
        if let cached = cachedKey {
            return cached
        }

        // Try to load from Keychain
        if let existingKey = try loadKeyFromKeychain() {
            cachedKey = existingKey
            return existingKey
        }

        // Generate and store new key
        let newKey = try generateNewEncryptionKey()
        try storeKeyInKeychain(newKey)
        cachedKey = newKey

        await logger.info("Generated new encryption key")
        return newKey
    }

    private func generateNewEncryptionKey() throws -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    private func storeKeyInKeychain(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }

        // Delete existing key first
        try? deleteKeyFromKeychain()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.service,
            kSecAttrAccount as String: Constants.encryptionKeyAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw SecureStorageError.keychainError(status)
        }
    }

    private func loadKeyFromKeychain() throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.service,
            kSecAttrAccount as String: Constants.encryptionKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let keyData = result as? Data else {
                throw SecureStorageError.dataCorrupted
            }
            return SymmetricKey(data: keyData)

        case errSecItemNotFound:
            return nil

        default:
            throw SecureStorageError.keychainError(status)
        }
    }

    private func deleteKeyFromKeychain() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.service,
            kSecAttrAccount as String: Constants.encryptionKeyAccount,
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureStorageError.keychainError(status)
        }
    }

    // MARK: - File Management

    private func secureStorageDirectory() throws -> URL {
        guard let documentsDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
        ).first else {
            throw SecureStorageError.directoryAccessFailed
        }

        let secureDirectory = documentsDirectory.appendingPathComponent("SecureStorage", isDirectory: true)

        if !fileManager.fileExists(atPath: secureDirectory.path) {
            try fileManager.createDirectory(
                at: secureDirectory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete],
            )
        }

        return secureDirectory
    }

    private func storageURL(for key: String) throws -> URL {
        let directory = try secureStorageDirectory()
        let sanitizedKey = key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return directory.appendingPathComponent("\(sanitizedKey).encrypted")
    }
}

#endif
