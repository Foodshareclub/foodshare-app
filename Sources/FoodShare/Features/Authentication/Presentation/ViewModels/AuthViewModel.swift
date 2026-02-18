//
//  AuthViewModel.swift
//  Foodshare
//
//  Authentication ViewModel using modern Swift 6.2 @Observable pattern
//  Enhanced with comprehensive error handling and user-friendly feedback
//  Migrated from ObservableObject for improved performance and type safety
//



#if !SKIP
import AuthenticationServices
import Foundation
import Observation
import OSLog
import Supabase

// MARK: - Type Alias for Backward Compatibility

/// Use AppAuthError from LayerErrors for comprehensive authentication error handling
/// This type alias maintains API compatibility while using the centralized error system
typealias AuthenticationError = AppAuthError

// MARK: - Auth ViewModel (Modern @Observable Pattern)

@MainActor
@Observable
final class AuthViewModel {
    // MARK: - Observable Properties

    var email = ""
    var password = ""
    var user: User?
    var errorMessage: String?
    var authError: AuthenticationError?
    var isLoading = false
    var showEmailVerificationPrompt = false

    // MARK: - Dependencies

    let supabase: SupabaseClient
    var client: SupabaseClient {
        supabase
    }

    /// Delegate to AuthenticationService for proper session management
    private let authService = AuthenticationService.shared

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "AuthViewModel")

    // MARK: - Initialization

    init(supabase: Supabase.SupabaseClient) {
        self.supabase = supabase
        Task { await listenForSession() }
    }

    // MARK: - Error Handling

    /// Parses Supabase errors into user-friendly AppAuthError types using centralized factory
    private func parseError(_ error: Error) -> AppAuthError {
        // If already an AppAuthError, return as-is
        if let authError = error as? AppAuthError {
            return authError
        }

        // Check for network errors first
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return .networkError(reason: "No internet connection")
            case .timedOut:
                return .networkError(reason: "Request timed out")
            case .networkConnectionLost:
                return .networkError(reason: "Connection lost")
            case .cannotConnectToHost:
                return .networkError(reason: "Cannot reach server")
            default:
                return .networkError(reason: urlError.localizedDescription)
            }
        }

        // Use centralized factory for Supabase errors
        return AppAuthError.from(supabaseError: error)
    }

    /// Sets the current error state with both typed error and message
    private func setError(_ error: AuthenticationError) {
        authError = error
        errorMessage = error.errorDescription
        logger.warning("[AUTH] Error: \(error.errorDescription ?? "Unknown error")")
    }

    /// Clears all error state
    func clearError() {
        authError = nil
        errorMessage = nil
    }

    // MARK: - Email Sign Up

    @MainActor
    func signUpEmail() async {
        // Clear previous errors
        clearError()
        isLoading = true

        // Validate email format
        guard isValidEmail(email) else {
            setError(.invalidEmail)
            HapticManager.error()
            isLoading = false
            return
        }

        // Validate password strength
        guard isValidPassword(password) else {
            setError(.weakPassword)
            HapticManager.error()
            isLoading = false
            return
        }

        do {
            logger.info("[AUTH] Delegating email sign up to AuthenticationService")

            // Delegate to AuthenticationService for proper session and profile management
            try await authService.signUp(email: email, password: password, name: nil)

            clearError()

            // Show email verification prompt if email confirmation is required
            if !authService.isEmailVerified {
                showEmailVerificationPrompt = true
                logger.info("[AUTH] Sign up successful, email verification required")
            } else {
                logger.info("[AUTH] Sign up successful, email already confirmed")
            }

            isLoading = false
            HapticManager.success()
        } catch {
            isLoading = false
            let parsedError = parseError(error)
            setError(parsedError)
            logger.error("[AUTH] Sign up failed: \(error.localizedDescription)")
            HapticManager.error()
        }
    }

    // MARK: - Email Sign In

    @MainActor
    func signInEmail() async {
        // Clear previous errors
        clearError()
        isLoading = true

        // Validate email format
        guard isValidEmail(email) else {
            setError(.invalidEmail)
            HapticManager.error()
            isLoading = false
            return
        }

        // Basic password validation
        guard !password.isEmpty else {
            setError(.invalidCredentials)
            HapticManager.error()
            isLoading = false
            return
        }

        do {
            logger.info("[AUTH] Delegating email sign in to AuthenticationService")

            // Delegate to AuthenticationService for proper session propagation
            try await authService.signIn(email: email, password: password)

            clearError()
            isLoading = false

            logger.info("[AUTH] Sign in successful via AuthenticationService")
            HapticManager.success()
        } catch {
            isLoading = false
            let parsedError = parseError(error)
            setError(parsedError)

            // Show email verification prompt if that's the specific error
            if case .emailNotConfirmed = parsedError {
                showEmailVerificationPrompt = true
            }

            logger.error("[AUTH] Sign in failed: \(error.localizedDescription)")
            HapticManager.error()
        }
    }

    // MARK: - Validation Helpers

    /// Validates email format using a simple regex pattern
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: String.CompareOptions.regularExpression) != nil
    }

    /// Validates password meets minimum requirements
    private func isValidPassword(_ password: String) -> Bool {
        // At least 8 characters
        guard password.count >= 8 else { return false }
        // Contains at least one letter and one number
        let hasLetter = password.range(of: "[A-Za-z]", options: String.CompareOptions.regularExpression) != nil
        let hasNumber = password.range(of: "[0-9]", options: String.CompareOptions.regularExpression) != nil
        return hasLetter && hasNumber
    }

    // MARK: - Sign Out

    @MainActor
    func signOut() async {
        clearError()
        isLoading = true

        logger.info("[AUTH] Delegating sign out to AuthenticationService")

        // Delegate to AuthenticationService for proper session cleanup
        await authService.signOut()

        // Clear local form state
        user = nil
        email = ""
        password = ""
        isLoading = false

        HapticManager.light()
        logger.info("[AUTH] Sign out successful via AuthenticationService")
    }

    // MARK: - Delete Account

    @MainActor
    func deleteAccount() async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
            logger.debug("[AUTH] Delete account operation completed")
        }

        guard user != nil else {
            errorMessage = "No user logged in"
            logger.warning("[AUTH] Delete failed: No user logged in")
            return
        }

        do {
            logger.info("[AUTH] Starting account deletion")

            // Get current session for authentication
            let session = try await supabase.auth.session
            logger.debug("[AUTH] Got session for deletion")

            // Call Supabase Edge Function for secure deletion
            let supabaseURL = ProcessInfo.processInfo.environment["SUPABASE_URL"]
                ?? "https://api.foodshare.club"

            guard let url = URL(string: "\(supabaseURL)/functions/v1/delete-account") else {
                errorMessage = "Invalid API URL"
                logger.error("[AUTH] Failed to create delete-account URL")
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 15

            logger.debug("[AUTH] Sending delete request to Edge Function")

            // Execute deletion request
            let (data, response) = try await URLSession.shared.data(for: request)

            logger.debug("[AUTH] Received response from Edge Function")

            // Validate response
            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid server response"
                logger.error("[AUTH] Invalid HTTP response type")
                return
            }

            logger.debug("[AUTH] Response status code: \(httpResponse.statusCode)")

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
                logger.error("[AUTH] Server error: \(httpResponse.statusCode) - \(responseBody, privacy: .private)")

                switch httpResponse.statusCode {
                case 401:
                    errorMessage = "Session expired. Please sign in again."
                case 403:
                    errorMessage = "You don't have permission to delete this account."
                case 500 ... 599:
                    errorMessage = "Server error. Please try again later."
                default:
                    errorMessage = "Failed to delete account (Error \(httpResponse.statusCode))"
                }
                return
            }

            logger.info("[AUTH] Account deleted successfully, signing out")

            // Sign out after successful deletion
            try await supabase.auth.signOut()
            user = nil
            errorMessage = nil
            HapticManager.success()

            logger.info("[AUTH] Account deletion complete")
        } catch let error as URLError {
            // Handle network-specific errors
            logger.error("[AUTH] Network error during deletion: \(error.localizedDescription)")
            switch error.code {
            case .timedOut:
                errorMessage = "Request timed out. Please check your connection and try again."
            case .notConnectedToInternet:
                errorMessage = "No internet connection. Please connect and try again."
            case .networkConnectionLost:
                errorMessage = "Connection lost. Please try again."
            default:
                errorMessage = "Network error: \(error.localizedDescription)"
            }
            HapticManager.error()
        } catch {
            logger.error("[AUTH] Unexpected error during deletion: \(error.localizedDescription)")
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
            HapticManager.error()
        }
    }

    #if !SKIP
    // MARK: - OAuth (Deprecated - Use AuthenticationService methods instead)

    /// Legacy OAuth method - Deprecated in favor of AuthenticationService.signInWithGoogle()
    /// This method is kept for backward compatibility but should not be used for new implementations
    @available(*, deprecated, message: "Use AuthenticationService.shared.signInWithGoogle() instead")
    func signInWithOAuth(provider: Provider) {
        Task { @MainActor in
            isLoading = true

            // Delegate to AuthenticationService for consistent OAuth handling
            do {
                switch provider {
                case .google:
                    try await AuthenticationService.shared.signInWithGoogle()
                case .apple:
                    // Apple Sign In uses native flow, not OAuth
                    throw AuthenticationError.oauthFailed(
                        provider: "Apple",
                        reason: "Use signInWithApple() for Apple authentication",
                    )
                default:
                    throw AuthenticationError.oauthFailed(
                        provider: provider.rawValue,
                        reason: "Provider not supported",
                    )
                }

                clearError()
                isLoading = false
                HapticManager.success()
            } catch {
                isLoading = false

                // Check if user cancelled
                if let authError = error as? ASWebAuthenticationSessionError,
                   authError.code == .canceledLogin
                {
                    logger.info("[AUTH] OAuth cancelled by user")
                    return
                }

                let parsedError = parseError(error)
                setError(parsedError)
                logger.error("[AUTH] OAuth failed: \(error.localizedDescription)")
                HapticManager.error()
            }
        }
    }

    // MARK: - Native Apple Sign In

    @MainActor
    func signInWithApple() async {
        isLoading = true
        errorMessage = nil

        do {
            logger.info("[AUTH] Delegating Apple Sign In to AuthenticationService")

            // Get the presentation anchor for Apple Sign In
            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
                let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first else
            {
                throw AuthenticationError.appleSignInFailed(reason: "No window available for presentation")
            }

            // Delegate to AuthenticationService which has proper continuation handling
            try await authService.signInWithApple(presentationAnchor: window)

            clearError()
            isLoading = false
            logger.info("[AUTH] Apple Sign In successful via AuthenticationService")
            HapticManager.success()
        } catch {
            isLoading = false

            // Debug logging
            logger.info("[AUTH] Apple Sign In error type: \(type(of: error))")
            logger.info("[AUTH] Apple Sign In error: \(error)")

            // Check if user cancelled - handle silently
            if let appError = error as? AppAuthError {
                logger.info("[AUTH] Error is AppAuthError: \(appError)")
                if appError == .oauthCancelled {
                    logger.info("[AUTH] Apple Sign In cancelled by user (AppAuthError.oauthCancelled)")
                    clearError() // Clear any previous errors
                    return
                }
            }

            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                logger.info("[AUTH] Apple Sign In cancelled by user (ASAuthorizationError.canceled)")
                clearError() // Clear any previous errors
                return
            }

            // Check for cancellation in error description
            let errorDesc = error.localizedDescription.lowercased()
            if errorDesc.contains("cancel") {
                logger.info("[AUTH] Apple Sign In cancelled by user (error description contains 'cancel')")
                clearError()
                return
            }

            // Handle Supabase AuthError cases
            if let supabaseAuthError = error as? AuthError {
                // Convert Supabase error to user-friendly message
                let errorMessage = supabaseAuthError.localizedDescription
                setError(.appleSignInFailed(reason: errorMessage))
            } else {
                setError(.appleSignInFailed(reason: error.localizedDescription))
            }

            logger.error("[AUTH] Apple Sign In failed: \(error.localizedDescription)")
            HapticManager.error()
        }
    }
    #endif

    // MARK: - Resend Confirmation Email

    @MainActor
    func resendConfirmationEmail(email: String) async {
        clearError()
        isLoading = true
        defer { isLoading = false }

        // Validate email format
        guard isValidEmail(email) else {
            setError(.invalidEmail)
            HapticManager.error()
            return
        }

        do {
            logger.info("[AUTH] Resending confirmation email to: \(email, privacy: .private)")

            // Note: The type is .signup to resend the initial confirmation email
            try await supabase.auth.resend(email: email, type: ResendEmailType.signup)

            // Use a success message instead of error for positive feedback
            errorMessage = "A new confirmation link has been sent to \(email)"
            authError = nil // Clear error state but keep the message

            showEmailVerificationPrompt = true
            HapticManager.success()
            logger.info("[AUTH] Confirmation email resent successfully")
        } catch {
            let parsedError = parseError(error)
            setError(parsedError)
            logger.error("[AUTH] Failed to resend confirmation: \(error.localizedDescription)")
            HapticManager.error()
        }
    }

    // MARK: - Password Reset

    @MainActor
    func resetPassword(email: String) async {
        clearError()
        isLoading = true
        defer { isLoading = false }

        // Validate email format
        guard isValidEmail(email) else {
            setError(.invalidEmail)
            HapticManager.error()
            return
        }

        do {
            logger.info("[AUTH] Sending password reset email to: \(email, privacy: .private)")

            try await supabase.auth.resetPasswordForEmail(email)

            // Use a success message
            errorMessage = "Password reset email sent to \(email)"
            authError = nil

            HapticManager.success()
            logger.info("[AUTH] Password reset email sent successfully")
        } catch {
            let parsedError = parseError(error)
            setError(parsedError)
            logger.error("[AUTH] Failed to send password reset: \(error.localizedDescription)")
            HapticManager.error()
        }
    }

    // MARK: - Session Management

    /// Keep local user in sync (listen to auth changes)
    private func listenForSession() async {
        // If there's an active session on startup
        if let session = try? await supabase.auth.session {
            await MainActor.run { self.user = session.user }
        }
    }

    func getCurrentAccessToken() async throws -> String {
        let session = try await supabase.auth.session
        return session.accessToken
    }
}

