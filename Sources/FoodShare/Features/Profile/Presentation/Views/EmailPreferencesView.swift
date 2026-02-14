//
//  EmailPreferencesView.swift
//  Foodshare
//
//  Email notification preferences settings view
//  ProMotion 120Hz optimized with smooth animations
//

import SwiftUI
import FoodShareDesignSystem



// MARK: - Email Preferences View

/// Settings view for managing email notification preferences
struct EmailPreferencesView: View {
    
    @Environment(\.translationService) private var t

    // MARK: - State

    @State private var viewModel = EmailPreferencesViewModel()

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Notification toggles
                notificationTogglesSection

                // Frequency picker
                frequencySection

                // Quiet hours
                quietHoursSection
            }
            .padding()
        }
        .background(Color.DesignSystem.background)
        .navigationTitle(t.t("email_preferences.title"))
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadPreferences()
        }
        .alert(t.t("common.error.title"), isPresented: $viewModel.showError) {
            Button(t.t("common.ok")) { viewModel.dismissError() }
        } message: {
            Text(viewModel.localizedErrorMessage(using: t))
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t.t("email_preferences.header.title"))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.DesignSystem.textPrimary)

            Text(t.t("email_preferences.header.description"))
                .font(.subheadline)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Notification Toggles Section

    private var notificationTogglesSection: some View {
        VStack(spacing: 0) {
            PreferenceToggleRow(
                title: t.t("email_preferences.notifications.chat.title"),
                subtitle: t.t("email_preferences.notifications.chat.subtitle"),
                icon: "message.fill",
                iconColor: .DesignSystem.brandTeal,
                isOn: $viewModel.chatNotifications,
                isLoading: viewModel.isLoading,
            ) {
                Task { await viewModel.toggleChatNotifications() }
            }

            Divider()
                .padding(.leading, 56)

            PreferenceToggleRow(
                title: t.t("email_preferences.notifications.food_listings.title"),
                subtitle: t.t("email_preferences.notifications.food_listings.subtitle"),
                icon: "leaf.fill",
                iconColor: .DesignSystem.brandGreen,
                isOn: $viewModel.foodListingsNotifications,
                isLoading: viewModel.isLoading,
            ) {
                Task { await viewModel.toggleFoodListingsNotifications() }
            }

            Divider()
                .padding(.leading, 56)

            PreferenceToggleRow(
                title: t.t("email_preferences.notifications.feedback.title"),
                subtitle: t.t("email_preferences.notifications.feedback.subtitle"),
                icon: "bubble.left.fill",
                iconColor: .DesignSystem.brandPink,
                isOn: $viewModel.feedbackNotifications,
                isLoading: viewModel.isLoading,
            ) {
                Task { await viewModel.toggleFeedbackNotifications() }
            }

            Divider()
                .padding(.leading, 56)

            PreferenceToggleRow(
                title: t.t("email_preferences.notifications.review_reminders.title"),
                subtitle: t.t("email_preferences.notifications.review_reminders.subtitle"),
                icon: "star.fill",
                iconColor: .orange,
                isOn: $viewModel.reviewReminders,
                isLoading: viewModel.isLoading,
            ) {
                Task { await viewModel.toggleReviewReminders() }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1),
                ),
        )
    }

    // MARK: - Frequency Section

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t.t("email_preferences.frequency.title"))
                .font(.headline)
                .foregroundColor(.DesignSystem.textPrimary)

            VStack(spacing: 0) {
                ForEach(NotificationFrequency.allCases, id: \.self) { frequency in
                    FrequencyOptionRow(
                        frequency: frequency,
                        isSelected: viewModel.notificationFrequency == frequency,
                        isLoading: viewModel.isLoading,
                    ) {
                        Task { await viewModel.setFrequency(frequency) }
                    }

                    if frequency != NotificationFrequency.allCases.last {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1),
                    ),
            )
        }
    }

    // MARK: - Quiet Hours Section

    private var quietHoursSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(t.t("email_preferences.quiet_hours.title"))
                    .font(.headline)
                    .foregroundColor(.DesignSystem.textPrimary)

                Spacer()

                Toggle("", isOn: $viewModel.quietHoursEnabled)
                    .labelsHidden()
                    .tint(.DesignSystem.brandTeal)
                    .onChange(of: viewModel.quietHoursEnabled) { _, enabled in
                        Task { await viewModel.toggleQuietHours(enabled: enabled) }
                    }
            }

            Text(t.t("email_preferences.quiet_hours.description"))
                .font(.caption)
                .foregroundColor(.DesignSystem.textSecondary)

            if viewModel.quietHoursEnabled {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t.t("email_preferences.quiet_hours.start"))
                            .font(.caption)
                            .foregroundColor(.DesignSystem.textTertiary)

                        DatePicker(
                            "",
                            selection: $viewModel.quietHoursStart,
                            displayedComponents: .hourAndMinute,
                        )
                        .labelsHidden()
                        .onChange(of: viewModel.quietHoursStart) { _, _ in
                            Task { await viewModel.saveQuietHours() }
                        }
                    }

                    Image(systemName: "arrow.right")
                        .foregroundColor(.DesignSystem.textTertiary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(t.t("email_preferences.quiet_hours.end"))
                            .font(.caption)
                            .foregroundColor(.DesignSystem.textTertiary)

                        DatePicker(
                            "",
                            selection: $viewModel.quietHoursEnd,
                            displayedComponents: .hourAndMinute,
                        )
                        .labelsHidden()
                        .onChange(of: viewModel.quietHoursEnd) { _, _ in
                            Task { await viewModel.saveQuietHours() }
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.04)),
                )
                .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: viewModel.quietHoursEnabled)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1),
                ),
        )
    }
}

