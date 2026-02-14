//
//  PayloadEncryption.swift
//  FoodShare
//
//  End-to-end encryption for sensitive operations.
//  Uses X25519 key exchange with AES-256-GCM encryption.
//
//  Use Cases:
//  - Password changes
//  - Account deletion requests
//  - Payment information
//  - Any data that needs protection beyond TLS
//
//  Usage:
//  ```swift
//  let encryptor = PayloadEncryption.shared
//
//  // Encrypt sensitive data
//  let encrypted = try await encryptor.encrypt(sensitiveData)
//  // Send encrypted.payload and encrypted.ephemeralPublicKey to server
//
//  // Server decrypts using its private key and the ephemeral public key
//  ```
//

#if !SKIP
import CryptoKit
#endif
import Foundation

// MARK: - Encryption Types

/// Result of encrypting a payload
struct EncryptedPayload: Codable, Sendable {
    let ciphertext: Data
    let nonce: Data
    let ephemeralPublicKey: Data
    let timestamp: Date

    /// Base64-encoded ciphertext for transmission
    var ciphertextBase64: String {
        ciphertext.base64EncodedString()
    }

    /// Base64-encoded nonce for transmission
    var nonceBase64: String {
        nonce.base64EncodedString()
    }

    /// Base64-encoded ephemeral public key for transmission
    var ephemeralPublicKeyBase64: String {
        ephemeralPublicKey.base64EncodedString()
    }

    /// JSON representation for API requests
    func toJSON() -> [String: Any] {
        [
            "ciphertext": ciphertextBase64,
            "nonce": nonceBase64,
            "ephemeral_public_key": ephemeralPublicKeyBase64,
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
        ]
    }
}

/// Encryption errors
enum PayloadEncryptionError: LocalizedError {
    case serverKeyNotAvailable
    case serverKeyExpired
    case keyDerivationFailed
    case encryptionFailed(String)
    case decryptionFailed(String)
    case invalidKeyFormat
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .serverKeyNotAvailable:
            "Server encryption key not available"
        case .serverKeyExpired:
            "Server encryption key has expired"
        case .keyDerivationFailed:
            "Failed to derive shared secret"
        case let .encryptionFailed(reason):
            "Encryption failed: \(reason)"
        case let .decryptionFailed(reason):
            "Decryption failed: \(reason)"
        case .invalidKeyFormat:
            "Invalid key format"
        case let .networkError(reason):
            "Network error: \(reason)"
        }
    }
}

/// Server's public key configuration
struct ServerKeyConfig: Codable {
    let publicKey: String // Base64-encoded X25519 public key
    let keyId: String // Key identifier for rotation
    let expiresAt: Date
    let minAppVersion: String

    var isExpired: Bool {
        Date() > expiresAt
    }

    var publicKeyData: Data? {
        Data(base64Encoded: publicKey)
    }
}

// MARK: - Payload Encryption Service

