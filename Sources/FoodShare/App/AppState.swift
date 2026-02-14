//
//  AppState.swift
//  Foodshare
//
//  Global app state with Clean Architecture
//  Delegates authentication to AuthenticationService singleton
//

#if !SKIP
import CoreLocation
#endif
import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class AppState {
    // MARK: - State

    var showError = false
    var error: AppError?
    var showAuthentication = false

    // MARK: - Deep Link Navigation State

    /// Active deep link destination
    var deepLinkDestination: DeepLinkDestination?

    /// Enum defining all possible deep link destinations
    enum DeepLinkDestination: Hashable {
        // Content
        case listing(Int)
        case profile(UUID)
        case messages
        case messageRoom(String) // Room ID
        case challenge(Int)
        case forumPost(Int)
        case map(Double?, Double?) // Optional lat/lng coordinates

        // User
        case myPosts
        case myPost(Int)
        case chat
        case chatRoom(String)
        case settings
        case settingsSection(String)
        case notifications

        // Community
        case donation
        case help
        case feedback

        // Legal
        case privacy
        case terms

        /// Actions
        case createListing
    }

    // MARK: - Services

    let authService: AuthenticationService
    let locationManager: LocationManager
    let widgetDataProvider: WidgetDataProvider
    let dependencies: DependencyContainer

    // NOTE: guestManager is now injected via @StateObject/@EnvironmentObject (CareEcho pattern)
    // NOTE: onboardingManager is replaced by @AppStorage("hasCompletedOnboarding") (CareEcho pattern)

    // MARK: - Computed Properties (Delegate to AuthService)

    var isAuthenticated: Bool {
        authService.isAuthenticated
    }

    var currentUser: AuthUserProfile? {
        authService.currentUser
    }

    var isLoading: Bool {
        authService.isLoading
    }

    /// Whether the current user's email has been verified
    var isEmailVerified: Bool {
        authService.isEmailVerified
    }

    /// Current user's email address (for verification display)
    var currentUserEmail: String? {
        authService.currentUserEmail ?? authService.currentUser?.email
    }

    // MARK: - Subscription (Delegate to StoreKitService)

    /// Whether the current user has an active premium subscription
    var isPremium: Bool {
        StoreKitService.shared.isPremium
    }

    /// StoreKit service for subscription management
    var storeKitService: StoreKitService {
        .shared
    }

    // MARK: - Initialization

    init(
        authService: AuthenticationService = .shared,
        locationManager: LocationManager = LocationManager(),
        widgetDataProvider: WidgetDataProvider = .shared,
        dependencies: DependencyContainer? = nil,
    ) {
        self.authService = authService
        self.locationManager = locationManager
        self.widgetDataProvider = widgetDataProvider
        self.dependencies = dependencies ?? DependencyContainer.create(from: authService)
        // Note: guestManager is now injected via @StateObject/@EnvironmentObject (CareEcho pattern)
        // Note: Session check is handled by RootView with proper guards
    }

    // MARK: - Widget Data

    /// Refresh widget data with current user and location
    func refreshWidgetData() async {
        let userId = currentUser?.id
        let location = locationManager.currentLocation?.coordinate
        await widgetDataProvider.updateAllWidgetData(userId: userId, userLocation: location)
    }

    // MARK: - Auth Actions (Delegate to AuthService)

    func signIn(email: String, password: String) async throws {
        try await authService.signIn(email: email, password: password)
    }

    func signUp(email: String, password: String, nickname: String?) async throws {
        try await authService.signUp(email: email, password: password, name: nickname)
    }

    func signOut() async {
        await authService.signOut()
        // Clear widget data on sign out
        widgetDataProvider.clearAllWidgetData()
    }

    func signInWithApple(presentationAnchor: ASPresentationAnchor) async throws {
        try await authService.signInWithApple(presentationAnchor: presentationAnchor)
    }

    func signInWithGoogle() async throws {
        try await authService.signInWithGoogle()
    }

    func resetPassword(email: String) async throws {
        try await authService.resetPassword(email: email)
    }

    func handleOAuthCallback(url: URL) async {
        do {
            try await authService.handleOAuthCallback(url: url)
        } catch {
            await AppLogger.shared.error("❌ [APP] OAuth callback failed: \(error.localizedDescription)")
        }
    }

    func updateProfile(name: String? = nil, avatarUrl: String? = nil) async throws {
        try await authService.updateProfile(name: name, avatarUrl: avatarUrl)
    }

    func reloadUserProfile() async throws {
        try await authService.reloadUserProfile()
    }

    func deleteAccount() async throws {
        try await authService.deleteAccount()
    }

    // MARK: - Preferences

    /// Update search radius preference (syncs to backend if needed)
    func updateSearchRadius(_ radius: Double) async throws {
        // For now, just store locally via PreferencesService
        // In the future, could sync to user profile in database
        await AppLogger.shared.debug("Search radius updated to \(radius)")
    }

    /// Update notification preferences (syncs to backend)
    func updateNotificationPreferences(push: Bool, messages: Bool, likes: Bool) async throws {
        // For now, just log
        // In the future, sync to user profile in database
        await AppLogger.shared
            .debug("Notification preferences updated: push=\(push), messages=\(messages), likes=\(likes)")
    }

    func dismissError() {
        error = nil
        showError = false
    }

    // MARK: - Email Verification (CareEcho-style)

    func resendVerificationEmail() async throws {
        try await authService.resendVerificationEmail()
    }

    func checkEmailVerificationStatus() async -> Bool {
        await authService.checkEmailVerificationStatus()
    }

    // NOTE: Guest mode methods are now handled directly through GuestManager (CareEcho pattern)
    // Use guestManager.enableGuestMode() and guestManager.disableGuestMode() via @EnvironmentObject

    // MARK: - Deep Link Navigation

    /// Navigate to a specific listing
    func navigateToListing(_ listingId: Int) {
        deepLinkDestination = .listing(listingId)
    }

    /// Navigate to a user profile
    func navigateToProfile(_ profileId: UUID) {
        deepLinkDestination = .profile(profileId)
    }

    /// Navigate to create listing
    func navigateToCreateListing() {
        deepLinkDestination = .createListing
    }

    /// Navigate to messages
    func navigateToMessages() {
        deepLinkDestination = .messages
    }

    /// Navigate to a challenge
    func navigateToChallenge(_ challengeId: Int) {
        deepLinkDestination = .challenge(challengeId)
    }

    /// Navigate to a forum post
    func navigateToForumPost(_ postId: Int) {
        deepLinkDestination = .forumPost(postId)
    }

    /// Navigate to map with optional coordinates
    func navigateToMap(latitude: Double? = nil, longitude: Double? = nil) {
        deepLinkDestination = .map(latitude, longitude)
    }

    /// Clear the current deep link destination after navigation is complete
    func clearDeepLinkDestination() {
        deepLinkDestination = nil
    }
}

// MARK: - Factory

extension AppState {
    static func create() throws -> AppState {
        // Validate environment configuration
        guard AppEnvironment.supabaseURL != nil,
              AppEnvironment.supabasePublishableKey != nil else
        {
            throw AppError.configurationError("Supabase configuration missing")
        }

        // AuthenticationService.shared handles its own Supabase client
        return AppState()
    }
}

// MARK: - Preview Support

extension AppState {
    /// Creates a mock AppState for previews
    static var preview: AppState {
        AppState()
    }
}

// MARK: - ASPresentationAnchor Import

#if !SKIP
import AuthenticationServices
#endif
