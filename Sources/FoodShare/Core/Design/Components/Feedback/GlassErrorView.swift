//
//  GlassErrorView.swift
//  Foodshare
//
//  Liquid Glass error display components for various error scenarios
//  Provides contextual error UI with recovery actions
//


#if !SKIP
import SwiftUI

// MARK: - Glass Error View

/// Full-screen error view with recovery options
struct GlassErrorView: View {
    let error: AppError
    let title: String?
    let retryAction: (() -> Void)?
    let dismissAction: (() -> Void)?

    @State private var isAnimating = false

    init(
        error: AppError,
        title: String? = nil,
        retryAction: (() -> Void)? = nil,
        dismissAction: (() -> Void)? = nil
    ) {
        self.error = error
        self.title = title
        self.retryAction = retryAction
        self.dismissAction = dismissAction
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            // Animated icon
            errorIcon
                .padding(.bottom, Spacing.md)

            // Error title
            Text(title ?? errorTitle)
                .font(.DesignSystem.headlineLarge)
                .foregroundColor(Color.DesignSystem.text)
                .multilineTextAlignment(.center)

            // Error description
            Text(error.userFriendlyMessage)
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(Color.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)

            Spacer()

            // Action buttons
            actionButtons
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.DesignSystem.background)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }

    // MARK: - Error Icon

    @ViewBuilder
    private var errorIcon: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            errorColor.opacity(0.3),
                            errorColor.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 80
                    )
                )
                .frame(width: 160.0, height: 160)
                .scaleEffect(isAnimating ? 1.1 : 1.0)

            // Glass circle
            Circle()
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .frame(width: 100.0, height: 100)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    errorColor.opacity(0.5),
                                    errorColor.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )

            // Icon
            Image(systemName: error.iconName)
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [errorColor, errorColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: Spacing.md) {
            if let retryAction, error.isRetryable {
                GlassButton("Try Again", icon: "arrow.clockwise", style: .primary) {
                    HapticManager.medium()
                    retryAction()
                }
            }

            if let dismissAction {
                GlassButton("Go Back", style: .secondary) {
                    HapticManager.light()
                    dismissAction()
                }
            }

            // Context-specific actions
            contextualActions
        }
    }

    @ViewBuilder
    private var contextualActions: some View {
        switch error {
        case .networkError:
            HStack(spacing: Spacing.md) {
                actionChip(icon: "wifi", label: "Check Wi-Fi") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }

                actionChip(icon: "antenna.radiowaves.left.and.right", label: "Cellular") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }

        case .locationError:
            actionChip(icon: "location.fill", label: "Location Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }

        case .unauthorized:
            actionChip(icon: "person.crop.circle", label: "Sign In") {
                NotificationCenter.default.post(name: .showLoginRequired, object: nil)
            }

        default:
            EmptyView()
        }
    }

    private func actionChip(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(.DesignSystem.captionSmall)
            }
            .foregroundColor(Color.DesignSystem.textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    #if !SKIP
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
            )
            .overlay(
                Capsule()
                    .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.95, haptic: .light))
    }

    // MARK: - Computed Properties

    private var errorTitle: String {
        switch error {
        case .networkError:
            "Connection Lost"
        case .unauthorized:
            "Sign In Required"
        case .notFound:
            "Not Found"
        case .locationError:
            "Location Unavailable"
        case .databaseError, .syncFailed:
            "Sync Error"
        case .rateLimitExceeded:
            "Slow Down"
        case .permissionDenied:
            "Access Denied"
        case .configurationError:
            "Setup Required"
        case .validationError, .validation:
            "Invalid Input"
        case .decodingError:
            "Data Error"
        case .unknown:
            "Something Went Wrong"
        }
    }

    private var errorColor: Color {
        switch error {
        case .networkError, .syncFailed, .databaseError:
            Color.DesignSystem.warning
        case .unauthorized, .permissionDenied:
            Color.DesignSystem.brandPink
        case .rateLimitExceeded:
            Color.DesignSystem.brandOrange
        default:
            Color.DesignSystem.error
        }
    }
}