// MARK: - ASPresentationContextProviding

#if !SKIP
final class ASContextProvider: NSObject, ASAuthorizationControllerPresentationContextProviding,
    ASWebAuthenticationPresentationContextProviding
{
    static let shared = ASContextProvider()

    func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
        getMainWindow()
    }

    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        getMainWindow()
    }

    private func getMainWindow() -> ASPresentationAnchor {
        // iPad-safe window discovery - handles Stage Manager and multi-window scenarios
        // 1. Try foreground active scene with key window
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
            let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first
        {
            return window
        }

        // 2. Fallback: Try any connected scene (iPad multi-window)
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
            let window = windowScene.windows.first
        {
            return window
        }

        // 3. Last resort: Create window attached to current screen
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
        return window
    }
}

#endif

#else
// MARK: - Android AuthViewModel (Skip)

import Foundation
import Observation

/// Use AppAuthError for authentication error handling
typealias AuthenticationError = AppAuthError

@MainActor
@Observable
final class AuthViewModel {
    // MARK: - Observable Properties

    var email = ""
    var password = ""
    var errorMessage: String?
    var authError: AuthenticationError?
    var isLoading = false
    var showEmailVerificationPrompt = false

    // MARK: - Dependencies

    private let authService: AuthenticationService = AuthenticationService.shared
    private let log = AppLog(category: "AuthViewModel")

