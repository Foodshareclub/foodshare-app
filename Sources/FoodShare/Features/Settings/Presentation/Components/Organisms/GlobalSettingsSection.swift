// MARK: - GlobalSettingsSection.swift
// Organism Component: Master Toggles for Push/Email/SMS
// FoodShare iOS - Liquid Glass Design System
// Version: 1.0 - Enterprise Grade


#if !SKIP
import SwiftUI

/// A section containing master toggles for all notification channels.
///
/// This organism component provides:
/// - Master toggles for push, email, and SMS
/// - Availability indicators
/// - Verification prompts
/// - Stats summary
/// - Expandable channel sections
///
/// ## Usage
/// ```swift
/// GlobalSettingsSection(viewModel: viewModel)
/// ```
@MainActor
public struct GlobalSettingsSection: View {
    // MARK: - Properties

    @Bindable private var viewModel: NotificationPreferencesViewModel

    // MARK: - Initialization

    /// Creates a new global settings section.
    ///
    /// - Parameter viewModel: The notification preferences view model
    public init(viewModel: NotificationPreferencesViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: Spacing.md) {
            // Section header
            sectionHeader

            // Channel toggles
            VStack(spacing: Spacing.sm) {
                // Push notifications
                ChannelHeader(
                    channel: .push,
                    isExpanded: Binding(
                        get: { viewModel.isSectionExpanded(.push) },
                        set: { _ in viewModel.toggleSection(.push) },
                    ),
                    isEnabled: Binding(
                        get: { viewModel.preferences.settings.pushEnabled },
                        set: { _ in
                            Task {
                                await viewModel.togglePushEnabled()
                            }
                        },
                    ),
                    isAvailable: viewModel.isPushAvailable,
                    isLoading: viewModel.updatingPreferences.contains("push-global"),
                )

                // Expandable push categories
                if viewModel.isSectionExpanded(.push) {
                    pushCategoriesView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .top)),
                        ))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(spacing: Spacing.sm) {
                // Email notifications
                ChannelHeader(
                    channel: .email,
                    isExpanded: Binding(
                        get: { viewModel.isSectionExpanded(.email) },
                        set: { _ in viewModel.toggleSection(.email) },
                    ),
                    isEnabled: Binding(
                        get: { viewModel.preferences.settings.emailEnabled },
                        set: { _ in
                            Task {
                                await viewModel.toggleEmailEnabled()
                            }
                        },
                    ),
                    isAvailable: viewModel.isEmailAvailable,
                    isLoading: viewModel.updatingPreferences.contains("email-global"),
                )

                // Expandable email categories
                if viewModel.isSectionExpanded(.email) {
                    emailCategoriesView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .top)),
                        ))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(spacing: Spacing.sm) {
                // SMS notifications
                ChannelHeader(
                    channel: .sms,
                    isExpanded: Binding(
                        get: { viewModel.isSectionExpanded(.sms) },
                        set: { _ in viewModel.toggleSection(.sms) },
                    ),
                    isEnabled: Binding(
                        get: { viewModel.preferences.settings.smsEnabled },
                        set: { _ in
                            Task {
                                await viewModel.toggleSMSEnabled()
                            }
                        },
                    ),
                    isAvailable: viewModel.isSMSAvailable,
                    isLoading: viewModel.updatingPreferences.contains("sms-global"),
                )

                // Expandable SMS categories
                if viewModel.isSectionExpanded(.sms) {
                    smsCategoriesView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .top)),
                        ))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Statistics summary
            if viewModel.preferences.settings.pushEnabled ||
                viewModel.preferences.settings.emailEnabled ||
                viewModel.preferences.settings.smsEnabled
            {
                statisticsSummary
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Notification Channels")
                    .font(.DesignSystem.headlineLarge)
                    .foregroundColor(.DesignSystem.textPrimary)

                Text("Control how you receive notifications")
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Category Views

    private var pushCategoriesView: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(viewModel.filteredCategories, id: \.self) { category in
                SimpleNotificationPreferenceRow(
                    category: category,
                    channel: .push,
                    isEnabled: viewModel.enabledBinding(category: category, channel: .push),
                    isLoading: viewModel.isUpdating(category: category, channel: .push),
                    isDisabled: !viewModel.preferences.settings.pushEnabled,
                )
            }
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.glassBackground)
    }

    private var emailCategoriesView: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(viewModel.filteredCategories, id: \.self) { category in
                SimpleNotificationPreferenceRow(
                    category: category,
                    channel: .email,
                    isEnabled: viewModel.enabledBinding(category: category, channel: .email),
                    isLoading: viewModel.isUpdating(category: category, channel: .email),
                    isDisabled: !viewModel.preferences.settings.emailEnabled,
                )
            }
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.glassBackground)
    }

    private var smsCategoriesView: some View {
        VStack(spacing: Spacing.sm) {
            if !viewModel.isSMSAvailable {
                // Verification prompt
                VStack(spacing: Spacing.sm) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "phone.fill.badge.checkmark")
                            .font(.DesignSystem.titleMedium)
                            .foregroundColor(.DesignSystem.brandBlue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Verify Your Phone")
                                .font(.DesignSystem.bodyMedium)
                                .foregroundColor(.DesignSystem.textPrimary)

                            Text("Add and verify your phone number to receive SMS notifications")
                                .font(.DesignSystem.captionSmall)
                                .foregroundColor(.DesignSystem.textSecondary)
                        }

                        Spacer()
                    }

                    Button {
                        viewModel.showPhoneVerificationSheet = true
                    } label: {
                        Text("Verify Phone Number")
                            .font(.DesignSystem.bodyMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .background(Color.DesignSystem.brandBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(Spacing.md)
            } else {
                ForEach(viewModel.filteredCategories, id: \.self) { category in
                    SimpleNotificationPreferenceRow(
                        category: category,
                        channel: .sms,
                        isEnabled: viewModel.enabledBinding(category: category, channel: .sms),
                        isLoading: viewModel.isUpdating(category: category, channel: .sms),
                        isDisabled: !viewModel.preferences.settings.smsEnabled,
                    )
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.glassBackground)
    }

    // MARK: - Statistics Summary

    private var statisticsSummary: some View {
        HStack(spacing: Spacing.lg) {
            // Push stats
            if viewModel.preferences.settings.pushEnabled {
                statItem(
                    icon: "bell.badge.fill",
                    color: .DesignSystem.brandGreen,
                    count: viewModel.preferences.preferences(for: NotificationChannel.push).filter({ $0.enabled }).count,
                    total: NotificationCategory.allCases.count,
                    label: "Push",
                )
            }

            // Email stats
            if viewModel.preferences.settings.emailEnabled {
                statItem(
                    icon: "envelope.fill",
                    color: .DesignSystem.brandBlue,
                    count: viewModel.preferences.preferences(for: NotificationChannel.email).filter({ $0.enabled }).count,
                    total: NotificationCategory.allCases.count,
                    label: "Email",
                )
            }

            // SMS stats
            if viewModel.preferences.settings.smsEnabled {
                statItem(
                    icon: "text.bubble.fill",
                    color: .DesignSystem.accentPurple,
                    count: viewModel.preferences.preferences(for: NotificationChannel.sms).filter({ $0.enabled }).count,
                    total: NotificationCategory.allCases.count,
                    label: "SMS",
                )
            }
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statItem(icon: String, color: Color, count: Int, total: Int, label: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text("\(count)/\(total)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.DesignSystem.textPrimary)

            Text(label)
                .font(.DesignSystem.captionSmall)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview("Global Settings Section") {
    ScrollView {
        GlobalSettingsSection(viewModel: .preview)
            .padding(Spacing.md)
    }
    .background(Color.DesignSystem.background)
}

#Preview("With Expanded Sections") {
    struct PreviewContainer: View {
        @State private var viewModel = NotificationPreferencesViewModel.preview

        var body: some View {
            ScrollView {
                GlobalSettingsSection(viewModel: viewModel)
                    .padding(Spacing.md)
            }
            .background(Color.DesignSystem.background)
            .onAppear {
                viewModel.expandedSections = [.push, .email]
            }
        }
    }

    return PreviewContainer()
}

#Preview("SMS Not Verified") {
    struct PreviewContainer: View {
        @State private var viewModel = NotificationPreferencesViewModel.preview

        var body: some View {
            ScrollView {
                GlobalSettingsSection(viewModel: viewModel)
                    .padding(Spacing.md)
            }
            .background(Color.DesignSystem.background)
            .onAppear {
                viewModel.preferences.settings.phoneVerified = false
                viewModel.expandedSections = [.sms]
            }
        }
    }

    return PreviewContainer()
}

#endif
