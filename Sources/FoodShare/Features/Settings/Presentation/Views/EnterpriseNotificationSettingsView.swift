// MARK: - EnterpriseNotificationSettingsView.swift
// Enterprise Notification Settings UI
// FoodShare iOS - Liquid Glass Design System

import FoodShareDesignSystem
import SwiftUI

// MARK: - Main View

/// Enterprise-grade notification settings view
/// Features: Category-based controls, multiple channels, quiet hours, DND, digest settings
public struct EnterpriseNotificationSettingsView: View {

    // MARK: - Properties

    @State private var viewModel: NotificationPreferencesViewModel
    @Environment(\.translationService) private var t
    @Environment(\.dismiss) private var dismiss

    // MARK: - Initialization

    public init(viewModel: NotificationPreferencesViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {

                // Global Status Banner
                if viewModel.preferences.settings.dnd.isActive {
                    dndActiveBanner
                }

                // Push Notifications Section
                pushNotificationsSection

                // Email Notifications Section
                emailNotificationsSection

                // SMS Notifications Section
                smsNotificationsSection

                // Digest Settings Section
                digestSettingsSection

                // Quiet Hours Section
                quietHoursSection

                // Do Not Disturb Section
                dndSection

            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.lg)
        }
        .background(Color.DesignSystem.background)
        .navigationTitle(t.t("settings.notifications.title", default: "Notifications"))
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await viewModel.refreshPreferences()
        }
        .task {
            await viewModel.loadPreferences()
        }
        .overlay {
            if viewModel.loadingState.isLoading {
                loadingOverlay
            }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.lastError != nil },
                set: { if !$0 { viewModel.clearError() } },
            ),
        ) {
            Button("OK") { viewModel.clearError() }
        } message: {
            if let error = viewModel.lastError {
                Text(error.localizedDescription)
            }
        }
        .sheet(isPresented: $viewModel.showDNDSheet) {
            DNDConfigurationSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showQuietHoursSheet) {
            QuietHoursConfigurationSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showPhoneVerificationSheet) {
            PhoneVerificationSheet(viewModel: viewModel)
        }
    }

    // MARK: - DND Active Banner

    private var dndActiveBanner: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "moon.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.DesignSystem.warning)

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text("Do Not Disturb Active")
                    .font(.DesignSystem.labelLarge)
                    .foregroundStyle(Color.DesignSystem.text)

                if let remaining = viewModel.preferences.settings.dnd.remainingTimeFormatted {
                    Text(remaining)
                        .font(.DesignSystem.captionSmall)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
            }

            Spacer()

            Button {
                Task { await viewModel.disableDND() }
            } label: {
                Text("Turn Off")
                    .font(.DesignSystem.labelLarge)
                    .foregroundStyle(Color.DesignSystem.primary)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(Color.DesignSystem.warning.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .strokeBorder(Color.DesignSystem.warning.opacity(0.3), lineWidth: 1),
                ),
        )
    }

    // MARK: - Push Notifications Section

    private var pushNotificationsSection: some View {
        GlassSettingsSection(
            title: t.t("settings.notifications.push", default: "Push Notifications"),
            icon: "bell.badge.fill",
            titleColor: .DesignSystem.brandGreen,
        ) {
            VStack(spacing: 0) {
                // Master toggle
                GlassSettingsToggle(
                    icon: "bell.fill",
                    iconColor: .DesignSystem.brandGreen,
                    title: t.t("settings.notifications.enabled", default: "Enable Push Notifications"),
                    isOn: Binding(
                        get: { viewModel.preferences.settings.pushEnabled },
                        set: { _ in Task { await viewModel.togglePushEnabled() } },
                    ),
                )

                if viewModel.preferences.settings.pushEnabled {
                    Divider()
                        .padding(.leading, 52)

                    // Category toggles
                    ForEach(viewModel.filteredCategories, id: \.rawValue) { category in
                        if category.canDisable {
                            categoryToggleRow(category: category, channel: .push)

                            if category != viewModel.filteredCategories.last {
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Email Notifications Section

    private var emailNotificationsSection: some View {
        GlassSettingsSection(
            title: t.t("settings.notifications.email", default: "Email Notifications"),
            icon: "envelope.fill",
            titleColor: .DesignSystem.brandBlue,
        ) {
            VStack(spacing: 0) {
                // Master toggle
                GlassSettingsToggle(
                    icon: "envelope.fill",
                    iconColor: .DesignSystem.brandBlue,
                    title: t.t("settings.notifications.enabled", default: "Enable Email Notifications"),
                    isOn: Binding(
                        get: { viewModel.preferences.settings.emailEnabled },
                        set: { _ in Task { await viewModel.toggleEmailEnabled() } },
                    ),
                )

                if viewModel.preferences.settings.emailEnabled {
                    Divider()
                        .padding(.leading, 52)

                    // Category toggles with frequency selector
                    ForEach(viewModel.filteredCategories, id: \.rawValue) { category in
                        if category.canDisable {
                            emailCategoryRow(category: category)

                            if category != viewModel.filteredCategories.last {
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - SMS Notifications Section

    private var smsNotificationsSection: some View {
        GlassSettingsSection(
            title: t.t("settings.notifications.sms", default: "SMS Notifications"),
            icon: "text.bubble.fill",
            titleColor: .DesignSystem.primary,
        ) {
            VStack(spacing: 0) {
                // Master toggle / Phone verification
                if viewModel.preferences.settings.phoneVerified {
                    GlassSettingsToggle(
                        icon: "text.bubble.fill",
                        iconColor: .DesignSystem.primary,
                        title: t.t("settings.notifications.enabled", default: "Enable SMS Notifications"),
                        isOn: Binding(
                            get: { viewModel.preferences.settings.smsEnabled },
                            set: { _ in Task { await viewModel.toggleSMSEnabled() } },
                        ),
                    )

                    if viewModel.preferences.settings.smsEnabled {
                        Divider()
                            .padding(.leading, 52)

                        // Only critical categories for SMS
                        ForEach([NotificationCategory.chats, .system], id: \.rawValue) { category in
                            categoryToggleRow(category: category, channel: .sms)

                            if category != .system {
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }
                    }
                } else {
                    // Phone verification required
                    phoneVerificationPrompt
                }
            }
        }
    }

    // MARK: - Digest Settings Section

    private var digestSettingsSection: some View {
        GlassSettingsSection(
            title: t.t("settings.notifications.digest", default: "Digest Settings"),
            icon: "tray.full.fill",
            titleColor: .DesignSystem.brandGreen,
        ) {
            VStack(spacing: 0) {
                // Daily digest toggle
                GlassSettingsToggle(
                    icon: "sun.max.fill",
                    iconColor: .DesignSystem.warning,
                    title: t.t("settings.notifications.daily_digest", default: "Daily Digest"),
                    subtitle: t.t("settings.notifications.daily_digest_desc", default: "Receive a summary at 9am"),
                    isOn: Binding(
                        get: { viewModel.preferences.settings.digest.dailyEnabled },
                        set: { newValue in
                            Task { await viewModel.updateDigestSettings(dailyEnabled: newValue) }
                        },
                    ),
                )

                Divider()
                    .padding(.leading, 52)

                // Weekly digest toggle
                GlassSettingsToggle(
                    icon: "calendar",
                    iconColor: .DesignSystem.brandBlue,
                    title: t.t("settings.notifications.weekly_digest", default: "Weekly Digest"),
                    subtitle: t.t(
                        "settings.notifications.weekly_digest_desc",
                        default: "Receive a summary every Monday",
                    ),
                    isOn: Binding(
                        get: { viewModel.preferences.settings.digest.weeklyEnabled },
                        set: { newValue in
                            Task { await viewModel.updateDigestSettings(weeklyEnabled: newValue) }
                        },
                    ),
                )
            }
        }
    }

    // MARK: - Quiet Hours Section

    private var quietHoursSection: some View {
        GlassSettingsSection(
            title: t.t("settings.notifications.quiet_hours", default: "Quiet Hours"),
            icon: "moon.stars.fill",
            titleColor: .DesignSystem.brandBlue,
        ) {
            VStack(spacing: 0) {
                Button {
                    viewModel.showQuietHoursSheet = true
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.DesignSystem.brandBlue)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: Spacing.xxxs) {
                            Text(t.t("settings.notifications.quiet_hours", default: "Quiet Hours"))
                                .font(.DesignSystem.bodyLarge)
                                .foregroundStyle(Color.DesignSystem.text)

                            Text(t.t(
                                "settings.notifications.quiet_hours_desc",
                                default: "Pause non-urgent notifications",
                            ))
                            .font(.DesignSystem.captionSmall)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                        }

                        Spacer()

                        Text(viewModel.quietHoursStatusText)
                            .font(.DesignSystem.bodyMedium)
                            .foregroundStyle(Color.DesignSystem.textSecondary)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                    .padding(.vertical, Spacing.sm)
                    .padding(.horizontal, Spacing.md)
                }
            }
        }
    }

    // MARK: - Do Not Disturb Section

    private var dndSection: some View {
        GlassSettingsSection(
            title: t.t("settings.notifications.dnd", default: "Do Not Disturb"),
            icon: "moon.fill",
            titleColor: .DesignSystem.warning,
        ) {
            VStack(spacing: 0) {
                Button {
                    viewModel.showDNDSheet = true
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.DesignSystem.warning)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: Spacing.xxxs) {
                            Text(t.t("settings.notifications.dnd", default: "Do Not Disturb"))
                                .font(.DesignSystem.bodyLarge)
                                .foregroundStyle(Color.DesignSystem.text)

                            Text(t.t(
                                "settings.notifications.dnd_desc",
                                default: "Silence all notifications temporarily",
                            ))
                            .font(.DesignSystem.captionSmall)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                        }

                        Spacer()

                        Text(viewModel.dndStatusText)
                            .font(.DesignSystem.bodyMedium)
                            .foregroundStyle(
                                viewModel.preferences.settings.dnd.isActive
                                    ? Color.DesignSystem.warning
                                    : Color.DesignSystem.textSecondary,
                            )

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                    .padding(.vertical, Spacing.sm)
                    .padding(.horizontal, Spacing.md)
                }
            }
        }
    }

    // MARK: - Category Toggle Row

    private func categoryToggleRow(category: NotificationCategory, channel: NotificationChannel) -> some View {
        let isUpdating = viewModel.isUpdating(category: category, channel: channel)

        return HStack(spacing: Spacing.sm) {
            Image(systemName: category.icon)
                .font(.system(size: 18))
                .foregroundStyle(channelColor(channel))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(category.displayName)
                    .font(.DesignSystem.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.text)

                Text(category.description)
                    .font(.DesignSystem.captionSmall)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if isUpdating {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Toggle(
                    "",
                    isOn: viewModel.enabledBinding(category: category, channel: channel),
                )
                .labelsHidden()
                .tint(Color.DesignSystem.brandGreen)
            }
        }
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.displayName) \(channel.displayName) notifications")
        .accessibilityValue(viewModel.preferences.preference(for: category, channel: channel).enabled ? "On" : "Off")
    }

    // MARK: - Email Category Row (with frequency)

    private func emailCategoryRow(category: NotificationCategory) -> some View {
        let preference = viewModel.preferences.preference(for: category, channel: .email)
        let isUpdating = viewModel.isUpdating(category: category, channel: .email)

        return VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: category.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.DesignSystem.brandBlue)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    Text(category.displayName)
                        .font(.DesignSystem.bodyMedium)
                        .foregroundStyle(Color.DesignSystem.text)

                    Text(category.description)
                        .font(.DesignSystem.captionSmall)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if isUpdating {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Toggle(
                        "",
                        isOn: viewModel.enabledBinding(category: category, channel: .email),
                    )
                    .labelsHidden()
                    .tint(Color.DesignSystem.brandGreen)
                }
            }
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal, Spacing.md)

            // Frequency picker (only if enabled)
            if preference.enabled {
                HStack(spacing: Spacing.sm) {
                    Spacer()
                        .frame(width: 32)

                    Text("Frequency:")
                        .font(.DesignSystem.captionSmall)
                        .foregroundStyle(Color.DesignSystem.textSecondary)

                    Picker(
                        "",
                        selection: viewModel.frequencyBinding(category: category, channel: .email),
                    ) {
                        ForEach([NotificationFrequency.instant, .daily, .weekly], id: \.rawValue) { freq in
                            Text(freq.displayName)
                                .tag(freq)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)

                    Spacer()
                }
                .padding(.bottom, Spacing.xs)
                .padding(.horizontal, Spacing.md)
            }
        }
    }

    // MARK: - Phone Verification Prompt

    private var phoneVerificationPrompt: some View {
        Button {
            viewModel.showPhoneVerificationSheet = true
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "phone.badge.checkmark")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.DesignSystem.primary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    Text(t.t("settings.notifications.verify_phone", default: "Verify Phone Number"))
                        .font(.DesignSystem.bodyLarge)
                        .foregroundStyle(Color.DesignSystem.text)

                    Text(t.t("settings.notifications.verify_phone_desc", default: "Required for SMS notifications"))
                        .font(.DesignSystem.captionSmall)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.DesignSystem.background.opacity(0.8)

            VStack(spacing: Spacing.md) {
                ProgressView()
                    .scaleEffect(1.2)

                Text("Loading preferences...")
                    .font(.DesignSystem.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Helpers

    private func channelColor(_ channel: NotificationChannel) -> Color {
        switch channel {
        case .push: .DesignSystem.brandGreen
        case .email: .DesignSystem.brandBlue
        case .sms: .DesignSystem.primary
        }
    }
}

// MARK: - DND Configuration Sheet

struct DNDConfigurationSheet: View {
    @Bindable var viewModel: NotificationPreferencesViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                // Header
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.DesignSystem.warning)

                    Text("Do Not Disturb")
                        .font(.DesignSystem.headlineSmall)
                        .foregroundStyle(Color.DesignSystem.text)

                    Text("All notifications will be silenced")
                        .font(.DesignSystem.bodyMedium)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
                .padding(.top, Spacing.xl)

                // Duration Options
                VStack(spacing: Spacing.sm) {
                    dndDurationButton(hours: 1, label: "For 1 hour")
                    dndDurationButton(hours: 2, label: "For 2 hours")
                    dndDurationButton(hours: 4, label: "For 4 hours")
                    dndDurationButton(hours: 8, label: "For 8 hours")
                    dndDurationButton(hours: 24, label: "For 24 hours")
                }
                .padding(.horizontal, Spacing.md)

                Spacer()

                // Cancel
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.DesignSystem.bodyLarge)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
                .padding(.bottom, Spacing.lg)
            }
            .background(Color.DesignSystem.background)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private func dndDurationButton(hours: Int, label: String) -> some View {
        Button {
            Task {
                await viewModel.enableDND(hours: hours)
            }
        } label: {
            HStack {
                Text(label)
                    .font(.DesignSystem.bodyLarge)
                    .foregroundStyle(Color.DesignSystem.text)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(Color.DesignSystem.surface),
            )
        }
    }
}

// MARK: - Quiet Hours Configuration Sheet

struct QuietHoursConfigurationSheet: View {
    @Bindable var viewModel: NotificationPreferencesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isEnabled = false
    @State private var startTime = Date()
    @State private var endTime = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable Quiet Hours", isOn: $isEnabled)
                }

                if isEnabled {
                    Section("Schedule") {
                        DatePicker(
                            "Start Time",
                            selection: $startTime,
                            displayedComponents: .hourAndMinute,
                        )

                        DatePicker(
                            "End Time",
                            selection: $endTime,
                            displayedComponents: .hourAndMinute,
                        )
                    }

                    Section {
                        Text(
                            "During quiet hours, only critical notifications will be delivered. System and security notifications will always come through.",
                        )
                        .font(.DesignSystem.captionSmall)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                }
            }
            .navigationTitle("Quiet Hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm"

                        Task {
                            await viewModel.updateQuietHours(
                                enabled: isEnabled,
                                start: formatter.string(from: startTime),
                                end: formatter.string(from: endTime),
                            )
                        }
                    }
                }
            }
        }
        .onAppear {
            let qh = viewModel.preferences.settings.quietHours
            isEnabled = qh.enabled

            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            startTime = formatter.date(from: qh.start) ?? Date()
            endTime = formatter.date(from: qh.end) ?? Date()
        }
    }
}

// MARK: - Phone Verification Sheet

struct PhoneVerificationSheet: View {
    @Bindable var viewModel: NotificationPreferencesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var step: VerificationStep = .enterPhone

    enum VerificationStep {
        case enterPhone
        case enterCode
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                // Header
                VStack(spacing: Spacing.sm) {
                    Image(systemName: step == .enterPhone ? "phone.fill" : "checkmark.shield.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.DesignSystem.primary)

                    Text(step == .enterPhone ? "Verify Your Phone" : "Enter Verification Code")
                        .font(.DesignSystem.headlineSmall)
                        .foregroundStyle(Color.DesignSystem.text)

                    Text(step == .enterPhone
                        ? "We'll send a verification code via SMS"
                        : "Enter the 6-digit code sent to your phone")
                        .font(.DesignSystem.bodyMedium)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Spacing.xl)

                // Input
                if step == .enterPhone {
                    TextField("Phone Number", text: $viewModel.phoneVerificationNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .font(.DesignSystem.bodyLarge)
                        .padding(Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(Color.DesignSystem.surface),
                        )
                        .padding(.horizontal, Spacing.md)
                } else {
                    TextField("Verification Code", text: $viewModel.phoneVerificationCode)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(.DesignSystem.displayLarge)
                        .multilineTextAlignment(.center)
                        .padding(Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(Color.DesignSystem.surface),
                        )
                        .padding(.horizontal, Spacing.xl)
                }

                Spacer()

                // Action Button
                Button {
                    Task {
                        if step == .enterPhone {
                            await viewModel.initiatePhoneVerification()
                            step = .enterCode
                        } else {
                            await viewModel.verifyPhoneCode()
                        }
                    }
                } label: {
                    if viewModel.isVerifyingPhone {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(step == .enterPhone ? "Send Code" : "Verify")
                    }
                }
                .font(.DesignSystem.labelLarge)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(Spacing.md)
                .background(Color.DesignSystem.primary)
                .cornerRadius(CornerRadius.large)
                .padding(.horizontal, Spacing.md)
                .disabled(
                    viewModel.isVerifyingPhone ||
                        (step == .enterPhone && viewModel.phoneVerificationNumber.isEmpty) ||
                        (step == .enterCode && viewModel.phoneVerificationCode.count != 6),
                )

                // Cancel
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.DesignSystem.bodyLarge)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
                .padding(.bottom, Spacing.lg)
            }
            .background(Color.DesignSystem.background)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Notification Settings") {
        NavigationStack {
            EnterpriseNotificationSettingsView(viewModel: .preview)
        }
    }

    #Preview("Loading State") {
        NavigationStack {
            EnterpriseNotificationSettingsView(viewModel: .loadingPreview)
        }
    }

    #Preview("Error State") {
        NavigationStack {
            EnterpriseNotificationSettingsView(viewModel: .errorPreview)
        }
    }
#endif
