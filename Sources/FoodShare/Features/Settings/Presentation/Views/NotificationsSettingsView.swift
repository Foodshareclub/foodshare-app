//
//  NotificationsSettingsView.swift
//  Foodshare
//
//  Notification settings view with Liquid Glass v26 design
//

import SwiftUI
import FoodShareDesignSystem

struct NotificationsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.translationService) private var t

    // Push notification settings
    @State private var pushEnabled = true
    @State private var newListingsNearby = true
    @State private var messageNotifications = true
    @State private var arrangementUpdates = true
    @State private var communityAnnouncements = false

    // Email notification settings
    @State private var emailDigest = true
    @State private var weeklyNewsletter = false
    @State private var marketingEmails = false

    // Sound & Vibration
    @State private var soundEnabled = true
    @State private var vibrationEnabled = true

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Push Notifications Section
                pushNotificationsSection

                // Alert Types Section
                alertTypesSection

                // Email Notifications Section
                emailNotificationsSection

                // Sound & Vibration Section
                soundVibrationSection

                // Info Footer
                infoFooter
            }
            .padding(Spacing.md)
        }
        .background(Color.DesignSystem.background)
        .navigationTitle(t.t("settings.notifications.title"))
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Push Notifications Section

    private var pushNotificationsSection: some View {
        GlassSettingsSection(
            title: t.t("settings.notifications.push"),
            icon: "bell.badge.fill",
            titleColor: .DesignSystem.brandGreen,
        ) {
            VStack(spacing: 0) {
                HStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: "bell.fill")
                            .font(.DesignSystem.titleMedium)
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(t.t("settings.notifications.enable_push"))
                            .font(.DesignSystem.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(.DesignSystem.text)

                        Text(t.t("settings.notifications.push_desc"))
                            .font(.DesignSystem.captionSmall)
                            .foregroundColor(.DesignSystem.textSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: $pushEnabled)
                        .tint(.DesignSystem.brandGreen)
                        .labelsHidden()
                }
                .padding(Spacing.md)

                if !pushEnabled {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.DesignSystem.warning)

                        Text(t.t("settings.notifications.enable_in_settings"))
                            .font(.DesignSystem.captionSmall)
                            .foregroundColor(.DesignSystem.warning)

                        Spacer()

                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text(t.t("settings.notifications.open_settings"))
                                .font(.DesignSystem.captionSmall)
                                .fontWeight(.semibold)
                                .foregroundColor(.DesignSystem.brandGreen)
                        }
                    }
                    .padding(Spacing.md)
                    .background(Color.DesignSystem.warning.opacity(0.1))
                }
            }
        }
    }

    // MARK: - Alert Types Section

    private var alertTypesSection: some View {
        GlassSettingsSection(title: t.t("settings.notifications.alert_types"), icon: "checklist") {
            GlassSettingsToggle(
                icon: "leaf.fill",
                iconColor: .DesignSystem.brandGreen,
                title: t.t("settings.notifications.new_listings"),
                isOn: $newListingsNearby,
            )
            .disabled(!pushEnabled)
            .opacity(pushEnabled ? 1 : 0.5)

            GlassSettingsToggle(
                icon: "message.fill",
                iconColor: .DesignSystem.brandBlue,
                title: t.t("settings.notifications.messages"),
                isOn: $messageNotifications,
            )
            .disabled(!pushEnabled)
            .opacity(pushEnabled ? 1 : 0.5)

            GlassSettingsToggle(
                icon: "hand.raised.fill",
                iconColor: .DesignSystem.accentPurple,
                title: t.t("settings.notifications.arrangements"),
                isOn: $arrangementUpdates,
            )
            .disabled(!pushEnabled)
            .opacity(pushEnabled ? 1 : 0.5)

            GlassSettingsToggle(
                icon: "megaphone.fill",
                iconColor: .DesignSystem.accentOrange,
                title: t.t("settings.notifications.community"),
                isOn: $communityAnnouncements,
            )
            .disabled(!pushEnabled)
            .opacity(pushEnabled ? 1 : 0.5)
        }
    }

    // MARK: - Email Notifications Section

    private var emailNotificationsSection: some View {
        GlassSettingsSection(title: t.t("settings.notifications.email"), icon: "envelope.fill") {
            GlassSettingsToggle(
                icon: "doc.text.fill",
                iconColor: .DesignSystem.brandBlue,
                title: t.t("settings.notifications.daily_digest"),
                isOn: $emailDigest,
            )

            GlassSettingsToggle(
                icon: "newspaper.fill",
                iconColor: .DesignSystem.blueLight,
                title: t.t("settings.notifications.weekly_newsletter"),
                isOn: $weeklyNewsletter,
            )

            GlassSettingsToggle(
                icon: "sparkles",
                iconColor: .DesignSystem.accentPink,
                title: t.t("settings.notifications.tips_updates"),
                isOn: $marketingEmails,
            )
        }
    }

    // MARK: - Sound & Vibration Section

    private var soundVibrationSection: some View {
        GlassSettingsSection(title: t.t("settings.notifications.sound_vibration"), icon: "speaker.wave.2.fill") {
            GlassSettingsToggle(
                icon: "speaker.fill",
                iconColor: .DesignSystem.brandGreen,
                title: t.t("settings.notifications.sound"),
                isOn: $soundEnabled,
            )

            GlassSettingsToggle(
                icon: "iphone.radiowaves.left.and.right",
                iconColor: .DesignSystem.brandBlue,
                title: t.t("settings.notifications.vibration"),
                isOn: $vibrationEnabled,
            )
        }
    }

    // MARK: - Info Footer

    private var infoFooter: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.DesignSystem.titleLarge)
                .foregroundColor(.DesignSystem.textTertiary)

            Text(t.t("settings.notifications.footer"))
                .font(.DesignSystem.captionSmall)
                .foregroundColor(.DesignSystem.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.lg)
    }
}

#Preview {
    NavigationStack {
        NotificationsSettingsView()
    }
}
