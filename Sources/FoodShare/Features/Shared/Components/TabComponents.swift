//
//  TabComponents.swift
//  Foodshare
//
//  Reusable components for tab views
//  Extracted from MainTabView for better organization
//


#if !SKIP
import SwiftUI

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isFocused ? .DesignSystem.brandGreen : .DesignSystem.textSecondary)
                .font(.body)

            TextField(placeholder, text: $text)
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.text)
                .focused($isFocused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.DesignSystem.textSecondary)
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(
                            isFocused ? Color.DesignSystem.brandGreen : Color.DesignSystem.glassStroke,
                            lineWidth: 1,
                        ),
                ),
        )
    }
}

// MARK: - Welcome Card

struct WelcomeCard: View {
    @Environment(\.translationService) private var t

    var body: some View {
        HStack(spacing: Spacing.md) {
            // App Logo
            AppLogoView(size: .medium)

            // Content
            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(t.t("onboarding.welcome"))
                    .font(.DesignSystem.titleMedium)
                    .foregroundStyle(Color.DesignSystem.text)

                Text(t.t("onboarding.discover"))
                    .font(.DesignSystem.bodySmall)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    #if !SKIP
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif

                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.glassHighlight,
                                Color.DesignSystem.glassBorder,
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                        lineWidth: 1,
                    )
            },
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
        .padding(.horizontal, Spacing.md)
    }
}

// MARK: - Explore Empty State

struct ExploreEmptyState: View {
    @Environment(\.translationService) private var t
    let action: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "leaf.circle")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )

            VStack(spacing: Spacing.sm) {
                Text(t.t("feed.no_listings"))
                    .font(.DesignSystem.headlineLarge)
                    .foregroundColor(.DesignSystem.text)

                Text(t.t("feed.empty_state_subtitle"))
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
            }

            GlassButton(t.t("common.share_food"), icon: "plus.circle.fill", style: .primary) {
                action()
            }
        }
        .padding(Spacing.xl)
    }
}

// MARK: - Stat Column

struct StatColumn: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack {
            Text(value)
                .font(.DesignSystem.displayLarge)
                .foregroundColor(color)
            Text(label)
                .font(.DesignSystem.bodySmall)
                .foregroundColor(.DesignSystem.textSecondary)
        }
    }
}

// MARK: - Challenge Progress Card

struct ChallengeProgressCard: View {
    @Environment(\.translationService) private var t
    let title: String
    let description: String
    let progress: Double
    let points: Int
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(.DesignSystem.headlineMedium)
                        .foregroundColor(.DesignSystem.text)

                    Text(description)
                        .font(.DesignSystem.bodySmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                }

                Spacer()

                VStack {
                    Text("+\(points)")
                        .font(.DesignSystem.headlineSmall)
                        .foregroundColor(.DesignSystem.brandGreen)
                    Text(t.t("common.points_abbrev"))
                        .font(.caption2)
                        .foregroundColor(.DesignSystem.textSecondary)
                }
            }

            ProgressView(value: progress)
                .tint(.DesignSystem.brandGreen)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassStroke, lineWidth: 1),
                ),
        )
        .padding(.horizontal, Spacing.md)
    }
}

// MARK: - Leaderboard Entry Row

struct LeaderboardEntryRow: View {
    @Environment(\.translationService) private var t
    let rank: Int
    let name: String
    let points: Int
    let badge: String

    var body: some View {
        HStack {
            Text(badge)
                .font(.title2)

            Text("#\(rank)")
                .font(.DesignSystem.headlineSmall)
                .foregroundColor(.DesignSystem.textSecondary)
                .frame(width: 40.0, alignment: .leading)

            Text(name)
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.text)

            Spacer()

            Text(t.t("common.points_format", args: ["count": String(points)]))
                .font(.DesignSystem.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(.DesignSystem.brandGreen)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.DesignSystem.glassStroke, lineWidth: 1),
                ),
        )
    }
}

// MARK: - Profile Stat

struct ProfileStat: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.DesignSystem.brandGreen)

            Text(value)
                .font(.DesignSystem.headlineLarge)
                .fontWeight(.bold)
                .foregroundColor(.DesignSystem.text)

            Text(label)
                .font(.DesignSystem.captionSmall)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Profile Action Button

struct ProfileActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24.0)

                Text(title)
                    .font(.DesignSystem.bodyLarge)
                    .foregroundColor(.DesignSystem.text)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.DesignSystem.textTertiary)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    #if !SKIP
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .strokeBorder(Color.DesignSystem.glassBorder, lineWidth: 1),
                    ),
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.translationService) private var t
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("locationEnabled") private var locationEnabled = true

    var body: some View {
        NavigationStack {
            Form {
                Section(t.t("settings.section.preferences")) {
                    Toggle(t.t("settings.push_notifications"), isOn: $notificationsEnabled)
                    Toggle(t.t("settings.location_services"), isOn: $locationEnabled)
                }

                Section(t.t("settings.section.about")) {
                    HStack {
                        Text(t.t("settings.version"))
                        Spacer()
                        Text(Constants.appVersion)
                            .foregroundColor(.DesignSystem.textSecondary)
                    }

                    Link(t.t("common.privacy_policy"), destination: URL(string: "https://foodshare.club/privacy")!)
                    Link(t.t("common.terms_of_service"), destination: URL(string: "https://foodshare.club/terms")!)
                }

                Section(t.t("settings.section.support")) {
                    Link(t.t("common.contact_us"), destination: URL(string: "mailto:support@foodshare.club")!)
                    Link(t.t("common.faq"), destination: URL(string: "https://foodshare.club/faq")!)
                }
            }
            .navigationTitle(t.t("common.settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(t.t("common.done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#endif