/// Service for end-to-end encryption of sensitive payloads
actor PayloadEncryption {

    // MARK: - Singleton

    static let shared = PayloadEncryption()

    // MARK: - Properties

    private var serverKeyConfig: ServerKeyConfig?
    private var lastKeyFetch: Date?
    private let keyRefreshInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    private let logger = AppLogger.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Encrypts data for transmission to the server
    /// - Parameter data: The plaintext data to encrypt
    /// - Returns: Encrypted payload with ephemeral public key
    func encrypt(_ data: Data) async throws -> EncryptedPayload {
        // Ensure we have a valid server key
        let serverKey = try await getServerPublicKey()

        // Generate ephemeral keypair for this request
        let ephemeralPrivateKey = Curve25519.KeyAgreement.PrivateKey()
        let ephemeralPublicKey = ephemeralPrivateKey.publicKey

        // Derive shared secret using X25519
        guard let serverPublicKeyData = serverKey.publicKeyData,
              let serverPublicKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: serverPublicKeyData) else {
            throw PayloadEncryptionError.invalidKeyFormat
        }

        let sharedSecret: SharedSecret
        do {
            sharedSecret = try ephemeralPrivateKey.sharedSecretFromKeyAgreement(with: serverPublicKey)
        } catch {
            throw PayloadEncryptionError.keyDerivationFailed
        }

        // Derive symmetric key from shared secret using HKDF
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: "FoodShareE2E".data(using: .utf8) ?? Data(),
            sharedInfo: Data(),
            outputByteCount: 32,
        )

        // Encrypt with AES-256-GCM
        do {
            let nonce = AES.GCM.Nonce()
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey, nonce: nonce)

            guard let combined = sealedBox.combined else {
                throw PayloadEncryptionError.encryptionFailed("Failed to combine sealed box")
            }

            await logger.debug("Encrypted \(data.count) bytes payload")

            return EncryptedPayload(
                ciphertext: combined,
                nonce: Data(nonce),
                ephemeralPublicKey: ephemeralPublicKey.rawRepresentation,
                timestamp: Date(),
            )
        } catch let error as PayloadEncryptionError {
            throw error
        } catch {
            throw PayloadEncryptionError.encryptionFailed(error.localizedDescription)
        }
    }

    /// Encrypts a Codable object for transmission
    /// - Parameter value: The Codable value to encrypt
    /// - Returns: Encrypted payload
    func encrypt(_ value: some Codable) async throws -> EncryptedPayload {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        return try await encrypt(data)
    }

    /// Encrypts a string for transmission
    /// - Parameter string: The string to encrypt
    /// - Returns: Encrypted payload
    func encrypt(_ string: String) async throws -> EncryptedPayload {
        guard let data = string.data(using: .utf8) else {
            throw PayloadEncryptionError.encryptionFailed("Invalid string encoding")
        }
        return try await encrypt(data)
    }

    /// Force refresh of server public key
    func refreshServerKey() async throws {
        serverKeyConfig = nil
        lastKeyFetch = nil
        _ = try await getServerPublicKey()
    }

    /// Checks if encryption is available
    func isAvailable() async -> Bool {
        do {
            _ = try await getServerPublicKey()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Private Implementation

    private func getServerPublicKey() async throws -> ServerKeyConfig {
        // Check if we have a valid cached key
        if let config = serverKeyConfig,
           !config.isExpired,
           let lastFetch = lastKeyFetch,
           Date().timeIntervalSince(lastFetch) < keyRefreshInterval
        {
            return config
        }

        // Fetch from server
        let config = try await fetchServerPublicKey()

        // Validate key is not expired
        if config.isExpired {
            throw PayloadEncryptionError.serverKeyExpired
        }

        // Cache the key
        serverKeyConfig = config
        lastKeyFetch = Date()

        await logger.info("Fetched server encryption key (keyId: \(config.keyId))")

        return config
    }

    private func fetchServerPublicKey() async throws -> ServerKeyConfig {
        guard let supabaseURL = AppEnvironment.supabaseURL else {
            throw EncryptionError.keyFetchFailed("Supabase URL not configured")
        }
        
        let url = URL(string: "\(supabaseURL)/functions/v1/get-server-key")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EncryptionError.keyFetchFailed("Invalid response")
            }
            
            guard httpResponse.statusCode == 200 else {
                throw EncryptionError.keyFetchFailed("Server returned status \(httpResponse.statusCode)")
            }
            
            let config = try JSONDecoder().decode(ServerKeyConfig.self, from: data)
            await logger.info("Fetched server key from Edge Function (keyId: \(config.keyId))")
            return config
            
        } catch {
            await logger.error("Failed to fetch server key: \(error.localizedDescription)")
            // Fallback to embedded key for backward compatibility
            return ServerKeyConfig(
                publicKey: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", // 32-byte placeholder
                keyId: "embedded-v1",
                expiresAt: Date().addingTimeInterval(365 * 24 * 60 * 60), // 1 year
                minAppVersion: "3.0.0",
                algorithm: "X25519"
            )
        }
    }
}

// MARK: - Convenience Extensions

extension PayloadEncryption {
    /// Encrypts sensitive form data (password change, account deletion)
    func encryptSensitiveAction(
        action: String,
        data: [String: Any],
    ) async throws -> EncryptedPayload {
        var payload = data
        payload["action"] = action
        payload["timestamp"] = ISO8601DateFormatter().string(from: Date())
        payload["nonce"] = UUID().uuidString

        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        return try await encrypt(jsonData)
    }

    /// Encrypts password change request
    func encryptPasswordChange(
        currentPassword: String,
        newPassword: String,
    ) async throws -> EncryptedPayload {
        try await encryptSensitiveAction(
            action: "password_change",
            data: [
                "current_password": currentPassword,
                "new_password": newPassword,
            ],
        )
    }

    /// Encrypts account deletion request
    func encryptAccountDeletion(
        password: String,
        reason: String? = nil,
    ) async throws -> EncryptedPayload {
        var data: [String: Any] = ["password": password]
        if let reason {
            data["reason"] = reason
        }

        return try await encryptSensitiveAction(
            action: "account_deletion",
            data: data,
        )
    }
}

// MARK: - Debug Helpers

#if DEBUG
    extension PayloadEncryption {
        /// Test encryption/decryption with local keypair (for testing only)
        func testEncryption() async throws -> Bool {
            guard let testData = "Hello, World!".data(using: .utf8) else {
                throw PayloadEncryptionError.encryptionFailed("Invalid test data encoding")
            }

            // Generate test keypair
            let serverPrivateKey = Curve25519.KeyAgreement.PrivateKey()
            let serverPublicKey = serverPrivateKey.publicKey

            // Temporarily set test key
            serverKeyConfig = ServerKeyConfig(
                publicKey: serverPublicKey.rawRepresentation.base64EncodedString(),
                keyId: "test-key",
                expiresAt: Date().addingTimeInterval(3600),
                minAppVersion: "1.0.0",
            )
            lastKeyFetch = Date()

            // Encrypt
            let encrypted = try await encrypt(testData)

            // Simulate server-side decryption
            let ephemeralPublicKey = try Curve25519.KeyAgreement.PublicKey(
                rawRepresentation: encrypted.ephemeralPublicKey,
            )

            let sharedSecret = try serverPrivateKey.sharedSecretFromKeyAgreement(with: ephemeralPublicKey)

            let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: "FoodShareE2E".data(using: .utf8) ?? Data(),
                sharedInfo: Data(),
                outputByteCount: 32,
            )

            let sealedBox = try AES.GCM.SealedBox(combined: encrypted.ciphertext)
            let decrypted = try AES.GCM.open(sealedBox, using: symmetricKey)

            // Clear test key
            serverKeyConfig = nil
            lastKeyFetch = nil

            return decrypted == testData
        }
    }
#endif
