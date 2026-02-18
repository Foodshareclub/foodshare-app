//
//  KeychainHelper.swift
//  Foodshare
//
//  Low-level Keychain wrapper for secure storage
//  Thread-safe actor with typed access
//


#if !SKIP
import Foundation
import OSLog
#if !SKIP
import Security
#endif

/// Keychain access errors
enum KeychainError: LocalizedError, Sendable {
    case itemNotFound
    case duplicateItem
    case invalidData
    case unhandledError(OSStatus)
    case encodingFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            "Item not found in Keychain"
        case .duplicateItem:
            "Item already exists in Keychain"
        case .invalidData:
            "Invalid data format"
        case let .unhandledError(status):
            "Keychain error: \(status)"
        case .encodingFailed:
            "Failed to encode data"
        case .decodingFailed:
            "Failed to decode data"
        }
    }
}

/// Thread-safe Keychain helper using actor isolation
actor KeychainHelper {
    /// Shared instance for app-wide use
    static let shared = KeychainHelper()

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "KeychainHelper")

    /// Service identifier for all Keychain items
    private let service = "com.flutterflow.foodshare"

    /// Access group for sharing between app and extensions
    private let accessGroup: String? = nil // Set to team ID + group if sharing needed

    private init() {}

    // MARK: - String Operations

    /// Save a string value to Keychain
    /// - Parameters:
    ///   - value: The string value to save
    ///   - key: The key to store the value under
    func save(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        try saveData(data, forKey: key)
    }

    /// Retrieve a string value from Keychain
    /// - Parameter key: The key to retrieve
    /// - Returns: The stored string value
    func retrieve(forKey key: String) throws -> String? {
        guard let data = try retrieveData(forKey: key) else {
            return nil
        }
        guard let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }
        return value
    }

    // MARK: - Data Operations

    /// Save data to Keychain
    /// - Parameters:
    ///   - data: The data to save
    ///   - key: The key to store the data under
    func saveData(_ data: Data, forKey key: String) throws {
        var query = baseQuery(forKey: key)
        query[kSecValueData as String] = data

        // Try to add the item
        var status = SecItemAdd(query as CFDictionary, nil)

        // If it already exists, update it
        if status == errSecDuplicateItem {
            let updateQuery = baseQuery(forKey: key)
            let attributesToUpdate: [String: Any] = [kSecValueData as String: data]
            status = SecItemUpdate(updateQuery as CFDictionary, attributesToUpdate as CFDictionary)
        }

        guard status == errSecSuccess else {
            logger.error("Failed to save to Keychain: \(status)")
            throw KeychainError.unhandledError(status)
        }

        logger.debug("Saved item to Keychain for key: \(key)")
    }

    /// Retrieve data from Keychain
    /// - Parameter key: The key to retrieve
    /// - Returns: The stored data, or nil if not found
    func retrieveData(forKey key: String) throws -> Data? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.invalidData
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            logger.error("Failed to retrieve from Keychain: \(status)")
            throw KeychainError.unhandledError(status)
        }
    }

    /// Delete an item from Keychain
    /// - Parameter key: The key to delete
    func delete(forKey key: String) throws {
        let query = baseQuery(forKey: key)
        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Failed to delete from Keychain: \(status)")
            throw KeychainError.unhandledError(status)
        }

        logger.debug("Deleted item from Keychain for key: \(key)")
    }

    /// Check if an item exists in Keychain
    /// - Parameter key: The key to check
    /// - Returns: True if the item exists
    func exists(forKey key: String) -> Bool {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = false

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Delete all items for this service
    func deleteAll() throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Failed to delete all from Keychain: \(status)")
            throw KeychainError.unhandledError(status)
        }

        logger.info("Deleted all Keychain items for service: \(self.service)")
    }

    // MARK: - Codable Operations

    /// Save a Codable object to Keychain
    /// - Parameters:
    ///   - value: The Codable object to save
    ///   - key: The key to store the object under
    func save(_ value: some Encodable, forKey key: String) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        try saveData(data, forKey: key)
    }

    /// Retrieve a Codable object from Keychain
    /// - Parameters:
    ///   - type: The type to decode
    ///   - key: The key to retrieve
    /// - Returns: The decoded object, or nil if not found
    func retrieve<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let data = try retrieveData(forKey: key) else {
            return nil
        }
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }

    // MARK: - Private Helpers

    private func baseQuery(forKey key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }
}

#endif
