//
//  RequestSigner.swift
//  Foodshare
//
//  HMAC-SHA256 request signing for API integrity protection
//
//  This service signs sensitive API requests to:
//  - Prevent request tampering (MITM attacks)
//  - Provide request authenticity verification
//  - Add replay attack protection with timestamps
//

#if !SKIP
import CryptoKit
import Foundation
import OSLog

// MARK: - Request Signer

/// Enterprise-grade request signing using HMAC-SHA256
///
/// Signs sensitive API requests to ensure:
/// - Request integrity (body hasn't been tampered with)
/// - Request authenticity (came from this app)
/// - Replay protection (timestamp-based nonce)
///
/// Usage:
/// ```swift
/// let signer = RequestSigner()
///
/// // Sign a request
/// let signedRequest = try await signer.sign(
///     request: &urlRequest,
///     body: jsonData,
///     operation: .profileUpdate
/// )
///
/// // Server validates signature using shared secret
/// ```
@MainActor
final class RequestSigner {
    // MARK: - Types

    /// Operations that require request signing
    enum SignedOperation: String, Sendable {
        case profileUpdate = "profile.update"
        case listingCreate = "listing.create"
        case listingUpdate = "listing.update"
        case listingDelete = "listing.delete"
        case messageCreate = "message.create"
        case paymentProcess = "payment.process"
        case reviewCreate = "review.create"
        case reportCreate = "report.create"
        case accountDelete = "account.delete"

        /// Priority level for server-side rate limiting
        var priority: Int {
            switch self {
            case .paymentProcess: 1
            case .accountDelete: 1
            case .profileUpdate: 2
            case .listingCreate, .listingUpdate, .listingDelete: 3
            case .messageCreate, .reviewCreate, .reportCreate: 4
            }
        }
    }

    /// Errors that can occur during signing
    enum SigningError: Error, LocalizedError {
        case noSigningKey
        case invalidKeyFormat
        case signingFailed(Error)
        case timestampExpired
        case invalidSignature

        var errorDescription: String? {
            switch self {
            case .noSigningKey:
                "Request signing key not configured"
            case .invalidKeyFormat:
                "Invalid signing key format"
            case let .signingFailed(error):
                "Failed to sign request: \(error.localizedDescription)"
            case .timestampExpired:
                "Request timestamp has expired"
            case .invalidSignature:
                "Request signature validation failed"
            }
        }
    }

    /// Signed request metadata
    struct SignatureMetadata: Sendable, Codable {
        let signature: String
        let timestamp: Int64
        let nonce: String
        let operation: String
        let keyVersion: String
    }

    // MARK: - Properties

    private let logger = Logger(subsystem: Constants.bundleIdentifier, category: "RequestSigner")

    /// Keychain storage for secure key persistence
    private let keychainStorage = KeychainStorage()

    /// Keychain key for signing key storage
    private static let signingKeyKeychainKey = "request.signing.key"
    private static let keyVersionKeychainKey = "request.signing.key.version"

    /// Current signing key (should be rotated periodically)
    private var signingKey: SymmetricKey?

    /// Key version for key rotation support
    private var keyVersion = "v1"

    /// Maximum age for request timestamps (prevents replay attacks)
    private let maxTimestampAge: TimeInterval = 300 // 5 minutes

    // MARK: - Initialization

    init() {
        // Load key from Keychain on initialization
        loadSigningKey()
    }

    // MARK: - Key Management

    /// Load signing key from Keychain, generating a new one if not found
    private func loadSigningKey() {
        // 1. Try to load existing key from Keychain
        if let keyData = try? keychainStorage.retrieve(key: Self.signingKeyKeychainKey),
           keyData.count == 32 { // SHA256 = 32 bytes
            signingKey = SymmetricKey(data: keyData)

            // Load key version if available
            if let versionData = try? keychainStorage.retrieve(key: Self.keyVersionKeychainKey),
               let version = String(data: versionData, encoding: .utf8) {
                keyVersion = version
            }

            logger.debug("Signing key loaded from Keychain (version: \(self.keyVersion))")
            return
        }

        // 2. Generate a new cryptographically secure key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }

        // 3. Store in Keychain
        do {
            try keychainStorage.store(key: Self.signingKeyKeychainKey, value: keyData)
            try keychainStorage.store(key: Self.keyVersionKeychainKey, value: Data("v1".utf8))
            signingKey = newKey
            keyVersion = "v1"
            logger.info("New signing key generated and stored in Keychain")
        } catch {
            // Fallback: generate ephemeral key (will change on each app launch)
            logger.error("Failed to store signing key in Keychain: \(error.localizedDescription)")
            signingKey = newKey
        }
    }

    /// Rotate signing key (for key rotation)
    ///
    /// - Parameters:
    ///   - newKeyData: The new 32-byte key data
    ///   - version: The version identifier for this key
    /// - Throws: KeychainError if storing fails
    func rotateKey(newKeyData: Data, version: String) throws {
        // Store new key in Keychain
        try keychainStorage.store(key: Self.signingKeyKeychainKey, value: newKeyData)
        try keychainStorage.store(key: Self.keyVersionKeychainKey, value: Data(version.utf8))

        // Update in-memory state
        signingKey = SymmetricKey(data: newKeyData)
        keyVersion = version
        logger.info("Signing key rotated to version: \(version)")
    }

    // MARK: - Request Signing

