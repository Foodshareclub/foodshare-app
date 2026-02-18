//
//  NotificationNames.swift
//  Foodshare
//
//  Shared notification names for cross-component communication
//


#if !SKIP
import Foundation

// MARK: - Push Notification Names

extension Notification.Name {
    /// Posted when a push notification is received
    static let didReceivePushNotification = Notification.Name("didReceivePushNotification")

    /// Posted when a device token is registered with APNs
    static let didRegisterDeviceToken = Notification.Name("didRegisterDeviceToken")

    /// Posted when a user successfully authenticates
    /// AppDelegate listens for this to register pending device tokens
    static let didAuthenticate = Notification.Name("didAuthenticate")
}

// MARK: - Error Recovery & Session Names

extension Notification.Name {
    /// Posted when network connectivity status changes
    /// UserInfo: ["isConnected": Bool]
    static let networkStatusChanged = Notification.Name("networkStatusChanged")

    /// Posted when user session has expired and requires re-authentication
    static let sessionExpired = Notification.Name("sessionExpired")

    /// Posted when app requires user to log in again
    static let showLoginRequired = Notification.Name("showLoginRequired")

    /// Posted when MFA verification is required to proceed
    static let showMFARequired = Notification.Name("showMFARequired")

    /// Posted when an operation should be retried
    /// UserInfo: ["operationId": String]
    static let retryOperation = Notification.Name("retryOperation")
}

// MARK: - Forum Notification Names

extension Notification.Name {
    /// Posted when a forum notification is received (badge earned, reply, mention, etc.)
    static let forumNotificationReceived = Notification.Name("forumNotificationReceived")

    /// Posted when user subscribes/unsubscribes from a forum post
    static let forumSubscriptionChanged = Notification.Name("forumSubscriptionChanged")
}

#endif