    // MARK: - Initialization

    init() {}

    // MARK: - Error Handling

    private func setError(_ error: AuthenticationError) {
        authError = error
        errorMessage = error.errorDescription
        log.warning("Auth error: \(error.errorDescription ?? "Unknown")")
    }

    func clearError() {
        authError = nil
        errorMessage = nil
    }

    // MARK: - Email Sign Up

    func signUpEmail() async {
        clearError()
        isLoading = true

        guard isValidEmail(email) else {
            setError(.invalidEmail)
            HapticManager.error()
            isLoading = false
            return
        }

        guard isValidPassword(password) else {
            setError(.weakPassword)
            HapticManager.error()
            isLoading = false
            return
        }

        do {
            try await authService.signUp(email: email, password: password, name: nil)
            clearError()
            if !authService.isEmailVerified {
                showEmailVerificationPrompt = true
            }
            isLoading = false
            HapticManager.success()
        } catch {
            isLoading = false
            if let authErr = error as? AppAuthError {
                setError(authErr)
            } else {
                setError(.serverError(statusCode: 0, errorMessage: error.localizedDescription))
            }
            HapticManager.error()
        }
    }

    // MARK: - Email Sign In

    func signInEmail() async {
        clearError()
        isLoading = true

        guard isValidEmail(email) else {
            setError(.invalidEmail)
            HapticManager.error()
            isLoading = false
            return
        }

        guard !password.isEmpty else {
            setError(.invalidCredentials)
            HapticManager.error()
            isLoading = false
            return
        }

        do {
            try await authService.signIn(email: email, password: password)
            clearError()
            isLoading = false
            HapticManager.success()
        } catch {
            isLoading = false
            if let authErr = error as? AppAuthError {
                setError(authErr)
                if case .emailNotConfirmed = authErr {
                    showEmailVerificationPrompt = true
                }
            } else {
                setError(.serverError(statusCode: 0, errorMessage: error.localizedDescription))
            }
            HapticManager.error()
        }
    }