// MARK: - Inline Error Banner

/// Compact inline error banner with recovery options and animated states
struct GlassInlineErrorBanner: View {
    let message: String
    let context: BannerErrorContext?
    let style: BannerStyle
    let retryAfter: TimeInterval?
    let action: (() -> Void)?
    let dismissAction: (() -> Void)?

    @State private var remainingTime: Int = 0
    @State private var isVisible = false
    @State private var isRetrying = false

    enum BannerStyle {
        case error
        case warning
        case info
        case rateLimited

        var icon: String {
            switch self {
            case .error: "exclamationmark.triangle.fill"
            case .warning: "exclamationmark.circle.fill"
            case .info: "info.circle.fill"
            case .rateLimited: "clock.fill"
            }
        }

        var color: Color {
            switch self {
            case .error: Color.DesignSystem.error
            case .warning: Color.DesignSystem.warning
            case .info: Color.DesignSystem.brandBlue
            case .rateLimited: Color.DesignSystem.brandOrange
            }
        }
    }

    /// Additional context about what failed
    struct BannerErrorContext {
        let operation: String // What was the user trying to do
        let reason: String? // Why it failed
        let suggestion: String? // What to do next

        init(operation: String, reason: String? = nil, suggestion: String? = nil) {
            self.operation = operation
            self.reason = reason
            self.suggestion = suggestion
        }

        static func network(_ operation: String) -> BannerErrorContext {
            BannerErrorContext(
                operation: operation,
                reason: "No internet connection",
                suggestion: "Check your connection and try again"
            )
        }

        static func server(_ operation: String) -> BannerErrorContext {
            BannerErrorContext(
                operation: operation,
                reason: "Server temporarily unavailable",
                suggestion: "Please wait a moment and retry"
            )
        }

        static func permission(_ operation: String) -> BannerErrorContext {
            BannerErrorContext(
                operation: operation,
                reason: "Access denied",
                suggestion: "Sign in to continue"
            )
        }
    }

