//
//  MFAService.swift
//  Foodshare
//
//  Multi-Factor Authentication service using Supabase TOTP MFA
//  Provides enrollment, verification, and management of 2FA factors
//
//  MIGRATED: From ObservableObject to @Observable for improved performance
//



#if !SKIP
import Foundation
import Observation
import OSLog
import Supabase

// MARK: - MFA Status

enum MFAStatus: Sendable {
    case unenrolled
    case unverified
    case verified
    case disabled

    var description: String {
        switch self {
        case .unenrolled:
            "Two-factor authentication is not enabled"
        case .unverified:
            "2FA enrollment started but not yet verified"
        case .verified:
            "Two-factor authentication is active"
        case .disabled:
            "2FA has been disabled (session expired)"
        }
    }

    var icon: String {
        switch self {
        case .unenrolled: "shield"
        case .unverified: "shield.lefthalf.filled"
        case .verified: "checkmark.shield.fill"
        case .disabled: "shield.slash"
        }
    }

    var iconColor: String {
        switch self {
        case .unenrolled: "textSecondary"
        case .unverified: "warning"
        case .verified: "brandGreen"
        case .disabled: "error"
        }
    }
}

// MARK: - MFA Error

enum MFAError: LocalizedError, Sendable {
    case enrollmentFailed(String)
    case verificationFailed(String)
    case challengeFailed(String)
    case unenrollFailed(String)
    case noFactorFound
    case invalidCode
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case let .enrollmentFailed(message):
            "Failed to enroll MFA: \(message)"
        case let .verificationFailed(message):
            "Verification failed: \(message)"
        case let .challengeFailed(message):
            "Challenge failed: \(message)"
        case let .unenrollFailed(message):
            "Failed to remove MFA: \(message)"
        case .noFactorFound:
            "No MFA factor found"
        case .invalidCode:
            "Invalid verification code"
        case .sessionExpired:
            "Your session has expired. Please sign in again."
        }
    }
}

// MARK: - MFA Factor Info

struct MFAFactorInfo: Identifiable, Sendable {
    let id: String
    let factorType: String
    let friendlyName: String?
    let status: FactorStatus
    let createdAt: Date?

    enum FactorStatus: String, Sendable {
        case unverified
        case verified
    }
}

// MARK: - MFA Enrollment Result

struct MFAEnrollmentResult: Sendable {
    let factorId: String
    let qrCode: String
    let secret: String
    let uri: String
}

// MARK: - MFA Service

@MainActor
@Observable
final class MFAService {
    static let shared = MFAService()

    // MARK: - Observable State

    private(set) var status: MFAStatus = .unenrolled
    private(set) var factors: [MFAFactorInfo] = []
    private(set) var isLoading = false
    private(set) var currentEnrollment: MFAEnrollmentResult?

