//
//  SavedPostsView.swift
//  Foodshare
//
//  Displays user's bookmarked forum posts with glass styling
//  Part of Forum UI improvements
//

import SwiftUI
import FoodShareDesignSystem

#if DEBUG
    import Inject
#endif

// MARK: - Saved Posts View

struct SavedPostsView: View {
    
    @Environment(\.translationService) private var t
    let repository: ForumRepository
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var savedPosts: [ForumPost] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMorePosts = true
    @State private var currentOffset = 0
    @State private var selectedPost: ForumPost?
    @State private var hasAppeared = false
    @State private var showRemoveConfirmation: ForumPost?

    private var pageSize: Int { AppConfiguration.shared.pageSize }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()

                content
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
            }
            .navigationTitle(t.t("forum.saved_posts"))
            .navigationBarTitleDisplayMode(.large)
            .glassNavigationBar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t.t("common.close")) {
                        dismiss()
                    }
                }

                if !savedPosts.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                // Clear all saved posts
                            } label: {
                                Label(t.t("forum.remove_all"), systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(Color.DesignSystem.textSecondary)
                        }
                    }
                }
            }
            .sheet(item: $selectedPost) { post in
                ForumPostDetailView(post: post, repository: repository)
                    .glassSheet()
            }
            .confirmationDialog(
                t.t("forum.remove_from_saved"),
                isPresented: .init(
                    get: { showRemoveConfirmation != nil },
                    set: { if !$0 { showRemoveConfirmation = nil } },
                ),
                titleVisibility: .visible,
            ) {
                Button(t.t("common.remove"), role: .destructive) {
                    if let post = showRemoveConfirmation {
                        Task { await removeBookmark(post) }
                    }
                }
                Button(t.t("common.cancel"), role: .cancel) {}
            } message: {
                Text(t.t("forum.remove_confirmation_message"))
            }
        }
        .task {
            await loadSavedPosts()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading, savedPosts.isEmpty {
            loadingView
        } else if savedPosts.isEmpty {
            emptyStateView
        } else {
            savedPostsList
        }
    }

    private var savedPostsList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                // Stats header
                savedStatsHeader
                    .staggeredAppearance(index: 0, baseDelay: 0.1)

                // Saved posts
                ForEach(Array(savedPosts.enumerated()), id: \.element.id) { index, post in
                    SavedPostCard(
                        post: post,
                        onTap: {
                            HapticManager.light()
                            selectedPost = post
                        },
                        onRemove: {
                            showRemoveConfirmation = post
                        },
                    )
                    .staggeredAppearance(index: index + 1, baseDelay: 0.1, staggerDelay: 0.04)
                    .onAppear {
                        if post.id == savedPosts.last?.id, hasMorePosts {
                            Task { await loadMorePosts() }
                        }
                    }
                }

                if isLoadingMore {
                    GlassLoadingIndicator(message: "Loading more...")
                        .padding(.vertical, Spacing.lg)
                }
            }
            .padding(Spacing.md)
        }
        .refreshable {
            currentOffset = 0
            hasMorePosts = true
            await loadSavedPosts()
        }
    }

    private var savedStatsHeader: some View {
        HStack(spacing: Spacing.md) {
            // Total saved count
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("\(savedPosts.count)")
                    .font(.DesignSystem.headlineLarge)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.DesignSystem.text)
                    .contentTransition(.numericText())

                Text(t.t("forum.saved_posts"))
                    .font(.DesignSystem.captionSmall)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            Spacer()

            // Bookmark icon
            Image(systemName: "bookmark.fill")
                .font(.system(size: 24))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.DesignSystem.accentOrange, Color.DesignSystem.brandPink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            ForEach(0 ..< 4, id: \.self) { index in
                GlassSkeletonCard()
                    .staggeredAppearance(index: index, baseDelay: 0.1)
            }
        }
        .padding(Spacing.md)
    }

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.DesignSystem.glassBorder,
                                        Color.DesignSystem.accentOrange.opacity(0.3),
                                        Color.DesignSystem.glassBorder
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                                lineWidth: 1,
                            ),
                    )
                    .glassBreathing(intensity: 0.5)

                Image(systemName: "bookmark")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.DesignSystem.accentOrange, Color.DesignSystem.brandPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
            }
            .padding(.bottom, Spacing.sm)

            VStack(spacing: Spacing.sm) {
                Text(t.t("forum.no_saved_posts"))
                    .font(.DesignSystem.headlineMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.DesignSystem.text)

                Text(t.t("forum.saved_posts_empty_desc"))
                    .font(.DesignSystem.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.xl)
        .animatedAppearance()
    }

    private var backgroundGradient: some View {
        ZStack {
            Color.DesignSystem.background

            LinearGradient(
                colors: [
                    Color.DesignSystem.accentOrange.opacity(0.03),
                    Color.clear,
                    Color.DesignSystem.brandPink.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        }
    }

    // MARK: - Actions

    private func loadSavedPosts() async {
        guard let userId = appState.currentUser?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            savedPosts = try await repository.fetchBookmarkedPosts(
                profileId: userId,
                limit: pageSize,
                offset: 0,
            )
            currentOffset = 0
            hasMorePosts = savedPosts.count >= pageSize
        } catch {
            // Handle error
        }
    }

    private func loadMorePosts() async {
        guard let userId = appState.currentUser?.id,
              !isLoadingMore,
              hasMorePosts else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let newOffset = currentOffset + pageSize
            let newPosts = try await repository.fetchBookmarkedPosts(
                profileId: userId,
                limit: pageSize,
                offset: newOffset,
            )

            savedPosts.append(contentsOf: newPosts)
            currentOffset = newOffset
            hasMorePosts = newPosts.count >= pageSize
        } catch {
            // Silently fail for pagination
        }
    }

    private func removeBookmark(_ post: ForumPost) async {
        guard let userId = appState.currentUser?.id else { return }

        // Optimistic removal
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            savedPosts.removeAll { $0.id == post.id }
        }
        HapticManager.success()

        do {
            _ = try await repository.toggleBookmark(forumId: post.id, profileId: userId)
        } catch {
            // Revert on failure
            withAnimation {
                savedPosts.append(post)
            }
            HapticManager.error()
        }
    }
}

