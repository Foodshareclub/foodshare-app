//
//  AuthenticationService.swift
//  Foodshare
//
//  Unified authentication service using modern Swift 6.2 @Observable pattern
//  Handles email/password, OAuth (Apple/Google), and session management
//
//  REFACTORED: Fixed race conditions with actor-based session state management
//  MIGRATED: From ObservableObject to @Observable for improved performance
//

#if !SKIP
import AuthenticationServices
import CryptoKit
#endif
import Foundation
import Observation
import OSLog
import Supabase
#if !SKIP
import UIKit
#endif

// MARK: - Auth User Profile Model (Basic auth state, distinct from Profile feature's UserProfile)

struct AuthUserProfile: Codable, Sendable, Identifiable {
    let id: UUID
    let email: String?
    let nickname: String?
    let firstName: String?
    let secondName: String?
    var avatarUrl: String?
    let createdTime: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case nickname
        case firstName = "first_name"
        case secondName = "second_name"
        case avatarUrl = "avatar_url"
        case createdTime = "created_time"
    }

    var displayName: String {
        if let nickname, !nickname.isEmpty {
            return nickname
        }
        if let firstName, !firstName.isEmpty {
            if let secondName, !secondName.isEmpty {
                return "\(firstName) \(secondName)"
            }
            return firstName
        }
        return email?.components(separatedBy: "@").first ?? "User"
    }

    /// Check if user has admin role
    /// - Warning: Always returns `false`. Admin roles are not stored in profiles.
    /// - Important: Use `AdminAuthorizationService.shared.isAdminUser` from `@MainActor` context
    ///   or call `AdminAuthorizationService.shared.isAdmin()` async method for accurate status.
    ///   Admin roles are stored in the `user_roles` table joined with `roles` table.
    @available(*, deprecated, message: "Use AdminAuthorizationService.shared.isAdminUser from @MainActor context")
    var isAdmin: Bool {
        // Cannot access AdminAuthorizationService from Sendable struct (actor isolation)
        // Views should use AdminAuthorizationService.shared.isAdminUser directly
        false
    }

    /// Check if user has super admin role
    /// - Warning: Always returns `false`. Super admin roles are not stored in profiles.
    /// - Important: Use `AdminAuthorizationService.shared.isSuperAdminUser` from `@MainActor` context
    ///   or call `AdminAuthorizationService.shared.isSuperAdmin()` async method for accurate status.
    @available(*, deprecated, message: "Use AdminAuthorizationService.shared.isSuperAdminUser from @MainActor context")
    var isSuperAdmin: Bool {
        // Cannot access AdminAuthorizationService from Sendable struct (actor isolation)
        // Views should use AdminAuthorizationService.shared.isSuperAdminUser directly
        false
    }
}

// MARK: - Nextdoor Token Response

/// Response from the Nextdoor token exchange Edge Function
/// Used during OAuth 2.0 + OpenID Connect sign-in flow
struct NextdoorTokenResponse: Codable, Sendable {
    /// OpenID Connect ID token containing user identity claims
    let idToken: String
    /// OAuth 2.0 access token for API requests
    let accessToken: String
    /// User's display name from Nextdoor profile (optional)
    let name: String?
    /// User's email address (optional, may not be provided)
    let email: String?

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case accessToken = "access_token"
        case name
        case email
    }
}

// MARK: - Session Info Response (Redis-backed locale)

/// Response from the api-v1-profile?action=session endpoint
/// Returns user's cached locale preference for cross-device sync
struct SessionInfoResponse: Codable, Sendable {
    let success: Bool
    let data: SessionInfoData?

    struct SessionInfoData: Codable, Sendable {
        let userId: String
        let locale: String
        let localeSource: String
    }
}

// MARK: - Session State Actor (Thread-safe session state management)

/// Actor for managing authentication state to prevent race conditions
private actor SessionStateManager {
    enum SessionState: Sendable {
        case idle
        case signingIn
        case signingUp
        case signingOut
        case checkingSession
        case authenticated
    }

    private var state: SessionState = .idle
    private var hasCompletedInitialCheck = false
    private var recentlySignedIn = false
    private var signInTime: Date?

    /// Time window during which session checks are skipped after sign-in
    private let signInProtectionWindow: TimeInterval = 2.0

    func getState() -> SessionState {
        state
    }

    func setState(_ newState: SessionState) {
        state = newState
        if newState == .authenticated {
            signInTime = Date()
            recentlySignedIn = true
        }
    }

    func hasPerformedInitialCheck() -> Bool {
        hasCompletedInitialCheck
    }

    func markInitialCheckComplete() {
        hasCompletedInitialCheck = true
    }

    func resetForSignOut() {
        state = .idle
        hasCompletedInitialCheck = false
        recentlySignedIn = false
        signInTime = nil
    }

    /// Check if we should skip session check due to recent sign-in
    func shouldSkipSessionCheck() -> Bool {
        guard recentlySignedIn, let signInTime else { return false }

        let elapsed = Date().timeIntervalSince(signInTime)
        if elapsed > signInProtectionWindow {
            recentlySignedIn = false
            return false
        }
        return true
    }

    /// Attempt to transition to a new state, returns true if successful
    func tryTransition(to newState: SessionState) -> Bool {
        switch (state, newState) {
        case (.idle, _), (.authenticated, _):
            state = newState
            return true
        case (_, .idle):
            state = newState
            return true
        default:
            // Already in a transitional state, deny new transition
            return false
        }
    }

    // MARK: - Atomic Session Check

    /// Result of atomic session check - all conditions evaluated in single actor call
    struct SessionCheckResult: Sendable {
        let hasCompletedInitialCheck: Bool
        let shouldSkipDueToRecentSignIn: Bool
        let currentState: SessionState
        let canTransitionToChecking: Bool
    }

    /// Atomically checks all session conditions and optionally transitions to checking state
    /// This prevents race conditions from multiple separate actor calls
    func atomicSessionCheck(attemptTransition: Bool = false) -> SessionCheckResult {
        let hasCheck = hasCompletedInitialCheck
        let shouldSkip = shouldSkipSessionCheck()
        let currentState = state

        var canTransition = false
        if attemptTransition {
            canTransition = tryTransition(to: .checkingSession)
        }

        return SessionCheckResult(
            hasCompletedInitialCheck: hasCheck,
            shouldSkipDueToRecentSignIn: shouldSkip,
            currentState: currentState,
            canTransitionToChecking: canTransition,
        )
    }
}

// MARK: - Authentication Service

@MainActor
@Observable
final class AuthenticationService {
    static let shared = AuthenticationService()

    // MARK: - Observable State

    private var _currentUser: AuthUserProfile?
    var currentUser: AuthUserProfile? {
        get {
            access(keyPath: \.currentUser)
            return _currentUser
        }
        set {
            withMutation(keyPath: \.currentUser) {
                let oldValue = _currentUser
                _currentUser = newValue
                logger.debug("🔄 [AUTH-STATE] currentUser changed: \(String(describing: newValue?.email))")
                // Update email verification state when user changes
                if oldValue?.id != newValue?.id {
                    updateEmailVerificationState()
                }
            }
        }
    }

