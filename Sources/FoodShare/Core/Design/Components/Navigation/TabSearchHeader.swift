//
//  TabSearchHeader.swift
//  Foodshare
//
//  Unified search header component for all tabs
//  Ensures pixel-perfect consistency across Explore, Forum, and Profile tabs
//
//  Best practices:
//  - Single source of truth for search header layout
//  - Configurable action button via ViewBuilder
//  - Consistent animations, spacing, and styling
//  - iOS 17+ @FocusState integration
//

import FoodShareDesignSystem
import SwiftUI

// MARK: - Tab Search Header

/// A unified search header component that provides consistent layout across all tabs.
/// Uses the Explore tab pattern as the source of truth.
///
/// Usage:
/// ```swift
/// TabSearchHeader(
///     searchText: $searchText,
///     isSearchActive: $isSearchActive,
///     isSearchFocused: $isSearchFocused,
///     placeholder: "Search food near you...",
///     showAppInfo: $showAppInfo,
///     onSearchTextChange: { query in
///         // Handle search
///     },
///     onSearchSubmit: {
///         // Handle submit
///     }
/// ) {
///     // Action button (filter, settings, etc.)
///     filterButton
/// }
/// ```
struct TabSearchHeader<ActionButton: View>: View {
    @Binding var searchText: String
    @Binding var isSearchActive: Bool
    var isSearchFocused: FocusState<Bool>.Binding
    let placeholder: String
    @Binding var showAppInfo: Bool
    var onSearchTextChange: ((String) -> Void)?
    var onSearchSubmit: (() -> Void)?
    var onSearchClear: (() -> Void)?
    @ViewBuilder let actionButton: () -> ActionButton

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.translationService) private var t

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // App logo - tap for app info
            appLogoButton

            // Search bar
            searchBar

            // Action button (only show when not in search mode)
            if !isSearchActive {
                actionButton()
                    .transition(.scale.combined(with: .opacity))
            }

            // Cancel button (only show when in search mode)
            if isSearchActive {
                cancelButton
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color.DesignSystem.background.opacity(0.95))
        .animation(springAnimation, value: isSearchActive)
    }

    // MARK: - App Logo Button

    private var appLogoButton: some View {
        Button(action: { showAppInfo = true }) {
            AppLogoView(size: .custom(56), showGlow: false, circular: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(t.t("accessibility.app_info"))
        .accessibilityHint(t.t("accessibility.hint.app_info"))
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        GlassSearchBar(
            text: $searchText,
            placeholder: placeholder,
            onSubmit: {
                onSearchSubmit?()
            },
            onClear: {
                if searchText.isEmpty {
                    withAnimation(springAnimation) {
                        isSearchActive = false
                        isSearchFocused.wrappedValue = false
                    }
                    onSearchClear?()
                }
            },
        )
        .focused(isSearchFocused)
        .onChange(of: searchText) { _, newValue in
            onSearchTextChange?(newValue)
            withAnimation(springAnimation) {
                isSearchActive = !newValue.isEmpty || isSearchFocused.wrappedValue
            }
        }
        .onChange(of: isSearchFocused.wrappedValue) { _, focused in
            if focused {
                withAnimation(springAnimation) {
                    isSearchActive = true
                }
            }
        }
    }

    // MARK: - Cancel Button

    private var cancelButton: some View {
        Button(t.t("common.cancel")) {
            withAnimation(springAnimation) {
                searchText = ""
                isSearchActive = false
                isSearchFocused.wrappedValue = false
            }
            onSearchClear?()
        }
        .font(.DesignSystem.bodyMedium)
        .foregroundColor(.DesignSystem.brandGreen)
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .accessibilityLabel(t.t("accessibility.cancel_search"))
    }

    // MARK: - Animation

    private var springAnimation: Animation {
        reduceMotion ? .linear(duration: 0) : .spring(response: 0.3, dampingFraction: 0.7)
    }
}

// MARK: - Glass Action Button Style

/// Standard action button style for tab search headers.
/// Use this for filter, settings, or other action buttons to ensure consistency.
struct GlassActionButton: View {
    let icon: String
    var rotationDegrees: Double = 0
    var accessibilityLabel = "Action"
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.DesignSystem.text)
                .rotationEffect(.degrees(rotationDegrees))
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                        ),
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Glass Action Button with Notification Indicator

