//
//  TabViewContainer.swift
//  FoodShare
//
//  Created by Claude on 2025-12-29.
//  Copyright © 2025 FoodShare. All rights reserved.
//


#if !SKIP
import SwiftUI

/// A standardized container for tab views that provides consistent background handling,
/// safe area management, and navigation bar configuration.
///
/// This component ensures all tab views follow the Liquid Glass design system patterns
/// and maintain visual consistency across the application.
///
/// ## Usage
///
/// ```swift
/// TabViewContainer {
///     VStack(spacing: 0) {
///         // Header content
///         // Main content
///     }
/// }
///
/// // With gradient background
/// TabViewContainer(backgroundStyle: .gradient) {
///     // Tab content
/// }
///
/// // With custom background
/// TabViewContainer(backgroundStyle: .custom(AnyView(
///     LinearGradient(...)
/// ))) {
///     // Tab content
/// }
/// ```
///
/// ## Design System Integration
///
/// The container automatically applies:
/// - Proper safe area handling with `.ignoresSafeArea()` for backgrounds
/// - Hidden navigation bar for tab-based navigation
/// - Design system color tokens for consistent theming
/// - ZStack pattern for layered content
///
/// ## Performance Considerations
///
/// The container uses a ZStack pattern with a background layer that ignores safe areas.
/// This ensures consistent rendering across different device sizes and orientations
/// while maintaining optimal performance for 120Hz ProMotion displays.
///
/// Defines the background style for the tab view container.
///
/// Use predefined styles for consistency, or provide a custom background
/// when specific visual effects are required.
public enum TabBackgroundStyle: @unchecked Sendable {
    /// Standard solid background using design system background color.
    /// This is the default and most commonly used style.
    case standard

    /// Gradient background using design system gradient colors.
    /// Provides visual depth while maintaining design system consistency.
    case gradient

    /// Custom background view for specialized visual effects.
    /// Use sparingly to maintain design system consistency.
    case custom(AnyView)

    /// Returns the SwiftUI view for the background style.
    @ViewBuilder
    @MainActor
    var backgroundView: some View {
        switch self {
        case .standard:
            Color.DesignSystem.background
                .ignoresSafeArea()

        case .gradient:
            Color.backgroundGradient
                .ignoresSafeArea()

        case let .custom(view):
            view
                .ignoresSafeArea()
        }
    }
}

@frozen
public struct TabViewContainer<Content: View>: View {

    // MARK: - Properties

    /// The background style for this container.
    private let backgroundStyle: TabBackgroundStyle

    /// Whether to hide the navigation bar. Defaults to `true` for tab views.
    private let hideNavigationBar: Bool

    /// The content to display within the container.
    @ViewBuilder private let content: () -> Content

    // MARK: - Initialization

    /// Creates a new tab view container with the specified configuration.
    ///
    /// - Parameters:
    ///   - backgroundStyle: The background style to use. Defaults to `.standard`.
    ///   - hideNavigationBar: Whether to hide the navigation bar. Defaults to `true`.
    ///   - content: A view builder that creates the container's content.
    public init(
        backgroundStyle: TabBackgroundStyle = .standard,
        hideNavigationBar: Bool = true,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.backgroundStyle = backgroundStyle
        self.hideNavigationBar = hideNavigationBar
        self.content = content
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Background layer with safe area handling
            backgroundStyle.backgroundView

            // Content layer respects safe areas
            content()
        }
        .navigationBarHidden(hideNavigationBar)
    }
}

// MARK: - Previews

#Preview("Standard Background") {
    TabViewContainer {
        VStack(spacing: Spacing.lg) {
            Text("Tab Content")
                .font(.DesignSystem.displayLarge)
                .foregroundStyle(Color.DesignSystem.textPrimary)

            GlassCard {
                Text("Sample card content")
                    .font(.DesignSystem.bodyLarge)
                    .foregroundStyle(Color.DesignSystem.textPrimary)
                    .padding(Spacing.md)
            }
        }
        .padding(Spacing.md)
    }
}

#Preview("Gradient Background") {
    TabViewContainer(backgroundStyle: .gradient) {
        VStack(spacing: Spacing.lg) {
            Text("Gradient Tab")
                .font(.DesignSystem.displayLarge)
                .foregroundStyle(Color.DesignSystem.textPrimary)

            GlassCard {
                Text("Content on gradient background")
                    .font(.DesignSystem.bodyLarge)
                    .foregroundStyle(Color.DesignSystem.textPrimary)
                    .padding(Spacing.md)
            }
        }
        .padding(Spacing.md)
    }
}

#Preview("Custom Background") {
    TabViewContainer(
        backgroundStyle: .custom(AnyView(
            LinearGradient(
                colors: [
                    Color.DesignSystem.primary.opacity(0.1),
                    Color.DesignSystem.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            ),
        )),
    ) {
        VStack(spacing: Spacing.lg) {
            Text("Custom Background")
                .font(.DesignSystem.displayLarge)
                .foregroundStyle(Color.DesignSystem.textPrimary)

            GlassCard {
                Text("Content on custom background")
                    .font(.DesignSystem.bodyLarge)
                    .foregroundStyle(Color.DesignSystem.textPrimary)
                    .padding(Spacing.md)
            }
        }
        .padding(Spacing.md)
    }
}

#Preview("Dark Mode") {
    TabViewContainer {
        VStack(spacing: Spacing.lg) {
            Text("Dark Mode")
                .font(.DesignSystem.displayLarge)
                .foregroundStyle(Color.DesignSystem.textPrimary)

            GlassCard {
                Text("Design system colors adapt automatically")
                    .font(.DesignSystem.bodyLarge)
                    .foregroundStyle(Color.DesignSystem.textPrimary)
                    .padding(Spacing.md)
            }
        }
        .padding(Spacing.md)
    }
    .preferredColorScheme(.dark)
}

#Preview("With Navigation Bar") {
    NavigationStack {
        TabViewContainer(hideNavigationBar: false) {
            VStack(spacing: Spacing.lg) {
                Text("Navigation Visible")
                    .font(.DesignSystem.displayLarge)
                    .foregroundStyle(Color.DesignSystem.textPrimary)
            }
            .padding(Spacing.md)
        }
        .navigationTitle("Tab View")
    }
}

#endif
