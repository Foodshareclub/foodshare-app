//
//  ErrorRecoveryService.swift
//  Foodshare
//
//  Centralized error recovery and user notification service
//  Provides automatic retry logic, auth recovery, and toast notifications
//


#if !SKIP
import Foundation
import OSLog
import SwiftUI

// MARK: - Recoverable Error Types

/// Categorized error types for error recovery and handling
enum RecoverableError: Error, LocalizedError, Sendable {
    // Network errors
    case networkUnavailable
    case timeout
    case serverError(statusCode: Int, message: String?)
    case rateLimited(retryAfter: TimeInterval?)

    // Auth errors
    case sessionExpired
    case invalidCredentials
    case unauthorized
    case mfaRequired

    // Data errors
    case notFound(resource: String)
    case validationFailed(field: String, reason: String)
    case conflict(message: String)
    case dataCorrupted

    // Storage errors
    case uploadFailed(reason: String)
    case downloadFailed(reason: String)
    case quotaExceeded

    // Generic
    case unknown(underlying: Error?)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            "No internet connection. Please check your network settings."
        case .timeout:
            "Request timed out. Please try again."
        case let .serverError(code, message):
            message ?? "Server error (\(code)). Please try again later."
        case let .rateLimited(retryAfter):
            if let seconds = retryAfter {
                "Too many requests. Please wait \(Int(seconds)) seconds."
            } else {
                "Too many requests. Please try again later."
            }
        case .sessionExpired:
            "Your session has expired. Please sign in again."
        case .invalidCredentials:
            "Invalid email or password."
        case .unauthorized:
            "You don't have permission to perform this action."
        case .mfaRequired:
            "Two-factor authentication is required."
        case let .notFound(resource):
            "\(resource) not found."
        case let .validationFailed(field, reason):
            "\(field): \(reason)"
        case let .conflict(message):
            message
        case .dataCorrupted:
            "Data appears to be corrupted. Please refresh."
        case let .uploadFailed(reason):
            "Upload failed: \(reason)"
        case let .downloadFailed(reason):
            "Download failed: \(reason)"
        case .quotaExceeded:
            "Storage quota exceeded."
        case let .unknown(underlying):
            underlying?.localizedDescription ?? "An unexpected error occurred."
        }
    }

    /// Whether this error is recoverable via retry
    var isRecoverable: Bool {
        switch self {
        case .networkUnavailable, .timeout, .serverError, .rateLimited:
            true
        case .sessionExpired:
            true // Can recover by re-authenticating
        case .invalidCredentials, .unauthorized, .mfaRequired:
            false // User action required
        case .notFound, .validationFailed, .conflict, .dataCorrupted:
            false
        case .uploadFailed, .downloadFailed:
            true
        case .quotaExceeded:
            false
        case .unknown:
            false
        }
    }

    /// Suggested recovery action
    var recoveryAction: RecoveryAction {
        switch self {
        case .networkUnavailable:
            .retry(delay: 2.0)
        case .timeout:
            .retry(delay: 1.0)
        case let .serverError(code, _):
            code >= 500 ? .retry(delay: 3.0) : .none
        case let .rateLimited(retryAfter):
            .retry(delay: retryAfter ?? 30.0)
        case .sessionExpired:
            .reauthenticate
        case .invalidCredentials, .unauthorized:
            .showLogin
        case .mfaRequired:
            .showMFA
        case .notFound, .conflict, .dataCorrupted:
            .refresh
        case .validationFailed:
            .none
        case .uploadFailed, .downloadFailed:
            .retry(delay: 2.0)
        case .quotaExceeded:
            .none
        case .unknown:
            .none
        }
    }
}

// MARK: - Recovery Action

enum RecoveryAction: Sendable {
    case none
    case retry(delay: TimeInterval)
    case refresh
    case reauthenticate
    case showLogin
    case showMFA
}

// MARK: - Toast Notification

/// Toast notification model for user feedback
struct ToastNotification: Identifiable, Sendable, Equatable {
    let id: UUID
    let message: String
    let style: ToastStyle
    let duration: TimeInterval
    let action: ToastAction?

    enum ToastStyle: Sendable {
        case success
        case error
        case warning
        case info

        var icon: String {
            switch self {
            case .success: "checkmark.circle.fill"
            case .error: "exclamationmark.triangle.fill"
            case .warning: "exclamationmark.circle.fill"
            case .info: "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: Color.DesignSystem.brandGreen
            case .error: Color.DesignSystem.error
            case .warning: Color.DesignSystem.warning
            case .info: Color.DesignSystem.brandBlue
            }
        }
    }

    struct ToastAction: Sendable, Equatable {
        let title: String
        let handler: @Sendable () -> Void

        static func == (lhs: ToastAction, rhs: ToastAction) -> Bool {
            lhs.title == rhs.title
        }
    }

    init(
        message: String,
        style: ToastStyle = .info,
        duration: TimeInterval = 3.0,
        action: ToastAction? = nil,
    ) {
        id = UUID()
        self.message = message
        self.style = style
        self.duration = duration
        self.action = action
    }

