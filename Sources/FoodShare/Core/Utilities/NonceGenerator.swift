//
//  NonceGenerator.swift
//  Foodshare
//
//  Cryptographic nonce generation utilities for OAuth and security operations
//
//  Extracted from AuthenticationService for better reusability and separation of concerns
//


#if !SKIP
#if !SKIP
import CryptoKit
#endif
import Foundation

// MARK: - Nonce Generator

/// Utility for generating cryptographically secure nonces and hashes
///
/// Used for:
/// - Apple Sign In (OIDC nonce requirement)
/// - Google Sign In (OIDC nonce requirement)
/// - CSRF token generation
/// - Request signing nonces
///
/// Usage:
/// ```swift
/// let nonce = try NonceGenerator.generateNonce()
/// let hashedNonce = NonceGenerator.sha256(nonce)
/// ```
enum NonceGenerator {
    // MARK: - Errors

    enum NonceError: Error, LocalizedError {
        case invalidLength
        case randomGenerationFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .invalidLength:
                "Nonce length must be positive"
            case let .randomGenerationFailed(status):
                "Unable to generate secure random nonce (status: \(status))"
            }
        }
    }

    // MARK: - Constants

    /// Characters used in nonce generation (URL-safe)
    private static let charset: [Character] = Array(
        "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._",
    )

    // MARK: - Nonce Generation

    /// Generate a cryptographically secure random nonce
    ///
    /// - Parameter length: The length of the nonce (default: 32)
    /// - Returns: A random string of the specified length
    /// - Throws: `NonceError` if random generation fails
    static func generateNonce(length: Int = 32) throws -> String {
        guard length > 0 else {
            throw NonceError.invalidLength
        }

        var result = ""
        result.reserveCapacity(length)
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)

            let errorCode = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if errorCode != errSecSuccess {
                throw NonceError.randomGenerationFailed(errorCode)
            }

            for random in randoms {
                guard remainingLength > 0 else { break }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    // MARK: - Hashing

    /// Compute SHA-256 hash of a string
    ///
    /// - Parameter input: The string to hash
    /// - Returns: Lowercase hexadecimal representation of the hash
    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Compute SHA-256 hash of data
    ///
    /// - Parameter data: The data to hash
    /// - Returns: The hash as Data
    static func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    /// Compute SHA-256 hash of data and return as base64
    ///
    /// - Parameter data: The data to hash
    /// - Returns: Base64-encoded hash
    static func sha256Base64(_ data: Data) -> String {
        sha256(data).base64EncodedString()
    }
}

// MARK: - Convenience Extensions

extension String {
    /// Compute SHA-256 hash of this string
    var sha256Hash: String {
        NonceGenerator.sha256(self)
    }
}

extension Data {
    /// Compute SHA-256 hash of this data
    var sha256Hash: Data {
        NonceGenerator.sha256(self)
    }

    /// Compute SHA-256 hash of this data as base64
    var sha256Base64: String {
        NonceGenerator.sha256Base64(self)
    }
}

#endif
