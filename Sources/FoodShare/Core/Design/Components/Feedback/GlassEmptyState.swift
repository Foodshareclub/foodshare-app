//
//  GlassEmptyState.swift
//  Foodshare
//
//  Liquid Glass v27 Empty State Component
//  Premium empty state views with animated illustrations, glassmorphism styling,
//  and ProMotion 120Hz optimized animations for smooth visual feedback
//


#if !SKIP
import SwiftUI

// MARK: - Glass Empty State

/// A premium empty state view with Liquid Glass styling and ProMotion animations
/// Use for empty feeds, search results, error states, and onboarding hints
struct GlassEmptyState: View {
    let configuration: EmptyStateConfiguration

    @State private var isAnimating = false
    @State private var iconScale: CGFloat = 0.8
    @State private var iconRotation: Double = -5
    @State private var contentOpacity: Double = 0

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Animated icon
            animatedIcon

            // Text content
            textContent

            // Action button (optional)
            if let action = configuration.action {
                actionButton(action)
            }

            // Secondary action (optional)
            if let secondaryAction = configuration.secondaryAction {
                secondaryButton(secondaryAction)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Animated Icon

    private var animatedIcon: some View {
        ZStack {
            // Glow background
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            configuration.accentColor.opacity(0.3),
                            configuration.accentColor.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 160.0, height: 160)
                .blur(radius: 20)
                .scaleEffect(isAnimating ? 1.1 : 0.9)

            // Glass circle background
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
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: configuration.accentColor.opacity(0.2), radius: 20, y: 5)

            // Icon
            Image(systemName: configuration.icon)
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            configuration.accentColor,
                            configuration.accentColor.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(iconScale)
                .rotationEffect(.degrees(iconRotation))
        }
        .drawingGroup() // GPU rasterization for smooth 120Hz
    }

    // MARK: - Text Content

    private var textContent: some View {
        VStack(spacing: Spacing.sm) {
            Text(configuration.title)
                .font(.DesignSystem.titleMedium)
                .fontWeight(.semibold)
                .foregroundColor(.DesignSystem.text)
                .multilineTextAlignment(.center)

            if let message = configuration.message {
                Text(message)
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .opacity(contentOpacity)
        .offset(y: contentOpacity == 1 ? 0 : 10)
    }

    // MARK: - Action Button

    private func actionButton(_ action: EmptyStateAction) -> some View {
        Button {
            HapticManager.medium()
            action.handler()
        } label: {
            HStack(spacing: Spacing.sm) {
                if let icon = action.icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(action.title)
                    .font(.DesignSystem.labelLarge)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(
                LinearGradient(
                    colors: [
                        configuration.accentColor,
                        configuration.accentColor.opacity(0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: configuration.accentColor.opacity(0.4), radius: 15, y: 5)
        }
        .buttonStyle(EmptyStateButtonStyle())
        .opacity(contentOpacity)
    }

    // MARK: - Secondary Button

    private func secondaryButton(_ action: EmptyStateAction) -> some View {
        Button {
            HapticManager.light()
            action.handler()
        } label: {
            HStack(spacing: Spacing.xs) {
                if let icon = action.icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(action.title)
                    .font(.DesignSystem.labelMedium)
            }
            .foregroundColor(.DesignSystem.textSecondary)
        }
        .buttonStyle(EmptyStateSecondaryButtonStyle())
        .opacity(contentOpacity)
    }

    // MARK: - Animations

    private func startAnimations() {
        // Icon entrance with ProMotion spring
        withAnimation(.interpolatingSpring(stiffness: 200, damping: 15).delay(0.1)) {
            iconScale = 1.0
            iconRotation = 0
        }

        // Content fade in
        withAnimation(.interpolatingSpring(stiffness: 150, damping: 20).delay(0.2)) {
            contentOpacity = 1
        }

        // Continuous glow pulse
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            isAnimating = true
        }
    }
}

// MARK: - Empty State Configuration

struct EmptyStateConfiguration {
    let icon: String
    let title: String
    let message: String?
    let accentColor: Color
    let action: EmptyStateAction?
    let secondaryAction: EmptyStateAction?

    init(
        icon: String,
        title: String,
        message: String? = nil,
        accentColor: Color = .DesignSystem.brandPink,
        action: EmptyStateAction? = nil,
        secondaryAction: EmptyStateAction? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.accentColor = accentColor
        self.action = action
        self.secondaryAction = secondaryAction
    }
}

// MARK: - Empty State Action

struct EmptyStateAction {
    let title: String
    let icon: String?
    let handler: () -> Void

    init(title: String, icon: String? = nil, handler: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.handler = handler
    }
}

// MARK: - Button Styles

private struct EmptyStateButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(Animation.interpolatingSpring(stiffness: 400, damping: 25), value: configuration.isPressed)
    }
}

private struct EmptyStateSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(Animation.interpolatingSpring(stiffness: 400, damping: 25), value: configuration.isPressed)
    }
}

