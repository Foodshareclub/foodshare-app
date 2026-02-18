//
//  TrendingPostsSection.swift
//  Foodshare
//
//  Horizontal carousel displaying trending/hot forum posts
//  Part of Forum UI improvements
//


#if !SKIP
import SwiftUI

// MARK: - Trending Posts Section

struct TrendingPostsSection: View {
    @Environment(\.translationService) private var t
    let posts: [ForumPost]
    let onPostTap: (ForumPost) -> Void
    let onSeeAllTap: () -> Void

    @State private var hasAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Section header
            HStack {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.DesignSystem.accentOrange, Color.DesignSystem.error],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        #if !SKIP
                        .symbolEffect(.pulse, options: .repeating)
                        #endif

                    Text(t.t("forum.trending"))
                        .font(.DesignSystem.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.DesignSystem.text)
                }

                Spacer()

                Button {
                    HapticManager.light()
                    onSeeAllTap()
                } label: {
                    HStack(spacing: Spacing.xxs) {
                        Text(t.t("common.see_all"))
                            .font(.DesignSystem.caption)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.xs)

            // Horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                        TrendingPostCard(
                            post: post,
                            rank: index + 1,
                            onTap: { onPostTap(post) },
                        )
                        .staggeredAppearance(index: index, baseDelay: 0.1, staggerDelay: 0.05)
                    }
                }
                .padding(.horizontal, Spacing.xs)
            }
            #if !SKIP
            .scrollTargetBehavior(.viewAligned)
            #endif
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 10)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
            }
        }
    }
}

// MARK: - Trending Post Card

private struct TrendingPostCard: View {
    let post: ForumPost
    let rank: Int
    let onTap: () -> Void

    @State private var isPressed = false
    @State private var isLiked = false
    @State private var likeCount = 0

    init(post: ForumPost, rank: Int, onTap: @escaping () -> Void) {
        self.post = post
        self.rank = rank
        self.onTap = onTap
        _likeCount = State(initialValue: post.likesCount)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Top row: Rank badge + Like button + Category
                HStack {
                    // Rank badge
                    ZStack {
                        Circle()
                            .fill(rankGradient)
                            .frame(width: 24.0, height: 24)
                            .shadow(color: rankColor.opacity(0.4), radius: 4, y: 2)

                        Text("#\(rank)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    // Like button with beautiful animation
                    CompactEngagementLikeButton(
                        domain: EngagementDomain.forum(id: post.id),
                        initialIsLiked: isLiked,
                        onToggle: { liked in
                            isLiked = liked
                            likeCount += liked ? 1 : -1
                        },
                    )
                    .scaleEffect(0.65)
                    .background(
                        Circle()
                            #if !SKIP
                            .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                            #else
                            .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                            #endif
                            .frame(width: 26.0, height: 26),
                    )

                    // Category chip
                    if let category = post.category {
                        Text(category.name)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(category.displayColor)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(category.displayColor.opacity(0.1)),
                            )
                    }
                }

                // Title (uses translated version if available)
                Text(post.displayTitle)
                    .font(.DesignSystem.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.DesignSystem.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                // Stats row with like count
                HStack(spacing: Spacing.sm) {
                    // Like count with heart icon
                    HStack(spacing: 3) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(isLiked ? Color.DesignSystem.brandPink : Color.DesignSystem.textSecondary)
                        Text("\(likeCount)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(isLiked ? Color.DesignSystem.brandPink : Color.DesignSystem.textSecondary)
                            #if !SKIP
                            .contentTransition(.numericText())
                            #endif
                    }

                    // Comments count
                    HStack(spacing: 3) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 9, weight: .medium))
                        Text("\(post.commentsCount)")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(Color.DesignSystem.textTertiary)

                    Spacer()

                    // Time ago
                    #if !SKIP
                    Text(post.forumPostCreatedAt, style: .relative)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.DesignSystem.textTertiary)
                    #else
                    Text({
                        let interval = Date().timeIntervalSince(post.forumPostCreatedAt)
                        if interval < 60 { return "just now" }
                        if interval < 3600 { return "\(Int(interval / 60))m ago" }
                        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
                        return "\(Int(interval / 86400))d ago"
                    }())
                        .font(Font.system(size: 9))
                        .foregroundStyle(Color.DesignSystem.textTertiary)
                    #endif
                }
            }
            .padding(Spacing.sm)
            .frame(width: 170.0, height: 140)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.DesignSystem.glassBorder,
                                Color.white.opacity(0.1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                        lineWidth: 1,
                    ),
            )
            .shadow(color: rankColor.opacity(0.15), radius: 8, y: 4)
            .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
        }
        .buttonStyle(TrendingCardButtonStyle())
        .task {
            // Fetch actual like status from server
            do {
                let status = try await ForumEngagementService.shared.checkLiked(forumId: post.id)
                isLiked = status.isLiked
                likeCount = status.likeCount
            } catch {
                // Use post's count as fallback
                likeCount = post.likesCount
            }
        }
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif

            // Subtle rank-colored tint at top
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(
                    LinearGradient(
                        colors: [
                            rankColor.opacity(0.05),
                            Color.clear,
                        ],
                        startPoint: .top,
                        endPoint: .center,
                    ),
                )
        }
    }

    private var rankGradient: LinearGradient {
        LinearGradient(
            colors: rank == 1
                ? [Color.DesignSystem.medalGold, Color.DesignSystem.accentOrange]
                : rank == 2
                    ? [Color.DesignSystem.medalSilver, Color.DesignSystem.textTertiary]
                    : rank == 3
                        ? [Color.DesignSystem.medalBronze, Color.brown]
                        : [Color.DesignSystem.brandGreen, Color.DesignSystem.brandBlue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        )
    }

    private var rankColor: Color {
        switch rank {
        case 1: Color.DesignSystem.medalGold
        case 2: Color.DesignSystem.medalSilver
        case 3: Color.DesignSystem.medalBronze
        default: Color.DesignSystem.brandGreen
        }
    }
}

// MARK: - Trending Card Button Style

private struct TrendingCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? 0.02 : 0)
            .animation(Animation.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Empty Trending State

struct EmptyTrendingView: View {
    @Environment(\.translationService) private var t

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 20))
                .foregroundStyle(Color.DesignSystem.textTertiary)

            VStack(alignment: .leading, spacing: 2) {
                Text(t.t("forum.no_trending_posts"))
                    .font(.DesignSystem.bodySmall)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                Text(t.t("forum.check_back_later"))
                    .font(.DesignSystem.captionSmall)
                    .foregroundStyle(Color.DesignSystem.textTertiary)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.DesignSystem.glassBackground.opacity(0.5)),
        )
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        VStack(spacing: Spacing.lg) {
            TrendingPostsSection(
                posts: [
                    ForumPost.fixture(id: 1, title: "Best tips for reducing food waste at home"),
                    ForumPost.fixture(id: 2, title: "Community garden initiative - join us!"),
                    ForumPost.fixture(id: 3, title: "Recipe ideas for leftover vegetables"),
                    ForumPost.fixture(id: 4, title: "How to properly store different foods"),
                    ForumPost.fixture(id: 5, title: "Weekly neighborhood food swap meetup"),
                ],
                onPostTap: { _ in },
                onSeeAllTap: {},
            )

            EmptyTrendingView()
        }
        .padding()
        .background(Color.DesignSystem.background)
    }
#endif

#endif