    /// Sign a URLRequest with HMAC-SHA256
    ///
    /// - Parameters:
    ///   - request: The URLRequest to sign (modified in place)
    ///   - body: The request body data (if any)
    ///   - operation: The type of operation being performed
    /// - Returns: Signature metadata for debugging/logging
    /// - Throws: `SigningError` if signing fails
    func sign(
        request: inout URLRequest,
        body: Data?,
        operation: SignedOperation,
    ) throws -> SignatureMetadata {
        guard let key = signingKey else {
            throw SigningError.noSigningKey
        }

        // Generate timestamp and nonce
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let nonce = UUID().uuidString

        // Build canonical request string for signing
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? "/"
        let query = request.url?.query ?? ""
        let bodyHash = body.map { Data(SHA256.hash(data: $0)).base64EncodedString() } ?? ""

        let canonicalRequest = """
        \(method)
        \(path)
        \(query)
        \(timestamp)
        \(nonce)
        \(operation.rawValue)
        \(bodyHash)
        """

        // Create HMAC signature
        let signatureData = HMAC<SHA256>.authenticationCode(
            for: Data(canonicalRequest.utf8),
            using: key,
        )
        let signature = Data(signatureData).base64EncodedString()

        // Add signature headers to request
        request.setValue(signature, forHTTPHeaderField: "X-Signature")
        request.setValue(String(timestamp), forHTTPHeaderField: "X-Timestamp")
        request.setValue(nonce, forHTTPHeaderField: "X-Nonce")
        request.setValue(operation.rawValue, forHTTPHeaderField: "X-Operation")
        request.setValue(keyVersion, forHTTPHeaderField: "X-Key-Version")

        logger.debug("Signed request: \(operation.rawValue)")

        return SignatureMetadata(
            signature: signature,
            timestamp: timestamp,
            nonce: nonce,
            operation: operation.rawValue,
            keyVersion: keyVersion,
        )
    }

    // MARK: - Signature Verification (for testing)

    /// Verify a signature (used for testing and debugging)
    ///
    /// - Parameters:
    ///   - signature: The signature to verify
    ///   - canonicalRequest: The canonical request string that was signed
    /// - Returns: Whether the signature is valid
    func verify(signature: String, canonicalRequest: String) throws -> Bool {
        guard let key = signingKey else {
            throw SigningError.noSigningKey
        }

        guard let signatureData = Data(base64Encoded: signature) else {
            return false
        }

        return HMAC<SHA256>.isValidAuthenticationCode(
            signatureData,
            authenticating: Data(canonicalRequest.utf8),
            using: key,
        )
    }

    /// Check if a timestamp is still valid (not too old)
    func isTimestampValid(_ timestamp: Int64) -> Bool {
        let requestTime = Date(timeIntervalSince1970: Double(timestamp) / 1000)
        let age = Date().timeIntervalSince(requestTime)
        return age >= 0 && age <= maxTimestampAge
    }
}

// MARK: - URLRequest Extension

extension URLRequest {
    /// Sign this request with the RequestSigner
    ///
    /// Usage:
    /// ```swift
    /// var request = URLRequest(url: url)
    /// request.httpBody = jsonData
    /// try await request.sign(for: .profileUpdate)
    /// ```
    @MainActor
    mutating func sign(
        for operation: RequestSigner.SignedOperation,
        using signer: RequestSigner = RequestSigner(),
    ) throws {
        _ = try signer.sign(request: &self, body: httpBody, operation: operation)
    }
}

// MARK: - Signed Request Builder

/// Builder for creating signed requests fluently
@MainActor
final class SignedRequestBuilder {
    private var request: URLRequest
    private let signer: RequestSigner

    init(url: URL, signer: RequestSigner = RequestSigner()) {
        self.request = URLRequest(url: url)
        self.signer = signer
    }

    func method(_ method: String) -> Self {
        request.httpMethod = method
        return self
    }

    func body(_ data: Data) -> Self {
        request.httpBody = data
        return self
    }

    func jsonBody(_ value: some Encodable) throws -> Self {
        request.httpBody = try JSONEncoder().encode(value)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return self
    }

    func header(_ name: String, value: String) -> Self {
        request.setValue(value, forHTTPHeaderField: name)
        return self
    }

    func authorization(_ token: String) -> Self {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return self
    }

    func sign(for operation: RequestSigner.SignedOperation) throws -> URLRequest {
        _ = try signer.sign(request: &request, body: request.httpBody, operation: operation)
        return request
    }
}

// MARK: - Mock for Testing

#if DEBUG
    /// Mock request signer for unit testing
    final class MockRequestSigner: @unchecked Sendable {
        var shouldSucceed = true
        var lastSignedOperation: RequestSigner.SignedOperation?

        @MainActor
        func sign(
            request: inout URLRequest,
            body: Data?,
            operation: RequestSigner.SignedOperation,
        ) throws -> RequestSigner.SignatureMetadata {
            guard shouldSucceed else {
                throw RequestSigner.SigningError.signingFailed(NSError(domain: "mock", code: -1))
            }

            lastSignedOperation = operation

            return RequestSigner.SignatureMetadata(
                signature: "mock-signature",
                timestamp: Int64(Date().timeIntervalSince1970 * 1000),
                nonce: "mock-nonce",
                operation: operation.rawValue,
                keyVersion: "mock-v1",
            )
        }
    }
#endif

#endif
