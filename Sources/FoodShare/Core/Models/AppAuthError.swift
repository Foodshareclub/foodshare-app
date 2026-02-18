//
//  AppAuthError.swift
//  Foodshare
//
//  Comprehensive error types for authentication operations.
//  Named AppAuthError to avoid conflicts with Supabase's AuthError.
//


import Foundation

// MARK: - App Auth Error

/// Comprehensive error types for authentication operations
///
/// Named `AppAuthError` to avoid conflicts with Supabase's `AuthError`.
/// Provides user-friendly error messages and recovery suggestions.
public enum AppAuthError: Error, LocalizedError, Equatable, Sendable {
    // Input validation
    case invalidEmail
    case weakPassword
    case passwordMismatch
    case missingCredentials

    // Authentication failures
    case invalidCredentials
    case userNotFound
    case emailNotConfirmed
    case sessionExpired
    case mfaRequired
    case mfaFailed(reason: String)

    // Account issues
    case emailAlreadyInUse
    case accountDisabled
    case accountLocked(until: Date?)

    // OAuth/SSO
    case appleSignInFailed(reason: String)
    case googleSignInFailed(reason: String)
    case oauthFailed(provider: String, reason: String)
    case oauthCancelled

    // Network/Server
    case networkError(reason: String)
    case serverError(statusCode: Int, errorMessage: String?)
    case rateLimited(retryAfter: TimeInterval)
    case serviceUnavailable

    // Token/Session
    case tokenExpired
    case tokenInvalid
    case refreshFailed(reason: String)

    /// Generic
    case unknown(reason: String)

    public var errorDescription: String? {
        switch self {
        case .invalidEmail:
            "Please enter a valid email address"
        case .weakPassword:
            "Password must be at least 8 characters with a mix of letters and numbers"
        case .passwordMismatch:
            "Passwords don't match"
        case .missingCredentials:
            "Please enter both email and password"
        case .invalidCredentials:
            "Invalid email or password. Please try again"
        case .userNotFound:
            "No account found with this email. Sign up to create one"
        case .emailNotConfirmed:
            "Please verify your email. Check your inbox for a confirmation link"
        case .sessionExpired:
            "Your session has expired. Please sign in again"
        case .mfaRequired:
            "Two-factor authentication is required"
        case let .mfaFailed(reason):
            "Two-factor authentication failed: \(reason)"
        case .emailAlreadyInUse:
            "An account already exists with this email. Try signing in"
        case .accountDisabled:
            "This account has been disabled. Contact support for assistance"
        case let .accountLocked(until):
            if let until {
                #if !SKIP
                "Account locked until \(until.formatted(date: Date.FormatStyle.DateStyle.abbreviated, time: Date.FormatStyle.TimeStyle.shortened))"
                #else
                "Account has been temporarily locked. Please try again later"
                #endif
            } else {
                "Account has been temporarily locked. Please try again later"
            }
        case let .appleSignInFailed(reason):
            "Apple Sign In failed: \(reason)"
        case let .googleSignInFailed(reason):
            "Google Sign In failed: \(reason)"
        case let .oauthFailed(provider, reason):
            "\(provider) sign in failed: \(reason)"
        case .oauthCancelled:
            "Sign in was cancelled"
        case let .networkError(reason):
            "Connection issue: \(reason)"
        case let .serverError(code, errorMessage):
            if let errorMessage { "Server error (\(code)): \(errorMessage)" }
            else { "Server error (\(code)). Please try again later" }
        case let .rateLimited(retryAfter):
            "Too many attempts. Please wait \(Int(retryAfter)) seconds"
        case .serviceUnavailable:
            "Authentication service is temporarily unavailable"
        case .tokenExpired:
            "Your session token has expired"
        case .tokenInvalid:
            "Invalid session token"
        case let .refreshFailed(reason):
            "Failed to refresh session: \(reason)"
        case let .unknown(reason):
            reason
        }
    }

