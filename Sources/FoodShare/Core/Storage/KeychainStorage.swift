//
//  KeychainStorage.swift
//  Foodshare
//
//  Secure keychain storage for auth tokens
//

import Foundation
#if !SKIP
import Security
#endif

/// Keychain storage implementation for Supabase Auth
final class KeychainStorage: @unchecked Sendable {
    private let service = Constants.bundleIdentifier
    private let accessGroup: String?

    init(accessGroup: String? = nil) {
        self.accessGroup = accessGroup
    }

    // MARK: - Storage Methods

    func store(key: String, value: Data) throws {
        // Delete existing item first
        try? delete(key: key)

        var query = baseQuery(for: key)
        query[kSecValueData as String] = value

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unableToStore(status)
        }
    }

    func retrieve(key: String) throws -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.unableToRetrieve(status)
        }

        return result as? Data
    }

    func delete(key: String) throws {
        let query = baseQuery(for: key)
        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete(status)
        }
    }

    func deleteAll() throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete(status)
        }
    }

    // MARK: - Private Methods

    private func baseQuery(for key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }
}

// MARK: - Keychain Error

/// Errors that can occur during Keychain operations.
///
/// Thread-safe for Swift 6 concurrency.
enum KeychainError: LocalizedError, Sendable {
    /// Failed to store item in keychain
    case unableToStore(OSStatus)
    /// Failed to retrieve item from keychain
    case unableToRetrieve(OSStatus)
    /// Failed to delete item from keychain
    case unableToDelete(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .unableToStore(status):
            "Unable to store item in keychain. Status: \(status)"
        case let .unableToRetrieve(status):
            "Unable to retrieve item from keychain. Status: \(status)"
        case let .unableToDelete(status):
            "Unable to delete item from keychain. Status: \(status)"
        }
    }
}

// MARK: - Supabase Auth Storage Extension
// KeychainStorage implements the required methods for auth storage
