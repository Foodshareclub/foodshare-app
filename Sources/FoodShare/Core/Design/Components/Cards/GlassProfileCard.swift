//
//  GlassProfileCard.swift
//  Foodshare
//
//  Liquid Glass profile card with stats and actions
//  Matches web app profile design
//

import SwiftUI
import FoodShareDesignSystem

struct GlassProfileCard: View {
    let name: String
    let avatarUrl: String?
    let stats: ProfileCardStats
    let isCurrentUser: Bool
    let onEditProfile: (() -> Void)?
    let onMessage: (() -> Void)?

    init(
        name: String,
        avatarUrl: String? = nil,
        stats: ProfileCardStats,
        isCurrentUser: Bool = false,
        onEditProfile: (() -> Void)? = nil,
        onMessage: (() -> Void)? = nil,
    ) {
        self.name = name
        self.avatarUrl = avatarUrl
        self.stats = stats
        self.isCurrentUser = isCurrentUser
        self.onEditProfile = onEditProfile
        self.onMessage = onMessage
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Avatar and Name
            VStack(spacing: Spacing.md) {
                avatarView

                Text(name)
                    .font(.DesignSystem.displaySmall)
                    .foregroundColor(.DesignSystem.text)

                // Rating
                if stats.ratingCount > 0 {
                    HStack(spacing: Spacing.xs) {
                        ForEach(0 ..< 5) { index in
                            Image(systemName: index < Int(stats.ratingAverage.rounded()) ? "star.fill" : "star")
                                .font(.system(size: 14))
                                .foregroundColor(.yellow)
                        }
                        Text(String(format: "%.1f", stats.ratingAverage))
                            .font(.DesignSystem.bodySmall)
                            .foregroundColor(.DesignSystem.textSecondary)
                        Text("(\(stats.ratingCount))")
                            .font(.DesignSystem.caption)
                            .foregroundColor(.DesignSystem.textTertiary)
                    }
                }
            }

            // Stats Row
            HStack(spacing: 0) {
                StatItem(
                    value: "\(stats.itemsShared)",
                    label: "Shared",
                    icon: "gift.fill",
                    color: .DesignSystem.brandGreen,
                )

                Divider()
                    .frame(height: 40)

                StatItem(
                    value: "\(stats.itemsReceived)",
                    label: "Received",
                    icon: "hand.raised.fill",
                    color: .DesignSystem.brandBlue,
                )

                Divider()
                    .frame(height: 40)

                StatItem(value: "\(stats.totalLikes)", label: "Likes", icon: "heart.fill", color: .red)
            }
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                    ),
            )

            // Action Buttons
            if isCurrentUser {
                GlassButton("Edit Profile", icon: "pencil", style: .secondary) {
                    onEditProfile?()
                }
            } else {
                GlassButton("Send Message", icon: "message.fill", style: .primary) {
                    onMessage?()
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.xl)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
        .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var description = "Profile. \(name)"

        if stats.ratingCount > 0 {
            description += ". Rating \(String(format: "%.1f", stats.ratingAverage)) out of 5, based on \(stats.ratingCount) reviews"
        }

        description += ". \(stats.itemsShared) items shared"
        description += ". \(stats.itemsReceived) items received"
        description += ". \(stats.totalLikes) total likes"

        if isCurrentUser {
            description += ". Edit profile button available"
        } else {
            description += ". Send message button available"
        }

        return description
    }

    // MARK: - Avatar View

    private var avatarView: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                    lineWidth: 3,
                )
                .frame(width: 104, height: 104)

            // Avatar image
            if let avatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    avatarPlaceholder
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
            }
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.DesignSystem.brandGreen.opacity(0.3), .DesignSystem.brandBlue.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                ),
            )
            .frame(width: 96, height: 96)
            .overlay(
                Text(name.prefix(1).uppercased())
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.DesignSystem.brandGreen),
            )
    }
}

// MARK: - Stat Item

private struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(value)
                    .font(.DesignSystem.headlineMedium)
                    .foregroundColor(.DesignSystem.text)
            }

            Text(label)
                .font(.DesignSystem.captionSmall)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Profile Card Stats Model (UI-specific)

struct ProfileCardStats {
    let itemsShared: Int
    let itemsReceived: Int
    let totalLikes: Int
    let ratingAverage: Double
    let ratingCount: Int

    static let empty = ProfileCardStats(
        itemsShared: 0,
        itemsReceived: 0,
        totalLikes: 0,
        ratingAverage: 0,
        ratingCount: 0,
    )

    static let sample = ProfileCardStats(
        itemsShared: 42,
        itemsReceived: 15,
        totalLikes: 128,
        ratingAverage: 4.8,
        ratingCount: 23,
    )

    /// Create from domain ProfileStats model
    init(from stats: ProfileStats) {
        itemsShared = stats.itemsShared
        itemsReceived = stats.itemsReceived
        totalLikes = stats.totalLikes
        ratingAverage = stats.ratingAverage
        ratingCount = stats.ratingCount
    }

    init(itemsShared: Int, itemsReceived: Int, totalLikes: Int, ratingAverage: Double, ratingCount: Int) {
        self.itemsShared = itemsShared
        self.itemsReceived = itemsReceived
        self.totalLikes = totalLikes
        self.ratingAverage = ratingAverage
        self.ratingCount = ratingCount
    }
}

// MARK: - Compact Profile Row

struct GlassProfileRow: View {
    let name: String
    let avatarUrl: String?
    let subtitle: String?
    let badge: String?
    let onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: Spacing.md) {
                // Avatar
                if let avatarUrl, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.DesignSystem.glassBackground)
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.DesignSystem.brandGreen.opacity(0.3), .DesignSystem.brandBlue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .frame(width: 48, height: 48)
                        .overlay(
                            Text(name.prefix(1).uppercased())
                                .font(.DesignSystem.headlineSmall)
                                .foregroundColor(.DesignSystem.brandGreen),
                        )
                }

                // Name and subtitle
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.xs) {
                        Text(name)
                            .font(.DesignSystem.bodyLarge)
                            .fontWeight(.medium)
                            .foregroundColor(.DesignSystem.text)

                        if let badge {
                            Text(badge)
                                .font(.DesignSystem.captionSmall)
                                .foregroundColor(.white)
                                .padding(.horizontal, Spacing.xs)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.DesignSystem.brandGreen),
                                )
                        }
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(.DesignSystem.bodySmall)
                            .foregroundColor(.DesignSystem.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.DesignSystem.textTertiary)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                    ),
            )
        }
        .buttonStyle(CardPressStyle())
    }
}

#Preview("Profile Card") {
    VStack(spacing: Spacing.lg) {
        GlassProfileCard(
            name: "Sarah Mitchell",
            stats: .sample,
            isCurrentUser: true,
            onEditProfile: {},
        )

        GlassProfileRow(
            name: "John Doe",
            avatarUrl: nil,
            subtitle: "Shared 15 items",
            badge: "Top Sharer",
            onTap: {},
        )
    }
    .padding()
    .background(Color.DesignSystem.background)
}