    /// User-friendly message for UI display
    public var userFriendlyMessage: String {
        switch self {
        case .invalidEmail, .weakPassword, .passwordMismatch, .missingCredentials:
            "Please check your input and try again."
        case .invalidCredentials, .userNotFound:
            "Unable to sign in. Please check your credentials."
        case .emailNotConfirmed:
            "Please verify your email before signing in."
        case .sessionExpired, .tokenExpired, .tokenInvalid:
            "Please sign in again to continue."
        case .mfaRequired:
            "Additional verification is required."
        case .mfaFailed:
            "Verification failed. Please try again."
        case .emailAlreadyInUse:
            "This email is already registered."
        case .accountDisabled, .accountLocked:
            "Your account is currently unavailable."
        case .appleSignInFailed, .googleSignInFailed, .oauthFailed:
            "Sign in with this provider failed. Please try again."
        case .oauthCancelled:
            "Sign in was cancelled."
        case .networkError:
            "Please check your internet connection."
        case .serverError, .serviceUnavailable:
            "Service temporarily unavailable. Please try again."
        case .rateLimited:
            "Too many attempts. Please wait before trying again."
        case .refreshFailed:
            "Session refresh failed. Please sign in again."
        case .unknown:
            "An unexpected error occurred. Please try again."
        }
    }

    #if !SKIP
    /// Localized user-friendly message for UI display
    @MainActor
    public func localizedUserFriendlyMessage(using t: EnhancedTranslationService) -> String {
        switch self {
        case .invalidEmail, .weakPassword, .passwordMismatch, .missingCredentials:
            t.t("errors.auth.check_input")
        case .invalidCredentials, .userNotFound:
            t.t("errors.auth.invalid_credentials")
        case .emailNotConfirmed:
            t.t("errors.auth.email_not_confirmed")
        case .sessionExpired, .tokenExpired, .tokenInvalid:
            t.t("errors.auth.session_expired")
        case .mfaRequired:
            t.t("errors.auth.mfa_required")
        case .mfaFailed:
            t.t("errors.auth.mfa_failed")
        case .emailAlreadyInUse:
            t.t("errors.auth.email_in_use")
        case .accountDisabled, .accountLocked:
            t.t("errors.auth.account_unavailable")
        case .appleSignInFailed, .googleSignInFailed, .oauthFailed:
            t.t("errors.auth.oauth_failed")
        case .oauthCancelled:
            t.t("errors.auth.oauth_cancelled")
        case .networkError:
            t.t("errors.auth.network_error")
        case .serverError, .serviceUnavailable:
            t.t("errors.auth.service_unavailable")
        case .rateLimited:
            t.t("errors.auth.rate_limited")
        case .refreshFailed:
            t.t("errors.auth.refresh_failed")
        case .unknown:
            t.t("errors.auth.unknown")
        }
    }
    #endif

    /// Icon to display in UI for this error
    public var iconName: String {
        switch self {
        case .invalidEmail, .emailAlreadyInUse, .emailNotConfirmed:
            "envelope.badge.fill"
        case .weakPassword, .passwordMismatch, .invalidCredentials, .missingCredentials:
            "lock.trianglebadge.exclamationmark.fill"
        case .userNotFound:
            "person.crop.circle.badge.questionmark"
        case .sessionExpired, .tokenExpired, .tokenInvalid:
            "clock.badge.exclamationmark.fill"
        case .mfaRequired, .mfaFailed:
            "lock.shield.fill"
        case .accountDisabled, .accountLocked:
            "person.crop.circle.badge.xmark"
        case .appleSignInFailed:
            "apple.logo"
        case .googleSignInFailed:
            "g.circle.fill"
        case .oauthFailed, .oauthCancelled:
            "person.crop.circle.badge.xmark"
        case .networkError:
            "wifi.exclamationmark"
        case .serverError, .serviceUnavailable:
            "server.rack"
        case .rateLimited:
            "clock.arrow.circlepath"
        case .refreshFailed:
            "arrow.clockwise.circle"
        case .unknown:
            "exclamationmark.triangle.fill"
        }
    }