    static func == (lhs: ToastNotification, rhs: ToastNotification) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Error Recovery Service

/// Centralized service for error handling, recovery, and user notifications
@MainActor
@Observable
final class ErrorRecoveryService {
    static let shared = ErrorRecoveryService()

    // MARK: - Published State

    /// Current toast notifications to display
    private(set) var toasts: [ToastNotification] = []

    /// Whether a global error banner should be shown
    private(set) var showGlobalError = false
    private(set) var globalErrorMessage: String?

    /// Whether the app is in offline mode
    private(set) var isOffline = false

    /// Pending operations that failed due to network issues
    private var pendingOperations: [PendingOperation] = []

    // MARK: - Private

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "ErrorRecovery")
    private let maxRetries = 3
    private let maxToasts = 3
    private nonisolated(unsafe) var networkObserver: NSObjectProtocol?

    private init() {
        setupNetworkMonitoring()
    }

    deinit {
        if let observer = networkObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        // Listen for network status changes
        networkObserver = NotificationCenter.default.addObserver(
            forName: .networkStatusChanged,
            object: nil,
            queue: .main,
        ) { [weak self] notification in
            // Extract value before Task to avoid sending non-Sendable Notification
            guard let isConnected = notification.userInfo?["isConnected"] as? Bool else { return }
            Task { @MainActor [weak self] in
                self?.handleNetworkStatusChange(isConnected: isConnected)
            }
        }
    }

    private func handleNetworkStatusChange(isConnected: Bool) {
        let wasOffline = isOffline
        isOffline = !isConnected

        if wasOffline, isConnected {
            // Back online - show success and retry pending operations
            showToast("Back online", style: .success, duration: 2.0)
            retryPendingOperations()
        } else if !wasOffline, !isConnected {
            // Just went offline
            showToast("You're offline. Some features may be limited.", style: .warning, duration: 4.0)
        }
    }

    // MARK: - Error Classification

