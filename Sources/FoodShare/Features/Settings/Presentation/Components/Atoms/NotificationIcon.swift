// MARK: - NotificationIcon.swift
// Atomic Component: Category/Channel Icon with Gradient Background
// FoodShare iOS - Liquid Glass Design System
// Version: 1.0 - Enterprise Grade

import SwiftUI

/// A circular icon with gradient background for notification categories and channels.
///
/// This atomic component provides:
/// - Gradient backgrounds matching Liquid Glass design
/// - Multiple size variants (small, medium, large)
/// - Customizable icon and colors
/// - Accessibility support
///
/// ## Usage
/// ```swift
/// NotificationIcon(
///     systemName: "bell.fill",
///     gradientColors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
///     size: .medium
/// )
/// ```
public struct NotificationIcon: View {
    // MARK: - Size

    /// Predefined size variants
    public enum Size {
        case small
        case medium
        case large

        var dimension: CGFloat {
            switch self {
            case .small: 32
            case .medium: 44
            case .large: 56
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small: 14
            case .medium: 18
            case .large: 24
            }
        }
    }

    // MARK: - Properties

    /// SF Symbol name for the icon
    private let systemName: String

    /// Gradient colors (top-leading to bottom-trailing)
    private let gradientColors: [Color]

    /// Size variant
    private let size: Size

    /// Optional badge count
    private let badgeCount: Int?

    // MARK: - Initialization

    /// Creates a new notification icon.
    ///
    /// - Parameters:
    ///   - systemName: SF Symbol name
    ///   - gradientColors: Array of colors for gradient (defaults to green-blue)
    ///   - size: Size variant
    ///   - badgeCount: Optional badge count to display
    public init(
        systemName: String,
        gradientColors: [Color] = [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
        size: Size = .medium,
        badgeCount: Int? = nil,
    ) {
        self.systemName = systemName
        self.gradientColors = gradientColors
        self.size = size
        self.badgeCount = badgeCount
    }

    // MARK: - Body

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            // Icon container
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .frame(width: size.dimension, height: size.dimension)
                    .shadow(
                        color: gradientColors.first?.opacity(0.3) ?? .clear,
                        radius: 8,
                        x: 0,
                        y: 4,
                    )

                Image(systemName: systemName)
                    .font(.system(size: size.iconSize, weight: .semibold))
                    .foregroundStyle(.white)
            }

            // Badge
            if let count = badgeCount, count > 0 {
                Text("\(min(count, 99))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(minWidth: 16, minHeight: 16)
                    .padding(.horizontal, 4)
                    .background(Color.DesignSystem.error)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.DesignSystem.background, lineWidth: 2),
                    )
                    .offset(x: 4, y: -4)
            }
        }
    }
}

// MARK: - Category Convenience

extension NotificationIcon {
    /// Create an icon for a notification category with preset colors
    ///
    /// - Parameters:
    ///   - category: The notification category
    ///   - size: Size variant
    ///   - badgeCount: Optional badge count
    public init(category: NotificationCategory, size: Size = .medium, badgeCount: Int? = nil) {
        let colors = category.gradientColors
        self.init(
            systemName: category.icon,
            gradientColors: colors,
            size: size,
            badgeCount: badgeCount,
        )
    }

    /// Create an icon for a notification channel with preset colors
    ///
    /// - Parameters:
    ///   - channel: The notification channel
    ///   - size: Size variant
    ///   - badgeCount: Optional badge count
    public init(channel: NotificationChannel, size: Size = .medium, badgeCount: Int? = nil) {
        let colors = channel.gradientColors
        self.init(
            systemName: channel.icon,
            gradientColors: colors,
            size: size,
            badgeCount: badgeCount,
        )
    }
}

// MARK: - Category Extensions

