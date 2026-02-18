//
//  DeviceCheckService.swift
//  Foodshare
//
//  Enterprise DeviceCheck integration for device reputation tracking
//
//  DeviceCheck allows tracking device reputation across app installs:
//  - Detect devices that have been flagged for abuse
//  - Prevent trial abuse or promotional fraud
//  - Track device trust level over time
//


#if !SKIP
import DeviceCheck
import Foundation
import OSLog
import UIKit

// MARK: - Device Check Service

/// Enterprise-grade device reputation tracking using Apple's DeviceCheck API
///
/// Unlike App Attest, DeviceCheck persists across app installs and allows you to:
/// - Track whether a device has been flagged for abuse
/// - Prevent promotional fraud (e.g., one-time offers being redeemed multiple times)
/// - Maintain device trust scores
///
/// Usage:
/// ```swift
/// let deviceCheck = DeviceCheckService()
///
/// // Generate token for server validation
/// if await deviceCheck.isSupported {
///     let token = try await deviceCheck.generateToken()
///     // Send to backend to check/update device bits
/// }
/// ```
@MainActor
final class DeviceCheckService {
    // MARK: - Types

    /// Errors that can occur during device check operations
    enum DeviceCheckError: Error, LocalizedError {
        case notSupported
        case tokenGenerationFailed(Error)
        case serverError(String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .notSupported:
                "DeviceCheck is not supported on this device"
            case let .tokenGenerationFailed(error):
                "Failed to generate device token: \(error.localizedDescription)"
            case let .serverError(message):
                "Server error: \(message)"
            case .invalidResponse:
                "Invalid response from server"
            }
        }
    }

    /// Device trust level based on server-side bit tracking
    enum TrustLevel: String, Sendable, Codable {
        case unknown // No data on this device
        case trusted // Device has good history
        case suspicious // Some concerning behavior
        case blocked // Device is blocked
    }

    /// Result from device verification
    struct VerificationResult: Sendable {
        let trustLevel: TrustLevel
        let lastVerified: Date
        let deviceId: String // Anonymized device identifier
    }

    // MARK: - Properties

    private let device: DCDevice
    private let logger = Logger(subsystem: Constants.bundleIdentifier, category: "DeviceCheck")

    /// Cached verification result
    private var cachedResult: VerificationResult?
    private var lastTokenGenerationDate: Date?

    // MARK: - Computed Properties

    /// Whether DeviceCheck is supported on this device
    var isSupported: Bool {
        device.isSupported
    }

    // MARK: - Initialization

    init(device: DCDevice = .current) {
        self.device = device
    }

    // MARK: - Token Generation

    /// Generate a DeviceCheck token for server verification
    ///
    /// The token is ephemeral and should be sent to your server immediately.
    /// Your server can then use Apple's DeviceCheck API to:
    /// - Query the device's bit state
    /// - Update the device's bit state
    ///
    /// - Returns: Base64-encoded device token
    /// - Throws: `DeviceCheckError` if token generation fails
    func generateToken() async throws -> Data {
        guard isSupported else {
            logger.warning("DeviceCheck not supported on this device")
            throw DeviceCheckError.notSupported
        }

        do {
            let token = try await device.generateToken()
            lastTokenGenerationDate = Date()
            logger.info("Generated DeviceCheck token (\(token.count) bytes)")
            return token
        } catch {
            logger.error("Token generation failed: \(error.localizedDescription)")
            throw DeviceCheckError.tokenGenerationFailed(error)
        }
    }

    // MARK: - Verification Flow

    /// Verify device with server and get trust level
    ///
    /// This sends the device token to your server which then:
    /// 1. Calls Apple's DeviceCheck API
    /// 2. Checks/updates the device bits
    /// 3. Returns the trust level
    ///
    /// - Parameter verifier: Async closure that sends token to server and returns trust level
    /// - Returns: VerificationResult with trust level and metadata
    func verifyDevice(
        verifier: (Data) async throws -> TrustLevel,
    ) async throws -> VerificationResult {
        let token = try await generateToken()
        let trustLevel = try await verifier(token)

        let result = VerificationResult(
            trustLevel: trustLevel,
            lastVerified: Date(),
            deviceId: generateAnonymousDeviceId(),
        )

        cachedResult = result

        switch trustLevel {
        case .trusted:
            logger.info("Device verified as trusted")
        case .suspicious:
            logger.warning("Device flagged as suspicious")
        case .blocked:
            logger.error("Device is blocked")
        case .unknown:
            logger.debug("No prior data for this device")
        }

        return result
    }

    // MARK: - Convenience Methods

    /// Check if device should be allowed to proceed
    ///
    /// Uses cached result if available and recent enough
    ///
    /// - Parameter maxAge: Maximum age of cached result (default 1 hour)
    /// - Returns: Whether device should be allowed
    func isDeviceAllowed(maxAge: TimeInterval = 3600) -> Bool {
        guard let result = cachedResult else { return true } // Allow if no data
        guard Date().timeIntervalSince(result.lastVerified) <= maxAge else { return true }

        return result.trustLevel != .blocked
    }

    /// Get the current trust level if available
    var currentTrustLevel: TrustLevel? {
        cachedResult?.trustLevel
    }

    // MARK: - Private Helpers

    /// Generate an anonymous device identifier for logging
    private func generateAnonymousDeviceId() -> String {
        // Create a stable but anonymized identifier
        let vendorId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let hash = vendorId.data(using: .utf8)?.base64EncodedString() ?? "unknown"
        return String(hash.prefix(8))
    }

    // MARK: - State Management

    /// Clear cached verification result
    func clearCache() {
        cachedResult = nil
        lastTokenGenerationDate = nil
        logger.info("DeviceCheck cache cleared")
    }
}

