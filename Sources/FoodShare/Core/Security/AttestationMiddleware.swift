//
//  AttestationMiddleware.swift
//  Foodshare
//
//  Middleware for adding device attestation to sensitive API requests
//
//  This middleware integrates Apple's App Attest for device integrity verification,
//  with automatic fallback to DeviceCheck on unsupported devices.
//


#if !SKIP
import CryptoKit
#if !SKIP
import DeviceCheck
#endif
import Foundation
import OSLog
import Supabase

// MARK: - Attestation Middleware

/// Middleware that adds device attestation headers to sensitive API requests
///
/// This provides an additional layer of security by proving requests originate
/// from a genuine Apple device running the unmodified app.
///
/// Usage:
/// ```swift
/// let middleware = AttestationMiddleware.shared
///
/// // For initial attestation (call once after login)
/// try await middleware.performInitialAttestation()
///
/// // For subsequent requests
/// var request = URLRequest(url: sensitiveEndpoint)
/// try await middleware.addAttestation(to: &request, body: requestBody)
/// ```
@MainActor
final class AttestationMiddleware {
    // MARK: - Singleton

    static let shared = AttestationMiddleware()

    // MARK: - Types

    /// Operations that require attestation
    enum SecureOperation: String, Sendable, CaseIterable {
        case authentication = "auth"
        case profileUpdate = "profile.update"
        case listingCreate = "listing.create"
        case paymentProcess = "payment"
        case accountDelete = "account.delete"
        case sensitiveDataAccess = "data.access"

        /// Whether this operation requires full attestation (vs just assertion)
        var requiresFullAttestation: Bool {
            switch self {
            case .authentication, .paymentProcess, .accountDelete:
                true
            default:
                false
            }
        }
    }

    /// Result of attestation verification from server
    struct AttestationResponse: Codable, Sendable {
        let verified: Bool
        let trustLevel: String
        let message: String?
        let expiresAt: String?
    }

    /// Errors that can occur during attestation
    enum MiddlewareError: Error, LocalizedError {
        case attestationNotSupported
        case attestationNotComplete
        case assertionFailed(Error)
        case serverVerificationFailed(String)
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .attestationNotSupported:
                "Device attestation is not supported on this device"
            case .attestationNotComplete:
                "Device attestation has not been completed"
            case let .assertionFailed(error):
                "Failed to create attestation assertion: \(error.localizedDescription)"
            case let .serverVerificationFailed(reason):
                "Server rejected attestation: \(reason)"
            case let .networkError(error):
                "Network error during attestation: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Properties

    private let logger = Logger(subsystem: Constants.bundleIdentifier, category: "AttestationMiddleware")
    private let appAttestService: AppAttestService
    private let deviceCheckService: DeviceCheckService
    private let keychainStorage = KeychainStorage()

    /// Whether the device has been successfully attested
    private var isAttested = false

    /// When the attestation expires (24 hours by default)
    private var attestationExpiresAt: Date?

    /// Keychain key for storing attestation state
    private static let attestationStateKey = "attestation.state"

    // MARK: - Computed Properties

    /// Whether attestation is available on this device
    var isAttestationAvailable: Bool {
        appAttestService.isSupported || deviceCheckService.isSupported
    }

    /// Whether attestation is required (based on security policy)
    var isAttestationRequired: Bool {
        // In production, you might want to enforce this
        // For now, we gracefully degrade if not supported
        #if DEBUG
            return false // Don't require in debug builds
        #else
            return true
        #endif
    }

    /// Whether we have a valid, non-expired attestation
    var hasValidAttestation: Bool {
        guard isAttested else { return false }
        if let expiresAt = attestationExpiresAt {
            return Date() < expiresAt
        }
        return true
    }

    // MARK: - Initialization

    init(
        appAttestService: AppAttestService = AppAttestService(),
        deviceCheckService: DeviceCheckService = DeviceCheckService(),
    ) {
        self.appAttestService = appAttestService
        self.deviceCheckService = deviceCheckService

        // Restore attestation state from Keychain
        loadAttestationState()
    }

    // MARK: - Initial Attestation