extension NotificationCategory {
    fileprivate var gradientColors: [Color] {
        switch self {
        case .posts:
            [.DesignSystem.brandGreen, .DesignSystem.greenLight]
        case .forum:
            [.DesignSystem.brandBlue, .DesignSystem.blueLight]
        case .challenges:
            [.DesignSystem.accentOrange, .DesignSystem.accentPink]
        case .comments:
            [.DesignSystem.accentPurple, .DesignSystem.brandBlue]
        case .chats:
            [.DesignSystem.brandBlue, .DesignSystem.accentPurple]
        case .social:
            [.DesignSystem.accentPink, .DesignSystem.accentOrange]
        case .system:
            [.DesignSystem.textSecondary, .DesignSystem.textTertiary]
        case .marketing:
            [.DesignSystem.accentOrange, .DesignSystem.brandGreen]
        }
    }
}

extension NotificationChannel {
    fileprivate var gradientColors: [Color] {
        switch self {
        case .push:
            [.DesignSystem.brandGreen, .DesignSystem.brandBlue]
        case .email:
            [.DesignSystem.brandBlue, .DesignSystem.accentPurple]
        case .sms:
            [.DesignSystem.accentPurple, .DesignSystem.accentPink]
        }
    }
}

// MARK: - Preview

#Preview("Icon Sizes") {
    VStack(spacing: Spacing.xl) {
        // Size variants
        HStack(spacing: Spacing.lg) {
            VStack {
                NotificationIcon(
                    systemName: "bell.fill",
                    size: .small,
                )
                Text("Small")
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            VStack {
                NotificationIcon(
                    systemName: "bell.fill",
                    size: .medium,
                )
                Text("Medium")
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            VStack {
                NotificationIcon(
                    systemName: "bell.fill",
                    size: .large,
                )
                Text("Large")
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }
        }

        Divider()

        // Category icons
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Categories")
                .font(.DesignSystem.headlineSmall)
                .foregroundColor(.DesignSystem.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: Spacing.md) {
                ForEach(NotificationCategory.allCases, id: \.self) { category in
                    VStack(spacing: Spacing.xs) {
                        NotificationIcon(category: category)
                        Text(category.displayName)
                            .font(.DesignSystem.captionSmall)
                            .foregroundColor(.DesignSystem.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(height: 30)
                    }
                }
            }
        }

        Divider()

        // Channel icons
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Channels")
                .font(.DesignSystem.headlineSmall)
                .foregroundColor(.DesignSystem.textPrimary)

            HStack(spacing: Spacing.lg) {
                ForEach(NotificationChannel.allCases, id: \.self) { channel in
                    VStack(spacing: Spacing.xs) {
                        NotificationIcon(channel: channel)
                        Text(channel.displayName)
                            .font(.DesignSystem.captionSmall)
                            .foregroundColor(.DesignSystem.textSecondary)
                    }
                }
            }
        }

        Divider()

        // With badges
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("With Badges")
                .font(.DesignSystem.headlineSmall)
                .foregroundColor(.DesignSystem.textPrimary)

            HStack(spacing: Spacing.lg) {
                NotificationIcon(
                    category: .chats,
                    badgeCount: 3,
                )
                NotificationIcon(
                    category: .posts,
                    badgeCount: 12,
                )
                NotificationIcon(
                    category: .comments,
                    badgeCount: 99,
                )
                NotificationIcon(
                    category: .social,
                    badgeCount: 150, // Should show as 99
                )
            }
        }
    }
    .padding(Spacing.lg)
    .background(Color.DesignSystem.background)
}

#Preview("Custom Icons") {
    VStack(spacing: Spacing.lg) {
        NotificationIcon(
            systemName: "sparkles",
            gradientColors: [.yellow, .orange],
        )

        NotificationIcon(
            systemName: "heart.fill",
            gradientColors: [.pink, .red],
            size: .large,
        )

        NotificationIcon(
            systemName: "star.fill",
            gradientColors: [.purple, .blue],
            size: .small,
            badgeCount: 5,
        )
    }
    .padding(Spacing.lg)
    .background(Color.DesignSystem.background)
}