// MARK: - Preference Toggle Row

private struct PreferenceToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    @Binding var isOn: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.DesignSystem.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.DesignSystem.brandTeal)
                .disabled(isLoading)
                .onChange(of: isOn) { _, _ in
                    action()
                }
        }
        .padding()
    }
}

// MARK: - Frequency Option Row

private struct FrequencyOptionRow: View {
    @Environment(\.translationService) private var t
    let frequency: NotificationFrequency
    let isSelected: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: frequency.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .DesignSystem.brandTeal : .DesignSystem.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(
                        (isSelected ? Color.DesignSystem.brandTeal : Color.white).opacity(0.15),
                    )
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(t.t(frequency.titleKey))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.DesignSystem.textPrimary)

                    Text(t.t(frequency.descriptionKey))
                        .font(.caption)
                        .foregroundColor(.DesignSystem.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.DesignSystem.brandTeal)
                }
            }
            .padding()
        }
        .disabled(isLoading)
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class EmailPreferencesViewModel {
    // MARK: - State

    var chatNotifications = true
    var foodListingsNotifications = true
    var feedbackNotifications = false
    var reviewReminders = true
    var notificationFrequency: NotificationFrequency = .instant
    var quietHoursEnabled = false
    var quietHoursStart = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    var quietHoursEnd = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()

    var isLoading = false
    var error: Error?
    var showError = false

    var errorMessage: String {
        error?.localizedDescription ?? "An error occurred"
    }

    /// Localized error message (use in Views with translation service)
    func localizedErrorMessage(using t: EnhancedTranslationService) -> String {
        error?.localizedDescription ?? t.t("email_preferences.load_failed")
    }

    // MARK: - Load Preferences

    func loadPreferences() async {
        isLoading = true

        do {
            let prefs = try await EmailPreferencesService.shared.getPreferences()

            chatNotifications = prefs.chatNotifications
            foodListingsNotifications = prefs.foodListingsNotifications
            feedbackNotifications = prefs.feedbackNotifications
            reviewReminders = prefs.reviewReminders
            notificationFrequency = prefs.notificationFrequency

            if let start = prefs.quietHoursStart, let end = prefs.quietHoursEnd {
                quietHoursEnabled = true
                quietHoursStart = parseTime(start) ?? quietHoursStart
                quietHoursEnd = parseTime(end) ?? quietHoursEnd
            }

            isLoading = false
        } catch {
            self.error = error
            showError = true
            isLoading = false
        }
    }

    // MARK: - Toggle Actions

    func toggleChatNotifications() async {
        do {
            chatNotifications = try await EmailPreferencesService.shared.toggleChatNotifications()
        } catch {
            self.error = error
            showError = true
        }
    }

    func toggleFoodListingsNotifications() async {
        do {
            foodListingsNotifications = try await EmailPreferencesService.shared.toggleFoodListingsNotifications()
        } catch {
            self.error = error
            showError = true
        }
    }

    func toggleFeedbackNotifications() async {
        do {
            feedbackNotifications = try await EmailPreferencesService.shared.toggleFeedbackNotifications()
        } catch {
            self.error = error
            showError = true
        }
    }

    func toggleReviewReminders() async {
        do {
            reviewReminders = try await EmailPreferencesService.shared.toggleReviewReminders()
        } catch {
            self.error = error
            showError = true
        }
    }

    func setFrequency(_ frequency: NotificationFrequency) async {
        do {
            try await EmailPreferencesService.shared.setNotificationFrequency(frequency)
            notificationFrequency = frequency
            HapticManager.light()
        } catch {
            self.error = error
            showError = true
        }
    }

    func toggleQuietHours(enabled: Bool) async {
        if !enabled {
            do {
                try await EmailPreferencesService.shared.setQuietHours(start: nil, end: nil)
            } catch {
                self.error = error
                showError = true
            }
        } else {
            await saveQuietHours()
        }
    }

    func saveQuietHours() async {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        let start = formatter.string(from: quietHoursStart)
        let end = formatter.string(from: quietHoursEnd)

        do {
            try await EmailPreferencesService.shared.setQuietHours(start: start, end: end)
        } catch {
            self.error = error
            showError = true
        }
    }

    func dismissError() {
        showError = false
        error = nil
    }

    // MARK: - Helpers

    private func parseTime(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        if let date = formatter.date(from: timeString) {
            return date
        }
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: timeString)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EmailPreferencesView()
    }
}