    /// Classify any error into a RecoverableError for consistent handling
    func classify(_ error: Error) -> RecoverableError {
        // Already classified
        if let recoverableError = error as? RecoverableError {
            return recoverableError
        }

        let nsError = error as NSError

        // Network errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return .networkUnavailable
            case NSURLErrorTimedOut:
                return .timeout
            default:
                return .unknown(underlying: error)
            }
        }

        // Supabase/Auth errors (check error description for common patterns)
        let description = error.localizedDescription.lowercased()

        if description.contains("session") && description.contains("expired") {
            return .sessionExpired
        }
        if description
            .contains("invalid") && (description.contains("credentials") || description.contains("password")) {
            return .invalidCredentials
        }
        if description.contains("unauthorized") || description.contains("401") {
            return .unauthorized
        }
        if description.contains("not found") || description.contains("404") {
            return .notFound(resource: "Resource")
        }
        if description.contains("rate limit") || description.contains("429") {
            return .rateLimited(retryAfter: nil)
        }
        if description.contains("mfa") || description.contains("two-factor") {
            return .mfaRequired
        }

        // Check for HTTP status codes in the error
        if let statusCode = extractStatusCode(from: error) {
            switch statusCode {
            case 401:
                return .unauthorized
            case 403:
                return .unauthorized
            case 404:
                return .notFound(resource: "Resource")
            case 409:
                return .conflict(message: error.localizedDescription)
            case 422:
                return .validationFailed(field: "Input", reason: error.localizedDescription)
            case 429:
                return .rateLimited(retryAfter: nil)
            case 500 ... 599:
                return .serverError(statusCode: statusCode, message: error.localizedDescription)
            default:
                break
            }
        }

        return .unknown(underlying: error)
    }

    private func extractStatusCode(from error: Error) -> Int? {
        let description = error.localizedDescription

        // Try to find status code patterns like "status: 404" or "error 500"
        let patterns = [
            #"status[:\s]+(\d{3})"#,
            #"error[:\s]+(\d{3})"#,
            #"(\d{3})\s+error"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(
                   in: description,
                   range: NSRange(description.startIndex..., in: description),
               ),
               let range = Range(match.range(at: 1), in: description) {
                return Int(description[range])
            }
        }

        return nil
    }

    // MARK: - Error Handling

    /// Handle an error with automatic recovery attempts
    /// - Parameters:
    ///   - error: The error to handle
    ///   - context: Description of what operation failed
    ///   - showNotification: Whether to show a toast notification
    ///   - retryHandler: Optional handler to call for retry attempts
    /// - Returns: The classified RecoverableError
    @discardableResult
    func handle(
        _ error: Error,
        context: String,
        showNotification: Bool = true,
        retryHandler: (@Sendable () async throws -> Void)? = nil,
    ) async -> RecoverableError {
        let appError = classify(error)

        logger.error("❌ [\(context)] \(appError.localizedDescription ?? "Unknown error")")

        // Show notification if requested
        if showNotification {
            let action: ToastNotification.ToastAction? = if let retryHandler, appError.isRecoverable {
                ToastNotification.ToastAction(title: "Retry") {
                    Task { try? await retryHandler() }
                }
            } else {
                nil
            }

            showToast(
                appError.localizedDescription ?? "An error occurred",
                style: .error,
                action: action,
            )
        }

        // Handle specific recovery actions
        switch appError.recoveryAction {
        case .reauthenticate:
            await handleSessionExpired()
        case .showLogin:
            NotificationCenter.default.post(name: .showLoginRequired, object: nil)
        case .showMFA:
            NotificationCenter.default.post(name: .showMFARequired, object: nil)
        case let .retry(delay):
            if let retryHandler {
                await scheduleRetry(after: delay, handler: retryHandler)
            }
        case .refresh, .none:
            break
        }

        return appError
    }

    /// Handle session expiration by attempting to refresh
    private func handleSessionExpired() async {
        logger.info("🔄 Attempting to refresh expired session")

        // Post notification for UI to handle
        NotificationCenter.default.post(name: .sessionExpired, object: nil)
    }

    /// Schedule a retry operation
    private func scheduleRetry(after delay: TimeInterval, handler: @Sendable @escaping () async throws -> Void) async {
        logger.debug("⏰ Scheduling retry in \(delay) seconds")

        try? await Task.sleep(for: .seconds(delay))

        do {
            try await handler()
            logger.info("✅ Retry successful")
        } catch {
            logger.error("❌ Retry failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Retry with Exponential Backoff

    /// Execute an operation with automatic retry and exponential backoff
    /// - Parameters:
    ///   - maxAttempts: Maximum number of attempts
    ///   - initialDelay: Initial delay between retries
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation
    func withRetry<T: Sendable>(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        operation: @Sendable () async throws -> T,
    ) async throws -> T {
        var lastError: Error?
        var delay = initialDelay

        for attempt in 1 ... maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                let appError = classify(error)

                // Don't retry non-recoverable errors
                guard appError.isRecoverable else {
                    throw error
                }

                // Don't retry on last attempt
                guard attempt < maxAttempts else {
                    break
                }

                logger.warning("⚠️ Attempt \(attempt)/\(maxAttempts) failed, retrying in \(delay)s")

                try? await Task.sleep(for: .seconds(delay))
                delay *= 2 // Exponential backoff
            }
        }

        throw lastError ?? RecoverableError.unknown(underlying: nil)
    }

    // MARK: - Pending Operations

    /// Queue an operation to retry when network is available
    func queueForRetry(id: String, operation: @Sendable @escaping () async throws -> Void) {
        // Remove existing operation with same ID
        pendingOperations.removeAll { $0.id == id }

        let pending = PendingOperation(id: id, operation: operation)
        pendingOperations.append(pending)

        logger.debug("📦 Queued operation for retry: \(id)")
    }

    /// Retry all pending operations
    private func retryPendingOperations() {
        guard !pendingOperations.isEmpty else { return }

        logger.info("🔄 Retrying \(self.pendingOperations.count) pending operations")

        let operations = pendingOperations
        pendingOperations.removeAll()

        for operation in operations {
            Task {
                do {
                    try await operation.operation()
                    logger.debug("✅ Pending operation succeeded: \(operation.id)")
                } catch {
                    logger.error("❌ Pending operation failed: \(operation.id)")
                    // Re-queue if still offline
                    if isOffline {
                        queueForRetry(id: operation.id, operation: operation.operation)
                    }
                }
            }
        }
    }

    // MARK: - Toast Notifications

    /// Show a toast notification
    func showToast(
        _ message: String,
        style: ToastNotification.ToastStyle = .info,
        duration: TimeInterval = 3.0,
        action: ToastNotification.ToastAction? = nil,
    ) {
        let toast = ToastNotification(
            message: message,
            style: style,
            duration: duration,
            action: action,
        )

        // Limit number of visible toasts
        if toasts.count >= maxToasts {
            toasts.removeFirst()
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            toasts.append(toast)
        }

        // Schedule auto-dismiss
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            dismissToast(toast)
        }

        // Haptic feedback
        switch style {
        case .success:
            HapticManager.success()
        case .error:
            HapticManager.error()
        case .warning:
            HapticManager.warning()
        case .info:
            HapticManager.light()
        }
    }

    /// Dismiss a specific toast
    func dismissToast(_ toast: ToastNotification) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            toasts.removeAll { $0.id == toast.id }
        }
    }

    /// Dismiss all toasts
    func dismissAllToasts() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            toasts.removeAll()
        }
    }

    // MARK: - Convenience Methods

    /// Show a success toast
    func showSuccess(_ message: String) {
        showToast(message, style: .success)
    }

    /// Show an error toast
    func showError(_ message: String) {
        showToast(message, style: .error, duration: 4.0)
    }

    /// Show a warning toast
    func showWarning(_ message: String) {
        showToast(message, style: .warning)
    }

    /// Show an info toast
    func showInfo(_ message: String) {
        showToast(message, style: .info)
    }
}

// MARK: - Pending Operation

private struct PendingOperation: Sendable {
    let id: String
    let operation: @Sendable () async throws -> Void
    let queuedAt = Date()
}

// MARK: - Notification Names
// Note: Notification names are defined in Core/Extensions/NotificationNames.swift

// MARK: - HapticManager
// HapticManager is defined in Core/Design/Utilities/HapticFeedback.swift

#endif
