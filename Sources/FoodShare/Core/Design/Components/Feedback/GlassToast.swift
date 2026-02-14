//
//  GlassToast.swift
//  Foodshare
//
//  Liquid Glass v27 toast notification component
//  Displays transient feedback messages with ProMotion 120Hz animations
//  GPU-accelerated glass effects for smooth rendering
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Glass Toast View

/// Individual toast notification with Liquid Glass styling
struct GlassToast: View {
    let notification: ToastNotification
    let onDismiss: () -> Void
    let onAction: (() -> Void)?

    @State private var offset: CGFloat = -100
    @State private var opacity: Double = 0
    @Environment(\.translationService) private var t

    init(
        notification: ToastNotification,
        onDismiss: @escaping () -> Void,
    ) {
        self.notification = notification
        self.onDismiss = onDismiss
        onAction = notification.action?.handler
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Icon
            iconView

            // Message
            Text(notification.message)
                .font(.DesignSystem.bodySmall)
                .foregroundColor(Color.DesignSystem.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            // Action button (if any)
            if let action = notification.action {
                actionButton(title: action.title)
            }

            // Dismiss button
            dismissButton
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(glassOverlay)
        .shadow(color: notification.style.color.opacity(0.2), radius: 12, y: 4)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
        .offset(y: offset)
        .opacity(opacity)
        .drawingGroup() // GPU rasterization for glass effects
        .gesture(dismissGesture)
        // MARK: - Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(notification.action != nil
            ? "Double tap to perform action, or swipe up to dismiss"
            : "Swipe up to dismiss")
            .accessibilityAddTraits(.isStaticText)
            .accessibilityAction(.escape) {
                dismissWithAnimation()
            }
            .onAppear {
                withAnimation(.interpolatingSpring(stiffness: 250, damping: 22)) {
                    offset = 0
                    opacity = 1
                }
                HapticManager.light()

                // Announce to VoiceOver users (polite - doesn't interrupt)
                AccessibilityNotification.Announcement(accessibilityLabel).post()
            }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        let styleLabel = switch notification.style {
        case .success: t.t("accessibility.state.success")
        case .error: t.t("accessibility.state.error")
        case .warning: t.t("accessibility.state.warning")
        case .info: t.t("accessibility.state.info")
        }

        if let action = notification.action {
            return "\(styleLabel): \(notification.message). Action available: \(action.title)"
        }
        return "\(styleLabel): \(notification.message)"
    }

    // MARK: - Icon

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(notification.style.color.opacity(0.15))
                .frame(width: 32, height: 32)

            Image(systemName: notification.style.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            notification.style.color,
                            notification.style.color.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
        }
    }

    // MARK: - Action Button

    private func actionButton(title: String) -> some View {
        Button {
            HapticManager.medium()
            onAction?()
            onDismiss()
        } label: {
            Text(title)
                .font(.DesignSystem.captionSmall)
                .fontWeight(.semibold)
                .foregroundColor(notification.style.color)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule()
                        .fill(notification.style.color.opacity(0.15)),
                )
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.95, haptic: .none))
    }

    // MARK: - Dismiss Button

    private var dismissButton: some View {
        Button {
            dismissWithAnimation()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.DesignSystem.textSecondary)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Color.DesignSystem.textSecondary.opacity(0.1)),
                )
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.9, haptic: .light))
    }

    // MARK: - Glass Background

    private var glassBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)

            // Tinted gradient based on style
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(
                    LinearGradient(
                        colors: [
                            notification.style.color.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing,
                    ),
                )

            // Top highlight
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center,
                    ),
                )
        }
    }

    private var glassOverlay: some View {
        RoundedRectangle(cornerRadius: CornerRadius.large)
            .stroke(
                LinearGradient(
                    colors: [
                        notification.style.color.opacity(0.3),
                        Color.DesignSystem.glassBorder,
                        notification.style.color.opacity(0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                ),
                lineWidth: 1,
            )
    }

    // MARK: - Gestures

    private var dismissGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height < 0 {
                    offset = value.translation.height
                }
            }
            .onEnded { value in
                if value.translation.height < -50 {
                    dismissWithAnimation()
                } else {
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 22)) {
                        offset = 0
                    }
                }
            }
    }

    private func dismissWithAnimation() {
        HapticManager.light()
        withAnimation(.interpolatingSpring(stiffness: 350, damping: 25)) {
            offset = -100
            opacity = 0
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            onDismiss()
        }
    }
}

// MARK: - Toast Container

/// Container view that displays multiple toast notifications
struct ToastContainer: View {
    @Bindable var errorService: ErrorRecoveryService

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(errorService.toasts) { toast in
                GlassToast(notification: toast) {
                    errorService.dismissToast(toast)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity.combined(with: .scale(scale: 0.9)),
                ))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: errorService.toasts.count)
    }
}

// MARK: - View Modifier

/// View modifier to add toast notifications to any view
struct ToastModifier: ViewModifier {
    @Bindable var errorService: ErrorRecoveryService

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            ToastContainer(errorService: errorService)
        }
    }
}

extension View {
    /// Add toast notification support to a view
    func withToasts() -> some View {
        modifier(ToastModifier(errorService: ErrorRecoveryService.shared))
    }

    /// Add toast notification support with a custom error service
    func withToasts(errorService: ErrorRecoveryService) -> some View {
        modifier(ToastModifier(errorService: errorService))
    }
}

// Note: ScaleButtonStyle is defined in GlassButton.swift

// MARK: - Preview

#Preview("Toast Notifications") {
    struct PreviewContainer: View {
        @State private var toasts: [ToastNotification] = []

        var body: some View {
            ZStack {
                Color.DesignSystem.background
                    .ignoresSafeArea()

                VStack(spacing: Spacing.lg) {
                    GlassButton("Success Toast", style: .primary) {
                        addToast(message: "Operation completed successfully!", style: .success)
                    }

                    GlassButton("Error Toast", style: .secondary) {
                        addToast(message: "Failed to save changes. Please try again.", style: .error)
                    }

                    GlassButton("Warning Toast", style: .secondary) {
                        addToast(message: "Your session will expire in 5 minutes.", style: .warning)
                    }

                    GlassButton("Info Toast", style: .secondary) {
                        addToast(message: "New updates are available.", style: .info)
                    }

                    GlassButton("Toast with Action", style: .secondary) {
                        let action = ToastNotification.ToastAction(title: "Undo") {
                            print("Undo tapped")
                        }
                        let toast = ToastNotification(
                            message: "Item deleted",
                            style: .info,
                            action: action,
                        )
                        toasts.append(toast)
                    }
                }
                .padding()

                VStack {
                    VStack(spacing: Spacing.sm) {
                        ForEach(toasts) { toast in
                            GlassToast(notification: toast) {
                                toasts.removeAll { $0.id == toast.id }
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)
                    .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: toasts.count)

                    Spacer()
                }
            }
        }

        private func addToast(message: String, style: ToastNotification.ToastStyle) {
            let toast = ToastNotification(message: message, style: style)
            toasts.append(toast)

            // Auto-dismiss after duration
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(toast.duration))
                toasts.removeAll { $0.id == toast.id }
            }
        }
    }

    return PreviewContainer()
}
