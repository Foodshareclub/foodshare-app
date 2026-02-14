//
//  HelpView.swift
//  Foodshare
//
//  Help Center with FAQs using Liquid Glass design
//

import SwiftUI
import FoodShareDesignSystem

#if DEBUG
    import Inject
#endif

struct HelpView: View {
    
    @Environment(\.translationService) private var t
    @State private var expandedFAQs: Set<UUID> = []
    @State private var searchText = ""
    @State private var selectedQuickAction: QuickAction?
    @State private var showContactSupport = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                headerSection
                searchSection
                quickActionsSection
                faqSections
                contactSection
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Color.backgroundGradient)
        .navigationTitle(t.t("help.title"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedQuickAction) { action in
            QuickActionDetailSheet(action: action)
        }
        .sheet(isPresented: $showContactSupport) {
            ContactSupportSheet()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.DesignSystem.brandGreen.opacity(0.2),
                                Color.DesignSystem.brandBlue.opacity(0.1),
                                Color.clear,
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60,
                        ),
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
            }

            Text(t.t("help.how_can_help"))
                .font(.DesignSystem.headlineLarge)
                .fontWeight(.bold)
                .foregroundColor(.DesignSystem.text)

            Text(t.t("help.find_answers"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Spacing.lg)
    }

    // MARK: - Search

    private var searchSection: some View {
        GlassTextField(
            t.t("help.search_placeholder"),
            text: $searchText,
            icon: "magnifyingglass",
        )
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(t.t("help.popular_topics"))
                .font(.DesignSystem.headlineSmall)
                .fontWeight(.bold)
                .foregroundColor(.DesignSystem.text)
                .padding(.horizontal, Spacing.sm)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(QuickAction.allCases) { action in
                        quickActionButton(action)
                    }
                }
            }
        }
    }

    private func quickActionButton(_ action: QuickAction) -> some View {
        Button {
            selectedQuickAction = action
            HapticManager.light()
        } label: {
            VStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(action.color.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: action.icon)
                        .font(.system(size: 20))
                        .foregroundColor(action.color)
                }

                Text(action.title(t))
                    .font(.DesignSystem.captionSmall)
                    .fontWeight(.medium)
                    .foregroundColor(.DesignSystem.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 80)
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.xs)
            .background(Color.DesignSystem.glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - FAQ Sections

    private var faqSections: some View {
        VStack(spacing: Spacing.lg) {
            ForEach(filteredSections) { section in
                faqSectionView(section)
            }
        }
    }

    private var filteredSections: [FAQSection] {
        guard !searchText.isEmpty else {
            return FAQSection.allSections
        }

        let query = searchText.lowercased()
        return FAQSection.allSections.compactMap { section in
            let matchingFAQs = section.faqs.filter { faq in
                faq.question.lowercased().contains(query) ||
                    faq.answer.lowercased().contains(query)
            }
            guard !matchingFAQs.isEmpty else { return nil }
            return FAQSection(title: section.title, icon: section.icon, faqs: matchingFAQs)
        }
    }

    private func faqSectionView(_ section: FAQSection) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section Header
            HStack(spacing: Spacing.sm) {
                Image(systemName: section.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.DesignSystem.brandGreen)

                Text(section.title)
                    .font(.DesignSystem.headlineSmall)
                    .fontWeight(.bold)
                    .foregroundColor(.DesignSystem.text)
            }
            .padding(.horizontal, Spacing.sm)

            // FAQ Items
            VStack(spacing: Spacing.sm) {
                ForEach(section.faqs) { faq in
                    faqItemView(faq)
                }
            }
        }
    }

    private func faqItemView(_ faq: FAQ) -> some View {
        let isExpanded = expandedFAQs.contains(faq.id)

        return VStack(alignment: .leading, spacing: 0) {
            // Question Header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isExpanded {
                        expandedFAQs.remove(faq.id)
                    } else {
                        expandedFAQs.insert(faq.id)
                    }
                }
                HapticManager.light()
            } label: {
                HStack {
                    Text(faq.question)
                        .font(.DesignSystem.labelLarge)
                        .fontWeight(.medium)
                        .foregroundColor(.DesignSystem.text)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.DesignSystem.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(Spacing.md)
            }

            // Answer (expandable)
            if isExpanded {
                Text(faq.answer)
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.textSecondary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.DesignSystem.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
        )
    }

    // MARK: - Contact Section

    private var contactSection: some View {
        VStack(spacing: Spacing.md) {
            // Header with icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.DesignSystem.brandBlue.opacity(0.2),
                                Color.DesignSystem.brandGreen.opacity(0.1),
                                Color.clear,
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 40,
                        ),
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "headphones.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.brandBlue, .DesignSystem.brandGreen],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
            }

            Text(t.t("help.need_more_help"))
                .font(.DesignSystem.headlineSmall)
                .fontWeight(.bold)
                .foregroundColor(.DesignSystem.text)

            Text(t.t("help.support_desc"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)

            // Contact Support Button
            Button {
                showContactSupport = true
                HapticManager.light()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "envelope.fill")
                    Text(t.t("help.contact_support"))
                        .fontWeight(.semibold)
                }
                .font(.DesignSystem.labelLarge)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(
                    LinearGradient(
                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                        startPoint: .leading,
                        endPoint: .trailing,
                    ),
                )
                .clipShape(Capsule())
            }
            .pressAnimation()

            // Send Feedback Link
            NavigationLink {
                FeedbackView()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "text.bubble.fill")
                    Text(t.t("help.send_feedback"))
                }
                .font(.DesignSystem.labelMedium)
                .foregroundColor(.DesignSystem.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Color.DesignSystem.glassBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                )
            }

            // Links
            HStack(spacing: Spacing.lg) {
                NavigationLink {
                    WebContentView(title: t.t("common.terms_of_service"), urlString: "https://foodshare.club/terms")
                } label: {
                    Text(t.t("common.terms_of_service"))
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.brandGreen)
                }

                NavigationLink {
                    WebContentView(title: t.t("common.privacy_policy"), urlString: "https://foodshare.club/privacy")
                } label: {
                    Text(t.t("common.privacy_policy"))
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.brandGreen)
                }
            }
            .padding(.top, Spacing.sm)
        }
        .padding(Spacing.xl)
        .glassBackground(cornerRadius: CornerRadius.large)
    }
}