// MARK: - Saved Post Card

private struct SavedPostCard: View {
    let post: ForumPost
    let onTap: () -> Void
    let onRemove: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                // Post image (if available)
                if let imageUrl = post.imageUrl {
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            Rectangle()
                                .fill(Color.DesignSystem.glassBackground)
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                } else {
                    // Placeholder with category color
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(
                            LinearGradient(
                                colors: [
                                    (post.category?.displayColor ?? Color.DesignSystem.brandGreen).opacity(0.3),
                                    (post.category?.displayColor ?? Color.DesignSystem.brandBlue).opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .frame(width: 80, height: 80)
                        .overlay {
                            Image(systemName: post.category?.systemIconName ?? "doc.text")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.DesignSystem.textSecondary)
                        }
                }

                // Content
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    // Category
                    if let category = post.category {
                        Text(category.name)
                            .font(.DesignSystem.captionSmall)
                            .fontWeight(.medium)
                            .foregroundStyle(category.displayColor)
                    }

                    // Title (uses translated version if available)
                    Text(post.displayTitle)
                        .font(.DesignSystem.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.DesignSystem.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Stats
                    HStack(spacing: Spacing.sm) {
                        Label("\(post.likesCount)", systemImage: "heart")
                        Label("\(post.commentsCount)", systemImage: "bubble.right")
                        Text("•")
                        Text(post.forumPostCreatedAt, style: .relative)
                    }
                    .font(.DesignSystem.captionSmall)
                    .foregroundStyle(Color.DesignSystem.textTertiary)
                }

                Spacer()

                // Remove button
                Button {
                    HapticManager.light()
                    onRemove()
                } label: {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.DesignSystem.accentOrange)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.DesignSystem.accentOrange.opacity(0.1)),
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                    ),
            )
            .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
        }
        .buttonStyle(GlassPostCardButtonStyle())
    }
}

// MARK: - Preview

#if DEBUG
    // Preview disabled - MockForumRepository unavailable
    // #Preview {
    //     SavedPostsView(repository: MockForumRepository())
    //         .environment(AppState())
    // }
#endif
