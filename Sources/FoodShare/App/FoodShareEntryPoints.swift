//
//  FoodShareEntryPoints.swift
//  FoodShare
//
//  Public entry points used by Darwin/Sources/Main.swift (the Xcode app target).
//  Provides FoodShareRootView and FoodShareAppDelegate expected by Skip Fuse's Main.swift.
//


#if !SKIP
import OSLog
import Supabase
import SwiftUI

/// The root view exposed to the Xcode app target.
public struct FoodShareRootView: View {
    @State private var appState: AppState
    @State private var guestManager = GuestManager()
    @State private var authViewModel = AuthViewModel(
        supabase: AuthenticationService.shared.supabase
    )
    @State private var feedViewModel: FeedViewModel
    @State private var showRecoveryBanner = false
    @State private var pendingOperationsCount = 0
    #if !SKIP
    @State private var appLockService = AppLockService.shared
    @Environment(\.scenePhase) private var scenePhase
    #endif

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "FoodShareRootView")

    public init() {
        let initialAppState = AppState()
        let deps = initialAppState.dependencies
        _appState = State(initialValue: initialAppState)
        _feedViewModel = State(initialValue: FeedViewModel(
            dataService: deps.feedDataService,
            translationService: deps.feedTranslationService,
            searchRadiusService: FeedSearchRadiusService(
                profileRepository: deps.profileRepository,
                getCurrentUserId: { [weak initialAppState] in initialAppState?.currentUser?.id },
                isGuestMode: false
            ),
            preferencesService: deps.feedPreferencesService
        ))
    }

    public var body: some View {
        ZStack {
            RootView()
                .environment(appState)
                .environment(authViewModel)
                .environment(guestManager)
                .environment(feedViewModel)
                .withTheme()

            GlassRecoveryBanner(
                isVisible: $showRecoveryBanner,
                pendingOperationsCount: pendingOperationsCount,
                onDismiss: {},
                onRetryOperations: {}
            )
        }
        .task {
            await AppLogger.shared.initialize()
            await CrashReporter.shared.configure()
            let supabase = SupabaseClient(
                supabaseURL: URL(string: AppEnvironment.supabaseURL ?? "https://api.foodshare.club")!,
                supabaseKey: AppEnvironment.supabasePublishableKey ?? "example-key"
            )
            await AppConfiguration.shared.loadFromServer(supabase: supabase)
            do {
                try await FeatureFlagManager.shared.refresh()
            } catch {
                logger.error("Failed to load feature flags: \(error.localizedDescription)")
            }
            if AuthenticationService.shared.isAuthenticated {
                await UserPreferencesService.shared.loadPreferences()
            }
        }
    }
}

/// Lifecycle delegate exposed to the Xcode app target.
public final class FoodShareAppDelegate: @unchecked Sendable {
    public static let shared = FoodShareAppDelegate()
    private init() {}

    public func onInit() {}
    public func onLaunch() {}
    public func onResume() {}
    public func onPause() {}
    public func onStop() {}
    public func onDestroy() {}
    public func onLowMemory() {}
}

#endif