    init(
        _ message: String,
        context: BannerErrorContext? = nil,
        style: BannerStyle = .error,
        retryAfter: TimeInterval? = nil,
        action: (() -> Void)? = nil,
        dismissAction: (() -> Void)? = nil
    ) {
        self.message = message
        self.context = context
        self.style = style
        self.retryAfter = retryAfter
        self.action = action
        self.dismissAction = dismissAction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Main banner content
            HStack(spacing: Spacing.sm) {
                // Animated icon
                iconView

                VStack(alignment: .leading, spacing: 2) {
                    // Main message
                    Text(message)
                        .font(.DesignSystem.bodySmall)
                        .foregroundColor(Color.DesignSystem.text)
                        .lineLimit(2)

                    // Context info (what failed)
                    if let context {
                        Text(context.operation)
                            .font(.DesignSystem.captionSmall)
                            .foregroundColor(Color.DesignSystem.textSecondary)
                    }
                }

                Spacer(minLength: 0)

                // Action area
                actionView
            }

            // Suggestion text
            if let suggestion = context?.suggestion {
                Text(suggestion)
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(Color.DesignSystem.textSecondary)
                    .padding(.leading, 24) // Align with text after icon
            }
        }
        .padding(Spacing.md)
        .background(glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(style.color.opacity(0.3), lineWidth: 1)
        )
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -10)
        .onAppear {
            // Animate in
            withAnimation(ProMotionAnimation.smooth) {
                isVisible = true
            }

            // Start countdown if rate limited
            if let retryAfter, retryAfter > 0 {
                startCountdown(Int(retryAfter))
            }
        }
        #if !SKIP
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(action != nil ? "Double tap to retry" : "")
        #endif
    }

    // MARK: - Subviews

    @ViewBuilder
    private var iconView: some View {
        ZStack {
            if isRetrying {
                ProgressView()
                    .tint(style.color)
                    .scaleEffect(0.8)
            } else {
                Image(systemName: style.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(style.color)
            }
        }
        .frame(width: 20.0, height: 20)
    }

    @ViewBuilder
    private var actionView: some View {
        if style == .rateLimited && remainingTime > 0 {
            // Countdown timer
            HStack(spacing: 4) {
                Text(formatTime(remainingTime))
                    .font(.DesignSystem.captionSmall)
                    .fontWeight(.medium)
                    .foregroundColor(style.color)
                    #if !SKIP
                    .monospacedDigit()
                    #endif

                CircularProgressView(progress: countdownProgress)
                    .frame(width: 16.0, height: 16)
            }
        } else if let action {
            Button {
                performRetry(action)
            } label: {
                Text(remainingTime > 0 ? "Wait..." : "Retry")
                    .font(.DesignSystem.captionSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(remainingTime > 0 ? Color.DesignSystem.textTertiary : style.color)
            }
            .disabled(remainingTime > 0 || isRetrying)
        }

        if let dismissAction {
            Button {
                withAnimation(ProMotionAnimation.quick) {
                    isVisible = false
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    dismissAction()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.DesignSystem.textTertiary)
            }
            .padding(.leading, Spacing.xs)
        }
    }

    private var glassBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif

            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(style.color.opacity(0.05))
        }
    }

    // MARK: - Helpers

    private func startCountdown(_ seconds: Int) {
        remainingTime = seconds

        Task {
            while remainingTime > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if remainingTime > 0 {
                    remainingTime -= 1
                }
            }
        }
    }

    private var countdownProgress: Double {
        guard let retryAfter, retryAfter > 0 else { return 0 }
        return 1 - (Double(remainingTime) / retryAfter)
    }

    private func formatTime(_ seconds: Int) -> String {
        if seconds >= 60 {
            let mins = seconds / 60
            let secs = seconds % 60
            return String(format: "%d:%02d", mins, secs)
        }
        return "\(seconds)s"
    }

    private func performRetry(_ action: @escaping () -> Void) {
        isRetrying = true
        HapticManager.medium()

        // Delay slightly to show loading state
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            action()
            isRetrying = false
        }
    }

    private var accessibilityDescription: String {
        var desc = message
        if let context {
            desc += ". \(context.operation)"
            if let reason = context.reason {
                desc += ". \(reason)"
            }
        }
        if remainingTime > 0 {
            desc += ". Retry available in \(remainingTime) seconds"
        }
        return desc
    }
}

// MARK: - Circular Progress View

private struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.DesignSystem.glassBorder, lineWidth: 2)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.DesignSystem.brandOrange, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(Angle.degrees(-90))
                .animation(Animation.linear(duration: 0.5), value: progress)
        }
    }
}

// MARK: - Convenience Initializers

extension GlassInlineErrorBanner {
    /// Create a rate-limited error banner with countdown
    static func rateLimited(
        retryAfter: TimeInterval,
        operation: String,
        onRetry: @escaping () -> Void
    ) -> GlassInlineErrorBanner {
        GlassInlineErrorBanner(
            "Too many requests",
            context: BannerErrorContext(
                operation: "While \(operation)",
                reason: "Rate limit exceeded",
                suggestion: "Please wait before trying again"
            ),
            style: .rateLimited,
            retryAfter: retryAfter,
            action: onRetry
        )
    }

    /// Create a network error banner
    static func networkError(
        operation: String,
        onRetry: @escaping () -> Void,
        onDismiss: (() -> Void)? = nil
    ) -> GlassInlineErrorBanner {
        GlassInlineErrorBanner(
            "Connection failed",
            context: .network(operation),
            style: .error,
            action: onRetry,
            dismissAction: onDismiss
        )
    }