    /// Recovery suggestion for the user
    public var recoverySuggestion: String? {
        switch self {
        case .emailNotConfirmed:
            "Didn't receive the email? Tap 'Resend' to get a new link"
        case .invalidCredentials:
            "Forgot your password? Tap 'Forgot Password' to reset it"
        case .networkError:
            "Check your internet connection and try again"
        case .serverError, .serviceUnavailable:
            "Our servers are experiencing issues. Please try again in a few minutes"
        case .accountLocked:
            "Wait for the lockout period to end, or contact support"
        case .mfaFailed:
            "Make sure you're using the correct verification code"
        case .oauthCancelled:
            "Tap the sign-in button to try again"
        default:
            nil
        }
    }

    #if !SKIP
    /// Localized recovery suggestion for the user
    @MainActor
    public func localizedRecoverySuggestion(using t: EnhancedTranslationService) -> String? {
        switch self {
        case .emailNotConfirmed:
            t.t("errors.auth.recovery.email_not_confirmed")
        case .invalidCredentials:
            t.t("errors.auth.recovery.invalid_credentials")
        case .networkError:
            t.t("errors.auth.recovery.network_error")
        case .serverError, .serviceUnavailable:
            t.t("errors.auth.recovery.server_error")
        case .accountLocked:
            t.t("errors.auth.recovery.account_locked")
        case .mfaFailed:
            t.t("errors.auth.recovery.mfa_failed")
        case .oauthCancelled:
            t.t("errors.auth.recovery.oauth_cancelled")
        default:
            nil
        }
    }
    #endif

    /// Whether this error is recoverable through retry
    public var isRetryable: Bool {
        switch self {
        case .networkError, .serverError, .serviceUnavailable, .refreshFailed:
            true
        case let .rateLimited(retryAfter):
            retryAfter < 60
        default:
            false
        }
    }

    // MARK: - Equatable

    public static func == (lhs: AppAuthError, rhs: AppAuthError) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }
}

// MARK: - Factory Methods

extension AppAuthError {
    /// Create AppAuthError from Supabase AuthError
    public static func from(supabaseError error: Error) -> AppAuthError {
        let errorString = error.localizedDescription.lowercased()
        let debugString = "\(error)".lowercased()

        // PKCE flow errors
        if errorString.contains("code verifier") || debugString.contains("code_verifier") {
            return .oauthFailed(
                provider: "OAuth",
                reason: "Authentication flow interrupted. Please try again."
            )
        }
        if errorString.contains("pkce") || debugString.contains("code_challenge") {
            return .oauthFailed(
                provider: "OAuth",
                reason: "Security verification failed. Please try again."
            )
        }

        // Check for common Supabase auth error patterns
        if errorString.contains("email not confirmed") || debugString.contains("email_not_confirmed") {
            return .emailNotConfirmed
        }
        if errorString.contains("invalid login credentials") || debugString.contains("invalid_credentials") {
            return .invalidCredentials
        }
        if errorString.contains("user not found") || debugString.contains("user_not_found") {
            return .userNotFound
        }
        if errorString.contains("email already") || debugString.contains("email_exists") ||
            debugString.contains("user_already_exists")
        {
            return .emailAlreadyInUse
        }
        if errorString.contains("session") && errorString.contains("expired") {
            return .sessionExpired
        }
        if errorString.contains("network") || errorString.contains("connection") ||
            errorString.contains("offline")
        {
            return .networkError(reason: error.localizedDescription)
        }
        if errorString.contains("rate limit") || debugString.contains("too_many_requests") {
            return .rateLimited(retryAfter: 30)
        }
        if errorString.contains("mfa") || debugString.contains("mfa_required") {
            return .mfaRequired
        }
        if errorString.contains("disabled") || debugString.contains("user_banned") {
            return .accountDisabled
        }

        return .unknown(reason: error.localizedDescription)
    }
}
