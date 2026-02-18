//
//  GlassErrorBanner.swift
//  Foodshare
//
//  Dismissible error banner with Liquid Glass v26 design
//  CareEcho-inspired layered glass effects and smooth animations
//


#if !SKIP
import SwiftUI

/// Dismissible error banner with Liquid Glass styling
/// Supports error, warning, success, and info variants
/// CareEcho-style layered background with gradient border
struct GlassErrorBanner: View {
    let message: String
    let style: BannerStyle
    let onDismiss: (() -> Void)?

    @Environment(\.translationService) private var t

    enum BannerStyle {
        case error
        case warning
        case success
        case info

        var icon: String {
            switch self {
            case .error: "exclamationmark.triangle.fill"
            case .warning: "exclamationmark.circle.fill"
            case .success: "checkmark.circle.fill"
            case .info: "info.circle.fill"
            }
        }

        var primaryColor: Color {
            switch self {
            case .error: Color.DesignSystem.error
            case .warning: Color.DesignSystem.warning
            case .success: Color.DesignSystem.success
            case .info: Color.DesignSystem.accentBlue
            }
        }

        var secondaryColor: Color {
            switch self {
            case .error: Color.DesignSystem.error.opacity(0.8)
            case .warning: Color.DesignSystem.accentYellow
            case .success: Color.DesignSystem.brandCyan
            case .info: Color.DesignSystem.accentCyan
            }
        }

        var iconGradient: LinearGradient {
            LinearGradient(
                colors: [primaryColor, secondaryColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        }

        var backgroundOpacity: Double {
            0.2
        }

        var borderOpacity: Double {
            0.4
        }
    }

    init(
        _ message: String,
        style: BannerStyle = .error,
        onDismiss: (() -> Void)? = nil,
    ) {
        self.message = message
        self.style = style
        self.onDismiss = onDismiss
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon with gradient (CareEcho-style)
            Image(systemName: style.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(style.iconGradient)

            // Message
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                #if !SKIP
                .fixedSize(horizontal: false, vertical: true)
                #endif

            Spacer(minLength: 0)

            // Dismiss button (if dismissible)
            if let onDismiss {
                Button(action: {
                    HapticManager.light()
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.9, haptic: .none))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(layeredGlassBackground)
        // MARK: - Accessibility
        #if !SKIP
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(onDismiss != nil ? Text(t.t("accessibility.action.dismiss")) : Text(""))
        .accessibilityAddTraits(.isStaticText)
        #endif
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        let styleLabel = switch style {
        case .error: t.t("accessibility.banner.error")
        case .warning: t.t("accessibility.banner.warning")
        case .success: t.t("accessibility.banner.success")
        case .info: t.t("accessibility.banner.info")
        }
        return "\(styleLabel): \(message)"
    }

    /// Creates a localized accessibility label for the banner
    @MainActor
    static func localizedAccessibilityLabel(
        style: BannerStyle,
        message: String,
        using t: EnhancedTranslationService
    ) -> String {
        let styleLabel = switch style {
        case .error: t.t("accessibility.banner.error")
        case .warning: t.t("accessibility.banner.warning")
        case .success: t.t("accessibility.banner.success")
        case .info: t.t("accessibility.banner.info")
        }
        return "\(styleLabel): \(message)"
    }

    /// Creates a localized accessibility hint for the banner
    @MainActor
    static func localizedAccessibilityHint(
        isDismissible: Bool,
        using t: EnhancedTranslationService
    ) -> String {
        isDismissible ? t.t("accessibility.action.dismiss") : ""
    }

    // MARK: - Layered Glass Background (CareEcho-style)

    private var layeredGlassBackground: some View {
        ZStack {
            // Base colored fill
            RoundedRectangle(cornerRadius: 12)
                .fill(style.primaryColor.opacity(style.backgroundOpacity))

            // Subtle gradient overlay
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            style.primaryColor.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom,
                    ),
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [
                            style.primaryColor.opacity(style.borderOpacity),
                            style.secondaryColor.opacity(style.borderOpacity * 0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                    lineWidth: 1,
                ),
        )
    }
}

// MARK: - Animated Error Banner Wrapper

/// Wrapper that handles show/hide animation for error banners
struct AnimatedErrorBanner: View {
    @Binding var isShowing: Bool
    let message: String
    let style: GlassErrorBanner.BannerStyle
    let autoDismissAfter: TimeInterval?

    init(
        isShowing: Binding<Bool>,
        message: String,
        style: GlassErrorBanner.BannerStyle = .error,
        autoDismissAfter: TimeInterval? = nil,
    ) {
        _isShowing = isShowing
        self.message = message
        self.style = style
        self.autoDismissAfter = autoDismissAfter
    }

    var body: some View {
        Group {
            if isShowing {
                GlassErrorBanner(message, style: style) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isShowing = false
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity.combined(with: .scale(scale: 0.95)),
                ))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isShowing)
        .onChange(of: isShowing) { _, newValue in
            if newValue {
                // Announce to VoiceOver users
                // Errors use assertive priority (interrupts current speech)
                let announcement = accessibilityAnnouncement
                if style == .error {
                    // Post with high priority for errors
                    AccessibilityNotification.Announcement(announcement).post()
                } else {
                    AccessibilityNotification.Announcement(announcement).post()
                }

                // Auto-dismiss if configured
                if let delay = autoDismissAfter {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        if isShowing {
                            withAnimation {
                                isShowing = false
                            }
                        }
                    }
                }
            }
        }
    }

    private var accessibilityAnnouncement: String {
        let styleLabel = switch style {
        case .error: "Error"
        case .warning: "Warning"
        case .success: "Success"
        case .info: "Information"
        }
        return "\(styleLabel): \(message)"
    }

    /// Creates a localized accessibility announcement
    @MainActor
    static func localizedAccessibilityAnnouncement(
        style: GlassErrorBanner.BannerStyle,
        message: String,
        using t: EnhancedTranslationService
    ) -> String {
        GlassErrorBanner.localizedAccessibilityLabel(style: style, message: message, using: t)
    }
}

// MARK: - View Extension

extension View {
    /// Attach an error banner to the top of a view
    func errorBanner(
        isShowing: Binding<Bool>,
        message: String,
        style: GlassErrorBanner.BannerStyle = .error,
        autoDismissAfter: TimeInterval? = nil,
    ) -> some View {
        VStack(spacing: Spacing.sm) {
            AnimatedErrorBanner(
                isShowing: isShowing,
                message: message,
                style: style,
                autoDismissAfter: autoDismissAfter,
            )
            self
        }
    }
}

// MARK: - Preview

#Preview("Error Banner Styles") {
    VStack(spacing: Spacing.md) {
        GlassErrorBanner("Invalid email or password. Please try again.", style: .error) {}
        GlassErrorBanner("Please check your internet connection.", style: .warning) {}
        GlassErrorBanner("Account created successfully!", style: .success) {}
        GlassErrorBanner("Email confirmation sent.", style: .info) {}
        GlassErrorBanner("Non-dismissible error message", style: .error)
    }
    .padding()
    .background(Color.black)
}

#endif
