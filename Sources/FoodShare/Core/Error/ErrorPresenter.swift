//
//  ErrorPresenter.swift
//  Foodshare
//
//  Unified error presentation system for ViewModels
//
//  Provides consistent error handling across the app:
//  - Standardized error display (toast, banner, alert)
//  - Automatic retry logic
//  - Error tracking and analytics
//  - Recovery suggestions
//

import Foundation
import Observation
import OSLog
import SwiftUI
import FoodShareDesignSystem

// MARK: - Error Presentation State

/// Represents the current error state for display
enum ErrorPresentationState: Sendable, Equatable {
    /// No error to display
    case none

    /// Show a dismissible toast (minor errors)
    case toast(ErrorToast)

    /// Show a banner at top/bottom (recoverable errors)
    case banner(ErrorBanner)

    /// Show an alert dialog (blocking errors)
    case alert(ErrorAlert)

    /// Show inline error (field validation)
    case inline(String)

    var hasError: Bool {
        if case .none = self { return false }
        return true
    }
}

// MARK: - Error Display Types

/// Toast notification for minor errors
struct ErrorToast: Sendable, Equatable, Identifiable {
    let id = UUID()
    let message: String
    let style: Style
    let duration: TimeInterval
    let action: Action?

    enum Style: Sendable {
        case error, warning, info
    }

    struct Action: Sendable, Equatable {
        let title: String
        let handler: @Sendable () -> Void

        static func == (lhs: Action, rhs: Action) -> Bool {
            lhs.title == rhs.title
        }
    }

    init(
        message: String,
        style: Style = .error,
        duration: TimeInterval = 3.0,
        action: Action? = nil,
    ) {
        self.message = message
        self.style = style
        self.duration = duration
        self.action = action
    }
}

/// Banner for recoverable errors
struct ErrorBanner: Sendable, Equatable, Identifiable {
    let id = UUID()
    let title: String
    let message: String?
    let style: Style
    let isDismissible: Bool
    let retryAction: Action?
    let dismissAction: Action?

    enum Style: Sendable {
        case error, warning, offline, maintenance
    }

    struct Action: Sendable, Equatable {
        let title: String
        let handler: @Sendable () -> Void

        static func == (lhs: Action, rhs: Action) -> Bool {
            lhs.title == rhs.title
        }
    }

    init(
        title: String,
        message: String? = nil,
        style: Style = .error,
        isDismissible: Bool = true,
        retryAction: Action? = nil,
        dismissAction: Action? = nil,
    ) {
        self.title = title
        self.message = message
        self.style = style
        self.isDismissible = isDismissible
        self.retryAction = retryAction
        self.dismissAction = dismissAction
    }
}

/// Alert dialog for blocking errors
struct ErrorAlert: Sendable, Equatable, Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let primaryAction: Action
    let secondaryAction: Action?
    let isDismissible: Bool

    struct Action: Sendable, Equatable {
        let title: String
        let style: Style
        let handler: @Sendable () -> Void

        enum Style: Sendable {
            case `default`, cancel, destructive
        }

        static func == (lhs: Action, rhs: Action) -> Bool {
            lhs.title == rhs.title && lhs.style == rhs.style
        }
    }

    init(
        title: String,
        message: String,
        primaryAction: Action,
        secondaryAction: Action? = nil,
        isDismissible: Bool = true,
    ) {
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self.isDismissible = isDismissible
    }

    /// Common OK alert
    static func ok(title: String, message: String) -> ErrorAlert {
        ErrorAlert(
            title: title,
            message: message,
            primaryAction: Action(title: "OK", style: .default) {},
        )
    }

    /// Localized common OK alert
    @MainActor
    static func ok(title: String, message: String, using t: EnhancedTranslationService) -> ErrorAlert {
        ErrorAlert(
            title: title,
            message: message,
            primaryAction: Action(title: t.t("common.ok"), style: .default) {},
        )
    }

    /// Retry/Cancel alert
    static func retry(
        title: String,
        message: String,
        onRetry: @escaping @Sendable () -> Void,
    ) -> ErrorAlert {
        ErrorAlert(
            title: title,
            message: message,
            primaryAction: Action(title: "Retry", style: .default, handler: onRetry),
            secondaryAction: Action(title: "Cancel", style: .cancel) {},
        )
    }

    /// Localized Retry/Cancel alert
    @MainActor
    static func retry(
        title: String,
        message: String,
        using t: EnhancedTranslationService,
        onRetry: @escaping @Sendable () -> Void,
    ) -> ErrorAlert {
        ErrorAlert(
            title: title,
            message: message,
            primaryAction: Action(title: t.t("common.retry"), style: .default, handler: onRetry),
            secondaryAction: Action(title: t.t("common.cancel"), style: .cancel) {},
        )
    }
}

