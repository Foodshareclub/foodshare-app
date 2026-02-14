//
//  SettingsView.swift
//  Foodshare
//
//  Settings view with Liquid Glass v26 design
//  Matches web app settings functionality
//
//  Settings 10x Overhaul:
//  - Search functionality
//  - Collapsible sections
//  - Haptic feedback
//  - Staggered animations
//  - Lazy loading
//  - New features: App Lock, Data Export, Backup, Accessibility, App Icons

import FoodShareDesignSystem
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(FeedViewModel.self) private var feedViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.translationService) private var t
    @State private var viewModel: SettingsViewModel
    @State private var preferencesService = PreferencesService.shared
    @State private var themeManager = ThemeManager.shared
    @State private var coordinator = SettingsCoordinator.shared
    @State private var isSavingRadius = false
    @State private var showEditProfile = false
    @State private var radiusLocalized = 5.0 // Local state for slider

    // Animation state
    @State private var hasAppeared = false
    @State private var loadedSections: Set<SettingsCategory> = []

    // MARK: - Initialization

    init(viewModel: SettingsViewModel? = nil, appState: AppState? = nil) {
        if let viewModel {
            _viewModel = State(initialValue: viewModel)
        } else if let appState {
            _viewModel = State(initialValue: SettingsViewModel(appState: appState))
        } else {
            // Fallback for previews
            _viewModel = State(initialValue: SettingsViewModel(appState: AppState.preview))
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.lg) {
                // Search results header
                if !coordinator.searchQuery.isEmpty {
                    let matchCount = coordinator.matchingCategories
                        .reduce(0) { $0 + (coordinator.filteredSettings[$1]?.count ?? 0) }
                    SettingsSearchResultsHeader(resultCount: matchCount, query: coordinator.searchQuery)
                }

                // Empty search state
                if !coordinator.searchQuery.isEmpty, coordinator.matchingCategories.isEmpty {
                    SettingsSearchEmptyState(query: coordinator.searchQuery)
                } else {
                    // Settings sections
                    ForEach(Array(SettingsCategory.sortedCases.enumerated()), id: \.element) { index, category in
                        if coordinator.categoryHasMatches(category) {
                            sectionView(for: category, index: index)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            }
            .padding(Spacing.md)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            // Pinned Glass Search Bar
            GlassSearchBar(
                text: $coordinator.searchQuery,
                placeholder: t.t("settings.search_settings"),
                onSubmit: nil,
                onClear: { coordinator.searchQuery = "" },
            )
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Color.DesignSystem.background
                    .overlay(
                        Rectangle()
                            .fill(Color.DesignSystem.glassBorder)
                            .frame(height: 0.5),
                        alignment: .bottom,
                    ),
            )
        }
        .background(Color.DesignSystem.background)
        .navigationTitle(t.t("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Initialize viewModel with current appState if needed
            if viewModel.currentUser == nil {
                viewModel = SettingsViewModel(appState: appState)
            }

            // Initialize search radius from FeedViewModel (injected via @Environment)
            let unit = DistanceUnit.current
            let initialRadius: Double = unit == .kilometers
                ? feedViewModel.searchRadius
                : feedViewModel.searchRadius * DistanceUnit.miles.fromKilometers
            radiusLocalized = max(unit.minSliderValue, min(initialRadius, unit.maxSliderValue))

            // Trigger staggered animations
            withAnimation(.easeOut(duration: 0.3)) {
                hasAppeared = true
            }
        }
        .sheet(isPresented: $viewModel.showSubscription) {
            SubscriptionView()
        }
        .sheet(isPresented: $viewModel.showThemePicker) {
            ThemePickerView()
        }
        .sheet(isPresented: $viewModel.showLanguagePicker) {
            LanguagePickerView()
        }
        .sheet(isPresented: $viewModel.showDonation) {
            DonationView()
        }
        .sheet(isPresented: $viewModel.showHelp) {
            HelpView()
        }
        .sheet(isPresented: $viewModel.showFeedback) {
            FeedbackView(viewModel: viewModel.createFeedbackViewModel(supabase: appState.authService.supabase))
        }
        .sheet(isPresented: $viewModel.showAppIconPicker) {
            AppIconPickerView()
        }
        .sheet(isPresented: $showEditProfile) {
            if let userId = appState.currentUser?.id {
                EditProfileView(
                    repository: appState.dependencies.profileRepository,
                    userId: userId,
                    profile: nil,
                )
            }
        }
        .alert(t.t("settings.sign_out"), isPresented: $viewModel.showSignOutConfirmation) {
            Button(t.t("common.cancel"), role: .cancel) {}
            Button(t.t("settings.sign_out"), role: .destructive) {
                Task {
                    await viewModel.signOut()
                    dismiss()
                }
            }
        } message: {
            Text(t.t("settings.sign_out_confirm"))
        }
        .alert(t.t("settings.delete_account"), isPresented: $viewModel.showDeleteConfirmation) {
            Button(t.t("common.cancel"), role: .cancel) {}
            Button(t.t("settings.delete_forever"), role: .destructive) {
                Task {
                    do {
                        try await viewModel.deleteAccount()
                        dismiss()
                    } catch {
                        // Error is handled in viewModel
                    }
                }
            }
        } message: {
            Text(t.t("settings.delete_account_confirm"))
        }
        .alert(t.t("settings.deletion_failed"), isPresented: $viewModel.showDeleteError) {
            Button(t.t("common.ok"), role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.deleteAccountError ?? t.t("common.error.title"))
        }
        .overlay {
            if viewModel.isDeletingAccount {
                ZStack {
                    Color.DesignSystem.scrim
                        .ignoresSafeArea()
                    VStack(spacing: Spacing.md) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text(t.t("settings.deleting_account"))
                            .font(.DesignSystem.bodyLarge)
                            .foregroundStyle(.white)
                    }
                    .padding(Spacing.xl)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: - Section View

    @ViewBuilder
    private func sectionView(for category: SettingsCategory, index: Int) -> some View {
        let isExpanded = coordinator.isSectionExpanded(category)

        CollapsibleSettingsSection(
            title: t.t(category.titleKey),
            icon: category.icon,
            titleColor: category.titleColor,
            isExpanded: isExpanded,
            onToggle: { coordinator.toggleSection(category) },
        ) {
            // Lazy load section content
            if loadedSections.contains(category) {
                sectionContent(for: category)
            } else {
                SettingsSectionSkeleton()
                    .onAppear {
                        loadedSections.insert(category)
                    }
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 8)
        .animation(
            .spring(response: 0.4, dampingFraction: 0.8)
                .delay(Double(index) * 0.05),
            value: hasAppeared,
        )
    }

    // MARK: - Section Content

    @ViewBuilder
    private func sectionContent(for category: SettingsCategory) -> some View {
        switch category {
        case .account:
            accountContent
        case .subscription:
            subscriptionContent
        case .security:
            securityContent
        case .preferences:
            preferencesContent
        case .appearance:
            appearanceContent
        case .notifications:
            notificationsContent
        case .communication:
            communicationContent
        case .accessibility:
            accessibilityContent
        case .dataPrivacy:
            dataPrivacyContent
        case .support:
            supportContent
        case .about:
            aboutContent
        case .dangerZone:
            dangerZoneContent
        }
    }

    // MARK: - Account Content

    private var accountContent: some View {
        Group {
            if let user = viewModel.currentUser {
                GlassSettingsRow(
                    icon: "envelope.fill",
                    iconColor: .DesignSystem.brandBlue,
                    title: t.t("email"),
                    value: user.email ?? t.t("not_set"),
                )

                GlassSettingsRow(
                    icon: "person.fill",
                    iconColor: .DesignSystem.brandGreen,
                    title: t.t("name"),
                    value: user.displayName,
                )

                Button {
                    showEditProfile = true
                } label: {
                    GlassSettingsRow(
                        icon: "pencil",
                        iconColor: .DesignSystem.accentOrange,
                        title: t.t("edit_profile"),
                        showChevron: true,
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Subscription Content

    private var subscriptionContent: some View {
        Button {
            viewModel.showSubscription = true
        } label: {
            HStack {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.DesignSystem.brandPink)
                    .frame(width: 28)

                Text(t.t("premium"))
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.text)

                Spacer()

                if viewModel.isPremium {
                    Text(t.t("active"))
                        .font(.DesignSystem.caption)
                        .foregroundColor(.DesignSystem.success)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 4)
                        .background(Color.DesignSystem.success.opacity(0.15))
                        .cornerRadius(CornerRadius.small)
                } else {
                    Text(t.t("upgrade"))
                        .font(.DesignSystem.caption)
                        .foregroundColor(.DesignSystem.brandPink)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.DesignSystem.textSecondary)
                }
            }
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal, Spacing.md)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Security Content

    private var securityContent: some View {
        Group {
            NavigationLink {
                AppLockSettingsView()
            } label: {
                GlassSettingsRow(
                    icon: AppLockService.shared.biometricIconName,
                    iconColor: .DesignSystem.brandBlue,
                    title: t.t("settings.app_lock"),
                    value: AppLockService.shared.isEnabled ? t.t("on") : t.t("off"),
                    showChevron: true,
                )
            }

            NavigationLink {
                LoginSecurityView()
            } label: {
                GlassSettingsRow(
                    icon: "shield.fill",
                    iconColor: .DesignSystem.brandGreen,
                    title: t.t("settings.login_security"),
                    showChevron: true,
                )
            }

            NavigationLink {
                PrivacySettingsView()
            } label: {
                GlassSettingsRow(
                    icon: "eye.slash.fill",
                    iconColor: .DesignSystem.accentPurple,
                    title: t.t("settings.privacy_protection"),
                    showChevron: true,
                )
            }

            NavigationLink {
                // BlockedUsersView() // Temporarily commented out
            } label: {
                GlassSettingsRow(
                    icon: "hand.raised.fill",
                    iconColor: .DesignSystem.error,
                    title: t.t("settings.blocked_users"),
                    showChevron: true,
                )
            }
        }
    }

    // MARK: - Preferences Content

    private var preferencesContent: some View {
        VStack(spacing: Spacing.md) {
            // Language setting - standalone row
            Button {
                viewModel.showLanguagePicker = true
            } label: {
                LanguageSettingsRow()
            }
            .buttonStyle(.plain)

            // Location Services - standalone row
            GlassSettingsToggle(
                icon: "location.fill",
                iconColor: .DesignSystem.brandBlue,
                title: t.t("location_services"),
                isOn: Binding(
                    get: { preferencesService.locationEnabled },
                    set: { newValue in
                        Task {
                            await viewModel.toggleLocationServices(newValue)
                        }
                    },
                ),
            )
            .sensoryFeedback(.selection, trigger: preferencesService.locationEnabled)

            // Search Radius - separate card within preferences
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Mini header
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "scope")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.DesignSystem.brandGreen, .DesignSystem.brandTeal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )

                    Text(t.t("filter.search_radius"))
                        .font(.DesignSystem.labelLarge)
                        .foregroundColor(.DesignSystem.text)

                    Spacer()
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)

                GlassSearchRadiusSection(
                    radiusLocalized: $radiusLocalized,
                    distanceUnit: .current,
                    style: .full,
                    onRadiusChange: { radiusKm in
                        await feedViewModel.updateSearchRadius(radiusKm)
                    },
                )
                .padding(.horizontal, Spacing.sm)
                .padding(.bottom, Spacing.md)
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Color.DesignSystem.glassBackground.opacity(0.5))
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .fill(.ultraThinMaterial),
                    ),
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.brandGreen.opacity(0.3),
                                Color.DesignSystem.glassBorder,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                        lineWidth: 1,
                    ),
            )
        }
    }

    // MARK: - Appearance Content

    private var appearanceContent: some View {
        Group {
            Button {
                viewModel.showThemePicker = true
            } label: {
                ThemeSettingsRow(
                    themeColors: themeManager.currentTheme.previewColors,
                    themeName: themeManager.currentTheme.displayName,
                )
            }

            // Color Scheme Selection
            HStack(spacing: Spacing.md) {
                Image(systemName: themeManager.colorSchemePreference.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.DesignSystem.brandBlue)
                    .frame(width: 28)

                Text(t.t("appearance_mode"))
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.text)

                Spacer()

                Picker("", selection: Binding(
                    get: { themeManager.colorSchemePreference },
                    set: { themeManager.setColorSchemePreference($0) },
                )) {
                    ForEach(ColorSchemePreference.allCases, id: \.self) { pref in
                        Text(pref.displayName).tag(pref)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(Spacing.md)

            // App Icon
            Button {
                viewModel.showAppIconPicker = true
            } label: {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "app.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.DesignSystem.brandGreen)
                        .frame(width: 28)

                    Text(t.t("app_icon"))
                        .font(.DesignSystem.bodyMedium)
                        .foregroundColor(.DesignSystem.text)

                    Spacer()

                    Text(AppIconOption.currentIcon.displayName)
                        .font(.DesignSystem.bodyMedium)
                        .foregroundColor(.DesignSystem.textSecondary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.DesignSystem.textTertiary)
                }
                .padding(Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Notifications Content

    private var notificationsContent: some View {
        VStack(spacing: 0) {
            // Quick toggle for push notifications
            GlassSettingsToggle(
                icon: "bell.badge.fill",
                iconColor: .DesignSystem.brandGreen,
                title: t.t("push_notifications"),
                isOn: $preferencesService.notificationsEnabled,
            )
            .sensoryFeedback(.selection, trigger: preferencesService.notificationsEnabled)

            // Notification preferences
            NavigationLink {
                NotificationsSettingsView()
            } label: {
                GlassSettingsRow(
                    icon: "gearshape.fill",
                    iconColor: .DesignSystem.brandBlue,
                    title: t.t("settings.notifications.preferences_title"),
                    subtitle: t.t("settings.notifications.advanced_desc"),
                    showChevron: true,
                )
            }
        }
    }

    // MARK: - Communication Content

    private var communicationContent: some View {
        Group {
            NavigationLink {
                EmailPreferencesView()
            } label: {
                GlassSettingsRow(
                    icon: "envelope.badge.fill",
                    iconColor: .DesignSystem.brandTeal,
                    title: t.t("email_preferences.title"),
                    showChevron: true,
                )
            }

            NavigationLink {
                NewsletterSubscriptionView()
            } label: {
                GlassSettingsRow(
                    icon: "newspaper.fill",
                    iconColor: .DesignSystem.brandGreen,
                    title: t.t("newsletter.title"),
                    showChevron: true,
                )
            }

            NavigationLink {
                InviteView()
            } label: {
                GlassSettingsRow(
                    icon: "person.badge.plus.fill",
                    iconColor: .DesignSystem.brandPink,
                    title: t.t("invite_friends"),
                    showChevron: true,
                )
            }
        }
    }

    // MARK: - Accessibility Content

    private var accessibilityContent: some View {
        NavigationLink {
            AccessibilitySettingsView()
        } label: {
            GlassSettingsRow(
                icon: "accessibility",
                iconColor: .DesignSystem.brandTeal,
                title: t.t("settings.accessibility_settings"),
                showChevron: true,
            )
        }
    }

    // MARK: - Data Privacy Content

    private var dataPrivacyContent: some View {
        Group {
            NavigationLink {
                DataExportView()
            } label: {
                GlassSettingsRow(
                    icon: "square.and.arrow.up.fill",
                    iconColor: .DesignSystem.accentPurple,
                    title: t.t("settings.export_data"),
                    showChevron: true,
                )
            }

            NavigationLink {
                SettingsBackupView()
            } label: {
                GlassSettingsRow(
                    icon: "externaldrive.fill",
                    iconColor: .DesignSystem.brandBlue,
                    title: t.t("settings.backup_restore"),
                    showChevron: true,
                )
            }
        }
    }

    // MARK: - Support Content

    private var supportContent: some View {
        Group {
            Button {
                viewModel.showDonation = true
            } label: {
                GlassSettingsRow(
                    icon: "cup.and.saucer.fill",
                    iconColor: .DesignSystem.accentPink,
                    title: t.t("buy_us_a_coffee"),
                    showChevron: true,
                )
            }

            Button {
                viewModel.showHelp = true
            } label: {
                GlassSettingsRow(
                    icon: "questionmark.circle.fill",
                    iconColor: .DesignSystem.accentOrange,
                    title: t.t("help_center"),
                    showChevron: true,
                )
            }

            Button {
                viewModel.showFeedback = true
            } label: {
                GlassSettingsRow(
                    icon: "bubble.left.and.bubble.right.fill",
                    iconColor: .DesignSystem.brandBlue,
                    title: t.t("send_feedback"),
                    showChevron: true,
                )
            }
        }
    }

    // MARK: - About Content

    private var aboutContent: some View {
        Group {
            GlassSettingsRow(
                icon: "app.badge.fill",
                iconColor: .DesignSystem.brandGreen,
                title: t.t("version"),
                value: viewModel.appVersion,
            )

            NavigationLink {
                LegalDocumentView(type: .privacy)
            } label: {
                GlassSettingsRow(
                    icon: "hand.raised.fill",
                    iconColor: .DesignSystem.accentPurple,
                    title: t.t("privacy_policy"),
                    showChevron: true,
                )
            }

            NavigationLink {
                LegalDocumentView(type: .terms)
            } label: {
                GlassSettingsRow(
                    icon: "doc.text.fill",
                    iconColor: .DesignSystem.brandBlue,
                    title: t.t("terms_of_service"),
                    showChevron: true,
                )
            }
        }
    }

    // MARK: - Danger Zone Content

    private var dangerZoneContent: some View {
        Group {
            Button {
                viewModel.showSignOutConfirmation = true
            } label: {
                GlassSettingsRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    iconColor: .DesignSystem.accentOrange,
                    title: t.t("sign_out"),
                    titleColor: .DesignSystem.accentOrange,
                )
            }

            Button {
                viewModel.showDeleteConfirmation = true
            } label: {
                GlassSettingsRow(
                    icon: "trash.fill",
                    iconColor: .DesignSystem.error,
                    title: t.t("delete_account"),
                    titleColor: .DesignSystem.error,
                )
            }
        }
    }
}

// MARK: - Collapsible Settings Section

struct CollapsibleSettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let titleColor: Color
    let isExpanded: Bool
    let onToggle: () -> Void
    let content: Content

    init(
        title: String,
        icon: String,
        titleColor: Color = .DesignSystem.text,
        isExpanded: Bool,
        onToggle: @escaping () -> Void,
        @ViewBuilder content: () -> Content,
    ) {
        self.title = title
        self.icon = icon
        self.titleColor = titleColor
        self.isExpanded = isExpanded
        self.onToggle = onToggle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header (tappable)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    onToggle()
                }
                HapticManager.light()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(titleColor)

                    Text(title)
                        .font(.DesignSystem.headlineSmall)
                        .foregroundColor(titleColor)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.DesignSystem.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, Spacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Content
            if isExpanded {
                VStack(spacing: 1) {
                    content
                }
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.large)
                                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                        ),
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
    }
}

// MARK: - Glass Settings Section (non-collapsible)

struct GlassSettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let titleColor: Color
    let content: Content

    init(
        title: String,
        icon: String,
        titleColor: Color = .DesignSystem.text,
        @ViewBuilder content: () -> Content,
    ) {
        self.title = title
        self.icon = icon
        self.titleColor = titleColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(titleColor)

                Text(title)
                    .font(.DesignSystem.headlineSmall)
                    .foregroundColor(titleColor)
            }
            .padding(.horizontal, Spacing.sm)

            // Content
            VStack(spacing: 1) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                    ),
            )
        }
    }
}

