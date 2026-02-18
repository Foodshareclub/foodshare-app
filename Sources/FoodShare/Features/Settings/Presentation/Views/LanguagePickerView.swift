//
//  LanguagePickerView.swift
//  Foodshare
//
//  Enterprise-grade in-app language picker with Liquid Glass design
//  Features: Search, accessibility, haptic feedback, confirmation
//


#if !SKIP
import SwiftUI

struct LanguagePickerView: View {
    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.translationService) private var translationService
    @State private var selectedLocale: String
    @State private var isChanging = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var searchText = ""
    @State private var showConfirmation = false
    @State private var pendingLocale: String?
    @State private var lastFailedAction: (() async -> Void)?

    private let haptics = UIImpactFeedbackGenerator(style: .medium)
    private let successHaptics = UINotificationFeedbackGenerator()

    @MainActor
    init() {
        _selectedLocale = State(initialValue: EnhancedTranslationService.shared.currentLocale)
    }

    // MARK: - Computed Properties

    private var filteredLocales: [SupportedLocale] {
        let locales = translationService.supportedLocales
        guard !searchText.isEmpty else { return locales }
        let query = searchText.lowercased()
        return locales.filter {
            $0.code.lowercased().contains(query) ||
                $0.name.lowercased().contains(query) ||
                $0.nativeName.lowercased().contains(query)
        }
    }

    private var pendingLocaleName: String {
        guard let code = pendingLocale else { return "" }
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code)?.capitalized ?? code.uppercased()
    }

    private var hasUnsavedChanges: Bool {
        selectedLocale != translationService.currentLocale
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                List {
                    systemSection
                    languagesSection
                }
                #if !SKIP
                .listStyle(.insetGrouped)
                #endif
                #if !SKIP
                .scrollDismissesKeyboard(.interactively)
                #endif
            }
            .background(Color.DesignSystem.background)
            .navigationTitle(translationService.t("settings.language"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .overlay { if isChanging { loadingOverlay } }
            .alert(translationService.t("common.error.title"), isPresented: $showError) {
                Button(translationService.t("common.ok"), role: .cancel) {}
                if lastFailedAction != nil {
                    Button(translationService.t("common.retry")) {
                        Task { await retryLastAction() }
                    }
                }
            } message: {
                Text(errorMessage)
            }
            .confirmationDialog(
                translationService.t("settings.language.change"),
                isPresented: $showConfirmation,
                titleVisibility: .visible,
            ) {
                confirmationButtons
            } message: {
                Text(translationService.t("settings.language.change_to", args: ["language": pendingLocaleName]))
            }
        }
        .interactiveDismissDisabled(hasUnsavedChanges || isChanging)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.DesignSystem.textSecondary)
                .font(.system(size: 16))

            TextField(translationService.t("settings.language.search"), text: $searchText)
                .font(.DesignSystem.bodyMedium)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel(translationService.t("settings.language.search"))
                .accessibilityHint(translationService.t("settings.language.search_hint"))

            if !searchText.isEmpty {
                Button {
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 24)) {
                        searchText = ""
                    }
                    haptics.impactOccurred(intensity: 0.5)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.DesignSystem.textTertiary)
                        .font(.system(size: 16))
                }
                .accessibilityLabel(translationService.t("common.clear_search"))
            }
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.DesignSystem.glassBackground),
        )
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - System Section

    private var systemSection: some View {
        Section {
            Button {
                haptics.impactOccurred(intensity: 0.6)
                if translationService.hasLocaleOverride {
                    pendingLocale = nil
                    showConfirmation = true
                }
            } label: {
                HStack(spacing: Spacing.md) {
                    Text("🌐")
                        .font(.system(size: 28))
                        .frame(width: 36.0)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(translationService.t("settings.language.system_default"))
                            .font(.DesignSystem.bodyMedium)
                            .foregroundColor(.DesignSystem.text)

                        Text(translationService.t("settings.language.follow_device"))
                            .font(.DesignSystem.caption)
                            .foregroundColor(.DesignSystem.textSecondary)
                    }

                    Spacer()

                    if !translationService.hasLocaleOverride {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.DesignSystem.success)
                            .accessibilityLabel(translationService.t("settings.language.currently_selected"))
                    }
                }
                .padding(.vertical, Spacing.xs)
                #if !SKIP
                .contentShape(Rectangle())
                #endif
            }
            .buttonStyle(.plain)
            .disabled(!translationService.hasLocaleOverride)
            .accessibilityLabel(translationService.t("settings.language.system_default"))
            .accessibilityHint(translationService.hasLocaleOverride
                ? translationService.t("settings.language.tap_to_use_device")
                : translationService.t("settings.language.using_device"))
                .accessibilityAddTraits(!translationService.hasLocaleOverride ? .isSelected : [])
        } header: {
            Text(translationService.t("settings.language.automatic"))
                .font(.DesignSystem.caption)
                .foregroundColor(.DesignSystem.textSecondary)
        }
    }

    // MARK: - Languages Section

    private var languagesSection: some View {
        Section {
            if filteredLocales.isEmpty {
                emptySearchState
            } else {
                ForEach(filteredLocales, id: \.code) { locale in
                    languageRow(locale)
                }
            }
        } header: {
            HStack {
                Text(translationService.t("settings.language.available"))
                    .font(.DesignSystem.caption)
                    .foregroundColor(.DesignSystem.textSecondary)

                Spacer()

                Text(translationService.t("settings.language.count", args: ["count": "\(filteredLocales.count)"]))
                    .font(.DesignSystem.caption)
                    .foregroundColor(.DesignSystem.textTertiary)
            }
        }
    }

    private func languageRow(_ locale: SupportedLocale) -> some View {
        let isSelected = translationService.hasLocaleOverride && selectedLocale == locale.code

        return Button {
            haptics.impactOccurred(intensity: 0.6)
            if !isSelected {
                pendingLocale = locale.code
                showConfirmation = true
            }
        } label: {
            HStack(spacing: Spacing.md) {
                Text(locale.flag)
                    .font(.system(size: 28))
                    .frame(width: 36.0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(locale.nativeName.capitalized)
                        .font(.DesignSystem.bodyMedium)
                        .foregroundColor(.DesignSystem.text)

                    Text(locale.name)
                        .font(.DesignSystem.caption)
                        .foregroundColor(.DesignSystem.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.DesignSystem.success)
                        .accessibilityLabel(translationService.t("settings.language.currently_selected"))
                }
            }
            .padding(.vertical, Spacing.xs)
            #if !SKIP
            .contentShape(Rectangle())
            #endif
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(locale.nativeName), \(locale.name)")
        .accessibilityHint(isSelected ? translationService.t("settings.language.currently_selected") : translationService.t("settings.language.tap_to_select"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var emptySearchState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.DesignSystem.textTertiary)

            Text(translationService.t("settings.language.no_results"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)

            Text(translationService.t("settings.language.try_different"))
                .font(.DesignSystem.caption)
                .foregroundColor(.DesignSystem.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        #if !SKIP
        .accessibilityElement(children: .combine)
        #endif
        .accessibilityLabel(translationService.t("settings.language.no_results_for", args: ["query": searchText]))
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.DesignSystem.scrim
                .ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text(translationService.t("settings.language.changing"))
                    .font(.DesignSystem.bodyLarge)
                    .foregroundStyle(.white)

                if let locale = pendingLocale {
                    Text(pendingLocaleName)
                        .font(.DesignSystem.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(Spacing.xl)
            .background(Color.DesignSystem.glassSurface.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        }
        #if !SKIP
        .accessibilityElement(children: .combine)
        #endif
        .accessibilityLabel(translationService.t("settings.language.changing_wait"))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(translationService.t("common.cancel")) {
                haptics.impactOccurred(intensity: 0.4)
                dismiss()
            }
            .disabled(isChanging)
            .accessibilityLabel(translationService.t("common.cancel"))
            .accessibilityHint(translationService.t("settings.language.dismiss_hint"))
        }

        ToolbarItem(placement: .topBarTrailing) {
            if translationService.state.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }

    // MARK: - Confirmation Buttons

    @ViewBuilder
    private var confirmationButtons: some View {
        if let locale = pendingLocale {
            Button(translationService.t("settings.language.change_to_btn", args: ["language": pendingLocaleName])) {
                Task { await selectLocale(locale) }
            }
        } else {
            Button(translationService.t("settings.language.use_system")) {
                Task { await resetToSystem() }
            }
        }

        Button(translationService.t("common.cancel"), role: .cancel) {
            pendingLocale = nil
        }
    }

    // MARK: - Actions

    private func selectLocale(_ locale: String) async {
        isChanging = true
        haptics.prepare()

        do {
            try await translationService.setLocale(locale)
            selectedLocale = locale
            successHaptics.notificationOccurred(.success)
            lastFailedAction = nil

            // Small delay for visual feedback
            try? await Task.sleep(nanoseconds: 300_000_000)
            dismiss()
        } catch {
            haptics.impactOccurred(intensity: 1.0)
            errorMessage = error.localizedDescription
            showError = true
            lastFailedAction = { [locale] in
                await selectLocale(locale)
            }
        }

        isChanging = false
    }

    private func resetToSystem() async {
        isChanging = true
        haptics.prepare()

        await translationService.resetToSystemLocale()
        selectedLocale = translationService.currentLocale
        successHaptics.notificationOccurred(.success)
        lastFailedAction = nil

        // Small delay for visual feedback
        try? await Task.sleep(nanoseconds: 300_000_000)
        isChanging = false
        dismiss()
    }

    private func retryLastAction() async {
        guard let action = lastFailedAction else { return }
        await action()
    }

    // MARK: - Helpers

    private func flagEmoji(for code: String) -> String {
        TranslationConfig.locale(for: code)?.flag ?? "🌐"
    }
}

// MARK: - Preview

#Preview("Language Picker") {
    LanguagePickerView()
}

#Preview("Language Picker - Dark") {
    LanguagePickerView()
        .preferredColorScheme(.dark)
}

#endif
