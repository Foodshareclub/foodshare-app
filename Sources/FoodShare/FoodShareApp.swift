//
//  FoodShareApp.swift
//  FoodShare - Skip Cross-Platform App
//
//  App entry point using modern Swift 6.2 @Observable pattern
//  Uses @State for @Observable objects and @Environment for dependency injection
//
//  Mirrors iOS FoodshareApp.swift initialization, skipping platform-specific code
//

import SwiftUI

#if !SKIP
import OSLog
import Supabase

// Entry point when building through SPM directly (not through Xcode target)
@main
struct FoodShareApp: App {
    // MARK: - AppDelegate for Push Notifications (iOS only)

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Dependencies (Modern @State + @Observable pattern)

    @State private var guestManager = GuestManager()

    /// AppState for @Environment(AppState.self) views (iOS 17+ @Observable pattern)
    @State private var appState: AppState

    /// FeedViewModel - shared across all tabs for search radius and feed state consistency
    /// Non-optional to guarantee availability in environment (prevents crashes in child views)
    @State private var feedViewModel: FeedViewModel

    // Enterprise infrastructure
    @State private var showRecoveryBanner = false
    @State private var pendingOperationsCount = 0

    // App lock
    @State private var appLockService = AppLockService.shared

    @Environment(\.scenePhase) private var scenePhase