// MARK: - Error Presenting Protocol

/// Protocol for ViewModels that can present errors
///
/// Provides a standardized way to handle and display errors across the app.
///
/// Usage:
/// ```swift
/// @MainActor @Observable
/// final class MyViewModel: ErrorPresenting {
///     var errorState: ErrorPresentationState = .none
///
///     func loadData() async {
///         do {
///             let data = try await repository.fetch()
///             // ...
///         } catch {
///             presentError(error)
///         }
///     }
/// }
/// ```
@MainActor
protocol ErrorPresenting: AnyObject, Observable {
    /// Current error state for display
    var errorState: ErrorPresentationState { get set }
}

// MARK: - Default Implementation

extension ErrorPresenting {
    /// Present an error with automatic categorization
    func presentError(_ error: Error, context: ErrorContext = .general) {
        let appError = (error as? AppError) ?? AppError.from(error)
        let presentation = ErrorPresentationFactory.create(for: appError, context: context)
        errorState = presentation

        // Log the error
        Task {
            await CrashReporter.shared.captureError(error, context: ["presentation": context.rawValue])
        }
    }

    /// Present a toast message
    func presentToast(_ message: String, style: ErrorToast.Style = .error) {
        errorState = .toast(ErrorToast(message: message, style: style))
    }

    /// Present a banner
    func presentBanner(
        title: String,
        message: String? = nil,
        style: ErrorBanner.Style = .error,
        onRetry: (@Sendable () -> Void)? = nil,
    ) {
        let retryAction = onRetry.map { handler in
            ErrorBanner.Action(title: "Retry", handler: handler)
        }
        errorState = .banner(ErrorBanner(
            title: title,
            message: message,
            style: style,
            retryAction: retryAction,
        ))
    }

    /// Present an alert
    func presentAlert(
        title: String,
        message: String,
        onDismiss: (@Sendable () -> Void)? = nil,
    ) {
        errorState = .alert(ErrorAlert(
            title: title,
            message: message,
            primaryAction: ErrorAlert.Action(
                title: "OK",
                style: .default,
                handler: onDismiss ?? {},
            ),
        ))
    }

    /// Present a retry alert
    func presentRetryAlert(
        title: String,
        message: String,
        onRetry: @escaping @Sendable () -> Void,
    ) {
        errorState = .alert(ErrorAlert.retry(title: title, message: message, onRetry: onRetry))
    }

    /// Dismiss current error
    func dismissError() {
        errorState = .none
    }

    /// Check if currently showing an error
    var isShowingError: Bool {
        errorState.hasError
    }
}

// MARK: - Error Context

/// Context in which an error occurred (affects presentation)
enum ErrorContext: String, Sendable {
    case general
    case authentication
    case network
    case validation
    case permission
    case payment
    case sync
    case background
}

// MARK: - Error Presentation Factory

/// Creates appropriate error presentations based on error type and context
enum ErrorPresentationFactory {
    private static let logger = Logger(subsystem: Constants.bundleIdentifier, category: "ErrorPresentation")