    /// Perform initial device attestation
    ///
    /// Call this once after user authentication to establish device trust.
    /// The attestation is cached and reused for subsequent requests.
    ///
    /// - Parameter supabase: Supabase client for server verification
    /// - Throws: `MiddlewareError` if attestation fails
    func performInitialAttestation(using supabase: Supabase.SupabaseClient) async throws {
        logger.info("Starting initial device attestation")

        // Check if already attested and not expired
        if hasValidAttestation {
            logger.debug("Using existing valid attestation")
            return
        }

        // Try App Attest first (preferred, hardware-backed)
        if appAttestService.isSupported {
            try await performAppAttestation(using: supabase)
            return
        }

        // Fall back to DeviceCheck
        if deviceCheckService.isSupported {
            try await performDeviceCheckAttestation(using: supabase)
            return
        }

        // No attestation method available
        logger.warning("No attestation method available on this device")

        if isAttestationRequired {
            throw MiddlewareError.attestationNotSupported
        }
    }

    /// Perform App Attest attestation flow
    private func performAppAttestation(using supabase: Supabase.SupabaseClient) async throws {
        logger.debug("Performing App Attest attestation")

        // Generate a challenge (in production, get this from your server)
        let challenge = generateChallenge()

        // Create attestation
        let attestation = try await appAttestService.attestKey(challenge: challenge)

        // Send to server for verification
        try await verifyAttestationWithServer(
            type: "app_attest",
            keyId: attestation.keyId,
            attestation: attestation.attestation.base64EncodedString(),
            challenge: challenge.base64EncodedString(),
            using: supabase,
        )

        // Mark as attested
        isAttested = true
        attestationExpiresAt = Date().addingTimeInterval(24 * 60 * 60) // 24 hours
        saveAttestationState()

        logger.info("App Attest attestation completed successfully")
    }

    /// Perform DeviceCheck attestation flow (fallback)
    private func performDeviceCheckAttestation(using supabase: Supabase.SupabaseClient) async throws {
        logger.debug("Performing DeviceCheck attestation (fallback)")

        // Generate DeviceCheck token
        let token = try await deviceCheckService.generateToken()

        // Send to server for verification
        try await verifyAttestationWithServer(
            type: "device_check",
            token: token.base64EncodedString(),
            using: supabase,
        )

        // Mark as attested
        isAttested = true
        attestationExpiresAt = Date().addingTimeInterval(24 * 60 * 60) // 24 hours
        saveAttestationState()

        logger.info("DeviceCheck attestation completed successfully")
    }

    // MARK: - Request Signing

    /// Add attestation assertion to a request
    ///
    /// Call this for sensitive operations to prove request authenticity.
    ///
    /// - Parameters:
    ///   - request: The URLRequest to sign
    ///   - body: Optional request body data
    ///   - operation: The type of operation being performed
    /// - Throws: `MiddlewareError` if assertion fails
    func addAttestation(
        to request: inout URLRequest,
        body: Data?,
        operation: SecureOperation = .sensitiveDataAccess,
    ) async throws {
        // Skip if attestation not available
        guard isAttestationAvailable else {
            logger.debug("Attestation not available, skipping")
            return
        }

        // Check if attestation is valid
        guard hasValidAttestation else {
            if isAttestationRequired, operation.requiresFullAttestation {
                throw MiddlewareError.attestationNotComplete
            }
            logger.warning("Attestation not complete, proceeding without")
            return
        }

        // Generate assertion for this request
        if appAttestService.isSupported, appAttestService.hasValidAttestation {
            try await addAppAttestAssertion(to: &request, body: body, operation: operation)
        }
    }