    @State private var authViewModel = AuthViewModel(
        supabase: AuthenticationService.shared.supabase,
    )

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "FoodShareApp")

    init() {
        // Initialize AppState first (provides DependencyContainer)
        let initialAppState = AppState()
        _appState = State(initialValue: initialAppState)

        // Initialize FeedViewModel synchronously to guarantee non-nil in environment
        // Uses guestManager's initial state (not guest mode) and nil user (not authenticated yet)
        let deps = initialAppState.dependencies
        let initialFeedViewModel = FeedViewModel(
            dataService: deps.feedDataService,
            translationService: deps.feedTranslationService,
            searchRadiusService: FeedSearchRadiusService(
                profileRepository: deps.profileRepository,
                getCurrentUserId: { [weak initialAppState] in initialAppState?.currentUser?.id },
                isGuestMode: false
            ),
            preferencesService: deps.feedPreferencesService,
        )
        _feedViewModel = State(initialValue: initialFeedViewModel)

        configureAppearance()

        logger.info("FoodShare app initialized")
    }

    /// Performs async initialization tasks on app launch
    private func performInitialization() async {
        // Initialize structured logging with persistence
        await AppLogger.shared.initialize()

        // Initialize crash reporting (Sentry)
        await CrashReporter.shared.configure()

        // Load remote app configuration from Supabase
        let supabase = SupabaseClient(
            supabaseURL: URL(string: AppEnvironment.supabaseURL ?? "https://api.foodshare.club")!,
            supabaseKey: AppEnvironment.supabasePublishableKey ?? "example-key",
        )
        await AppConfiguration.shared.loadFromServer(supabase: supabase)

        // Load feature flags from Supabase
        do {
            try await FeatureFlagManager.shared.refresh()
            logger.info("Feature flags loaded successfully")
        } catch {
            logger.error("Failed to load feature flags: \(error.localizedDescription)")
        }

        // Check for session restoration
        await checkSessionRestoration()
    }

    /// Checks if there's a previous session to restore
    private func checkSessionRestoration() async {
        let stateRestoration = AppStateRestoration.shared

        if await stateRestoration.hasSessionToRestore() {
            let operations = await stateRestoration.getRestorationPendingOperations()

            await MainActor.run {
                pendingOperationsCount = operations.count
                showRecoveryBanner = true
            }

            await stateRestoration.markSessionRestored()
            logger.info("Session restoration available with \(operations.count) pending operations")
        }

        // Load user preferences if authenticated (syncs theme across devices)
        if AuthenticationService.shared.isAuthenticated {
            await UserPreferencesService.shared.loadPreferences()
            logger.info("User preferences loaded on app startup")
        }
    }

    var body: some Scene {
        WindowGroup {
            // Modern @Observable pattern: Uses .environment() for @Observable objects
            ZStack {
                RootView()
                    .environment(appState)
                    .environment(authViewModel)
                    .environment(guestManager)
                    .environment(feedViewModel) // Shared FeedViewModel for all tabs
                    .withTheme() // Enterprise theme system with dark/light support
                    .onOpenURL { url in
                        handleDeepLink(url: url)
                    }

                // Session recovery banner overlay
                GlassRecoveryBanner(
                    isVisible: $showRecoveryBanner,
                    pendingOperationsCount: pendingOperationsCount,
                    onDismiss: {
                        logger.info("Recovery banner dismissed")
                    },
                    onRetryOperations: {
                        Task {
                            await processPendingOperations()
                        }
                    },
                )
            }
            .task {
                await performInitialization()
                // FeedViewModel is initialized in init() to guarantee non-nil in environment
                // Recreate with current guest mode state now that app is fully initialized
                reinitializeFeedViewModel()
            }
            .onChange(of: scenePhase) { _, newPhase in
                appLockService.handleScenePhase(newPhase)
            }
            .onChange(of: appState.isAuthenticated) { _, _ in
                // Recreate FeedViewModel when auth state changes to update user context
                reinitializeFeedViewModel()
            }
            .onChange(of: guestManager.isGuestMode) { _, _ in
                // Recreate FeedViewModel when guest mode changes
                reinitializeFeedViewModel()
            }
            .overlay {
                // App lock overlay (iOS only - uses biometric authentication)
                if appLockService.isLocked {
                    AppLockOverlay()
                        .transition(.opacity)
                }
            }
        }
    }

    // MARK: - FeedViewModel Reinitialization

    /// Recreates FeedViewModel with current auth/guest state
    /// Called when auth state or guest mode changes to ensure correct user context
    /// Initial creation happens in init() to guarantee non-nil in environment
    private func reinitializeFeedViewModel() {
        let deps = appState.dependencies
        feedViewModel = FeedViewModel(
            dataService: deps.feedDataService,
            translationService: deps.feedTranslationService,
            searchRadiusService: FeedSearchRadiusService(
                profileRepository: deps.profileRepository,
                getCurrentUserId: { [weak appState] in appState?.currentUser?.id },
                isGuestMode: guestManager.isGuestMode
            ),
            preferencesService: deps.feedPreferencesService,
        )
        logger
            .info(
                "FeedViewModel reinitialized (guest: \(guestManager.isGuestMode), authenticated: \(appState.isAuthenticated))",
            )
    }

    // MARK: - App Lock Overlay

    /// Overlay shown when the app is locked
    struct AppLockOverlay: View {
        @State private var appLockService = AppLockService.shared
        @State private var isAuthenticating = false

        var body: some View {
            ZStack {
                // Background blur
                Color.DesignSystem.background
                    .ignoresSafeArea()

                VStack(spacing: Spacing.xl) {
                    // App icon
                    Image("AppIcon")
                        .resizable()
                        .frame(width: 80.0, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

                    // Lock icon
                    Image(systemName: "lock.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.DesignSystem.textSecondary)

                    Text("Foodshare is Locked")
                        .font(.DesignSystem.headlineMedium)
                        .foregroundStyle(Color.DesignSystem.text)

                    // Unlock button
                    Button {
                        unlockApp()
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            if isAuthenticating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: appLockService.biometricIconName)
                            }
                            Text("Unlock with \(appLockService.biometricDisplayName)")
                        }
                        .font(.DesignSystem.bodyMedium.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.vertical, Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(
                                    LinearGradient(
                                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandTeal],
                                        startPoint: .leading,
                                        endPoint: .trailing,
                                    ),
                                ),
                        )
                    }
                    .disabled(isAuthenticating)

                    // Error message
                    if let error = appLockService.lastError {
                        Text(error)
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
            .onAppear {
                // Auto-trigger unlock on appear
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    await unlockApp()
                }
            }
        }

        private func unlockApp() {
            isAuthenticating = true

            Task {
                await appLockService.unlock()
                isAuthenticating = false
            }
        }
    }

    /// Processes pending operations from state restoration
    private func processPendingOperations() async {
        let stateRestoration = AppStateRestoration.shared

        await stateRestoration.processRestorationPendingOperations { operation in
            // Process each pending operation based on type
            switch operation.type {
            case .createListing, .updateListing:
                logger.info("Processing pending listing operation: \(operation.id)")
                return true
            case .sendMessage:
                logger.info("Processing pending message: \(operation.id)")
                return true
            default:
                logger.info("Processing pending operation: \(operation.type.rawValue)")
                return true
            }
        }
    }

    // MARK: - Deep Link Handling

    private func handleDeepLink(url: URL) {
        logger.info("Received deep link: \(url.absoluteString)")

        // Check if this is an OAuth callback first
        let isOAuthCallback = url.scheme == "foodshare" && (
            url.host == "oauth-callback" ||
                url.host == "login-callback" ||
                url.path.contains("auth/callback") ||
                url.path.contains("oauth-callback")
        )

        if isOAuthCallback {
            logger.info("Processing OAuth callback")
            Task {
                await appState.handleOAuthCallback(url: url)
            }
            return
        }

        // Handle content deep links (Universal Links from foodshare.club)
        guard let destination = parseDeepLink(url: url) else {
            logger.warning("Unknown deep link format: \(url.absoluteString)")
            return
        }

        logger.info("Navigating to: \(String(describing: destination))")
        appState.deepLinkDestination = destination
    }

    /// Parse deep link URL into navigation destination
    private func parseDeepLink(url: URL) -> AppState.DeepLinkDestination? {
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        // Handle single-segment paths (root paths)
        if pathComponents.count == 1 {
            switch pathComponents[0] {
            // Content
            case "create":
                return .createListing
            case "messages":
                return .messages
            case "map":
                return .map(nil, nil)
            // User
            case "my-posts":
                return .myPosts
            case "chat":
                return .chat
            case "settings":
                return .settings
            case "notifications":
                return .notifications
            // Community
            case "donation":
                return .donation
            case "help":
                return .help
            case "feedback":
                return .feedback
            // Legal
            case "privacy":
                return .privacy
            case "terms":
                return .terms
            default:
                return nil
            }
        }

        // Handle multi-segment paths
        guard pathComponents.count >= 2 else { return nil }

        let type = pathComponents[0]
        let idString = pathComponents[1]

        switch type {
        // Content paths
        case "listing", "food", "item":
            if let id = Int(idString) {
                return .listing(id)
            }
        case "profile", "user":
            if let uuid = UUID(uuidString: idString) {
                return .profile(uuid)
            }
        case "challenge":
            if let id = Int(idString) {
                return .challenge(id)
            }
        case "post", "forum":
            if let id = Int(idString) {
                return .forumPost(id)
            }
        case "fridge":
            if let id = Int(idString) {
                return .listing(id)
            }
        case "map":
            let coords = idString.split(separator: ",")
            if coords.count == 2,
               let lat = Double(coords[0]),
               let lng = Double(coords[1])
            {
                return .map(lat, lng)
            }
            return .map(nil, nil)
        case "messages":
            return .messageRoom(idString)
        // User paths
        case "my-posts":
            if let id = Int(idString) {
                return .myPost(id)
            }
        case "chat":
            return .chatRoom(idString)
        case "settings":
            return .settingsSection(idString)
        default:
            break
        }

        return nil
    }

    // MARK: - Appearance Configuration (iOS UIKit only)

    private func configureAppearance() {
        // Apply Liquid Glass design system to UIKit components
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: UIColor(Color.DesignSystem.text),
        ]
        UINavigationBar.appearance().titleTextAttributes = [
            .foregroundColor: UIColor(Color.DesignSystem.text),
        ]

        // Tab bar styling with macOS-style warm charcoal background
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0x1E / 255, green: 0x1E / 255, blue: 0x1E / 255, alpha: 1)
                : .systemBackground
        }
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().unselectedItemTintColor = UIColor(Color.DesignSystem.textSecondary)

        // Navigation bar styling with macOS-style warm charcoal background
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0x1E / 255, green: 0x1E / 255, blue: 0x1E / 255, alpha: 1)
                : .systemBackground
        }
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.DesignSystem.text)]
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.DesignSystem.text)]
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
    }
}

#else
// MARK: - Android Entry Point (Skip)
// Skip generates the Android Activity; FoodShareApp provides the root View content.
// App protocol is not yet supported in Skip Fuse — use View conformance instead.

public struct FoodShareApp: View {
    @State private var appState: AppState = AppState()
    @State private var authViewModel: AuthViewModel = AuthViewModel()
    @State private var guestManager: GuestManager = GuestManager()
    @State private var feedViewModel: FeedViewModel = FeedViewModel()

    public init() {}

    public var body: some View {
        RootView()
            .environment(appState)
            .environment(authViewModel)
            .environment(guestManager)
            .environment(feedViewModel)
    }
}
#endif