    static func create(for error: AppError, context: ErrorContext) -> ErrorPresentationState {
        logger.debug("Creating presentation for: \(error.localizedDescription), context: \(context.rawValue)")

        switch error {
        // Network errors - show banner with retry
        case let .networkError(message):
            // Check if it's an offline error
            if message.lowercased().contains("internet") || message.lowercased().contains("offline") {
                return .banner(ErrorBanner(
                    title: "You're Offline",
                    message: "Some features may be unavailable",
                    style: .offline,
                    isDismissible: false,
                ))
            }
            return .banner(ErrorBanner(
                title: "Connection Error",
                message: error.userFriendlyMessage,
                style: .error,
                retryAction: nil,
            ))

        // Auth errors - show alert
        case .unauthorized:
            return .alert(ErrorAlert(
                title: "Authentication Required",
                message: error.userFriendlyMessage,
                primaryAction: ErrorAlert.Action(title: "Sign In", style: .default) {},
                isDismissible: false,
            ))

        // Validation errors - show toast
        case let .validationError(message):
            return .toast(ErrorToast(message: message, style: .warning))

        case let .validation(validationError):
            return .toast(ErrorToast(message: validationError.userFriendlyMessage, style: .warning))

        // Not found - show toast
        case let .notFound(resource):
            return .toast(ErrorToast(message: "\(resource) was not found", style: .info))

        // Rate limited - show banner
        case let .rateLimitExceeded(retryAfter):
            return .banner(ErrorBanner(
                title: "Too Many Requests",
                message: "Please wait \(Int(retryAfter)) seconds before trying again",
                style: .warning,
            ))

        // Permission denied - show alert
        case let .permissionDenied(feature):
            return .alert(ErrorAlert(
                title: "Permission Required",
                message: "Access to \(feature) is required for this feature.",
                primaryAction: ErrorAlert.Action(title: "Settings", style: .default) {},
                secondaryAction: ErrorAlert.Action(title: "Cancel", style: .cancel) {},
            ))

        // Location errors - show toast
        case .locationError:
            return .toast(ErrorToast(message: error.userFriendlyMessage, style: .warning))

        // Sync errors - show banner
        case .syncFailed:
            return .banner(ErrorBanner(
                title: "Sync Failed",
                message: error.userFriendlyMessage,
                style: .warning,
                retryAction: nil,
            ))

        // Database/config/decoding errors - show toast
        case .databaseError, .configurationError, .decodingError:
            return .toast(ErrorToast(message: error.userFriendlyMessage, style: .error))

        // Unknown errors - show toast
        case .unknown:
            return .toast(ErrorToast(message: error.userFriendlyMessage, style: .error))
        }
    }

    /// Localized version of error presentation factory
    @MainActor
    static func create(for error: AppError, context: ErrorContext, using t: EnhancedTranslationService) -> ErrorPresentationState {
        logger.debug("Creating localized presentation for: \(error.localizedDescription), context: \(context.rawValue)")

        switch error {
        // Network errors - show banner with retry
        case let .networkError(message):
            // Check if it's an offline error
            if message.lowercased().contains("internet") || message.lowercased().contains("offline") {
                return .banner(ErrorBanner(
                    title: t.t("errors.presenter.offline"),
                    message: t.t("errors.presenter.offline_message"),
                    style: .offline,
                    isDismissible: false,
                ))
            }
            return .banner(ErrorBanner(
                title: t.t("errors.presenter.connection_error"),
                message: error.localizedUserFriendlyMessage(using: t),
                style: .error,
                retryAction: nil,
            ))

        // Auth errors - show alert
        case .unauthorized:
            return .alert(ErrorAlert(
                title: t.t("errors.presenter.auth_required"),
                message: error.localizedUserFriendlyMessage(using: t),
                primaryAction: ErrorAlert.Action(title: t.t("auth.sign_in"), style: .default) {},
                isDismissible: false,
            ))

        // Validation errors - show toast
        case let .validationError(message):
            return .toast(ErrorToast(message: message, style: .warning))

        case let .validation(validationError):
            return .toast(ErrorToast(message: validationError.localizedUserFriendlyMessage(using: t), style: .warning))

        // Not found - show toast
        case let .notFound(resource):
            return .toast(ErrorToast(message: t.t("errors.presenter.not_found", args: ["resource": resource]), style: .info))

        // Rate limited - show banner
        case let .rateLimitExceeded(retryAfter):
            return .banner(ErrorBanner(
                title: t.t("errors.presenter.rate_limited"),
                message: t.t("errors.presenter.rate_limited_message", args: ["seconds": String(Int(retryAfter))]),
                style: .warning,
            ))

        // Permission denied - show alert
        case let .permissionDenied(feature):
            return .alert(ErrorAlert(
                title: t.t("errors.presenter.permission_required"),
                message: t.t("errors.presenter.permission_message", args: ["feature": feature]),
                primaryAction: ErrorAlert.Action(title: t.t("common.settings"), style: .default) {},
                secondaryAction: ErrorAlert.Action(title: t.t("common.cancel"), style: .cancel) {},
            ))

        // Location errors - show toast
        case .locationError:
            return .toast(ErrorToast(message: error.localizedUserFriendlyMessage(using: t), style: .warning))

        // Sync errors - show banner
        case .syncFailed:
            return .banner(ErrorBanner(
                title: t.t("errors.presenter.sync_failed"),
                message: error.localizedUserFriendlyMessage(using: t),
                style: .warning,
                retryAction: nil,
            ))

        // Database/config/decoding errors - show toast
        case .databaseError, .configurationError, .decodingError:
            return .toast(ErrorToast(message: error.localizedUserFriendlyMessage(using: t), style: .error))

        // Unknown errors - show toast
        case .unknown:
            return .toast(ErrorToast(message: error.localizedUserFriendlyMessage(using: t), style: .error))
        }
    }
}

