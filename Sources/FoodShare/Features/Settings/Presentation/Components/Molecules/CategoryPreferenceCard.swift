// MARK: - CategoryPreferenceCard.swift
// Molecular Component: Card Showing All Channels for One Category
// FoodShare iOS - Liquid Glass Design System
// Version: 1.0 - Enterprise Grade

import SwiftUI

/// A card displaying all notification channels for a single category.
///
/// This molecular component provides:
/// - Category icon and description
/// - All channel preferences in one view
/// - Frequency badges for each channel
/// - Expandable/collapsible design
/// - Loading states
///
/// ## Usage
/// ```swift
/// CategoryPreferenceCard(
///     category: .posts,
///     preferences: preferences,
///     viewModel: viewModel
/// )
/// ```
public struct CategoryPreferenceCard: View {
    // MARK: - Properties

    private let category: NotificationCategory
    private let preferences: [NotificationChannel: CategoryPreference]
    private let isExpanded: Bool
    private let onToggle: (NotificationChannel) async -> Void
    private let onFrequencyChange: (NotificationChannel, NotificationFrequency) async -> Void
    private let isLoading: (NotificationChannel) -> Bool
    private let isChannelAvailable: (NotificationChannel) -> Bool

    // MARK: - State

    @State private var showDetails = false

    // MARK: - Initialization