    // MARK: - Validation Helpers

    private func isValidEmail(_ email: String) -> Bool {
        // Simple email validation without regex (Skip-compatible)
        return email.contains("@") && email.contains(".")
    }

    private func isValidPassword(_ password: String) -> Bool {
        guard password.count >= 8 else { return false }
        var hasLetter = false
        var hasNumber = false
        for char in password {
            if (char >= "a" && char <= "z") || (char >= "A" && char <= "Z") {
                hasLetter = true
            }
            if char >= "0" && char <= "9" {
                hasNumber = true
            }
        }
        return hasLetter && hasNumber
    }

    // MARK: - Sign Out

    func signOut() async {
        clearError()
        isLoading = true
        await authService.signOut()
        email = ""
        password = ""
        isLoading = false
        HapticManager.light()
    }

    // MARK: - Password Reset

    func resetPassword(email: String) async {
        clearError()
        isLoading = true
        do {
            try await authService.resetPassword(email: email)
            errorMessage = "Password reset email sent to \(email)"
            authError = nil
            isLoading = false
            HapticManager.success()
        } catch {
            isLoading = false
            if let authErr = error as? AppAuthError {
                setError(authErr)
            } else {
                setError(.serverError(statusCode: 0, errorMessage: error.localizedDescription))
            }
            HapticManager.error()
        }
    }

    // MARK: - Resend Confirmation Email

    func resendConfirmationEmail(email: String) async {
        clearError()
        isLoading = true
        // On Android, we don't have direct access to supabase.auth.resend
        // Show a message directing user to check email
        errorMessage = "Please check your email for a confirmation link"
        authError = nil
        isLoading = false
        showEmailVerificationPrompt = true
        HapticManager.success()
    }
}

#endif
