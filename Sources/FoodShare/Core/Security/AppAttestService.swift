//
//  AppAttestService.swift
//  Foodshare
//
//  Enterprise App Attest integration for device integrity verification
//
//  App Attest provides hardware-backed attestation to verify:
//  - The app is genuine and unmodified
//  - Running on a legitimate Apple device
//  - Not running in a jailbroken/modified environment
//

import CryptoKit
#if !SKIP
import DeviceCheck
#endif
import Foundation
import OSLog

// MARK: - App Attest Service

/// Enterprise-grade device attestation using Apple's App Attest API
///
/// This service provides cryptographic proof that:
/// 1. The app binary hasn't been modified
/// 2. The device is a genuine Apple device
/// 3. The request originated from your app
///
/// Usage:
/// ```swift
/// let attestService = AppAttestService()
///
/// // Check if supported (not available on simulators)
/// if await attestService.isSupported {
///     // Generate attestation for sensitive operations
///     let attestation = try await attestService.attestKey(for: challenge)
///     // Send attestation to backend for verification
/// }
/// ```
@MainActor
final class AppAttestService {
    // MARK: - Types

    /// Errors that can occur during attestation
    enum AttestError: Error, LocalizedError {
        case notSupported
        case keyGenerationFailed(Error)
        case attestationFailed(Error)
        case assertionFailed(Error)
        case serverVerificationFailed(String)
        case invalidChallenge
        case keyNotGenerated

        var errorDescription: String? {
            switch self {
            case .notSupported:
                "App Attest is not supported on this device"
            case let .keyGenerationFailed(error):
                "Failed to generate attestation key: \(error.localizedDescription)"
            case let .attestationFailed(error):
                "Failed to create attestation: \(error.localizedDescription)"
            case let .assertionFailed(error):
                "Failed to create assertion: \(error.localizedDescription)"
            case let .serverVerificationFailed(reason):
                "Server verification failed: \(reason)"
            case .invalidChallenge:
                "Invalid challenge data"
            case .keyNotGenerated:
                "Attestation key has not been generated"
            }
        }
    }

    /// Attestation result containing key ID and attestation data
    struct AttestationResult: Sendable {
        let keyId: String
        let attestation: Data
        let timestamp: Date
    }

    /// Assertion result for subsequent requests
    struct AssertionResult: Sendable {
        let keyId: String
        let assertion: Data
        let clientData: Data
    }

    // MARK: - Properties

    private let service: DCAppAttestService
    private let logger = Logger(subsystem: Constants.bundleIdentifier, category: "AppAttest")

    /// Stored key ID after successful attestation
    private var keyId: String?

    /// Whether the key has been attested
    private var isAttested = false

    // MARK: - Computed Properties

    /// Whether App Attest is supported on this device
    var isSupported: Bool {
        service.isSupported
    }

    // MARK: - Initialization

    init(service: DCAppAttestService = .shared) {
        self.service = service
    }

    // MARK: - Key Generation

    /// Generate a new attestation key
    ///
    /// This creates a hardware-bound key that can be used for attestation.
    /// The key is stored securely on the device.
    ///
    /// - Returns: The key identifier for the new key
    /// - Throws: `AttestError` if key generation fails
    func generateKey() async throws -> String {
        guard isSupported else {
            logger.warning("App Attest not supported on this device")
            throw AttestError.notSupported
        }

        do {
            let generatedKeyId = try await service.generateKey()
            keyId = generatedKeyId
            logger.info("Generated attestation key: \(generatedKeyId.prefix(8))...")
            return generatedKeyId
        } catch {
            logger.error("Key generation failed: \(error.localizedDescription)")
            throw AttestError.keyGenerationFailed(error)
        }
    }

    // MARK: - Attestation

    /// Attest the key using a server-provided challenge
    ///
    /// This creates an attestation object that proves:
    /// - The key was generated on a genuine Apple device
    /// - The app is the genuine, unmodified version
    ///
    /// - Parameter challenge: A unique challenge from your server (should be one-time use)
    /// - Returns: AttestationResult containing the attestation data
    /// - Throws: `AttestError` if attestation fails
    func attestKey(challenge: Data) async throws -> AttestationResult {
        guard isSupported else {
            throw AttestError.notSupported
        }

        // Generate key if not already done
        let currentKeyId: String = if let existingKeyId = keyId {
            existingKeyId
        } else {
            try await generateKey()
        }

        // Create hash of challenge
        let clientDataHash = Data(SHA256.hash(data: challenge))

        do {
            let attestationData = try await service.attestKey(currentKeyId, clientDataHash: clientDataHash)
            isAttested = true

            logger.info("Successfully attested key: \(currentKeyId.prefix(8))...")

            return AttestationResult(
                keyId: currentKeyId,
                attestation: attestationData,
                timestamp: Date(),
            )
        } catch {
            logger.error("Attestation failed: \(error.localizedDescription)")
            throw AttestError.attestationFailed(error)
        }
    }