// MARK: - Preset Configurations

extension EmptyStateConfiguration {
    /// Empty search results
    static func noSearchResults(
        query: String,
        onClearSearch: @escaping () -> Void
    ) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "magnifyingglass",
            title: "No Results Found",
            message: "We couldn't find anything matching \"\(query)\". Try adjusting your search or filters.",
            accentColor: .DesignSystem.accentBlue,
            action: EmptyStateAction(title: "Clear Search", icon: "xmark.circle", handler: onClearSearch)
        )
    }

    /// Empty feed / no listings nearby
    static func noListingsNearby(
        onExpandRadius: @escaping () -> Void,
        onCreateListing: @escaping () -> Void
    ) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "mappin.slash",
            title: "No Food Nearby",
            message: "There aren't any food listings in your area yet. Be the first to share!",
            accentColor: .DesignSystem.brandPink,
            action: EmptyStateAction(title: "Share Food", icon: "plus.circle", handler: onCreateListing),
            secondaryAction: EmptyStateAction(title: "Expand Search Radius", handler: onExpandRadius)
        )
    }

    /// Empty messages
    static func noMessages(
        onBrowseFeed: @escaping () -> Void
    ) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "bubble.left.and.bubble.right",
            title: "No Messages Yet",
            message: "Start a conversation by claiming food or responding to requests.",
            accentColor: .DesignSystem.success,
            action: EmptyStateAction(title: "Browse Food", icon: "fork.knife", handler: onBrowseFeed)
        )
    }

    /// Empty favorites
    static func noFavorites(
        onBrowseFeed: @escaping () -> Void
    ) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "heart.slash",
            title: "No Saved Items",
            message: "Tap the heart icon on listings to save them for later.",
            accentColor: .DesignSystem.error,
            action: EmptyStateAction(title: "Explore Food", icon: "sparkle.magnifyingglass", handler: onBrowseFeed)
        )
    }

    /// Empty notifications
    static func noNotifications() -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "bell.slash",
            title: "All Caught Up",
            message: "You don't have any notifications right now. Check back later!",
            accentColor: .DesignSystem.warning
        )
    }

    /// Empty user listings
    static func noUserListings(
        onCreateListing: @escaping () -> Void
    ) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "tray",
            title: "No Listings Yet",
            message: "Share your surplus food with the community and reduce food waste.",
            accentColor: .DesignSystem.brandPink,
            action: EmptyStateAction(title: "Create Listing", icon: "plus", handler: onCreateListing)
        )
    }

    /// Empty reviews
    static func noReviews() -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "star.slash",
            title: "No Reviews Yet",
            message: "Complete food exchanges to receive reviews from the community.",
            accentColor: .DesignSystem.warning
        )
    }

    /// Network error
    static func networkError(
        onRetry: @escaping () -> Void
    ) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "wifi.slash",
            title: "Connection Issue",
            message: "Unable to connect to the server. Please check your internet connection and try again.",
            accentColor: .DesignSystem.error,
            action: EmptyStateAction(title: "Try Again", icon: "arrow.clockwise", handler: onRetry)
        )
    }

    /// Generic error
    static func genericError(
        message: String? = nil,
        onRetry: @escaping () -> Void
    ) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "exclamationmark.triangle",
            title: "Something Went Wrong",
            message: message ?? "An unexpected error occurred. Please try again.",
            accentColor: .DesignSystem.error,
            action: EmptyStateAction(title: "Retry", icon: "arrow.clockwise", handler: onRetry)
        )
    }

    /// Empty forum / no posts
    static func noForumPosts(
        onCreatePost: @escaping () -> Void
    ) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "text.bubble",
            title: "No Discussions Yet",
            message: "Start the conversation! Share tips, ask questions, or connect with the community.",
            accentColor: .DesignSystem.accentBlue,
            action: EmptyStateAction(title: "Start Discussion", icon: "square.and.pencil", handler: onCreatePost)
        )
    }

    /// Empty challenges
    static func noChallenges() -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "trophy",
            title: "No Active Challenges",
            message: "Check back soon for new community challenges and earn badges!",
            accentColor: .DesignSystem.warning
        )
    }

    /// Location permission needed
    static func locationPermissionNeeded(
        onEnableLocation: @escaping () -> Void
    ) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "location.slash",
            title: "Location Access Needed",
            message: "Enable location services to see food listings near you.",
            accentColor: .DesignSystem.accentBlue,
            action: EmptyStateAction(title: "Enable Location", icon: "location.fill", handler: onEnableLocation)
        )
    }
}

