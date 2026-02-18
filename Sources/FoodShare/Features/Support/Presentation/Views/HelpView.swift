//
//  HelpView.swift
//  Foodshare
//
//  Help Center with Liquid Glass v26 design
//  iOS equivalent of web app's help/FAQ page with expandable sections
//


#if !SKIP
import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.translationService) private var t
    @State private var expandedSections: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Getting Started Section
                    helpSection(
                        title: t.t("help.section.getting_started"),
                        icon: "play.circle.fill",
                        iconColor: .DesignSystem.brandGreen,
                        items: gettingStartedItems,
                    )

                    // Food Safety Section
                    helpSection(
                        title: t.t("help.section.food_safety"),
                        icon: "shield.checkered",
                        iconColor: .orange,
                        items: foodSafetyItems,
                    )

                    // Using the App Section
                    helpSection(
                        title: t.t("help.section.using_app"),
                        icon: "iphone",
                        iconColor: .DesignSystem.brandBlue,
                        items: usingAppItems,
                    )

                    // Account & Privacy Section
                    helpSection(
                        title: t.t("help.section.account_privacy"),
                        icon: "lock.shield.fill",
                        iconColor: .purple,
                        items: accountPrivacyItems,
                    )

                    // Need More Help Section
                    needMoreHelpSection
                }
                .padding(Spacing.md)
            }
            .background(Color.DesignSystem.background)
            .navigationTitle(t.t("navigation.help_center"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t.t("common.done")) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Help Section

    private func helpSection(
        title: String,
        icon: String,
        iconColor: Color,
        items: [HelpItem],
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section Header
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)

                Text(title)
                    .font(.DesignSystem.headlineMedium)
                    .fontWeight(.bold)
                    .foregroundColor(.DesignSystem.text)
            }
            .padding(.horizontal, Spacing.sm)

            // Items
            VStack(spacing: 1) {
                ForEach(items) { item in
                    HelpItemRow(
                        item: item,
                        isExpanded: expandedSections.contains(item.id),
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if expandedSections.contains(item.id) {
                                    expandedSections.remove(item.id)
                                } else {
                                    expandedSections.insert(item.id)
                                }
                            }
                        },
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    #if !SKIP
                    .fill(.ultraThinMaterial)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                    ),
            )
        }
    }

    // MARK: - Need More Help Section

    private var needMoreHelpSection: some View {
        GlassCard(cornerRadius: 20, shadow: .medium) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.DesignSystem.brandGreen)

                    Text(t.t("help.need_more_help"))
                        .font(.DesignSystem.headlineMedium)
                        .fontWeight(.bold)
                        .foregroundColor(.DesignSystem.text)
                }

                Text(t.t("help.need_more_help_desc"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)

                HStack(spacing: Spacing.md) {
                    NavigationLink {
                        LegalDocumentView(type: .terms)
                    } label: {
                        Text(t.t("common.terms_of_service"))
                            .font(.DesignSystem.bodySmall)
                            .fontWeight(.medium)
                            .foregroundColor(.DesignSystem.brandGreen)
                    }

                    Text("•")
                        .foregroundColor(.DesignSystem.textTertiary)

                    NavigationLink {
                        LegalDocumentView(type: .privacy)
                    } label: {
                        Text(t.t("common.privacy_policy"))
                            .font(.DesignSystem.bodySmall)
                            .fontWeight(.medium)
                            .foregroundColor(.DesignSystem.brandGreen)
                    }
                }
            }
            .padding(Spacing.lg)
        }
    }

    // MARK: - Help Data

    private var gettingStartedItems: [HelpItem] {
        [
            HelpItem(
                question: t.t("help.faq.create_account.question"),
                answer: t.t("help.faq.create_account.answer")
            ),
            HelpItem(
                question: t.t("help.faq.share_food.question"),
                answer: t.t("help.faq.share_food.answer")
            ),
            HelpItem(
                question: t.t("help.faq.find_food.question"),
                answer: t.t("help.faq.find_food.answer")
            )
        ]
    }

    private var foodSafetyItems: [HelpItem] {
        [
            HelpItem(
                question: t.t("help.faq.what_food.question"),
                answer: t.t("help.faq.what_food.answer")
            ),
            HelpItem(
                question: t.t("help.faq.safety_tips.question"),
                answer: t.t("help.faq.safety_tips.answer")
            )
        ]
    }

    private var usingAppItems: [HelpItem] {
        [
            HelpItem(
                question: t.t("help.faq.messaging.question"),
                answer: t.t("help.faq.messaging.answer")
            ),
            HelpItem(
                question: t.t("help.faq.edit_listing.question"),
                answer: t.t("help.faq.edit_listing.answer")
            ),
            HelpItem(
                question: t.t("help.faq.community_fridges.question"),
                answer: t.t("help.faq.community_fridges.answer")
            )
        ]
    }

    private var accountPrivacyItems: [HelpItem] {
        [
            HelpItem(
                question: t.t("help.faq.settings.question"),
                answer: t.t("help.faq.settings.answer")
            ),
            HelpItem(
                question: t.t("help.faq.location_shared.question"),
                answer: t.t("help.faq.location_shared.answer")
            ),
            HelpItem(
                question: t.t("help.faq.delete_account.question"),
                answer: t.t("help.faq.delete_account.answer")
            )
        ]
    }
}

// MARK: - Help Item Model

struct HelpItem: Identifiable {
    let id = UUID().uuidString
    let question: String
    let answer: String
}

// MARK: - Help Item Row

struct HelpItemRow: View {
    let item: HelpItem
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Question
            Button(action: onTap) {
                HStack {
                    Text(item.question)
                        .font(.DesignSystem.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(.DesignSystem.text)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.DesignSystem.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Answer (expandable)
            if isExpanded {
                Text(item.answer)
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Divider
            Divider()
                .background(Color.DesignSystem.glassBorder)
        }
    }
}

// MARK: - Preview

#Preview {
    HelpView()
}

#endif