    // MARK: - Assertions

    /// Generate an assertion for a request
    ///
    /// After the key is attested, use this to sign subsequent requests.
    /// Each assertion proves the request came from your genuine app.
    ///
    /// - Parameter clientData: The request data to include in the assertion (usually request body hash)
    /// - Returns: AssertionResult containing the signed assertion
    /// - Throws: `AttestError` if assertion fails
    func generateAssertion(clientData: Data) async throws -> AssertionResult {
        guard isSupported else {
            throw AttestError.notSupported
        }

        guard let currentKeyId = keyId, isAttested else {
            throw AttestError.keyNotGenerated
        }

        // Create hash of client data
        let clientDataHash = Data(SHA256.hash(data: clientData))

        do {
            let assertion = try await service.generateAssertion(currentKeyId, clientDataHash: clientDataHash)

            logger.debug("Generated assertion for request")

            return AssertionResult(
                keyId: currentKeyId,
                assertion: assertion,
                clientData: clientData,
            )
        } catch {
            logger.error("Assertion generation failed: \(error.localizedDescription)")
            throw AttestError.assertionFailed(error)
        }
    }

    // MARK: - Convenience Methods

    /// Perform full attestation flow with server verification
    ///
    /// This handles the complete flow:
    /// 1. Generate key if needed
    /// 2. Request challenge from server
    /// 3. Create attestation
    /// 4. Send to server for verification
    ///
    /// - Parameters:
    ///   - challengeProvider: Async closure that fetches a challenge from your server
    ///   - verifier: Async closure that sends attestation to server and returns success
    /// - Returns: Whether attestation was successful
    func performAttestation(
        challengeProvider: () async throws -> Data,
        verifier: (AttestationResult) async throws -> Bool,
    ) async throws -> Bool {
        // Get challenge from server
        let challenge = try await challengeProvider()

        // Create attestation
        let attestation = try await attestKey(challenge: challenge)

        // Verify with server
        let verified = try await verifier(attestation)

        if verified {
            logger.info("Device attestation verified successfully")
        } else {
            logger.warning("Device attestation verification failed")
            throw AttestError.serverVerificationFailed("Server rejected attestation")
        }

        return verified
    }

    // MARK: - State Management

    /// Reset attestation state (useful for testing or re-attestation)
    func reset() {
        keyId = nil
        isAttested = false
        logger.info("Attestation state reset")
    }

    /// Check if this device has been attested
    var hasValidAttestation: Bool {
        keyId != nil && isAttested
    }
}

// MARK: - Mock for Testing

#if DEBUG
    /// Mock App Attest service for unit testing
    final class MockAppAttestService: @unchecked Sendable {
        var shouldSucceed = true
        var mockKeyId = "mock-key-id-12345"
        var mockAttestation = Data([0x01, 0x02, 0x03])
        var mockAssertion = Data([0x04, 0x05, 0x06])

        var isSupported: Bool { true }

        func generateKey() async throws -> String {
            guard shouldSucceed else {
                throw AppAttestService.AttestError.keyGenerationFailed(NSError(domain: "mock", code: -1))
            }
            return mockKeyId
        }

        func attestKey(challenge: Data) async throws -> AppAttestService.AttestationResult {
            guard shouldSucceed else {
                throw AppAttestService.AttestError.attestationFailed(NSError(domain: "mock", code: -1))
            }
            return AppAttestService.AttestationResult(
                keyId: mockKeyId,
                attestation: mockAttestation,
                timestamp: Date(),
            )
        }

        func generateAssertion(clientData: Data) async throws -> AppAttestService.AssertionResult {
            guard shouldSucceed else {
                throw AppAttestService.AttestError.assertionFailed(NSError(domain: "mock", code: -1))
            }
            return AppAttestService.AssertionResult(
                keyId: mockKeyId,
                assertion: mockAssertion,
                clientData: clientData,
            )
        }
    }
#endif