/// Action button with a notification indicator dot on the top-right corner.
/// The dot pulses with a 3-second cycle (1.5s expand, 1.5s contract) when there
/// are unread notifications and remains static grey when there are none.
///
/// Refactored to use NotificationIndicatorModifier for consistency.
///
/// Features:
/// - @MainActor for Swift 6 concurrency safety
/// - Uses atomic NotificationDot component
/// - 44pt minimum tap target for accessibility
/// - GPU-rasterized glass effects for 120Hz ProMotion
///
/// Usage:
/// ```swift
/// GlassActionButtonWithNotification(
///     icon: "slider.horizontal.3",
///     unreadCount: viewModel.unreadCount,
///     accessibilityLabel: "Filters",
///     onButtonTap: { showFilters = true },
///     onNotificationTap: { showNotifications = true }
/// )
/// ```
@MainActor
struct GlassActionButtonWithNotification: View {
    let icon: String
    let unreadCount: Int
    var rotationDegrees: Double = 0
    var accessibilityLabel = "Action"
    let onButtonTap: () -> Void
    let onNotificationTap: () -> Void

    @ScaledMetric(relativeTo: .body) private var buttonSize: CGFloat = 56

    var body: some View {
        Button {
            HapticManager.light()
            onButtonTap()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.DesignSystem.text)
                .rotationEffect(.degrees(rotationDegrees))
                .frame(width: buttonSize, height: buttonSize)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                        ),
                )
        }
        .buttonStyle(.plain)
        .notificationIndicator(
            count: unreadCount,
            style: .dot,
            color: .DesignSystem.brandPink,
            position: .topTrailing,
            showWhenZero: true,
            onTap: onNotificationTap,
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(combinedAccessibilityLabel)
        .accessibilityValue(unreadCount > 0
            ? "\(min(unreadCount, 999))\(unreadCount > 999 ? " plus" : "") unread"
            : "No unread notifications")
            .accessibilityHint("Swipe up or down for more actions")
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityAction(named: "Open Filters") {
                onButtonTap()
            }
            .accessibilityAction(named: "Open Notifications") {
                onNotificationTap()
            }
    }

    // MARK: - Accessibility

    private var combinedAccessibilityLabel: String {
        if unreadCount > 0 {
            let displayCount = min(unreadCount, 999)
            let suffix = unreadCount > 999 ? "+" : ""
            return "\(accessibilityLabel), \(displayCount)\(suffix) unread notification\(displayCount == 1 ? "" : "s")"
        } else {
            return accessibilityLabel
        }
    }
}

// MARK: - Preview

#Preview("Tab Search Header") {
    struct PreviewWrapper: View {
        @State private var searchText = ""
        @State private var isSearchActive = false
        @State private var showAppInfo = false
        @FocusState private var isSearchFocused: Bool

        var body: some View {
            VStack(spacing: 0) {
                TabSearchHeader(
                    searchText: $searchText,
                    isSearchActive: $isSearchActive,
                    isSearchFocused: $isSearchFocused,
                    placeholder: "Search food near you...",
                    showAppInfo: $showAppInfo,
                ) {
                    GlassActionButton(icon: "slider.horizontal.3") {
                        print("Filter tapped")
                    }
                }

                Spacer()

                Text("Search active: \(isSearchActive ? "Yes" : "No")")
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)

                Spacer()
            }
            .background(Color.DesignSystem.background)
        }
    }

    return PreviewWrapper()
}

#Preview("Glass Action Button with Notification") {
    struct PreviewWrapper: View {
        @State private var unreadCount = 5

        var body: some View {
            VStack(spacing: Spacing.xxl) {
                Text("Notification Indicator Button")
                    .font(.DesignSystem.headlineSmall)
                    .foregroundStyle(Color.DesignSystem.textPrimary)

                HStack(spacing: Spacing.xl) {
                    VStack(spacing: Spacing.sm) {
                        GlassActionButtonWithNotification(
                            icon: "slider.horizontal.3",
                            unreadCount: unreadCount,
                            accessibilityLabel: "Filters",
                            onButtonTap: { print("Filters tapped") },
                            onNotificationTap: { print("Notifications tapped") },
                        )
                        Text("With unread")
                            .font(.DesignSystem.caption)
                    }

                    VStack(spacing: Spacing.sm) {
                        GlassActionButtonWithNotification(
                            icon: "slider.horizontal.3",
                            unreadCount: 0,
                            accessibilityLabel: "Filters",
                            onButtonTap: { print("Filters tapped") },
                            onNotificationTap: { print("Notifications tapped") },
                        )
                        Text("No unread")
                            .font(.DesignSystem.caption)
                    }
                }

                Divider()
                    .padding(.horizontal, Spacing.xl)

                HStack(spacing: Spacing.md) {
                    Button("Add") {
                        unreadCount += 1
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Clear") {
                        unreadCount = 0
                    }
                    .buttonStyle(.bordered)
                }

                Text("Count: \(unreadCount)")
                    .font(.DesignSystem.bodySmall)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }
            .padding()
            .background(Color.DesignSystem.background)
        }
    }

    return PreviewWrapper()
}