    /// Create a server error banner
    static func serverError(
        operation: String,
        onRetry: @escaping () -> Void
    ) -> GlassInlineErrorBanner {
        GlassInlineErrorBanner(
            "Server error",
            context: .server(operation),
            style: .warning,
            action: onRetry
        )
    }
}

// MARK: - Empty State View

/// Glass-styled empty state view for lists and content areas
struct GlassEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    @State private var isAnimating = false

    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.DesignSystem.brandTeal.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120.0, height: 120)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)

                Circle()
                    #if !SKIP
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .frame(width: 80.0, height: 80)
                    .overlay(
                        Circle()
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                    )

                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.brandTeal,
                                Color.DesignSystem.brandPink
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.DesignSystem.headlineMedium)
                    .foregroundColor(Color.DesignSystem.text)

                Text(message)
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(Color.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            if let actionTitle, let action {
                GlassButton(actionTitle, style: .primary) {
                    action()
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.md)
            }
        }
        .padding(.vertical, Spacing.xl)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Error Boundary

/// View modifier that catches errors and displays error UI
struct ErrorBoundary<Content: View>: View {
    @ViewBuilder let content: () -> Content
    let onError: ((Error) -> Void)?

    @State private var error: AppError?
    @State private var showError = false

    init(
        onError: ((Error) -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.onError = onError
        self.content = content
    }

    var body: some View {
        ZStack {
            if showError, let error {
                GlassErrorView(
                    error: error,
                    retryAction: {
                        showError = false
                        self.error = nil
                    },
                    dismissAction: {
                        showError = false
                    }
                )
            } else {
                content()
            }
        }
    }

    /// Set the error state
    func setError(_ appError: AppError) {
        error = appError
        showError = true
        onError?(appError)
    }
}

// MARK: - View Extensions

extension View {
    /// Wrap view in an error boundary
    func errorBoundary(onError: ((Error) -> Void)? = nil) -> some View {
        ErrorBoundary(onError: onError) {
            self
        }
    }

    /// Show error state conditionally
    @ViewBuilder
    func showError(_ error: AppError?, retryAction: (() -> Void)? = nil) -> some View {
        if let error {
            GlassErrorView(error: error, retryAction: retryAction)
        } else {
            self
        }
    }

    /// Show empty state when collection is empty
    @ViewBuilder
    func emptyState<C: Collection>(
        for collection: C,
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        if collection.isEmpty {
            GlassEmptyStateView(
                icon: icon,
                title: title,
                message: message,
                actionTitle: actionTitle,
                action: action
            )
        } else {
            self
        }
    }
}

// MARK: - Preview

#Preview("Error Views") {
    ScrollView {
        VStack(spacing: Spacing.xl) {
            Text("Error Banner")
                .font(.DesignSystem.headlineSmall)
                .frame(maxWidth: .infinity, alignment: .leading)

            GlassInlineErrorBanner("Failed to load data. Please try again.", action: {})
            GlassInlineErrorBanner("Low storage space", style: .warning)
            GlassInlineErrorBanner("New version available", style: .info)

            Divider()
                .padding(.vertical)

            Text("Empty State")
                .font(.DesignSystem.headlineSmall)
                .frame(maxWidth: .infinity, alignment: .leading)

            GlassEmptyStateView(
                icon: "tray",
                title: "No Listings Yet",
                message: "Start sharing food with your community!",
                actionTitle: "Create Listing"
            ) {}

            Divider()
                .padding(.vertical)

            Text("Full Error View")
                .font(.DesignSystem.headlineSmall)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
    .background(Color.DesignSystem.background)
}

#Preview("Network Error") {
    GlassErrorView(
        error: .networkError("Unable to connect to server"),
        retryAction: {},
        dismissAction: {}
    )
}

#Preview("Auth Error") {
    GlassErrorView(
        error: .unauthorized(action: "view this content"),
        retryAction: nil,
        dismissAction: {}
    )
}

#endif