// MARK: - Localized Preset Configurations

extension EmptyStateConfiguration {
    /// Localized empty search results
    @MainActor
    static func localizedNoSearchResults(
        query: String,
        using t: EnhancedTranslationService,
        onClearSearch: @escaping () -> Void
    ) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "magnifyingglass",
            title: t.t("empty_state.no_results.title"),
            message: t.t("empty_state.no_results.message", args: ["query": query]),
            accentColor: .DesignSystem.accentBlue,
            action: EmptyStateAction(title: t.t("empty_state.no_results.action"), icon: "xmark.circle", handler: onClearSearch)
        )
    }

    /// Localized empty feed / no listings nearby
    @MainActor
    static func localizedNoListingsNearby(
        using t: EnhancedTranslationService,
        onExpandRadius: @escaping () -> Void,
        onCreateListing: @escaping () -> Void
    ) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "mappin.slash",
            title: t.t("empty_state.no_listings.title"),
            message: t.t("empty_state.no_listings.message"),
            accentColor: .DesignSystem.brandPink,
            action: EmptyStateAction(title: t.t("empty_state.no_listings.action"), icon: "plus.circle", handler: onCreateListing),
            secondaryAction: EmptyStateAction(title: t.t("empty_state.no_listings.secondary_action"), handler: onExpandRadius)
        )
    }

    /// Localized empty messages
    @MainActor
    static func localizedNoMessages(
        using t: EnhancedTranslationService,
        onBrowseFeed: @escaping () -> Void
    ) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "bubble.left.and.bubble.right",
            title: t.t("empty_state.no_messages.title"),
            message: t.t("empty_state.no_messages.message"),
            accentColor: .DesignSystem.success,
            action: EmptyStateAction(title: t.t("empty_state.no_messages.action"), icon: "fork.knife", handler: onBrowseFeed)
        )
    }

    /// Localized empty favorites
    @MainActor
    static func localizedNoFavorites(
        using t: EnhancedTranslationService,
        onBrowseFeed: @escaping () -> Void
    ) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "heart.slash",
            title: t.t("empty_state.no_favorites.title"),
            message: t.t("empty_state.no_favorites.message"),
            accentColor: .DesignSystem.error,
            action: EmptyStateAction(title: t.t("empty_state.no_favorites.action"), icon: "sparkle.magnifyingglass", handler: onBrowseFeed)
        )
    }

    /// Localized empty notifications
    @MainActor
    static func localizedNoNotifications(
        using t: EnhancedTranslationService
    ) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "bell.slash",
            title: t.t("empty_state.no_notifications.title"),
            message: t.t("empty_state.no_notifications.message"),
            accentColor: .DesignSystem.warning
        )
    }

    /// Localized empty user listings
    @MainActor
    static func localizedNoUserListings(
        using t: EnhancedTranslationService,
        onCreateListing: @escaping () -> Void
    ) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "tray",
            title: t.t("empty_state.no_user_listings.title"),
            message: t.t("empty_state.no_user_listings.message"),
            accentColor: .DesignSystem.brandPink,
            action: EmptyStateAction(title: t.t("empty_state.no_user_listings.action"), icon: "plus", handler: onCreateListing)
        )
    }

    /// Localized empty reviews
    @MainActor
    static func localizedNoReviews(
        using t: EnhancedTranslationService
    ) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "star.slash",
            title: t.t("empty_state.no_reviews.title"),
            message: t.t("empty_state.no_reviews.message"),
            accentColor: .DesignSystem.warning
        )
    }

    /// Localized network error
    @MainActor
    static func localizedNetworkError(
        using t: EnhancedTranslationService,
        onRetry: @escaping () -> Void
    ) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "wifi.slash",
            title: t.t("empty_state.network_error.title"),
            message: t.t("empty_state.network_error.message"),
            accentColor: .DesignSystem.error,
            action: EmptyStateAction(title: t.t("empty_state.network_error.action"), icon: "arrow.clockwise", handler: onRetry)
        )
    }

    /// Localized generic error
    @MainActor
    static func localizedGenericError(
        using t: EnhancedTranslationService,
        message: String? = nil,
        onRetry: @escaping () -> Void
    ) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "exclamationmark.triangle",
            title: t.t("empty_state.generic_error.title"),
            message: message ?? t.t("empty_state.generic_error.message"),
            accentColor: .DesignSystem.error,
            action: EmptyStateAction(title: t.t("empty_state.generic_error.action"), icon: "arrow.clockwise", handler: onRetry)
        )
    }

    /// Localized empty forum / no posts
    @MainActor
    static func localizedNoForumPosts(
        using t: EnhancedTranslationService,
        onCreatePost: @escaping () -> Void
    ) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "text.bubble",
            title: t.t("empty_state.no_forum_posts.title"),
            message: t.t("empty_state.no_forum_posts.message"),
            accentColor: .DesignSystem.accentBlue,
            action: EmptyStateAction(title: t.t("empty_state.no_forum_posts.action"), icon: "square.and.pencil", handler: onCreatePost)
        )
    }

    /// Localized empty challenges
    @MainActor
    static func localizedNoChallenges(
        using t: EnhancedTranslationService
    ) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "trophy",
            title: t.t("empty_state.no_challenges.title"),
            message: t.t("empty_state.no_challenges.message"),
            accentColor: .DesignSystem.warning
        )
    }

    /// Localized location permission needed
    @MainActor
    static func localizedLocationPermissionNeeded(
        using t: EnhancedTranslationService,
        onEnableLocation: @escaping () -> Void
    ) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "location.slash",
            title: t.t("empty_state.location_permission.title"),
            message: t.t("empty_state.location_permission.message"),
            accentColor: .DesignSystem.accentBlue,
            action: EmptyStateAction(title: t.t("empty_state.location_permission.action"), icon: "location.fill", handler: onEnableLocation)
        )
    }
}