    /// Add App Attest assertion headers to request
    private func addAppAttestAssertion(
        to request: inout URLRequest,
        body: Data?,
        operation: SecureOperation,
    ) async throws {
        // Create client data (request hash + timestamp + operation)
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? "/"
        let bodyHash = body.map { Data(SHA256.hash(data: $0)).base64EncodedString() } ?? ""

        let clientDataString = "\(method)|\(path)|\(timestamp)|\(operation.rawValue)|\(bodyHash)"
        guard let clientData = clientDataString.data(using: .utf8) else {
            throw MiddlewareError.assertionFailed(NSError(domain: "AttestationMiddleware", code: -1))
        }

        do {
            let assertion = try await appAttestService.generateAssertion(clientData: clientData)

            // Add attestation headers
            request.setValue(assertion.keyId, forHTTPHeaderField: "X-Attest-Key-Id")
            request.setValue(assertion.assertion.base64EncodedString(), forHTTPHeaderField: "X-Attest-Assertion")
            request.setValue(String(timestamp), forHTTPHeaderField: "X-Attest-Timestamp")
            request.setValue(operation.rawValue, forHTTPHeaderField: "X-Attest-Operation")

            logger.debug("Added attestation assertion for \(operation.rawValue)")
        } catch {
            logger.error("Failed to generate assertion: \(error.localizedDescription)")
            throw MiddlewareError.assertionFailed(error)
        }
    }

    // MARK: - Server Verification

    /// Request body for attestation verification
    private struct AttestationRequest: Codable {
        let type: String
        let bundleId: String
        let timestamp: String
        var keyId: String?
        var attestation: String?
        var challenge: String?
        var token: String?
    }

    /// Verify attestation with the backend server
    private func verifyAttestationWithServer(
        type: String,
        keyId: String? = nil,
        attestation: String? = nil,
        challenge: String? = nil,
        token: String? = nil,
        using supabase: Supabase.SupabaseClient,
    ) async throws {
        let body = AttestationRequest(
            type: type,
            bundleId: Constants.bundleIdentifier,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            keyId: keyId,
            attestation: attestation,
            challenge: challenge,
            token: token,
        )

        do {
            let response: AttestationResponse = try await supabase.functions
                .invoke("verify-attestation", options: .init(body: body))

            if !response.verified {
                throw MiddlewareError.serverVerificationFailed(response.message ?? "Unknown error")
            }

            // Update expiration if provided
            if let expiresAtString = response.expiresAt,
               let expiresAt = ISO8601DateFormatter().date(from: expiresAtString) {
                attestationExpiresAt = expiresAt
            }

            logger.info("Server verified attestation (trust level: \(response.trustLevel))")
        } catch let error as MiddlewareError {
            throw error
        } catch {
            logger.error("Server verification failed: \(error.localizedDescription)")
            throw MiddlewareError.networkError(error)
        }
    }

    // MARK: - Helper Methods

    /// Generate a unique challenge for attestation
    private func generateChallenge() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    /// Save attestation state to Keychain
    private func saveAttestationState() {
        let state: [String: Any] = [
            "isAttested": isAttested,
            "expiresAt": attestationExpiresAt?.timeIntervalSince1970 ?? 0
        ]

        if let data = try? JSONSerialization.data(withJSONObject: state) {
            try? keychainStorage.store(key: Self.attestationStateKey, value: data)
        }
    }

    /// Load attestation state from Keychain
    private func loadAttestationState() {
        guard let data = try? keychainStorage.retrieve(key: Self.attestationStateKey),
              let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        isAttested = state["isAttested"] as? Bool ?? false

        if let expiresAtTimestamp = state["expiresAt"] as? TimeInterval, expiresAtTimestamp > 0 {
            let expiresAt = Date(timeIntervalSince1970: expiresAtTimestamp)
            if Date() < expiresAt {
                attestationExpiresAt = expiresAt
            } else {
                // Expired, reset state
                isAttested = false
                attestationExpiresAt = nil
            }
        }
    }

    /// Reset attestation state (useful for logout or testing)
    func reset() {
        isAttested = false
        attestationExpiresAt = nil
        appAttestService.reset()
        try? keychainStorage.delete(key: Self.attestationStateKey)
        logger.info("Attestation state reset")
    }
}

// MARK: - URLRequest Extension

extension URLRequest {
    /// Add attestation to this request for sensitive operations
    ///
    /// Usage:
    /// ```swift
    /// var request = URLRequest(url: url)
    /// request.httpBody = jsonData
    /// try await request.addAttestation(for: .profileUpdate)
    /// ```
    @MainActor
    mutating func addAttestation(
        for operation: AttestationMiddleware.SecureOperation = .sensitiveDataAccess,
    ) async throws {
        try await AttestationMiddleware.shared.addAttestation(
            to: &self,
            body: httpBody,
            operation: operation,
        )
    }
}

#endif