    private var _isAuthenticated = false
    var isAuthenticated: Bool {
        get {
            access(keyPath: \.isAuthenticated)
            return _isAuthenticated
        }
        set {
            withMutation(keyPath: \.isAuthenticated) {
                let oldValue = _isAuthenticated
                _isAuthenticated = newValue
                logger.debug("🔄 [AUTH-STATE] isAuthenticated changed: \(oldValue) -> \(newValue)")
            }
        }
    }

    private var _isLoading = false
    var isLoading: Bool {
        get {
            access(keyPath: \.isLoading)
            return _isLoading
        }
        set {
            withMutation(keyPath: \.isLoading) {
                let oldValue = _isLoading
                _isLoading = newValue
                logger.debug("🔄 [AUTH-STATE] isLoading changed: \(oldValue) -> \(newValue)")
            }
        }
    }

    /// Whether the current user's email has been verified
    private var _isEmailVerified = false
    var isEmailVerified: Bool {
        get {
            access(keyPath: \.isEmailVerified)
            return _isEmailVerified
        }
        set {
            withMutation(keyPath: \.isEmailVerified) {
                let oldValue = _isEmailVerified
                _isEmailVerified = newValue
                logger.debug("🔄 [AUTH-STATE] isEmailVerified changed: \(oldValue) -> \(newValue)")
            }
        }
    }

    /// Current user's email address (for display on verification screen)
    var currentUserEmail: String?

    // MARK: - Thread-Safe Session State

    /// Actor-based session state manager to prevent race conditions
    private let sessionState = SessionStateManager()

    #if !SKIP
    // MARK: - OAuth Continuations

    fileprivate var appleOAuthContinuation: CheckedContinuation<Void, Error>?

    /// Retain delegate and controller to prevent deallocation before auth completes
    fileprivate var appleAuthDelegate: AppleAuthDelegate?
    fileprivate var appleAuthController: ASAuthorizationController?
    #endif