// MARK: - SwiftUI Error View Modifier

/// View modifier for displaying errors from ErrorPresenting ViewModels
struct ErrorPresenterModifier<ViewModel: ErrorPresenting>: ViewModifier {
    @Bindable var viewModel: ViewModel
    @State private var showAlert = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if case let .banner(banner) = viewModel.errorState {
                    ErrorBannerView(banner: banner) {
                        viewModel.dismissError()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottom) {
                if case let .toast(toast) = viewModel.errorState {
                    ErrorToastView(toast: toast) {
                        viewModel.dismissError()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .alert(
                alertTitle,
                isPresented: $showAlert,
                actions: alertActions,
                message: { Text(alertMessage) },
            )
            .onChange(of: viewModel.errorState) { _, newValue in
                if case .alert = newValue {
                    showAlert = true
                } else {
                    showAlert = false
                }
            }
    }

    private var alertTitle: String {
        if case let .alert(alert) = viewModel.errorState {
            return alert.title
        }
        return ""
    }

    private var alertMessage: String {
        if case let .alert(alert) = viewModel.errorState {
            return alert.message
        }
        return ""
    }

    @ViewBuilder
    private func alertActions() -> some View {
        if case let .alert(alert) = viewModel.errorState {
            Button(alert.primaryAction.title) {
                alert.primaryAction.handler()
                viewModel.dismissError()
            }

            if let secondary = alert.secondaryAction {
                Button(secondary.title, role: secondary.style == .destructive ? .destructive : .cancel) {
                    secondary.handler()
                    viewModel.dismissError()
                }
            }
        }
    }
}

// MARK: - Error Views

/// Toast view for minor errors
struct ErrorToastView: View {
    let toast: ErrorToast
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)

            Text(toast.message)
                .font(Font.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.text)

            if let action = toast.action {
                Button(action.title) {
                    action.handler()
                }
                .font(Font.DesignSystem.labelMedium)
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .foregroundStyle(Color.DesignSystem.textSecondary)
        }
        .padding(Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.lg)
        .task {
            try? await Task.sleep(nanoseconds: UInt64(toast.duration * 1_000_000_000))
            onDismiss()
        }
    }

    private var iconName: String {
        switch toast.style {
        case .error: "exclamationmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch toast.style {
        case .error: .red
        case .warning: .orange
        case .info: .blue
        }
    }
}

/// Banner view for recoverable errors
struct ErrorBannerView: View {
    let banner: ErrorBanner
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)

                Text(banner.title)
                    .font(Font.DesignSystem.labelLarge)
                    .foregroundStyle(Color.DesignSystem.text)

                Spacer()

                if banner.isDismissible {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                }
            }

            if let message = banner.message {
                Text(message)
                    .font(Font.DesignSystem.bodySmall)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            if let retry = banner.retryAction {
                Button(retry.title) {
                    retry.handler()
                }
                .font(Font.DesignSystem.labelMedium)
                .foregroundStyle(Color.DesignSystem.primary)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
    }

    private var iconName: String {
        switch banner.style {
        case .error: "exclamationmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .offline: "wifi.slash"
        case .maintenance: "wrench.and.screwdriver.fill"
        }
    }

    private var iconColor: Color {
        switch banner.style {
        case .error: .red
        case .warning: .orange
        case .offline: .gray
        case .maintenance: .blue
        }
    }

    private var backgroundColor: Color {
        switch banner.style {
        case .error: Color.red.opacity(0.1)
        case .warning: Color.orange.opacity(0.1)
        case .offline: Color.gray.opacity(0.1)
        case .maintenance: Color.blue.opacity(0.1)
        }
    }
}

// MARK: - View Extension

extension View {
    /// Add error presentation handling to a view
    func errorPresenter(_ viewModel: some ErrorPresenting) -> some View {
        modifier(ErrorPresenterModifier(viewModel: viewModel))
    }
}
