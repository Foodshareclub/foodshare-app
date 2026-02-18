//
//  AppDelegate.swift
//  Foodshare
//
//  AppDelegate for handling push notifications and APNs registration
//  iOS-only (wrapped in #if !SKIP)
//


#if !SKIP
import Foundation
import OSLog
import UIKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "AppDelegate")

    // MARK: - Application Lifecycle

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        logger.info("[AppDelegate] Application did finish launching")

        // Initialize core services
        initializeCoreServices()

        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Register for remote notifications
        registerForPushNotifications()

        // Listen for authentication events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthentication),
            name: .didAuthenticate,
            object: nil
        )

        return true
    }

    // MARK: - Core Services Initialization

    private func initializeCoreServices() {
        NetworkMonitor.shared.start()
        _ = ErrorRecoveryService.shared
        _ = SyncManager.shared

        Task {
            await StoreKitService.shared.checkSubscriptionStatus()
        }

        CacheWarmingService.shared.warmCaches()
    }

    @objc private func handleAuthentication() {
        logger.info("[AppDelegate] User authenticated")
        Task {
            await UserPreferencesService.shared.loadPreferences()
            if let userId = AuthenticationService.shared.currentUser?.id {
                await CacheWarmingService.shared.warmAuthenticatedCaches(userId: userId)
            }
        }
    }

    // MARK: - Push Notification Registration

    private func registerForPushNotifications() {
        Task {
            do {
                let center = UNUserNotificationCenter.current()
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])

                if granted {
                    await MainActor.run {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            } catch {
                logger.error("[AppDelegate] Failed to request push authorization: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - APNs Token Callbacks

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        logger.info("[AppDelegate] Received APNs device token: \(tokenString.prefix(20))...")

        Task {
            if let userId = AuthenticationService.shared.currentUser?.id {
                let pushService = PushNotificationService(supabase: AuthenticationService.shared.supabase)
                try? await pushService.registerDeviceToken(deviceToken, for: userId)
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        logger.error("[AppDelegate] Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let notificationType = userInfo["type"] as? String
        let postId = userInfo["postId"] as? String
        let roomId = userInfo["roomId"] as? String
        let forumId = userInfo["forumId"] as? String

        Task { @MainActor in
            self.handleNotificationTap(
                type: notificationType,
                postId: postId,
                roomId: roomId,
                forumId: forumId
            )
        }

        completionHandler()
    }

    private func handleNotificationTap(
        type: String?,
        postId: String?,
        roomId: String?,
        forumId: String?
    ) {
        guard let typeString = type else { return }

        var userInfo: [AnyHashable: Any] = ["type": typeString]
        if let postId { userInfo["postId"] = postId }
        if let roomId { userInfo["roomId"] = roomId }
        if let forumId { userInfo["forumId"] = forumId }

        NotificationCenter.default.post(
            name: .didReceivePushNotification,
            object: nil,
            userInfo: userInfo
        )
    }
}

#endif