// MARK: - Settings Section Skeleton

struct SettingsSectionSkeleton: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(0 ..< 3, id: \.self) { _ in
                HStack(spacing: Spacing.md) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.DesignSystem.textTertiary.opacity(0.3))
                        .frame(width: 28, height: 28)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.DesignSystem.textTertiary.opacity(0.3))
                        .frame(height: 16)
                        .frame(maxWidth: 150)

                    Spacer()
                }
                .padding(Spacing.md)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
        .redacted(reason: .placeholder)
        .shimmer()
    }
}

// MARK: - Theme Settings Row

/// Theme settings row with gradient preview circle
struct ThemeSettingsRow: View {
    @Environment(\.translationService) private var t
    let themeColors: [Color]
    let themeName: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Theme preview gradient circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: themeColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
                .frame(width: 28, height: 28)

            Text(t.t("settings.theme"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.text)

            Spacer()

            Text(themeName)
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.DesignSystem.textTertiary)
        }
        .padding(Spacing.md)
        .contentShape(Rectangle())
    }
}

// MARK: - Glass Settings Row

struct GlassSettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String?
    var value: String?
    var titleColor: Color = .DesignSystem.text
    var showChevron = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(title)
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(titleColor)

                if let subtitle {
                    Text(subtitle)
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let value {
                Text(value)
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.DesignSystem.textTertiary)
            }
        }
        .padding(Spacing.md)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(showChevron ? "Double tap to open" : "")
    }

    private var accessibilityLabel: String {
        var label = title
        if let subtitle {
            label += ", \(subtitle)"
        }
        if let value {
            label += ", \(value)"
        }
        return label
    }
}