// MARK: - Device Token Request

/// Request structure for sending device token to verification endpoint
struct DeviceTokenRequest: Codable, Sendable {
    let token: String // Base64-encoded device token
    let timestamp: Date
    let bundleId: String

    init(token: Data) {
        self.token = token.base64EncodedString()
        self.timestamp = Date()
        self.bundleId = Bundle.main.bundleIdentifier ?? ""
    }
}

/// Response structure from verification endpoint
struct DeviceVerificationResponse: Codable, Sendable {
    let trustLevel: DeviceCheckService.TrustLevel
    let message: String?
    let expiresAt: Date?
}

// MARK: - Integration Helper

extension DeviceCheckService {
    /// Perform full verification flow with Supabase Edge Function
    ///
    /// This is a convenience method that:
    /// 1. Generates a device token
    /// 2. Sends it to the verify-device-check Edge Function
    /// 3. Returns the trust level
    ///
    /// - Parameter client: Supabase client for calling Edge Function
    /// - Returns: Verification result
    func verifyWithSupabase(using urlSession: URLSession = .shared) async throws -> VerificationResult {
        let token = try await generateToken()

        // Construct request to Edge Function
        guard let projectUrl = AppEnvironment.supabaseURL,
              let functionUrl = URL(string: "\(projectUrl)/functions/v1/verify-device-check") else {
            throw DeviceCheckError.serverError("Invalid Supabase URL configuration")
        }

        var request = URLRequest(url: functionUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let anonKey = AppEnvironment.supabasePublishableKey {
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        }

        let body = DeviceTokenRequest(token: token)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode) else {
            throw DeviceCheckError.serverError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        let verificationResponse = try JSONDecoder().decode(DeviceVerificationResponse.self, from: data)

        let result = VerificationResult(
            trustLevel: verificationResponse.trustLevel,
            lastVerified: Date(),
            deviceId: generateAnonymousDeviceId(),
        )

        cachedResult = result
        return result
    }
}

// MARK: - Mock for Testing

#if DEBUG
    /// Mock DeviceCheck service for unit testing
    final class MockDeviceCheckService: @unchecked Sendable {
        var shouldSucceed = true
        var mockToken = Data([0x01, 0x02, 0x03, 0x04])
        var mockTrustLevel: DeviceCheckService.TrustLevel = .trusted

        var isSupported: Bool { true }

        func generateToken() async throws -> Data {
            guard shouldSucceed else {
                throw DeviceCheckService.DeviceCheckError.tokenGenerationFailed(NSError(domain: "mock", code: -1))
            }
            return mockToken
        }

        func verifyDevice(
            verifier: (Data) async throws -> DeviceCheckService.TrustLevel,
        ) async throws -> DeviceCheckService.VerificationResult {
            DeviceCheckService.VerificationResult(
                trustLevel: mockTrustLevel,
                lastVerified: Date(),
                deviceId: "mock-device",
            )
        }
    }
#endif

#endif