    /// Creates a new category preference card.
    ///
    /// - Parameters:
    ///   - category: The notification category
    ///   - preferences: Dictionary of channel preferences
    ///   - isExpanded: Whether to show expanded view initially
    ///   - onToggle: Handler for toggling channel
    ///   - onFrequencyChange: Handler for changing frequency
    ///   - isLoading: Function to check if channel is loading
    ///   - isChannelAvailable: Function to check if channel is available
    public init(
        category: NotificationCategory,
        preferences: [NotificationChannel: CategoryPreference],
        isExpanded: Bool = false,
        onToggle: @escaping (NotificationChannel) async -> Void,
        onFrequencyChange: @escaping (NotificationChannel, NotificationFrequency) async -> Void,
        isLoading: @escaping (NotificationChannel) -> Bool = { _ in false },
        isChannelAvailable: @escaping (NotificationChannel) -> Bool = { _ in true },
    ) {
        self.category = category
        self.preferences = preferences
        self.isExpanded = isExpanded
        self.onToggle = onToggle
        self.onFrequencyChange = onFrequencyChange
        self.isLoading = isLoading
        self.isChannelAvailable = isChannelAvailable
        self._showDetails = State(initialValue: isExpanded)
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.smooth) {
                    showDetails.toggle()
                }
                HapticFeedback.light()
            } label: {
                HStack(spacing: Spacing.md) {
                    // Expand indicator
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.DesignSystem.textSecondary)
                        .rotationEffect(.degrees(showDetails ? 90 : 0))

                    // Icon
                    NotificationIcon(category: category, size: .medium)

                    // Title and description
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(category.displayName)
                            .font(.DesignSystem.bodyMedium)
                            .foregroundColor(.DesignSystem.textPrimary)

                        if !showDetails {
                            activeChannelsSummary
                        }
                    }

                    Spacer()

                    // Badge count
                    if !showDetails {
                        badgeCount
                    }
                }
                .padding(Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded details
            if showDetails {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, Spacing.md)

                    // Description
                    Text(category.description)
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.sm)
                        .padding(.bottom, Spacing.md)

                    // Channel preferences
                    VStack(spacing: Spacing.sm) {
                        ForEach(NotificationChannel.allCases, id: \.self) { channel in
                            channelRow(for: channel)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.md)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top)),
                ))
            }
        }
        .background(Color.DesignSystem.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var activeChannelsSummary: some View {
        let activeChannels = preferences.values.filter(\.enabled)

        if activeChannels.isEmpty {
            Text("No channels enabled")
                .font(.DesignSystem.captionSmall)
                .foregroundColor(.DesignSystem.textTertiary)
        } else {
            HStack(spacing: 4) {
                ForEach(Array(activeChannels.prefix(3)), id: \.id) { pref in
                    FrequencyBadge(frequency: pref.frequency, isCompact: true)
                }

                if activeChannels.count > 3 {
                    Text("+\(activeChannels.count - 3)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.DesignSystem.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var badgeCount: some View {
        let enabledCount = preferences.values.count(where: { $0.enabled })

        if enabledCount > 0 {
            Text("\(enabledCount)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(minWidth: 20, minHeight: 20)
                .padding(.horizontal, 4)
                .background(Color.DesignSystem.brandGreen)
                .clipShape(Circle())
        }
    }

    @ViewBuilder
    private func channelRow(for channel: NotificationChannel) -> some View {
        let preference = preferences[channel] ?? CategoryPreference(
            category: category,
            channel: channel,
            enabled: false,
            frequency: .instant,
        )

        HStack(spacing: Spacing.sm) {
            // Channel icon
            Image(systemName: channel.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.DesignSystem.textSecondary)
                .frame(width: 20)

            // Channel name
            Text(channel.displayName)
                .font(.DesignSystem.bodySmall)
                .foregroundColor(.DesignSystem.textPrimary)

            // Frequency badge (when enabled)
            if preference.enabled {
                FrequencyBadge(frequency: preference.frequency, isCompact: true)
            }

            Spacer()

            // Toggle
            NotificationToggle(
                isOn: Binding(
                    get: { preference.enabled },
                    set: { _ in
                        Task {
                            await onToggle(channel)
                        }
                    },
                ),
                isLoading: isLoading(channel),
                isDisabled: !isChannelAvailable(channel),
            )
        }
        .padding(Spacing.sm)
        .background(
            preference.enabled
                ? Color.DesignSystem.brandGreen.opacity(0.05)
                : Color.clear,
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    preference.enabled
                        ? Color.DesignSystem.brandGreen.opacity(0.2)
                        : Color.clear,
                    lineWidth: 1,
                ),
        )
        .onTapGesture {
            // Future: Show frequency picker
        }
    }
}

// MARK: - Compact Card

/// A compact version showing just the summary
public struct CompactCategoryPreferenceCard: View {
    private let category: NotificationCategory
    private let enabledCount: Int
    private let totalCount: Int

    public init(
        category: NotificationCategory,
        enabledCount: Int,
        totalCount: Int = 3,
    ) {
        self.category = category
        self.enabledCount = enabledCount
        self.totalCount = totalCount
    }

    public var body: some View {
        HStack(spacing: Spacing.md) {
            NotificationIcon(category: category, size: .small)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.textPrimary)

                Text("\(enabledCount) of \(totalCount) enabled")
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.DesignSystem.textTertiary)
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview("Category Cards") {
    ScrollView {
        VStack(spacing: Spacing.md) {
            // Collapsed
            CategoryPreferenceCard(
                category: .posts,
                preferences: [
                    .push: CategoryPreference(category: .posts, channel: .push, enabled: true, frequency: .instant),
                    .email: CategoryPreference(category: .posts, channel: .email, enabled: true, frequency: .daily),
                    .sms: CategoryPreference(category: .posts, channel: .sms, enabled: false, frequency: .never),
                ],
                onToggle: { _ in },
                onFrequencyChange: { _, _ in },
            )

            // Expanded
            CategoryPreferenceCard(
                category: .chats,
                preferences: [
                    .push: CategoryPreference(category: .chats, channel: .push, enabled: true, frequency: .instant),
                    .email: CategoryPreference(category: .chats, channel: .email, enabled: false, frequency: .daily),
                    .sms: CategoryPreference(category: .chats, channel: .sms, enabled: false, frequency: .never),
                ],
                isExpanded: true,
                onToggle: { _ in },
                onFrequencyChange: { _, _ in },
            )

            // All disabled
            CategoryPreferenceCard(
                category: .marketing,
                preferences: [
                    .push: CategoryPreference(category: .marketing, channel: .push, enabled: false, frequency: .never),
                    .email: CategoryPreference(
                        category: .marketing,
                        channel: .email,
                        enabled: false,
                        frequency: .never,
                    ),
                    .sms: CategoryPreference(category: .marketing, channel: .sms, enabled: false, frequency: .never),
                ],
                onToggle: { _ in },
                onFrequencyChange: { _, _ in },
            )
        }
        .padding(Spacing.md)
    }
    .background(Color.DesignSystem.background)
}

#Preview("Interactive") {
    struct InteractivePreview: View {
        @State private var preferences: [NotificationChannel: CategoryPreference] = [
            .push: CategoryPreference(category: .posts, channel: .push, enabled: true, frequency: .instant),
            .email: CategoryPreference(category: .posts, channel: .email, enabled: false, frequency: .daily),
            .sms: CategoryPreference(category: .posts, channel: .sms, enabled: false, frequency: .never),
        ]

        var body: some View {
            CategoryPreferenceCard(
                category: .posts,
                preferences: preferences,
                isExpanded: true,
                onToggle: { channel in
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    preferences[channel]?.enabled.toggle()
                },
                onFrequencyChange: { channel, frequency in
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    preferences[channel]?.frequency = frequency
                },
            )
            .padding(Spacing.md)
            .background(Color.DesignSystem.background)
        }
    }

    return InteractivePreview()
}

#Preview("Compact Cards") {
    VStack(spacing: Spacing.sm) {
        ForEach(NotificationCategory.allCases, id: \.self) { category in
            CompactCategoryPreferenceCard(
                category: category,
                enabledCount: Int.random(in: 0 ... 3),
                totalCount: 3,
            )
        }
    }
    .padding(Spacing.md)
    .background(Color.DesignSystem.background)
}

#Preview("All Categories Expanded") {
    ScrollView {
        VStack(spacing: Spacing.md) {
            ForEach(NotificationCategory.allCases, id: \.self) { category in
                CategoryPreferenceCard(
                    category: category,
                    preferences: NotificationChannel.allCases.reduce(into: [:]) { dict, channel in
                        dict[channel] = CategoryPreference(
                            category: category,
                            channel: channel,
                            enabled: Bool.random(),
                            frequency: NotificationFrequency.allCases.randomElement() ?? .instant,
                        )
                    },
                    isExpanded: true,
                    onToggle: { _ in },
                    onFrequencyChange: { _, _ in },
                )
            }
        }
        .padding(Spacing.md)
    }
    .background(Color.DesignSystem.background)
}