// MARK: - Web Content View

struct WebContentView: View {
    let title: String
    let urlString: String

    @Environment(\.openURL) private var openURL
    @Environment(\.translationService) private var t

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 50))
                .foregroundColor(.DesignSystem.brandGreen)

            Text(t.t("help.view_in_browser"))
                .font(.DesignSystem.headlineSmall)
                .foregroundColor(.DesignSystem.text)

            Text(t.t("help.open_in_browser_desc"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)

            if let url = URL(string: urlString) {
                GlassButton(t.t("common.open", args: ["title": title]), icon: "safari.fill", style: .primary) {
                    openURL(url)
                }
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundGradient)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Quick Action Enum

enum QuickAction: String, CaseIterable, Identifiable {
    case howToShare = "how_to_share"
    case foodSafety = "food_safety"
    case messaging
    case accountHelp = "account_help"
    case communityFridges = "community_fridges"
    case reportIssue = "report_issue"

    var id: String { rawValue }

    func title(_ t: TranslationService) -> String {
        t.t("help.quick_actions.\(rawValue)")
    }

    var icon: String {
        switch self {
        case .howToShare: "square.and.arrow.up.fill"
        case .foodSafety: "checkmark.shield.fill"
        case .messaging: "bubble.left.and.bubble.right.fill"
        case .accountHelp: "person.crop.circle.fill"
        case .communityFridges: "refrigerator.fill"
        case .reportIssue: "exclamationmark.bubble.fill"
        }
    }

    var color: Color {
        switch self {
        case .howToShare: .DesignSystem.brandGreen
        case .foodSafety: .DesignSystem.success
        case .messaging: .DesignSystem.brandBlue
        case .accountHelp: .DesignSystem.accentOrange
        case .communityFridges: .DesignSystem.info
        case .reportIssue: .DesignSystem.warning
        }
    }

    func detailContent(_ t: TranslationService) -> String {
        t.t("help.quick_actions.\(rawValue)_content")
    }
}

// MARK: - Quick Action Detail Sheet

struct QuickActionDetailSheet: View {
    let action: QuickAction
    @Environment(\.dismiss) private var dismiss
    @Environment(\.translationService) private var t

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(action.color.opacity(0.15))
                                .frame(width: 80, height: 80)

                            Image(systemName: action.icon)
                                .font(.system(size: 36))
                                .foregroundColor(action.color)
                        }
                        .padding(.top, Spacing.lg)

                        // Content
                        Text(action.detailContent(t))
                            .font(.DesignSystem.bodyMedium)
                            .foregroundColor(.DesignSystem.text)
                            .multilineTextAlignment(.leading)
                            .padding(Spacing.lg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassBackground(cornerRadius: CornerRadius.large)
                    }
                    .padding(Spacing.md)
                }
            }
            .navigationTitle(action.title(t))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(t.t("common.done")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Contact Support Sheet

struct ContactSupportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.translationService) private var t
    @State private var subject = ""
    @State private var message = ""
    @State private var selectedCategory: SupportCategory = .general
    @State private var isSubmitting = false
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Header
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "envelope.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing,
                                    ),
                                )

                            Text(t.t("help.we_are_here"))
                                .font(.DesignSystem.headlineSmall)
                                .foregroundColor(.DesignSystem.text)

                            Text(t.t("help.form_desc"))
                                .font(.DesignSystem.bodySmall)
                                .foregroundColor(.DesignSystem.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, Spacing.lg)

                        // Form
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            // Category
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text(t.t("help.category"))
                                    .font(.DesignSystem.labelMedium)
                                    .foregroundColor(.DesignSystem.text)

                                HStack(spacing: Spacing.sm) {
                                    ForEach(SupportCategory.allCases, id: \.self) { category in
                                        categoryButton(category)
                                    }
                                }
                            }

                            // Subject
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text(t.t("help.subject"))
                                    .font(.DesignSystem.labelMedium)
                                    .foregroundColor(.DesignSystem.text)

                                GlassTextField(
                                    t.t("help.subject_placeholder"),
                                    text: $subject,
                                    icon: "text.alignleft",
                                )
                            }

                            // Message
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text(t.t("help.message"))
                                    .font(.DesignSystem.labelMedium)
                                    .foregroundColor(.DesignSystem.text)

                                TextEditor(text: $message)
                                    .frame(minHeight: 150)
                                    .padding(Spacing.sm)
                                    .background(Color.DesignSystem.glassBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                                    )
                                    .font(.DesignSystem.bodyMedium)

                                Text(t.t("help.include_details"))
                                    .font(.DesignSystem.caption)
                                    .foregroundColor(.DesignSystem.textTertiary)
                            }
                        }
                        .padding(Spacing.lg)
                        .glassBackground(cornerRadius: CornerRadius.large)

                        // Submit Button
                        Button {
                            submitSupportRequest()
                        } label: {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Spacing.md)
                            } else {
                                Text(t.t("help.send_message"))
                                    .font(.DesignSystem.labelLarge)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Spacing.md)
                            }
                        }
                        .background(
                            LinearGradient(
                                colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                                startPoint: .leading,
                                endPoint: .trailing,
                            ),
                        )
                        .clipShape(Capsule())
                        .disabled(subject.isEmpty || message.isEmpty || isSubmitting)
                        .opacity(subject.isEmpty || message.isEmpty ? 0.6 : 1)
                    }
                    .padding(Spacing.md)
                }
            }
            .navigationTitle(t.t("help.contact_support"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t.t("common.cancel")) { dismiss() }
                }
            }
            .alert(t.t("help.message_sent"), isPresented: $showSuccess) {
                Button(t.t("common.ok")) { dismiss() }
            } message: {
                Text(t.t("help.thank_you"))
            }
        }
    }

    private func categoryButton(_ category: SupportCategory) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            selectedCategory = category
            HapticManager.light()
        } label: {
            VStack(spacing: Spacing.xs) {
                Image(systemName: category.icon)
                    .font(.system(size: 18))
                Text(category.title(t))
                    .font(.DesignSystem.captionSmall)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .foregroundColor(isSelected ? .white : .DesignSystem.textSecondary)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient(
                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                        startPoint: .leading,
                        endPoint: .trailing,
                    ))
                    : AnyShapeStyle(Color.DesignSystem.glassBackground),
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(isSelected ? Color.clear : Color.DesignSystem.glassBorder, lineWidth: 1),
            )
        }
        .buttonStyle(.plain)
    }

    private func submitSupportRequest() {
        isSubmitting = true
        HapticManager.medium()

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run {
                isSubmitting = false
                showSuccess = true
            }
        }
    }
}

// MARK: - Support Category

enum SupportCategory: String, CaseIterable, Sendable {
    case general
    case technical
    case report
    case other

    func title(_ t: TranslationService) -> String {
        t.t("help.categories.\(rawValue)")
    }

    var icon: String {
        switch self {
        case .general: "questionmark.circle"
        case .technical: "wrench.and.screwdriver"
        case .report: "exclamationmark.triangle"
        case .other: "ellipsis.circle"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HelpView()
    }
}