    // MARK: - Dependencies

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "MFAService")
    private var supabase: Supabase.SupabaseClient { AuthenticationService.shared.supabase }

    private init() {}

    // MARK: - Status Check

    /// Check the current MFA status for the authenticated user
    func checkStatus() async {
        logger.info("Checking MFA status...")
        isLoading = true
        defer { isLoading = false }

        do {
            let aalResponse = try await supabase.auth.mfa.getAuthenticatorAssuranceLevel()
            let factorsResponse = try await supabase.auth.mfa.listFactors()

            factors = factorsResponse.all.map { factor in
                MFAFactorInfo(
                    id: factor.id,
                    factorType: factor.factorType,
                    friendlyName: factor.friendlyName,
                    status: factor.status.rawValue == "verified" ? MFAFactorInfo.FactorStatus.verified : MFAFactorInfo.FactorStatus.unverified,
                    createdAt: factor.createdAt,
                )
            }

            // Determine status based on AAL and factors
            if factorsResponse.totp.isEmpty, factorsResponse.phone.isEmpty {
                status = .unenrolled
            } else if aalResponse.currentLevel == "aal2" {
                status = .verified
            } else if aalResponse.nextLevel == "aal2" {
                // Has verified factors but current session is aal1
                status = .unverified
            } else {
                status = .unenrolled
            }

            logger.info("MFA status: \(String(describing: self.status)), factors: \(self.factors.count)")
        } catch {
            logger.error("Failed to check MFA status: \(error.localizedDescription)")
            status = .unenrolled
            factors = []
        }
    }

    // MARK: - Enrollment

    /// Start MFA enrollment process
    /// Returns QR code and secret for TOTP setup
    func enroll() async throws -> MFAEnrollmentResult {
        logger.info("Starting MFA enrollment...")
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await supabase.auth.mfa.enroll(params: MFAEnrollParams.totp())

            guard let totp = response.totp else {
                throw MFAError.enrollmentFailed("No TOTP data returned")
            }

            let result = MFAEnrollmentResult(
                factorId: response.id,
                qrCode: totp.qrCode,
                secret: totp.secret,
                uri: totp.uri,
            )

            currentEnrollment = result
            logger.info("MFA enrollment started successfully")
            return result
        } catch {
            logger.error("MFA enrollment failed: \(error.localizedDescription)")
            throw MFAError.enrollmentFailed(error.localizedDescription)
        }
    }

    // MARK: - Verification

    /// Verify MFA enrollment with TOTP code from authenticator app
    func verify(factorId: String, code: String) async throws {
        logger.info("Verifying MFA factor: \(factorId)")
        isLoading = true
        defer { isLoading = false }

        guard code.count == 6, code.allSatisfy({ $0 >= "0" && $0 <= "9" }) else {
            throw MFAError.invalidCode
        }

        do {
            try await supabase.auth.mfa.challengeAndVerify(
                params: MFAChallengeAndVerifyParams(factorId: factorId, code: code),
            )

            currentEnrollment = nil
            await checkStatus()
            HapticManager.success()
            logger.info("MFA verification successful")
        } catch {
            HapticManager.error()
            logger.error("MFA verification failed: \(error.localizedDescription)")
            throw MFAError.verificationFailed(error.localizedDescription)
        }
    }

    // MARK: - Challenge (for login)

    /// Challenge and verify during login flow
    func challengeAndVerify(code: String) async throws {
        logger.info("Challenging MFA during login...")
        isLoading = true
        defer { isLoading = false }

        guard code.count == 6, code.allSatisfy({ $0 >= "0" && $0 <= "9" }) else {
            throw MFAError.invalidCode
        }

        do {
            let factors = try await supabase.auth.mfa.listFactors()

            guard let totpFactor = factors.totp.first else {
                throw MFAError.noFactorFound
            }

            try await supabase.auth.mfa.challengeAndVerify(
                params: MFAChallengeAndVerifyParams(factorId: totpFactor.id, code: code),
            )

            await checkStatus()
            HapticManager.success()
            logger.info("MFA challenge successful")
        } catch {
            HapticManager.error()
            logger.error("MFA challenge failed: \(error.localizedDescription)")
            throw MFAError.challengeFailed(error.localizedDescription)
        }
    }

    // MARK: - Unenroll

    /// Remove MFA factor
    func unenroll(factorId: String) async throws {
        logger.info("Removing MFA factor: \(factorId)")
        isLoading = true
        defer { isLoading = false }

        do {
            try await supabase.auth.mfa.unenroll(params: MFAUnenrollParams(factorId: factorId))
            await checkStatus()
            HapticManager.light()
            logger.info("MFA factor removed successfully")
        } catch {
            HapticManager.error()
            logger.error("Failed to remove MFA factor: \(error.localizedDescription)")
            throw MFAError.unenrollFailed(error.localizedDescription)
        }
    }

    // MARK: - Cancel Enrollment

    /// Cancel ongoing enrollment without completing verification
    func cancelEnrollment() {
        if let enrollment = currentEnrollment {
            Task {
                try? await supabase.auth.mfa.unenroll(params: MFAUnenrollParams(factorId: enrollment.factorId))
            }
        }
        currentEnrollment = nil
    }
}


#endif