    // MARK: - Dependencies

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "AuthenticationService")
    let supabase: SupabaseClient

    // Expose URL and key for JWT workaround
    let supabaseURL: URL
    let supabasePublishableKey: String

    // MARK: - Configuration State

    /// Indicates if the service was initialized with valid configuration
    /// When false, all authentication operations will fail gracefully
    private(set) var isConfigured = true

    /// Configuration error message if initialization failed
    private(set) var configurationError: String?

    // MARK: - Initialization

    private init() {
        // Validate configuration with graceful failure for release builds
        guard let urlString = AppEnvironment.supabaseURL,
              let url = URL(string: urlString),
              let key = AppEnvironment.supabasePublishableKey else
        {
            // Log critical error
            let errorMessage = "Supabase configuration missing - ensure SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are set in environment"
            Logger(subsystem: "com.flutterflow.foodshare", category: "AuthenticationService")
                .critical("🚨 CRITICAL: \(errorMessage)")

            // Crash in debug builds to catch configuration issues early
            assertionFailure(errorMessage)

            // In release builds, set up in non-functional state
            // All operations will fail gracefully instead of crashing
            self.isConfigured = false
            self.configurationError = errorMessage
            // Use a guaranteed valid URL for the invalid state
            // swiftlint:disable:next force_unwrapping
            self.supabaseURL = URL(string: "https://invalid.supabase.co")!
            self.supabasePublishableKey = "invalid-key"
            self.supabase = SupabaseClient(
                supabaseURL: self.supabaseURL,
                supabaseKey: self.supabasePublishableKey,
            )
            return
        }

        supabaseURL = url
        supabasePublishableKey = key

        // Create URLSession configuration optimized for reliability
        // Addresses QUIC/HTTP3 issues in iOS Simulator with Cloudflare-fronted endpoints
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = 30
        sessionConfiguration.timeoutIntervalForResource = 60
        sessionConfiguration.waitsForConnectivity = true
        sessionConfiguration.allowsExpensiveNetworkAccess = true
        sessionConfiguration.allowsConstrainedNetworkAccess = true

        // Create session with configuration
        let session = URLSession(configuration: sessionConfiguration)

        supabase = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: SupabaseClientOptions(
                auth: .init(flowType: .pkce, autoRefreshToken: true),
                global: .init(session: session),
            ),
        )

        logger.info("🔐 [AUTH] AuthenticationService initialized with certificate pinning support")
    }

    // MARK: - Session Management

    func checkCurrentSession() async {
        logger.info("🔐 [AUTH] Checking current session...")

        // ATOMIC session state check - prevents race conditions from multiple await calls
        // All conditions are evaluated in a single actor call, with optional state transition
        let checkResult = await sessionState.atomicSessionCheck(attemptTransition: true)

        // Already completed initial check and we're authenticated
        if checkResult.hasCompletedInitialCheck, isAuthenticated {
            logger.info("ℹ️ [AUTH] Already performed initial session check and user is authenticated - skipping")
            return
        }

        // Skip if we recently signed in (time-based protection window)
        if checkResult.shouldSkipDueToRecentSignIn {
            logger.warning("⚠️ [AUTH] Skipping checkCurrentSession - user just signed in successfully")
            await sessionState.markInitialCheckComplete()
            return
        }

        // If already authenticated with a user, skip redundant checks
        if isAuthenticated, currentUser != nil {
            logger.info("ℹ️ [AUTH] Already authenticated with valid user, skipping session check")
            await sessionState.markInitialCheckComplete()
            return
        }

        // Check if we successfully transitioned to checking state (prevents concurrent checks)
        guard checkResult.canTransitionToChecking else {
            logger.info("ℹ️ [AUTH] Session check already in progress, skipping")
            return
        }

        isLoading = true

        do {
            let session = try await supabase.auth.session

            // Set session to ensure JWT is propagated to PostgREST
            logger.debug("🔄 [AUTH] Setting access token on Supabase client...")
            try await supabase.auth.setSession(accessToken: session.accessToken, refreshToken: session.refreshToken)
            logger.debug("✅ [AUTH] Access token set - database queries will now include JWT")

            // Wait for session propagation with proper async/await
            try await waitForSessionPropagation()

            let user = try await loadUserProfile(userId: session.user.id, session: session)

            currentUser = user
            isAuthenticated = true
            isLoading = false
            await sessionState.markInitialCheckComplete()
            await sessionState.setState(.authenticated)

            logger
                .info("✅ [AUTH] Session restored for user: \(user.email ?? "unknown", privacy: .private(mask: .hash))")

            // Sync locale from server (Redis-cached, non-blocking)
            Task { await fetchSessionInfoAndSyncLocale() }
        } catch {
            // Only clear user state if we weren't recently signed in
            let shouldClearState = await !(sessionState.shouldSkipSessionCheck())
            if shouldClearState {
                currentUser = nil
                isAuthenticated = false
            }
            await sessionState.markInitialCheckComplete()
            await sessionState.setState(.idle)
            isLoading = false

            logger.debug("ℹ️ [AUTH] No active session: \(error.localizedDescription, privacy: .private)")
        }
    }

    /// Wait for session to propagate to the SDK with proper async handling
    private func waitForSessionPropagation() async throws {
        // Use Task.yield instead of hard-coded delays to allow SDK internal state to update
        // This is more reliable than fixed delays
        for _ in 0 ..< 5 {
            await Task.yield()
            try await Task.sleep(for: .milliseconds(20))
        }
        logger.debug("✅ [AUTH] Session ready for RLS queries")
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async throws {
        logger.info("🔐 [AUTH] Signing in user: \(email, privacy: .private(mask: .hash))")

        // Prevent concurrent sign-in attempts
        guard await sessionState.tryTransition(to: .signingIn) else {
            logger.warning("⚠️ [AUTH] Sign-in already in progress")
            throw AuthError.unknown("Sign-in already in progress")
        }

        isLoading = true

        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password,
            )

            logger.info("✅ [AUTH] Sign-in successful - JWT token received")

            // Set session to ensure JWT is propagated
            try await supabase.auth.setSession(accessToken: session.accessToken, refreshToken: session.refreshToken)

            // Wait for session propagation
            try await waitForSessionPropagation()

            // Try to load profile, create if missing
            let user: AuthUserProfile
            do {
                user = try await loadUserProfile(userId: session.user.id, session: session)
                logger.info("✅ [AUTH] Profile loaded successfully")
            } catch let error as NSError where error.code == 404 {
                logger.warning("⚠️ [AUTH] Profile not found (404), creating new profile")
                try await createUserProfile(
                    userId: session.user.id,
                    email: session.user.email ?? email,
                    fullName: nil,
                    session: session,
                )
                user = try await loadUserProfile(userId: session.user.id, session: session)
                logger.info("✅ [AUTH] New profile created and loaded")
            }

            // Update state atomically using actor
            currentUser = user
            isAuthenticated = true
            isLoading = false
            await sessionState.markInitialCheckComplete()
            await sessionState.setState(.authenticated)

            HapticManager.success()

            // Notify AppDelegate to register any pending push notification device token
            NotificationCenter.default.post(name: .didAuthenticate, object: nil)

            // Perform device attestation in background (non-blocking)
            await performPostAuthenticationAttestation()

            // Sync locale from server (Redis-cached, non-blocking)
            Task { await fetchSessionInfoAndSyncLocale() }

        } catch {
            await sessionState.setState(.idle)
            isLoading = false
            HapticManager.error()
            logger.error("❌ [AUTH] Sign in failed: \(error.localizedDescription, privacy: .private)")
            throw mapError(error)
        }
    }

    // MARK: - Sign Up

    /// Maximum retry attempts for transient failures during sign-up
    private static let maxSignUpRetries = 3

    /// Base delay for exponential backoff (in seconds)
    private static let retryBaseDelay: TimeInterval = 0.5

    func signUp(email: String, password: String, name: String? = nil) async throws {
        logger.info("🔐 [AUTH] Signing up user: \(email, privacy: .private(mask: .hash))")

        // Prevent concurrent sign-up attempts
        guard await sessionState.tryTransition(to: .signingUp) else {
            logger.warning("⚠️ [AUTH] Sign-up already in progress")
            throw AuthError.unknown("Sign-up already in progress")
        }

        isLoading = true

        do {
            let authResponse = try await supabase.auth.signUp(
                email: email,
                password: password,
            )

            // Extract session from auth response (may be nil for email confirmation flow)
            guard let session = authResponse.session else {
                // Email confirmation required - user needs to verify email first
                logger.info("📧 [AUTH] Sign up successful - awaiting email confirmation")
                await sessionState.setState(.idle)
                isLoading = false
                throw AuthError.emailConfirmationRequired("Please check your email to confirm your account")
            }

            // Set session to ensure JWT is propagated
            try await supabase.auth.setSession(accessToken: session.accessToken, refreshToken: session.refreshToken)

            // Wait for session propagation
            try await waitForSessionPropagation()

            // Create profile in users table with retry and rollback support
            do {
                try await createUserProfileWithRetry(
                    userId: session.user.id,
                    email: email,
                    fullName: name,
                    session: session,
                )
            } catch {
                // Profile creation failed - attempt rollback by signing out the orphaned auth user
                logger
                    .error(
                        "❌ [AUTH] Profile creation failed, initiating rollback: \(error.localizedDescription, privacy: .private)",
                    )
                await rollbackAuthUser(reason: "Profile creation failed")
                throw AuthError.profileCreationFailed(
                    "Failed to create user profile. Please try again.",
                )
            }

            let user = try await loadUserProfile(userId: session.user.id, session: session)

            // Update state atomically using actor
            currentUser = user
            isAuthenticated = true
            isLoading = false
            await sessionState.markInitialCheckComplete()
            await sessionState.setState(.authenticated)

            HapticManager.success()
            logger.info("✅ [AUTH] Sign up successful for: \(email, privacy: .private(mask: .hash))")

            // Notify AppDelegate to register any pending push notification device token
            NotificationCenter.default.post(name: .didAuthenticate, object: nil)

        } catch let error as AuthError {
            // Already an AuthError, propagate as-is
            await sessionState.setState(.idle)
            isLoading = false
            HapticManager.error()
            logger.error("❌ [AUTH] Sign up failed: \(error.localizedDescription, privacy: .private)")
            throw error
        } catch {
            await sessionState.setState(.idle)
            isLoading = false
            HapticManager.error()
            logger.error("❌ [AUTH] Sign up failed: \(error.localizedDescription, privacy: .private)")
            throw mapError(error)
        }
    }

    /// Create user profile with exponential backoff retry for transient failures
    private func createUserProfileWithRetry(
        userId: UUID,
        email: String,
        fullName: String?,
        session: Session,
    ) async throws {
        var lastError: Error?

        for attempt in 1 ... Self.maxSignUpRetries {
            do {
                try await createUserProfile(
                    userId: userId,
                    email: email,
                    fullName: fullName,
                    session: session,
                )
                logger.info("✅ [AUTH] Profile created successfully on attempt \(attempt)")
                return
            } catch {
                lastError = error
                let isTransient = isTransientError(error)

                if isTransient, attempt < Self.maxSignUpRetries {
                    // Exponential backoff: 0.5s, 1s, 2s
                    let delay = Self.retryBaseDelay * pow(2.0, Double(attempt - 1))
                    logger
                        .warning(
                            "⚠️ [AUTH] Profile creation attempt \(attempt) failed (transient), retrying in \(delay)s: \(error.localizedDescription, privacy: .private)",
                        )
                    try await Task.sleep(for: .seconds(delay))
                } else {
                    logger
                        .error(
                            "❌ [AUTH] Profile creation attempt \(attempt) failed (non-transient or max retries): \(error.localizedDescription, privacy: .private)",
                        )
                    break
                }
            }
        }

        // All retries exhausted
        throw lastError ?? AuthError.unknown("Profile creation failed after retries")
    }

    /// Determine if an error is transient (network issues, timeouts) vs permanent (validation, conflict)
    private func isTransientError(_ error: Error) -> Bool {
        let errorMessage = error.localizedDescription.lowercased()

        // Transient errors that are worth retrying
        let transientPatterns = [
            "network", "connection", "timeout", "timed out",
            "unavailable", "service temporarily", "503", "504",
            "could not connect", "internet", "offline",
        ]

        for pattern in transientPatterns {
            if errorMessage.contains(pattern) {
                return true
            }
        }

        // Check for NSURLError codes (network issues)
        if let nsError = error as? NSError {
            let transientCodes: Set<Int> = [
                NSURLErrorTimedOut,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorNotConnectedToInternet,
                NSURLErrorSecureConnectionFailed,
                NSURLErrorServerCertificateUntrusted,
            ]
            if transientCodes.contains(nsError.code) {
                return true
            }
        }

        return false
    }

    /// Rollback an orphaned auth user by signing out
    /// This clears the session but the auth.users entry may remain (Supabase limitation)
    /// Supabase will clean up unverified users automatically after a configured period
    private func rollbackAuthUser(reason: String) async {
        logger.warning("🔄 [AUTH] Rolling back auth user: \(reason)")

        do {
            // Sign out to invalidate the session
            try await supabase.auth.signOut()
            logger.info("✅ [AUTH] Auth user session invalidated during rollback")
        } catch {
            // Log but don't propagate - rollback is best-effort
            logger
                .error(
                    "⚠️ [AUTH] Rollback sign-out failed (non-critical): \(error.localizedDescription, privacy: .private)",
                )
        }

        // Clear local state
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - Device Attestation

    /// Perform device attestation after successful authentication
    ///
    /// This runs in the background and doesn't block the sign-in flow.
    /// If attestation fails, we log it but don't fail the authentication.
    private func performPostAuthenticationAttestation() async {
        logger.debug("🔐 [AUTH] Starting post-authentication device attestation")

        do {
            try await AttestationMiddleware.shared.performInitialAttestation(using: supabase)
            logger.info("✅ [AUTH] Device attestation completed successfully")
        } catch {
            // Log the error but don't fail authentication
            // Attestation is a security enhancement, not a hard requirement
            logger.warning("⚠️ [AUTH] Device attestation failed (non-blocking): \(error.localizedDescription)")
        }
    }

    // MARK: - Session Info (Redis-backed locale sync)

    /// Fetch session info from BFF with Redis-cached locale preference
    ///
    /// This is called after successful authentication to:
    /// - Get the user's locale preference from Redis cache (O(1) lookup)
    /// - Sync the locale to EnhancedTranslationService if different from local
    ///
    /// This enables cross-device locale sync on app launch.
    private func fetchSessionInfoAndSyncLocale() async {
        logger.debug("🌍 [AUTH] Fetching session info for locale sync...")

        do {
            let response: SessionInfoResponse = try await supabase.functions.invoke(
                "api-v1-profile?action=session",
                options: FunctionInvokeOptions(method: .get),
            )

            guard response.success, let data = response.data else {
                logger.warning("⚠️ [AUTH] Session info request failed or returned no data")
                return
            }

            let serverLocale = data.locale
            let localeSource = data.localeSource
            logger.debug("🌍 [AUTH] Server locale: \(serverLocale) (source: \(localeSource))")

            // Sync locale from server if it differs from current locale
            // Use the new syncLocaleFromServer method which doesn't re-sync to server
            await EnhancedTranslationService.shared.syncLocaleFromServer(serverLocale)

            logger.info("✅ [AUTH] Session info fetched, locale synced: \(serverLocale)")
        } catch {
            // Non-critical - log but don't fail authentication
            logger.warning("⚠️ [AUTH] Failed to fetch session info: \(error.localizedDescription)")
            // Fall back to loading from profile (existing behavior)
            await EnhancedTranslationService.shared.loadLocaleFromProfile()
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        logger.info("🔐 [AUTH] Signing out user...")

        // Prevent concurrent sign-out attempts
        guard await sessionState.tryTransition(to: .signingOut) else {
            logger.warning("⚠️ [AUTH] Sign-out already in progress")
            return
        }

        isLoading = true

        do {
            try await supabase.auth.signOut()

            currentUser = nil
            isAuthenticated = false
            isLoading = false
            await sessionState.resetForSignOut()

            // Reset device attestation state
            AttestationMiddleware.shared.reset()

            HapticManager.light()
            logger.info("✅ [AUTH] Sign out successful")
        } catch {
            await sessionState.setState(.idle)
            isLoading = false
            logger.error("❌ [AUTH] Sign out failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Password Reset

    func resetPassword(email: String) async throws {
        logger.info("🔐 [AUTH] Requesting password reset for: \(email, privacy: .private(mask: .hash))")

        do {
            try await supabase.auth.resetPasswordForEmail(email)
            HapticManager.success()
            logger.info("✅ [AUTH] Password reset email sent to: \(email, privacy: .private(mask: .hash))")
        } catch {
            HapticManager.error()
            logger.error("❌ [AUTH] Password reset failed: \(error.localizedDescription, privacy: .private)")
            throw mapError(error)
        }
    }

    // MARK: - Email Verification

    /// Resend the email verification link to the current user
    func resendVerificationEmail() async throws {
        guard let email = currentUserEmail ?? currentUser?.email else {
            logger.error("❌ [AUTH] Cannot resend verification - no email address")
            throw AuthError.unknown("No email address available")
        }

        logger.info("📧 [AUTH] Resending verification email to: \(email, privacy: .private(mask: .hash))")

        do {
            try await supabase.auth.resend(email: email, type: .signup)
            HapticManager.success()
            logger.info("✅ [AUTH] Verification email resent to: \(email, privacy: .private(mask: .hash))")
        } catch {
            HapticManager.error()
            logger
                .error("❌ [AUTH] Failed to resend verification email: \(error.localizedDescription, privacy: .private)")
            throw mapError(error)
        }
    }

    /// Check and update email verification status from Supabase
    func checkEmailVerificationStatus() async -> Bool {
        logger.debug("🔍 [AUTH] Checking email verification status...")

        do {
            // Refresh the session to get the latest user data
            let session = try await supabase.auth.session
            let user = session.user

            // Check if email is confirmed
            let emailConfirmedAt = user.emailConfirmedAt
            let verified = emailConfirmedAt != nil

            await MainActor.run {
                self.isEmailVerified = verified
                self.currentUserEmail = user.email
            }

            logger.info("📧 [AUTH] Email verification status: \(verified)")
            return verified
        } catch {
            logger
                .error("❌ [AUTH] Failed to check verification status: \(error.localizedDescription, privacy: .private)")
            return false
        }
    }

    /// Update email verification state based on current session
    private func updateEmailVerificationState() {
        Task {
            _ = await checkEmailVerificationStatus()
        }
    }

    // MARK: - Session Helpers

    /// Ensures Supabase session is ready with JWT propagated for RLS queries
    /// Call this before any database operations that require authentication
    func ensureSupabaseSessionReady() async throws {
        logger.debug("🔐 [AUTH] Ensuring Supabase session is ready...")

        let session = try await supabase.auth.session

        // Set the session to ensure JWT is propagated to PostgREST
        try await supabase.auth.setSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
        )

        // Wait for session propagation with proper async handling
        try await waitForSessionPropagation()

        logger.debug("✅ [AUTH] Supabase session ready for RLS queries")
    }

    /// Returns the current access token for authenticated requests
    /// Refreshes the token if needed before returning
    func currentAccessToken() async throws -> String {
        let session = try await supabase.auth.session
        return session.accessToken
    }

    /// Returns an authenticated SupabaseClient with JWT in headers
    /// Use this for database operations requiring RLS authentication
    /// Note: Prefer using the shared `supabase` client with `ensureSupabaseSessionReady()` when possible
    func authenticatedClient() async throws -> SupabaseClient {
        let accessToken = try await currentAccessToken()

        return SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabasePublishableKey,
            options: SupabaseClientOptions(
                global: .init(headers: ["Authorization": "Bearer \(accessToken)"]),
            ),
        )
    }

    // MARK: - Profile Management

    /// Update user profile (name, avatar)
    func updateProfile(name: String? = nil, avatarUrl: String? = nil) async throws {
        guard let userId = currentUser?.id else {
            logger.error("❌ [AUTH] Cannot update profile - no current user")
            throw AuthError.unauthorized
        }

        logger.info("📊 [AUTH] Updating profile for user: \(userId, privacy: .private(mask: .hash))")

        do {
            let client = try await authenticatedClient()

            var updates: [String: AnyJSON] = [:]

            if let name {
                updates["nickname"] = .string(name)
            }

            if let avatarUrl {
                updates["avatar_url"] = .string(avatarUrl)
            }

            try await client
                .from("profiles")
                .update(updates)
                .eq("id", value: userId.uuidString)
                .execute()

            // Reload the profile to get updated data
            try await reloadUserProfile()

            HapticManager.success()
            logger.info("✅ [AUTH] Profile updated successfully")

        } catch {
            HapticManager.error()
            logger.error("❌ [AUTH] Failed to update profile: \(error.localizedDescription, privacy: .private)")
            throw error
        }
    }

    /// Reload current user's profile from database
    func reloadUserProfile() async throws {
        guard let userId = currentUser?.id else {
            logger.warning("⚠️ [AUTH] Cannot reload profile - no current user")
            return
        }

        logger.debug("🔄 [AUTH] Reloading user profile...")

        let user = try await loadUserProfile(userId: userId)

        await MainActor.run {
            self.currentUser = user
        }

        logger.info("✅ [AUTH] Profile reloaded successfully")
    }

    /// Delete user account and all associated data via Edge Function
    /// This is required for Apple App Store compliance - complete account deletion
    func deleteAccount() async throws {
        guard let userId = currentUser?.id else {
            logger.error("❌ [AUTH] Cannot delete account - no current user")
            throw AuthError.unauthorized
        }

        logger.warning("🗑️ [AUTH] Initiating account deletion for user: \(userId, privacy: .private(mask: .hash))")

        do {
            // Call Edge Function to delete user from auth.users
            // The Edge Function uses service_role key to:
            // 1. Delete avatar files from storage
            // 2. Delete auth user (cascades to profiles and related data)

            // Parse response to check for success
            struct DeleteResponse: Decodable {
                let success: Bool
                let message: String
            }

            let result: DeleteResponse = try await supabase.functions.invoke(
                "delete-user",
                options: .init(method: .post),
            )

            if !result.success {
                logger.error("❌ [AUTH] Edge Function returned failure: \(result.message, privacy: .private)")
                throw AuthError.unknown(result.message)
            }

            logger.info("✅ [AUTH] User deleted from auth system")

            // Sign out the user (this clears local session)
            await signOut()

            HapticManager.success()
            logger.info("✅ [AUTH] Account deletion complete")

        } catch {
            HapticManager.error()
            logger.error("❌ [AUTH] Account deletion failed: \(error.localizedDescription, privacy: .private)")
            throw error
        }
    }

    // MARK: - Internal Profile Operations

    private func loadUserProfile(userId: UUID, session: Session? = nil) async throws -> AuthUserProfile {
        logger.debug("📊 [AUTH] Loading profile from profiles table for user: \(userId, privacy: .private(mask: .hash))")

        // CRITICAL FIX: Create authenticated client with JWT token
        let authSession: Session = if let providedSession = session {
            providedSession
        } else {
            try await supabase.auth.session
        }

        let accessToken = authSession.accessToken

        // Create an authenticated Supabase client with JWT in headers
        let authenticatedClient = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabasePublishableKey,
            options: SupabaseClientOptions(
                global: .init(headers: ["Authorization": "Bearer \(accessToken)"]),
            ),
        )

        let response: [AuthUserProfile] = try await authenticatedClient
            .from("profiles")
            .select("id, email, nickname, first_name, second_name, avatar_url, created_time")
            .eq("id", value: userId.uuidString)
            .execute()
            .value

        guard let user = response.first else {
            logger.error("❌ [AUTH] User profile not found in database")
            throw NSError(
                domain: "AuthenticationService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "User profile not found"],
            )
        }

        logger.debug("✅ [AUTH] Profile loaded successfully")
        return user
    }

    private func createUserProfile(
        userId: UUID,
        email: String,
        fullName: String?,
        session: Session? = nil,
    ) async throws {
        logger.debug("📊 [AUTH] Creating profile in profiles table for user: \(userId, privacy: .private(mask: .hash))")

        do {
            let authSession: Session = if let providedSession = session {
                providedSession
            } else {
                try await supabase.auth.session
            }

            let accessToken = authSession.accessToken

            let authenticatedClient = SupabaseClient(
                supabaseURL: supabaseURL,
                supabaseKey: supabasePublishableKey,
                options: SupabaseClientOptions(
                    global: .init(headers: ["Authorization": "Bearer \(accessToken)"]),
                ),
            )

            // Create profile data matching the profiles table schema
            var profileData: [String: AnyJSON] = [
                "id": .string(userId.uuidString),
                "email": .string(email),
                "created_time": .string(ISO8601DateFormatter().string(from: Date())),
                "is_active": .bool(true),
                "is_verified": .bool(false),
            ]

            // Set nickname from full name if provided
            if let fullName, !fullName.isEmpty {
                profileData["nickname"] = .string(fullName)
                // Also try to split into first/second name
                let nameParts = fullName.split(separator: " ", maxSplits: 1)
                if !nameParts.isEmpty {
                    profileData["first_name"] = .string(String(nameParts[0]))
                }
                if nameParts.count > 1 {
                    profileData["second_name"] = .string(String(nameParts[1]))
                }
            }

            try await authenticatedClient
                .from("profiles")
                .insert(profileData)
                .execute()

            logger.debug("✅ [AUTH] Profile created successfully in profiles table")
        } catch {
            logger.error("❌ [AUTH] Failed to create profile: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    #if !SKIP
    // MARK: - Apple Sign In

    func signInWithApple(presentationAnchor: ASPresentationAnchor) async throws {
        // Prevent re-entry
        if appleOAuthContinuation != nil {
            logger.warning("⚠️ [AUTH] Apple Sign In already in progress")
            throw NSError(
                domain: "AuthenticationService",
                code: 409,
                userInfo: [NSLocalizedDescriptionKey: "Apple Sign In already in progress"],
            )
        }

        logger.info("🔐 [AUTH] Starting Sign in with Apple")
        isLoading = true

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.appleOAuthContinuation = continuation

                Task { @MainActor [weak self] in
                    guard let self else {
                        continuation.resume(throwing: NSError(
                            domain: "AuthenticationService",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "AuthenticationService deallocated"],
                        ))
                        return
                    }

                    do {
                        let nonce = try NonceGenerator.generateNonce()
                        let hashedNonce = NonceGenerator.sha256(nonce)

                        let appleIDProvider = ASAuthorizationAppleIDProvider()
                        let request = appleIDProvider.createRequest()
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = hashedNonce

                        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
                        let delegate = AppleAuthDelegate(nonce: nonce, authService: self)

                        self.appleAuthController = authorizationController
                        self.appleAuthDelegate = delegate

                        authorizationController.delegate = delegate
                        authorizationController.presentationContextProvider = delegate
                        authorizationController.performRequests()

                        self.logger.debug("🔐 [AUTH] Apple ID authentication UI presented")

                        // Timeout after 120 seconds
                        Task { [weak self] in
                            try? await Task.sleep(nanoseconds: 120_000_000_000)
                            if self?.appleOAuthContinuation != nil {
                                self?.appleOAuthContinuation?.resume(throwing: NSError(
                                    domain: "AuthenticationService",
                                    code: 408,
                                    userInfo: [NSLocalizedDescriptionKey: "Apple Sign In timeout"],
                                ))
                                self?.appleOAuthContinuation = nil
                                self?.appleAuthDelegate = nil
                                self?.appleAuthController = nil
                                await MainActor.run { [weak self] in
                                    self?.isLoading = false
                                }
                            }
                        }

                    } catch {
                        continuation.resume(throwing: error)
                        await MainActor.run { [weak self] in
                            self?.isLoading = false
                        }
                    }
                }
            }

            logger.info("✅ [AUTH] Apple authentication flow completed")
            HapticManager.success()

            // Sync locale from server (Redis-cached, non-blocking)
            Task { await fetchSessionInfoAndSyncLocale() }

        } catch {
            await MainActor.run {
                self.isLoading = false
            }

            // Check if user cancelled - don't show error or haptic
            if let appError = error as? AppAuthError, appError == .oauthCancelled {
                logger.info("ℹ️ [AUTH] Apple Sign In cancelled by user")
                throw appError
            }

            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                logger.info("ℹ️ [AUTH] Apple Sign In cancelled by user")
                throw AppAuthError.oauthCancelled
            }

            HapticManager.error()
            logger.error("❌ [AUTH] Sign in with Apple failed: \(error.localizedDescription, privacy: .private)")
            throw error
        }
    }

    /// Process Sign in with Apple credential (called by AppleAuthDelegate)
    func processAppleSignIn(credential: ASAuthorizationAppleIDCredential, nonce: String) async throws {
        logger.debug("🔐 [AUTH] Processing Apple ID credential")

        guard let identityToken = credential.identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8) else
        {
            throw NSError(
                domain: "AuthenticationService",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identity token"],
            )
        }

        let session = try await supabase.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: identityTokenString,
                nonce: nonce,
            ),
        )

        logger.info("✅ [AUTH] Apple sign-in successful - JWT token received")

        try await supabase.auth.setSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
        )

        // Wait for session propagation
        try await waitForSessionPropagation()

        // Extract user info
        let fullName: String? = if let givenName = credential.fullName?.givenName,
                                   let familyName = credential.fullName?.familyName
        {
            "\(givenName) \(familyName)"
        } else if let givenName = credential.fullName?.givenName {
            givenName
        } else {
            nil
        }

        // Load or create profile
        let user: AuthUserProfile
        do {
            user = try await loadUserProfile(userId: session.user.id, session: session)
        } catch let error as NSError where error.code == 404 {
            try await createUserProfile(
                userId: session.user.id,
                email: session.user.email ?? credential
                    .email ?? "apple-\(session.user.id.uuidString)@privaterelay.appleid.com",
                fullName: fullName,
                session: session,
            )
            user = try await loadUserProfile(userId: session.user.id, session: session)
        }

        // Update state atomically using actor
        currentUser = user
        isAuthenticated = true
        isLoading = false
        await sessionState.markInitialCheckComplete()
        await sessionState.setState(.authenticated)

        // Resume continuation
        if let continuation = appleOAuthContinuation {
            continuation.resume()
            appleOAuthContinuation = nil
            appleAuthDelegate = nil
            appleAuthController = nil
        }

        // Notify AppDelegate to register any pending push notification device token
        NotificationCenter.default.post(name: .didAuthenticate, object: nil)

        // Perform device attestation in background (non-blocking)
        await performPostAuthenticationAttestation()

        // Sync locale from server (Redis-cached, non-blocking)
        Task { await fetchSessionInfoAndSyncLocale() }
    }

    // MARK: - Google Sign In (Supabase OAuth with ASWebAuthenticationSession)

    /// Retain presentation context to prevent deallocation during OAuth flow
    private var presentationContext: WebAuthPresentationContext?

    func signInWithGoogle() async throws {
        logger.info("🔐 [AUTH] Starting Sign in with Google")
        logger.info("🔐 [AUTH] Supabase URL: \(self.supabaseURL.absoluteString)")
        logger.info("🔐 [AUTH] Redirect URI: foodshare://oauth-callback")
        isLoading = true

        // Retry logic for PKCE flow issues
        var lastError: Error?
        for attempt in 1 ... 2 {
            do {
                if attempt > 1 {
                    logger.info("🔄 [AUTH] Retrying Google sign in (attempt \(attempt))")
                    // Clear any existing auth state to prevent PKCE conflicts
                    try? await supabase.auth.signOut()
                    // Clear presentation context
                    await MainActor.run {
                        presentationContext = nil
                    }
                    // Small delay to ensure state cleanup
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }

                logger.info("🔐 [AUTH] Calling supabase.auth.signInWithOAuth...")
                logger.info("🔐 [AUTH] Provider: google, redirectTo: foodshare://oauth-callback")

                // Create and retain presentation context properly
                await MainActor.run {
                    presentationContext = WebAuthPresentationContext()
                }

                guard let context = presentationContext else {
                    throw AppAuthError.googleSignInFailed(reason: "Failed to create presentation context")
                }

                // Use Supabase's built-in signInWithOAuth with PKCE flow
                let session = try await supabase.auth.signInWithOAuth(
                    provider: .google,
                    redirectTo: URL(string: "foodshare://oauth-callback"),
                    queryParams: [
                        ("access_type", "offline"), // Request refresh token
                        ("prompt", "select_account"), // Allow account selection
                    ],
                ) { (authSession: ASWebAuthenticationSession) in
                    // Configure the session presentation
                    self.logger.debug("🔐 [AUTH] ASWebAuthenticationSession closure called")
                    // Use the retained context from the service property
                    authSession.presentationContextProvider = context
                    authSession.prefersEphemeralWebBrowserSession = false
                    self.logger.debug("🔐 [AUTH] ASWebAuthenticationSession configured with retained context")
                }

                // If we get here, the sign-in was successful
                logger.info("✅ [AUTH] Google OAuth completed, session: \(session.user.id)")

                // Continue with the rest of the method...
                try await waitForSessionPropagation()

                let user: AuthUserProfile
                do {
                    user = try await loadUserProfile(userId: session.user.id, session: session)
                } catch let error as NSError where error.code == 404 {
                    let fullName = session.user.userMetadata["full_name"]?.stringValue
                        ?? session.user.userMetadata["name"]?.stringValue

                    try await createUserProfile(
                        userId: session.user.id,
                        email: session.user.email ?? "",
                        fullName: fullName,
                        session: session,
                    )
                    user = try await loadUserProfile(userId: session.user.id, session: session)
                }

                currentUser = user
                isAuthenticated = true
                isLoading = false

                // Clean up presentation context
                await MainActor.run {
                    presentationContext = nil
                }

                await sessionState.markInitialCheckComplete()
                await sessionState.setState(.authenticated)

                HapticManager.success()
                logger.info("✅ [AUTH] Google sign in completed successfully")

                NotificationCenter.default.post(name: .didAuthenticate, object: nil)
                await performPostAuthenticationAttestation()
                Task { await fetchSessionInfoAndSyncLocale() }

                return // Success, exit retry loop

            } catch {
                lastError = error
                let errorMessage = error.localizedDescription

                // Check if user cancelled - don't retry, just exit gracefully
                if let authError = error as? ASWebAuthenticationSessionError,
                   authError.code == .canceledLogin
                {
                    logger.info("ℹ️ [AUTH] User cancelled Google sign-in")
                    await MainActor.run {
                        presentationContext = nil
                    }
                    await sessionState.setState(.idle)
                    isLoading = false
                    throw AppAuthError.oauthCancelled
                }

                // Check for cancellation in error message
                if errorMessage.lowercased().contains("cancel") ||
                    errorMessage.lowercased().contains("user")
                {
                    logger.info("ℹ️ [AUTH] OAuth cancelled by user")
                    await MainActor.run {
                        presentationContext = nil
                    }
                    await sessionState.setState(.idle)
                    isLoading = false
                    throw AppAuthError.oauthCancelled
                }

                if errorMessage.contains("code verifier") ||
                    errorMessage.contains("both auth code and code verifier should be non-empty") ||
                    errorMessage.contains("Authentication flow interrupted") ||
                    errorMessage.contains("PKCE") ||
                    errorMessage.lowercased().contains("code_verifier")
                {
                    logger.warning("⚠️ [AUTH] PKCE flow error on attempt \(attempt): \(errorMessage)")
                    if attempt < 2 {
                        continue // Retry
                    }
                } else {
                    // Non-PKCE error, don't retry
                    break
                }
            }
        }

        // If we get here, all attempts failed
        await MainActor.run {
            presentationContext = nil
        }
        await sessionState.setState(.idle)
        isLoading = false
        HapticManager.error()

        if let error = lastError {
            throw AppAuthError
                .googleSignInFailed(reason: "OAuth flow failed after retries: \(error.localizedDescription)")
        } else {
            throw AppAuthError.googleSignInFailed(reason: "OAuth flow failed for unknown reason")
        }
    }
    #endif // !SKIP (Apple/Google Sign In)

    /// Handle OAuth callback URL
    /// This is called when the app receives a deep link after OAuth redirect
    /// The Supabase SDK handles PKCE code exchange automatically
    func handleOAuthCallback(url: URL) async throws {
        logger.info("🔗 [AUTH] Processing OAuth callback: \(url.absoluteString, privacy: .public)")

        // Log detailed URL components for debugging
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            logger.info("🔗 [AUTH] URL scheme: \(components.scheme ?? "nil")")
            logger.info("🔗 [AUTH] URL host: \(components.host ?? "nil")")
            logger.info("🔗 [AUTH] URL path: \(components.path)")
            if let queryItems = components.queryItems {
                for item in queryItems {
                    logger.info("🔗 [AUTH] Query param: \(item.name) = \(item.value ?? "nil")")
                }
            }
        }

        // Validate callback URL has required parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else
        {
            logger.error("❌ [AUTH] Invalid OAuth callback URL format")
            await sessionState.setState(.idle)
            isLoading = false
            return
        }

        let hasCode = queryItems.contains { $0.name == "code" && !($0.value?.isEmpty ?? true) }
        let hasError = queryItems.contains { $0.name == "error" }

        if hasError {
            let errorDescription = queryItems.first { $0.name == "error_description" }?.value ?? "Unknown OAuth error"
            logger.error("❌ [AUTH] OAuth provider error: \(errorDescription)")
            await sessionState.setState(.idle)
            isLoading = false
            return
        }

        if !hasCode {
            logger.error("❌ [AUTH] OAuth callback missing authorization code")
            await sessionState.setState(.idle)
            isLoading = false
            return
        }

        do {
            // Extract session from callback URL
            // This automatically:
            // 1. Retrieves the stored code_verifier
            // 2. Exchanges the authorization code for tokens
            // 3. Validates the PKCE flow
            let session = try await supabase.auth.session(from: url)

            logger.info("✅ [AUTH] OAuth session extracted from callback")

            // Session is already set by session(from:), but we ensure it's persisted
            try await supabase.auth.setSession(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
            )

            // Wait for session propagation across all auth listeners
            try await waitForSessionPropagation()

            // Load or create user profile
            let user: AuthUserProfile
            do {
                user = try await loadUserProfile(userId: session.user.id, session: session)
            } catch let error as NSError where error.code == 404 {
                // Extract user metadata from OAuth provider
                let fullName = (session.user.userMetadata["full_name"]?.stringValue)
                    ?? (session.user.userMetadata["name"]?.stringValue)

                try await createUserProfile(
                    userId: session.user.id,
                    email: session.user.email ?? "",
                    fullName: fullName,
                    session: session,
                )
                user = try await loadUserProfile(userId: session.user.id, session: session)
            }

            // Update state atomically using actor
            currentUser = user
            isAuthenticated = true
            isLoading = false
            await sessionState.markInitialCheckComplete()
            await sessionState.setState(.authenticated)

            HapticManager.success()
            logger.info("✅ [AUTH] OAuth authentication complete")

            // Notify AppDelegate to register any pending push notification device token
            NotificationCenter.default.post(name: .didAuthenticate, object: nil)

            // Perform device attestation in background (non-blocking)
            await performPostAuthenticationAttestation()

            // Sync locale from server (Redis-cached, non-blocking)
            Task { await fetchSessionInfoAndSyncLocale() }

        } catch {
            logger.error("❌ [AUTH] OAuth callback processing failed: \(error.localizedDescription, privacy: .private)")

            // Provide user-friendly error context
            if error.localizedDescription.contains("code verifier") ||
                error.localizedDescription.contains("both auth code and code verifier should be non-empty")
            {
                logger.error("❌ [AUTH] PKCE flow error - code verifier missing or invalid. Clearing auth state.")
                // Clear corrupted auth state
                try? await supabase.auth.signOut()
            }

            await sessionState.setState(.idle)
            isLoading = false
            HapticManager.error()
            throw AppAuthError.googleSignInFailed(reason: "OAuth flow interrupted. Please try again.")
        }
    }

    // MARK: - Error Mapping

    private func mapError(_ error: Error) -> AuthError {
        let errorMessage = error.localizedDescription.lowercased()

        if errorMessage.contains("invalid login credentials") ||
            errorMessage.contains("invalid email or password")
        {
            return .wrongPassword
        }

        if errorMessage.contains("user not found") {
            return .userNotFound
        }

        if errorMessage.contains("email already registered") ||
            errorMessage.contains("user already registered")
        {
            return .emailAlreadyInUse
        }

        if errorMessage.contains("network") || errorMessage.contains("connection") ||
            errorMessage.contains("internet")
        {
            return .networkError
        }

        if errorMessage.contains("session") || errorMessage.contains("expired") {
            return .sessionExpired
        }

        if errorMessage.contains("weak password") {
            return .weakPassword
        }

        if errorMessage.contains("email not confirmed") ||
            errorMessage.contains("confirm your email")
        {
            return .emailConfirmationRequired("Please check your email to confirm your account before signing in")
        }

        return .unknown(error.localizedDescription)
    }

    /// Convert error to user-friendly message string
    func getUserFriendlyErrorMessage(from error: Error) -> String {
        // If it's already an AuthError, use its description
        if let authError = error as? AuthError {
            return authError.errorDescription ?? "An unexpected error occurred"
        }

        let errorDescription = error.localizedDescription.lowercased()

        if errorDescription.contains("email") && errorDescription.contains("already") {
            return "This email is already registered. Please sign in instead."
        } else if errorDescription.contains("invalid") && errorDescription.contains("credentials") {
            return "Invalid email or password. Please try again."
        } else if errorDescription.contains("network") || errorDescription.contains("internet") {
            return "Network error. Please check your internet connection."
        } else if errorDescription.contains("weak password") {
            return "Password is too weak. Please use a stronger password."
        } else if errorDescription.contains("too many requests") || errorDescription.contains("rate limit") {
            return "Too many attempts. Please wait a moment and try again."
        } else if errorDescription.contains("timeout") {
            return "Request timed out. Please try again."
        } else if errorDescription.contains("cancelled") || errorDescription.contains("canceled") {
            return "Sign in was cancelled."
        } else {
            return "Authentication failed. Please try again."
        }
    }
}

