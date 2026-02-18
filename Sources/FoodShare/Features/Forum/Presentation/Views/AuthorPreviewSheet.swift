//
//  AuthorPreviewSheet.swift
//  Foodshare
//
//  Half-sheet preview of a forum author's profile with stats and badges
//  Part of Forum UI improvements
//


#if !SKIP
import SwiftUI

// MARK: - Author Preview Sheet

struct AuthorPreviewSheet: View {
    let author: ForumAuthor
    let repository: ForumRepository
    let onViewProfile: () -> Void

    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.translationService) private var t
    @State private var userStats: ForumUserStats?
    @State private var badges: [UserBadgeWithDetails] = []
    @State private var isLoading = true
    @State private var hasAppeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.DesignSystem.background
                    .ignoresSafeArea()

                content
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            #if !SKIP
            .toolbarBackground(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t.t("common.done")) {
                        dismiss()
                    }
                    .foregroundStyle(Color.DesignSystem.primary)
                }
            }
        }
        .presentationDetents([PresentationDetent.medium, PresentationDetent.large])
        #if !SKIP
        .presentationDragIndicator(.visible)
        #endif
        .task {
            await loadAuthorData()
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Author header
                authorHeader
                    .animatedAppearance()

                if isLoading {
                    loadingView
                } else {
                    // Stats cards
                    if let stats = userStats {
                        statsSection(stats)
                            .staggeredAppearance(index: 1, baseDelay: 0.1)
                    }

                    // Badges
                    if !badges.isEmpty {
                        badgesSection
                            .staggeredAppearance(index: 2, baseDelay: 0.1)
                    }

                    // View profile button
                    viewProfileButton
                        .staggeredAppearance(index: 3, baseDelay: 0.1)
                }
            }
            .padding(Spacing.md)
        }
    }

    // MARK: - Author Header

    private var authorHeader: some View {
        VStack(spacing: Spacing.md) {
            // Avatar
            ZStack {
                // Glow ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.brandGreen.opacity(0.5),
                                Color.DesignSystem.brandBlue.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 90.0, height: 90)
                    .glassBreathing(intensity: 0.3)

                AsyncImage(url: author.avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.DesignSystem.brandGreen.opacity(0.3),
                                        Color.DesignSystem.brandBlue.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Color.DesignSystem.textSecondary)
                            }
                    }
                }
                .frame(width: 80.0, height: 80)
                .clipShape(Circle())
            }

            // Name and verification
            VStack(spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Text(author.displayName)
                        .font(.DesignSystem.headlineMedium)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.DesignSystem.text)

                    if author.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.DesignSystem.brandGreen, Color.DesignSystem.brandBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }

                // Trust level badge (if available)
                if let stats = userStats {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: trustLevelIcon(stats.trustLevel))
                            .font(.system(size: 12))
                        Text(trustLevelName(stats.trustLevel))
                    }
                    .font(.DesignSystem.captionSmall)
                    .foregroundStyle(trustLevelColor(stats.trustLevel))
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(trustLevelColor(stats.trustLevel).opacity(0.1))
                    )
                }
            }
        }
    }

    // MARK: - Stats Section

    private func statsSection(_ stats: ForumUserStats) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(t.t("profile.activity"))
                .font(.DesignSystem.labelMedium)
                .foregroundStyle(Color.DesignSystem.textSecondary)

            HStack(spacing: Spacing.md) {
                AuthorStatCard(
                    icon: "doc.text.fill",
                    value: stats.postsCount,
                    label: t.t("forum.posts"),
                    color: .DesignSystem.brandGreen
                )

                AuthorStatCard(
                    icon: "bubble.right.fill",
                    value: stats.commentsCount,
                    label: t.t("forum.comments"),
                    color: .DesignSystem.brandBlue
                )

                AuthorStatCard(
                    icon: "star.fill",
                    value: stats.reputationScore,
                    label: t.t("forum.karma"),
                    color: .DesignSystem.accentOrange
                )
            }
        }
    }

    // MARK: - Badges Section

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(t.t("profile.badges"))
                    .font(.DesignSystem.labelMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)

                Spacer()

                Text(t.t("profile.badges_earned", args: ["count": String(badges.count)]))
                    .font(.DesignSystem.captionSmall)
                    .foregroundStyle(Color.DesignSystem.textTertiary)
            }

            // Badge grid (show up to 6)
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Spacing.sm) {
                ForEach(badges.prefix(6)) { badge in
                    BadgeItem(badge: badge)
                }
            }
        }
    }

    // MARK: - View Profile Button

    private var viewProfileButton: some View {
        GlassButton(t.t("profile.view_full_profile"), icon: "person.circle", style: .primary) {
            dismiss()
            onViewProfile()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            // Stats skeleton
            HStack(spacing: Spacing.md) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(Color.DesignSystem.glassBackground)
                        .frame(height: 70.0)
                }
            }
            .glassShimmer(isActive: true)

            // Badges skeleton
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Spacing.sm) {
                ForEach(0..<6, id: \.self) { _ in
                    Circle()
                        .fill(Color.DesignSystem.glassBackground)
                        .frame(width: 50.0, height: 50)
                }
            }
            .glassShimmer(isActive: true)
        }
    }

    // MARK: - Data Loading

    private func loadAuthorData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let statsTask = repository.fetchUserStats(profileId: author.id)
            async let badgesTask = repository.fetchUserBadges(profileId: author.id)

            userStats = try await statsTask
            badges = try await badgesTask
        } catch {
            // Handle error - show available data only
        }
    }

    // MARK: - Trust Level Helpers

    private func trustLevelIcon(_ level: Int) -> String {
        switch level {
        case 0: "leaf"
        case 1: "star"
        case 2: "star.fill"
        case 3: "crown"
        case 4: "crown.fill"
        default: "leaf"
        }
    }

    private func trustLevelName(_ level: Int) -> String {
        switch level {
        case 0: t.t("trust_level.new_member")
        case 1: t.t("trust_level.basic")
        case 2: t.t("trust_level.member")
        case 3: t.t("trust_level.regular")
        case 4: t.t("trust_level.leader")
        default: t.t("trust_level.new_member")
        }
    }

    private func trustLevelColor(_ level: Int) -> Color {
        switch level {
        case 0: Color.DesignSystem.textSecondary
        case 1: Color.DesignSystem.brandGreen
        case 2: Color.DesignSystem.brandBlue
        case 3: Color.DesignSystem.brandPink
        case 4: Color.DesignSystem.medalGold
        default: Color.DesignSystem.textSecondary
        }
    }
}

// MARK: - Author Stat Card

private struct AuthorStatCard: View {
    let icon: String
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)

            Text("\(value)")
                .font(.DesignSystem.headlineSmall)
                .fontWeight(.bold)
                .foregroundStyle(Color.DesignSystem.text)
                #if !SKIP
                .contentTransition(.numericText())
                #endif

            Text(label)
                .font(.DesignSystem.captionSmall)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Badge Item

private struct BadgeItem: View {
    let badge: UserBadgeWithDetails

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                badge.badge.swiftUIColor.opacity(0.2),
                                badge.badge.swiftUIColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50.0, height: 50)

                Image(systemName: badge.badge.sfSymbolName)
                    .font(.system(size: 24))
                    .foregroundStyle(badge.badge.swiftUIColor)
            }

            Text(badge.badge.name)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.DesignSystem.textSecondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Preview

#if DEBUG
// Preview disabled - MockForumRepository unavailable
// #Preview {
//     AuthorPreviewSheet(
//         author: ForumAuthor(
//             id: UUID(),
//             nickname: "FoodSaver123",
//             avatarUrl: nil,
//             isVerified: true
//         ),
//         repository: MockForumRepository(),
//         onViewProfile: {}
//     )
// }
#endif

#endif