// MARK: - Compact Empty State

/// A smaller empty state variant for inline use (e.g., in sections)
struct GlassEmptyStateCompact: View {
    let icon: String
    let message: String
    let accentColor: Color

    init(
        icon: String,
        message: String,
        accentColor: Color = .DesignSystem.textSecondary
    ) {
        self.icon = icon
        self.message = message
        self.accentColor = accentColor
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(accentColor.opacity(0.6))

            Text(message)
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - View Extension

extension View {
    /// Shows an empty state overlay when the condition is true
    @ViewBuilder
    func glassEmptyState(
        when isEmpty: Bool,
        configuration: EmptyStateConfiguration
    ) -> some View {
        if isEmpty {
            GlassEmptyState(configuration: configuration)
        } else {
            self
        }
    }
}

// MARK: - Previews

#Preview("No Listings Nearby") {
    ZStack {
        Color.DesignSystem.background
            .ignoresSafeArea()

        GlassEmptyState(
            configuration: .noListingsNearby(
                onExpandRadius: { print("Expand radius") },
                onCreateListing: { print("Create listing") }
            )
        )
    }
}

#Preview("No Search Results") {
    ZStack {
        Color.DesignSystem.background
            .ignoresSafeArea()

        GlassEmptyState(
            configuration: .noSearchResults(
                query: "organic apples",
                onClearSearch: { print("Clear search") }
            )
        )
    }
}

#Preview("Network Error") {
    ZStack {
        Color.DesignSystem.background
            .ignoresSafeArea()

        GlassEmptyState(
            configuration: .networkError(
                onRetry: { print("Retry") }
            )
        )
    }
}

#Preview("No Messages") {
    ZStack {
        Color.DesignSystem.background
            .ignoresSafeArea()

        GlassEmptyState(
            configuration: .noMessages(
                onBrowseFeed: { print("Browse") }
            )
        )
    }
}

#Preview("Compact Empty State") {
    ZStack {
        Color.DesignSystem.background
            .ignoresSafeArea()

        VStack(spacing: Spacing.lg) {
            GlassEmptyStateCompact(
                icon: "tray",
                message: "No items in this category"
            )

            GlassEmptyStateCompact(
                icon: "clock",
                message: "No recent activity",
                accentColor: .DesignSystem.warning
            )
        }
        .padding()
    }
}

#endif