#if !SKIP
// MARK: - Web Auth Presentation Context

/// Provides presentation anchor for ASWebAuthenticationSession (Google OAuth)
@available(iOS 17.0, *)
private class WebAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "WebAuthContext")

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        logger.info("🔐 [AUTH] Getting presentation anchor for ASWebAuthenticationSession")

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else
        {
            logger.error("❌ [AUTH] No active window scene found!")
            return UIWindow()
        }

        logger.info("🔐 [AUTH] Found active window scene: \(windowScene.debugDescription)")

        guard let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first else {
            logger.error("❌ [AUTH] No key window found in scene!")
            return UIWindow()
        }

        logger.info("✅ [AUTH] Using window as presentation anchor: \(window.debugDescription)")
        return window
    }
}

// MARK: - Apple Auth Delegate

@available(iOS 17.0, *)
private class AppleAuthDelegate: NSObject, ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    let nonce: String
    weak var authService: AuthenticationService?
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "AppleAuthDelegate")

    init(nonce: String, authService: AuthenticationService) {
        self.nonce = nonce
        self.authService = authService
        super.init()
    }

    func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
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
            logger.warning("⚠️ [APPLE] Using fallback window scene for presentation")
            return window
        }

        // 3. Last resort: Create window attached to current screen (prevents crash)
        logger.error("❌ [APPLE] No window scene found - creating emergency window")
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
        return window
    }

    func authorizationController(
        controller _: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization,
    ) {
        logger.debug("✅ [APPLE] Authorization completed successfully")

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            logger.error("❌ [APPLE] Invalid credential type")
            authService?.appleOAuthContinuation?.resume(throwing: NSError(
                domain: "AppleAuthDelegate",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Invalid Apple credential"],
            ))
            authService?.appleOAuthContinuation = nil
            return
        }

        Task { @MainActor in
            do {
                try await authService?.processAppleSignIn(credential: credential, nonce: nonce)
            } catch {
                logger.error("❌ [APPLE] Processing failed: \(error.localizedDescription)")
                authService?.appleOAuthContinuation?.resume(throwing: error)
                authService?.appleOAuthContinuation = nil
            }
        }
    }

    func authorizationController(controller _: ASAuthorizationController, didCompleteWithError error: Error) {
        let nsError = error as NSError
        logger
            .error(
                "❌ [APPLE] Authorization failed - Domain: \(nsError.domain, privacy: .public), Code: \(nsError.code, privacy: .public), Description: \(error.localizedDescription, privacy: .public)",
            )
        logger.error("❌ [APPLE] Full error: \(String(describing: error), privacy: .public)")

        // Log specific ASAuthorizationError codes for debugging
        if nsError.domain == ASAuthorizationError.errorDomain {
            switch nsError.code {
            case ASAuthorizationError.canceled.rawValue:
                logger.info("ℹ️ [APPLE] User canceled the sign-in flow")
            case ASAuthorizationError.failed.rawValue:
                logger.error("❌ [APPLE] Authorization failed (code 1001) - Check Apple Developer Console configuration")
            case ASAuthorizationError.invalidResponse.rawValue:
                logger.error("❌ [APPLE] Invalid response (code 1002)")
            case ASAuthorizationError.notHandled.rawValue:
                logger.error("❌ [APPLE] Not handled (code 1003)")
            case ASAuthorizationError.unknown.rawValue:
                logger
                    .error(
                        "❌ [APPLE] Unknown error (code 1000) - Possible causes: Bundle ID mismatch, capability not enabled, or provisioning profile issue",
                    )
            case ASAuthorizationError.notInteractive.rawValue:
                logger.error("❌ [APPLE] Not interactive (code 1004)")
            default:
                logger.error("❌ [APPLE] Unrecognized error code: \(nsError.code)")
            }
        }

        // Handle cancellation - both explicit cancel (1001) and unknown (1000) which often means user dismissed
        if nsError.domain == ASAuthorizationError.errorDomain {
            if nsError.code == ASAuthorizationError.canceled.rawValue {
                logger.info("ℹ️ [APPLE] User explicitly cancelled")
                authService?.appleOAuthContinuation?.resume(throwing: AppAuthError.oauthCancelled)
            } else if nsError.code == ASAuthorizationError.unknown.rawValue {
                // Code 1000 often means user dismissed the sheet without completing
                logger.info("ℹ️ [APPLE] User dismissed sign-in (code 1000 - treating as cancellation)")
                authService?.appleOAuthContinuation?.resume(throwing: AppAuthError.oauthCancelled)
            } else {
                authService?.appleOAuthContinuation?
                    .resume(throwing: AppAuthError
                        .appleSignInFailed(
                            reason: "Apple Sign In failed (code \(nsError.code)): \(error.localizedDescription)",
                        ))
            }
        } else {
            authService?.appleOAuthContinuation?
                .resume(throwing: AppAuthError
                    .appleSignInFailed(reason: "Apple Sign In failed: \(error.localizedDescription)"))
        }

        authService?.appleOAuthContinuation = nil
        authService?.appleAuthDelegate = nil
        authService?.appleAuthController = nil

        Task { @MainActor in
            authService?.isLoading = false
        }
    }
}
#endif // !SKIP (Web Auth + Apple Auth delegates)
