// MARK: - ScheduleSection.swift
// Organism Component: DND + Quiet Hours + Digest Settings
// FoodShare iOS - Liquid Glass Design System
// Version: 1.0 - Enterprise Grade

import SwiftUI

/// A section containing schedule-based notification controls.
///
/// This organism component provides:
/// - Do Not Disturb card
/// - Quiet Hours card
/// - Digest settings
/// - Schedule overview
///
/// ## Usage
/// ```swift
/// ScheduleSection(viewModel: viewModel)
/// ```
@MainActor
public struct ScheduleSection: View {
    // MARK: - Properties

    @Bindable private var viewModel: NotificationPreferencesViewModel

    // MARK: - Initialization

    /// Creates a new schedule section.
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

            // DND card
            DNDStatusCard(
                dnd: viewModel.preferences.settings.dnd,
                onEnable: { hours in
                    await viewModel.enableDND(hours: hours)
                },
                onDisable: {
                    await viewModel.disableDND()
                },
                onCustomize: {
                    viewModel.showDNDSheet = true
                },
            )

            // Quiet Hours card
            QuietHoursCard(
                quietHours: viewModel.preferences.settings.quietHours,
                onToggle: { enabled in
                    let qh = viewModel.preferences.settings.quietHours
                    await viewModel.updateQuietHours(
                        enabled: enabled,
                        start: qh.start,
                        end: qh.end,
                    )
                },
                onConfigure: {
                    viewModel.showQuietHoursSheet = true
                },
            )

            // Digest settings
            digestSettings

            // Info card
            infoCard
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Schedule & Delivery")
                    .font(.DesignSystem.headlineLarge)
                    .foregroundColor(.DesignSystem.textPrimary)

                Text("Control when and how often you receive notifications")
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Digest Settings

    private var digestSettings: some View {
        VStack(spacing: Spacing.md) {
            // Daily digest
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.DesignSystem.accentOrange, .DesignSystem.brandGreen],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Daily Digest")
                        .font(.DesignSystem.headlineSmall)
                        .foregroundColor(.DesignSystem.textPrimary)

                    if viewModel.preferences.settings.digest.dailyEnabled {
                        Text("Every day at \(viewModel.preferences.settings.digest.dailyTime)")
                            .font(.DesignSystem.captionSmall)
                            .foregroundColor(.DesignSystem.accentOrange)
                    } else {
                        Text("Disabled")
                            .font(.DesignSystem.captionSmall)
                            .foregroundColor(.DesignSystem.textSecondary)
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { viewModel.preferences.settings.digest.dailyEnabled },
                    set: { newValue in
                        Task {
                            await viewModel.updateDigestSettings(dailyEnabled: newValue)
                        }
                    },
                ))
                .tint(.DesignSystem.accentOrange)
                .labelsHidden()
            }
            .padding(Spacing.md)
            .background(Color.DesignSystem.glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Weekly digest
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.DesignSystem.accentPurple, .DesignSystem.brandBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "calendar")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Weekly Digest")
                        .font(.DesignSystem.headlineSmall)
                        .foregroundColor(.DesignSystem.textPrimary)

                    if viewModel.preferences.settings.digest.weeklyEnabled {
                        Text("Every \(viewModel.preferences.settings.digest.weeklyDayName)")
                            .font(.DesignSystem.captionSmall)
                            .foregroundColor(.DesignSystem.accentPurple)
                    } else {
                        Text("Disabled")
                            .font(.DesignSystem.captionSmall)
                            .foregroundColor(.DesignSystem.textSecondary)
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { viewModel.preferences.settings.digest.weeklyEnabled },
                    set: { newValue in
                        Task {
                            await viewModel.updateDigestSettings(weeklyEnabled: newValue)
                        }
                    },
                ))
                .tint(.DesignSystem.accentPurple)
                .labelsHidden()
            }
            .padding(Spacing.md)
            .background(Color.DesignSystem.glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.DesignSystem.brandBlue)

                Text("About Schedules")
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.textPrimary)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                infoRow(
                    icon: "moon.fill",
                    title: "Do Not Disturb",
                    description: "Silence all notifications for a set duration",
                )

                infoRow(
                    icon: "moon.stars.fill",
                    title: "Quiet Hours",
                    description: "Daily recurring silence during specific times",
                )

                infoRow(
                    icon: "sun.max.fill",
                    title: "Daily Digest",
                    description: "Bundle notifications into a single daily email",
                )

                infoRow(
                    icon: "calendar",
                    title: "Weekly Digest",
                    description: "Weekly summary of important updates",
                )
            }
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.brandBlue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.DesignSystem.brandBlue.opacity(0.2), lineWidth: 1),
        )
    }

    private func infoRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.DesignSystem.brandBlue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.DesignSystem.captionMedium)
                    .foregroundColor(.DesignSystem.textPrimary)

                Text(description)
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }
        }
    }
}

// MARK: - Preview

#Preview("Schedule Section") {
    ScrollView {
        ScheduleSection(viewModel: .preview)
            .padding(Spacing.md)
    }
    .background(Color.DesignSystem.background)
}

#Preview("With Active DND") {
    struct PreviewContainer: View {
        @State private var viewModel = NotificationPreferencesViewModel.preview

        var body: some View {
            ScrollView {
                ScheduleSection(viewModel: viewModel)
                    .padding(Spacing.md)
            }
            .background(Color.DesignSystem.background)
            .onAppear {
                viewModel.preferences.settings.dnd = DoNotDisturb(
                    enabled: true,
                    until: Date().addingTimeInterval(7200),
                )
                viewModel.preferences.settings.quietHours.enabled = true
            }
        }
    }

    return PreviewContainer()
}

#Preview("All Enabled") {
    struct PreviewContainer: View {
        @State private var viewModel = NotificationPreferencesViewModel.preview

        var body: some View {
            ScrollView {
                ScheduleSection(viewModel: viewModel)
                    .padding(Spacing.md)
            }
            .background(Color.DesignSystem.background)
            .onAppear {
                viewModel.preferences.settings.dnd.enabled = true
                viewModel.preferences.settings.quietHours.enabled = true
                viewModel.preferences.settings.digest.dailyEnabled = true
                viewModel.preferences.settings.digest.weeklyEnabled = true
            }
        }
    }

    return PreviewContainer()
}