// MARK: - Glass Settings Toggle

struct GlassSettingsToggle: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(title)
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.text)

                if let subtitle {
                    Text(subtitle)
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(.DesignSystem.brandGreen)
                .labelsHidden()
        }
        .padding(Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(subtitle.map { "\(title), \($0)" } ?? title)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityHint("Double tap to toggle")
    }
}

#Preview {
    NavigationStack {
        SettingsView(appState: AppState.preview)
            .environment(AppState.preview)
            .environment(FeedViewModel.preview)
    }
}

// MARK: - Language Settings Row

struct LanguageSettingsRow: View {
    @Environment(\.translationService) private var translationService

    private var currentLanguageName: String {
        let locale = Locale(identifier: translationService.currentLocale)
        return locale.localizedString(forLanguageCode: translationService.currentLocale)?.capitalized
            ?? translationService.currentLocale.uppercased()
    }

    private var flagEmoji: String {
        LocaleUtilities.flagEmoji(for: translationService.currentLocale)
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(flagEmoji)
                .font(.system(size: 22))
                .frame(width: 28)

            Text(translationService.t("language"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.text)

            Spacer()

            Text(currentLanguageName)
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.DesignSystem.textTertiary)
        }
        .padding(Spacing.md)
        .contentShape(Rectangle())
    }
}
