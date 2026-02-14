import FoodShareDesignSystem
import SwiftUI

// MARK: - Forum Post Detail View

struct ForumPostDetailView: View {
    @Environment(\.translationService) private var t
    let post: ForumPost
    let repository: ForumRepository

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var comments: [ForumComment] = []
    @State private var isLoadingComments = false
    @State private var newComment = ""
    @State private var isSubmitting = false
    @State private var replyingToComment: ForumComment?
    @State private var showReplySheet = false
    @State private var quotedText: String?
    @State private var editingComment: ForumComment?
    @State private var showEditSheet = false
    @State private var loadingMoreReplies: Set<Int> = []
    @State private var loadedRepliesOffset: [Int: Int] = [:]
    @State private var errorMessage: String?
    @State private var showErrorToast = false
    @State private var isBookmarked = false
    @State private var showShareSheet = false
    @State private var poll: ForumPoll?
    @State private var isLoadingPoll = false
    @State private var reactionsSummary = ReactionsSummary()
    @State private var isLoadingReactions = false
    @State private var subscription: ForumSubscription?
    @State private var isSubscribed = false
    @State private var isLoadingSubscription = false
    @State private var showSubscriptionSheet = false
    @State private var subscriptionPreferences = SubscriptionPreferences()
    @State private var displayDescription = ""
    @State private var isDescriptionTranslated = false
    @State private var displayTitle = ""
    @State private var isTitleTranslated = false
    @State private var sectionsAppeared = false
    @State private var isLiked = false
    @State private var localLikeCount = 0

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Post content
                        postContent

                        // Poll (if attached)
                        if let poll {
                            pollSection(poll)
                        } else if isLoadingPoll {
                            pollLoadingPlaceholder
                        }

                        // Action buttons
                        actionButtons

                        Divider()
                            .background(Color.DesignSystem.glassBorder)

                        // Comments section
                        commentsSection
                    }
                    .padding()
                }

                // Comment input
                VStack {
                    Spacer()
                    commentInput
                }
            }
            .navigationTitle(t.t("forum.discussion"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t.t("common.close")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: Spacing.sm) {
                        // Subscription toggle
                        GlassSubscriptionToggle(
                            isSubscribed: $isSubscribed,
                            notificationCount: 0,
                            isLoading: isLoadingSubscription,
                        ) {
                            Task { await toggleSubscription() }
                        }

                        Menu {
                            Button {
                                showSubscriptionSheet = true
                            } label: {
                                Label(t.t("forum.notification_settings"), systemImage: "bell.badge")
                            }

                            Button {
                                showShareSheet = true
                            } label: {
                                Label(t.t("common.share"), systemImage: "square.and.arrow.up")
                            }

                            Button {
                                // Report action
                            } label: {
                                Label(t.t("common.report"), systemImage: "flag")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .task {
            // Use model's translated version if available, otherwise original
            displayTitle = post.displayTitle
            displayDescription = post.displayDescription.htmlStripped
            isTitleTranslated = post.isTranslated
            isDescriptionTranslated = post.isTranslated

            // Record view for this forum post
            await recordView()

            await loadPoll()
            await loadComments()
            await loadReactions()
            await loadSubscription()

            // Trigger staggered section entrance animations
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15)) {
                sectionsAppeared = true
            }
        }
        .sheet(isPresented: $showSubscriptionSheet) {
            subscriptionSettingsSheet
        }
        .sheet(isPresented: $showReplySheet) {
            replySheet
        }
        .sheet(isPresented: $showEditSheet) {
            editSheet
        }
        .overlay(alignment: .top) {
            if showErrorToast {
                GlassToast(
                    notification: ToastNotification(
                        message: errorMessage ?? t.t("common.something_went_wrong"),
                        style: .error,
                    ),
                    onDismiss: { showErrorToast = false },
                )
                .padding(.top, Spacing.xl)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity,
                ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showErrorToast)
    }

    // MARK: - Post Content

    private var postContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Author info
            HStack(spacing: Spacing.sm) {
                AsyncImage(url: post.author?.avatarURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(Color.DesignSystem.glassBackground)
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.xs) {
                        Text(post.author?.displayName ?? t.t("common.anonymous"))
                            .font(.headline)

                        if post.author?.isVerified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(Color.DesignSystem.brandGreen)
                        }
                    }

                    HStack(spacing: Spacing.sm) {
                        Text(post.forumPostCreatedAt, style: .date)
                        Text("•")
                        Text(post.forumPostCreatedAt, style: .time)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Post type badge
                Label(post.postType.displayName, systemImage: post.postType.iconName)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.DesignSystem.glassBackground)
                    .clipShape(Capsule())
            }

            // Category
            if let category = post.category {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: category.systemIconName)
                    Text(category.name)
                }
                .font(.subheadline)
                .foregroundStyle(category.displayColor)
            }

            // Title
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(displayTitle.isEmpty ? post.title : displayTitle)
                    .font(.title2)
                    .fontWeight(.bold)

                if isTitleTranslated {
                    TranslatedIndicator()
                }
            }
            .autoTranslate(
                original: post.title,
                contentType: "forum_post",
                translated: $displayTitle,
                isTranslated: $isTitleTranslated,
            )

            // Description (HTML stripped for clean display)
            if !post.displayDescription.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(displayDescription)
                        .font(.DesignSystem.bodyMedium)
                        .foregroundStyle(Color.DesignSystem.textSecondary)

                    if isDescriptionTranslated {
                        TranslatedIndicator()
                    }
                }
                .autoTranslate(
                    original: post.description.htmlStripped,
                    contentType: "forum_post",
                    translated: $displayDescription,
                    isTranslated: $isDescriptionTranslated,
                )
            }

            // Image
            if let imageUrl = post.imageUrl {
                AsyncImage(url: imageUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.DesignSystem.glassBackground)
                        .aspectRatio(16 / 9, contentMode: .fit)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Stats
            HStack(spacing: Spacing.sm) {
                GlassStatPill.views(post.viewsCount)
                GlassStatPill.likes(post.likesCount, isLiked: isLiked)
                GlassStatPill.comments(post.commentsCount)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(.ultraThinMaterial),
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
        )
        .opacity(sectionsAppeared ? 1 : 0)
        .offset(y: sectionsAppeared ? 0 : 20)
    }

    // MARK: - Poll Section

    private func pollSection(_ poll: ForumPoll) -> some View {
        GlassPollCard(
            poll: poll,
            onVote: { optionIds in
                await votePoll(optionIds: optionIds)
            },
            onRemoveVote: { optionId in
                await removePollVote(optionId: optionId)
            },
        )
    }

    private var pollLoadingPlaceholder: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.DesignSystem.glassBackground)
                    .frame(width: 60, height: 16)
                Spacer()
            }

            ForEach(0 ..< 3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: Spacing.radiusMD)
                    .fill(Color.DesignSystem.glassBackground)
                    .frame(height: 48)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Spacing.radiusLG)
                .fill(.ultraThinMaterial),
        )
        .redacted(reason: .placeholder)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Emoji reactions bar
            GlassReactionBar(
                summary: reactionsSummary,
                onReactionTap: { reactionType in
                    await toggleReaction(reactionType)
                },
            )

            // Secondary actions row
            HStack(spacing: Spacing.sm) {
                // Bookmark button
                Button {
                    Task { await toggleBookmark() }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        Text(t.t("common.save"))
                    }
                }
                .buttonStyle(LiquidGlassActionButtonStyle(
                    isActive: isBookmarked,
                    activeColor: .DesignSystem.accentOrange,
                ))

                // Share button
                Button {
                    showShareSheet = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "square.and.arrow.up")
                        Text(t.t("common.share"))
                    }
                }
                .buttonStyle(LiquidGlassActionButtonStyle(isActive: false, activeColor: .DesignSystem.brandGreen))

                Spacer()
            }
        }
    }

    private func toggleBookmark() async {
        guard let userId = appState.currentUser?.id else { return }

        // Optimistic update
        let wasBookmarked = isBookmarked
        isBookmarked.toggle()
        HapticManager.light()

        do {
            let newBookmarkState = try await repository.toggleBookmark(forumId: post.id, profileId: userId)
            isBookmarked = newBookmarkState
            if newBookmarkState {
                HapticManager.success()
            }
        } catch {
            // Revert on failure
            isBookmarked = wasBookmarked
            HapticManager.error()
        }
    }

    // MARK: - Comments Section

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            GlassSectionHeader.comments(
                t.t("forum.comments_section", args: ["count": String(comments.count)]),
            )

            if isLoadingComments {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if comments.isEmpty {
                Text(t.t("forum.no_comments"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(comments) { comment in
                    CommentRow(
                        comment: comment,
                        repository: repository,
                        userId: appState.currentUser?.id,
                        onReply: {
                            replyingToComment = comment
                            quotedText = nil
                            showReplySheet = true
                            HapticManager.light()
                        },
                        onQuote: {
                            replyingToComment = comment
                            quotedText = comment.content
                            showReplySheet = true
                            HapticManager.light()
                        },
                        onEdit: comment.userId == appState.currentUser?.id
                            ? {
                                editingComment = comment
                                showEditSheet = true
                                HapticManager.light()
                            }
                            : nil,
                    )

                    // Show nested replies if any
                    if let replies = comment.replies, !replies.isEmpty {
                        ForEach(replies) { reply in
                            CommentRow(
                                comment: reply,
                                repository: repository,
                                userId: appState.currentUser?.id,
                                onReply: reply.canReply
                                    ? {
                                        replyingToComment = reply
                                        quotedText = nil
                                        showReplySheet = true
                                        HapticManager.light()
                                    }
                                    : nil,
                                onQuote: {
                                    replyingToComment = reply
                                    quotedText = reply.content
                                    showReplySheet = true
                                    HapticManager.light()
                                },
                                onEdit: reply.userId == appState.currentUser?.id
                                    ? {
                                        editingComment = reply
                                        showEditSheet = true
                                        HapticManager.light()
                                    }
                                    : nil,
                            )
                        }
                    }

                    // Load more replies button
                    if comment.repliesCount > (comment.replies?.count ?? 0) {
                        LoadMoreRepliesButton(
                            remainingCount: comment.repliesCount - (comment.replies?.count ?? 0),
                            isLoading: loadingMoreReplies.contains(comment.id),
                        ) {
                            Task { await loadMoreReplies(for: comment) }
                        }
                        .padding(.leading, Spacing.lg)
                    }
                }
            }
        }
        .padding(.bottom, 80) // Space for input
        .opacity(sectionsAppeared ? 1 : 0)
        .offset(y: sectionsAppeared ? 0 : 20)
    }

    // MARK: - Comment Input

    private var commentInput: some View {
        HStack(spacing: Spacing.sm) {
            TextField(t.t("forum.add_comment_placeholder"), text: $newComment, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(Color.DesignSystem.glassBackground),
                )
                .lineLimit(1 ... 4)

            Button {
                Task { await submitComment() }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(Spacing.sm)
                    .background(
                        Circle()
                            .fill(newComment.isEmpty ? Color.DesignSystem.textTertiary : Color.DesignSystem.brandGreen),
                    )
            }
            .disabled(newComment.isEmpty || isSubmitting)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        Color.DesignSystem.background
    }

    // MARK: - Actions

    private func loadComments() async {
        isLoadingComments = true
        defer { isLoadingComments = false }

        do {
            comments = try await repository.fetchComments(forumId: post.id, limit: 50, offset: 0)
        } catch {
            // Handle error
        }
    }

    private func loadMoreReplies(for comment: ForumComment) async {
        guard !loadingMoreReplies.contains(comment.id) else { return }

        loadingMoreReplies.insert(comment.id)
        defer { loadingMoreReplies.remove(comment.id) }

        let currentOffset = loadedRepliesOffset[comment.id] ?? (comment.replies?.count ?? 0)

        do {
            let newReplies = try await repository.fetchReplies(
                commentId: comment.id,
                limit: 10,
                offset: currentOffset,
            )

            // Update the comment with new replies
            if let index = comments.firstIndex(where: { $0.id == comment.id }) {
                var existingReplies = comments[index].replies ?? []
                existingReplies.append(contentsOf: newReplies)

                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    comments[index] = ForumComment(
                        id: comment.id,
                        userId: comment.userId,
                        forumId: comment.forumId,
                        parentId: comment.parentId,
                        comment: comment.comment,
                        depth: comment.depth,
                        isEdited: comment.isEdited,
                        updatedAt: comment.updatedAt,
                        likesCount: comment.likesCount,
                        repliesCount: comment.repliesCount,
                        reportsCount: comment.reportsCount,
                        isBestAnswer: comment.isBestAnswer,
                        isPinned: comment.isPinned,
                        commentCreatedAt: comment.commentCreatedAt,
                        author: comment.author,
                        replies: existingReplies,
                    )
                }
                loadedRepliesOffset[comment.id] = currentOffset + newReplies.count
            }
        } catch {
            HapticManager.error()
        }
    }

    private func updateComment(_ newContent: String) async {
        guard let comment = editingComment else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let updatedComment = try await repository.updateComment(id: comment.id, content: newContent)

            // Update in comments array
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if let index = comments.firstIndex(where: { $0.id == comment.id }) {
                    comments[index] = updatedComment
                } else {
                    // Check in replies
                    for (parentIndex, parentComment) in comments.enumerated() {
                        if let replyIndex = parentComment.replies?.firstIndex(where: { $0.id == comment.id }) {
                            var updatedReplies = parentComment.replies ?? []
                            updatedReplies[replyIndex] = updatedComment
                            comments[parentIndex] = ForumComment(
                                id: parentComment.id,
                                userId: parentComment.userId,
                                forumId: parentComment.forumId,
                                parentId: parentComment.parentId,
                                comment: parentComment.comment,
                                depth: parentComment.depth,
                                isEdited: parentComment.isEdited,
                                updatedAt: parentComment.updatedAt,
                                likesCount: parentComment.likesCount,
                                repliesCount: parentComment.repliesCount,
                                reportsCount: parentComment.reportsCount,
                                isBestAnswer: parentComment.isBestAnswer,
                                isPinned: parentComment.isPinned,
                                commentCreatedAt: parentComment.commentCreatedAt,
                                author: parentComment.author,
                                replies: updatedReplies,
                            )
                            break
                        }
                    }
                }
            }

            editingComment = nil
            showEditSheet = false
            HapticManager.success()
        } catch {
            HapticManager.error()
            errorMessage = t.t("forum.error.update_comment_failed")
            showErrorToast = true
        }
    }

    private func submitComment() async {
        guard !newComment.isEmpty else { return }
        guard let userId = appState.currentUser?.id else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let request = CreateCommentRequest(
                userId: userId,
                forumId: post.id,
                comment: newComment,
            )
            let comment = try await repository.createComment(request)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                comments.append(comment)
            }
            newComment = ""
            HapticManager.success()
        } catch {
            HapticManager.error()
            errorMessage = t.t("forum.error.post_comment_failed")
            showErrorToast = true

            // Auto-dismiss after 3 seconds
            Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run {
                    showErrorToast = false
                }
            }
        }
    }

    // MARK: - Submit Reply

    private func submitReply(_ replyText: String) async {
        guard !replyText.isEmpty else { return }
        guard let userId = appState.currentUser?.id,
              let parentComment = replyingToComment else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let request = CreateCommentRequest(
                userId: userId,
                forumId: post.id,
                parentId: parentComment.id,
                comment: replyText,
            )
            let reply = try await repository.createComment(request)

            // Add reply to the parent comment's replies
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if let index = comments.firstIndex(where: { $0.id == parentComment.id }) {
                    var updatedComment = comments[index]
                    var replies = updatedComment.replies ?? []
                    replies.append(reply)
                    // Update the comment with new replies (need to recreate since it's a struct)
                    comments[index] = ForumComment(
                        id: updatedComment.id,
                        userId: updatedComment.userId,
                        forumId: updatedComment.forumId,
                        parentId: updatedComment.parentId,
                        comment: updatedComment.comment,
                        depth: updatedComment.depth,
                        isEdited: updatedComment.isEdited,
                        updatedAt: updatedComment.updatedAt,
                        likesCount: updatedComment.likesCount,
                        repliesCount: updatedComment.repliesCount + 1,
                        reportsCount: updatedComment.reportsCount,
                        isBestAnswer: updatedComment.isBestAnswer,
                        isPinned: updatedComment.isPinned,
                        commentCreatedAt: updatedComment.commentCreatedAt,
                        author: updatedComment.author,
                        replies: replies,
                    )
                } else if let parentIndex = comments
                    .firstIndex(where: { $0.replies?.contains(where: { $0.id == parentComment.id }) ?? false })
                {
                    // Reply to a nested comment - add to that parent's replies
                    var parentReplies = comments[parentIndex].replies ?? []
                    parentReplies.append(reply)
                    let parent = comments[parentIndex]
                    comments[parentIndex] = ForumComment(
                        id: parent.id,
                        userId: parent.userId,
                        forumId: parent.forumId,
                        parentId: parent.parentId,
                        comment: parent.comment,
                        depth: parent.depth,
                        isEdited: parent.isEdited,
                        updatedAt: parent.updatedAt,
                        likesCount: parent.likesCount,
                        repliesCount: parent.repliesCount + 1,
                        reportsCount: parent.reportsCount,
                        isBestAnswer: parent.isBestAnswer,
                        isPinned: parent.isPinned,
                        commentCreatedAt: parent.commentCreatedAt,
                        author: parent.author,
                        replies: parentReplies,
                    )
                }
            }

            replyingToComment = nil
            showReplySheet = false
            HapticManager.success()
        } catch {
            HapticManager.error()
            errorMessage = t.t("forum.error.post_reply_failed")
            showErrorToast = true

            Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run {
                    showErrorToast = false
                }
            }
        }
    }

    // MARK: - Reply Sheet

    private var replySheet: some View {
        ReplyCommentSheet(
            parentComment: replyingToComment,
            quotedText: quotedText,
            isSubmitting: isSubmitting,
            onSubmit: { replyText in
                Task { await submitReply(replyText) }
            },
            onCancel: {
                replyingToComment = nil
                quotedText = nil
                showReplySheet = false
            },
        )
    }

    private var editSheet: some View {
        EditCommentSheet(
            comment: editingComment,
            isSubmitting: isSubmitting,
            onSubmit: { newContent in
                Task { await updateComment(newContent) }
            },
            onCancel: {
                editingComment = nil
                showEditSheet = false
            },
        )
    }

    // MARK: - Reaction Actions

    private func loadReactions() async {
        guard let userId = appState.currentUser?.id else { return }

        isLoadingReactions = true
        defer { isLoadingReactions = false }

        do {
            reactionsSummary = try await repository.fetchPostReactions(forumId: post.id, profileId: userId)
        } catch {
            // Silently fail - reactions are not critical
        }
    }

    private func toggleReaction(_ reactionType: ReactionType) async {
        guard let userId = appState.currentUser?.id else { return }

        // Optimistic update
        let wasReacted = reactionsSummary.userReactionTypeIds.contains(reactionType.id)
        let oldSummary = reactionsSummary

        // Create optimistic update
        var newReactions = reactionsSummary.reactions.map { rc -> ReactionCount in
            if rc.reactionType.id == reactionType.id {
                return ReactionCount(
                    reactionType: rc.reactionType,
                    count: wasReacted ? max(0, rc.count - 1) : rc.count + 1,
                    hasUserReacted: !wasReacted,
                )
            }
            return rc
        }

        // Add reaction type if not present
        if !newReactions.contains(where: { $0.reactionType.id == reactionType.id }) {
            newReactions.append(ReactionCount(
                reactionType: reactionType,
                count: 1,
                hasUserReacted: true,
            ))
        }

        var newUserReactionIds = reactionsSummary.userReactionTypeIds
        if wasReacted {
            newUserReactionIds.removeAll { $0 == reactionType.id }
        } else {
            newUserReactionIds.append(reactionType.id)
        }

        let newTotalCount = wasReacted ? reactionsSummary.totalCount - 1 : reactionsSummary.totalCount + 1

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            reactionsSummary = ReactionsSummary(
                totalCount: newTotalCount,
                reactions: newReactions,
                userReactionTypeIds: newUserReactionIds,
            )
        }

        do {
            let updatedSummary = try await repository.togglePostReaction(
                forumId: post.id,
                reactionTypeId: reactionType.id,
                profileId: userId,
            )
            withAnimation {
                reactionsSummary = updatedSummary
            }
        } catch {
            // Revert on failure
            withAnimation {
                reactionsSummary = oldSummary
            }
            HapticManager.error()
        }
    }

    // MARK: - Poll Actions

    private func loadPoll() async {
        isLoadingPoll = true
        defer { isLoadingPoll = false }

        do {
            if let fetchedPoll = try await repository.fetchPoll(forumId: post.id),
               let userId = appState.currentUser?.id
            {
                // Fetch with user votes
                poll = try await repository.fetchPollWithOptions(pollId: fetchedPoll.id, profileId: userId)
            }
        } catch {
            // Silently fail - poll is optional
        }
    }

    private func votePoll(optionIds: [UUID]) async {
        guard let currentPoll = poll,
              let userId = appState.currentUser?.id else { return }

        do {
            let updatedPoll = try await repository.votePoll(
                pollId: currentPoll.id,
                optionIds: optionIds,
                profileId: userId,
            )
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                poll = updatedPoll
            }
        } catch {
            HapticManager.error()
        }
    }

    private func removePollVote(optionId: UUID) async {
        guard let currentPoll = poll,
              let userId = appState.currentUser?.id else { return }

        do {
            try await repository.removeVote(
                pollId: currentPoll.id,
                optionId: optionId,
                profileId: userId,
            )
            // Refresh poll after vote removal
            poll = try await repository.fetchPollWithOptions(pollId: currentPoll.id, profileId: userId)
        } catch {
            HapticManager.error()
        }
    }

    // MARK: - Subscription Actions

    private func loadSubscription() async {
        guard let userId = appState.currentUser?.id else { return }

        do {
            subscription = try await repository.fetchPostSubscription(forumId: post.id, profileId: userId)
            isSubscribed = subscription != nil
            if let sub = subscription {
                subscriptionPreferences = SubscriptionPreferences(from: sub)
            }
        } catch {
            // Silently fail - not critical
        }
    }

    private func toggleSubscription() async {
        guard let userId = appState.currentUser?.id else { return }

        isLoadingSubscription = true
        defer { isLoadingSubscription = false }

        if isSubscribed {
            // Unsubscribe
            do {
                try await repository.unsubscribeFromPost(forumId: post.id, profileId: userId)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isSubscribed = false
                    subscription = nil
                }
                HapticManager.success()
            } catch {
                HapticManager.error()
            }
        } else {
            // Subscribe with default preferences
            do {
                let request = CreateSubscriptionRequest.forPost(
                    post.id,
                    profileId: userId,
                    preferences: subscriptionPreferences,
                )
                subscription = try await repository.subscribeToPost(request)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isSubscribed = true
                }
                HapticManager.success()
            } catch {
                HapticManager.error()
            }
        }
    }

    private func saveSubscriptionPreferences() async {
        guard let userId = appState.currentUser?.id else { return }

        if let existingSubscription = subscription {
            // Update existing subscription
            do {
                subscription = try await repository.updateSubscription(
                    id: existingSubscription.id,
                    preferences: subscriptionPreferences,
                )
                HapticManager.success()
            } catch {
                HapticManager.error()
            }
        } else {
            // Create new subscription
            do {
                let request = CreateSubscriptionRequest.forPost(
                    post.id,
                    profileId: userId,
                    preferences: subscriptionPreferences,
                )
                subscription = try await repository.subscribeToPost(request)
                withAnimation {
                    isSubscribed = true
                }
                HapticManager.success()
            } catch {
                HapticManager.error()
            }
        }
    }

    private func unsubscribe() async {
        guard let userId = appState.currentUser?.id else { return }

        do {
            try await repository.unsubscribeFromPost(forumId: post.id, profileId: userId)
            withAnimation {
                isSubscribed = false
                subscription = nil
            }
            HapticManager.success()
        } catch {
            HapticManager.error()
        }
    }

    // MARK: - View Tracking

    private func recordView() async {
        // Record view using ForumViewService
        await ForumViewService.shared.recordView(forumId: post.id)
    }

    // MARK: - Subscription Settings Sheet

    private var subscriptionSettingsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Post info header
                    VStack(spacing: Spacing.sm) {
                        Text(post.displayTitle)
                            .font(.DesignSystem.headlineSmall)
                            .foregroundStyle(Color.DesignSystem.text)
                            .multilineTextAlignment(.center)

                        Text(t.t("forum.notification_prompt"))
                            .font(.DesignSystem.bodySmall)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                    .padding(.top, Spacing.md)

                    // Subscription settings card
                    GlassSubscriptionCard(
                        subscription: subscription,
                        preferences: $subscriptionPreferences,
                        onSave: {
                            Task { await saveSubscriptionPreferences() }
                            showSubscriptionSheet = false
                        },
                        onUnsubscribe: {
                            Task { await unsubscribe() }
                            showSubscriptionSheet = false
                        },
                    )
                    .padding(.horizontal, Spacing.md)
                }
            }
            .background(Color.DesignSystem.background)
            .navigationTitle(t.t("common.notifications"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t.t("common.done")) {
                        showSubscriptionSheet = false
                    }
                    .foregroundStyle(Color.DesignSystem.primary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Comment Row

struct CommentRow: View {
    @Environment(\.translationService) private var t
    let comment: ForumComment
    let repository: ForumRepository?
    let userId: UUID?
    let onReply: (() -> Void)?
    let onQuote: (() -> Void)?
    let onEdit: (() -> Void)?

    @State private var reactionsSummary = ReactionsSummary()
    @State private var isLiked = false
    @State private var localLikeCount = 0

    // Translation state
    @State private var displayContent = ""
    @State private var isContentTranslated = false

    init(
        comment: ForumComment,
        repository: ForumRepository? = nil,
        userId: UUID? = nil,
        onReply: (() -> Void)? = nil,
        onQuote: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
    ) {
        self.comment = comment
        self.repository = repository
        self.userId = userId
        self.onReply = onReply
        self.onQuote = onQuote
        self.onEdit = onEdit
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            AsyncImage(url: comment.author?.avatarURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle().fill(Color.DesignSystem.glassBackground)
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Text(comment.author?.displayName ?? t.t("common.anonymous"))
                        .font(.DesignSystem.bodySmall)
                        .fontWeight(.medium)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(comment.commentCreatedAt, style: .relative)
                        .font(.DesignSystem.captionSmall)
                        .foregroundStyle(.secondary)

                    if comment.isEdited {
                        Text(t.t("forum.edited"))
                            .font(.DesignSystem.captionSmall)
                            .foregroundStyle(Color.DesignSystem.textTertiary)
                    }

                    if comment.isBestAnswer {
                        Label(t.t("forum.best_answer"), systemImage: "checkmark.circle.fill")
                            .font(.DesignSystem.captionSmall)
                            .foregroundStyle(Color.DesignSystem.success)
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(displayContent.isEmpty ? comment.content : displayContent)
                        .font(.DesignSystem.bodySmall)
                        .contextMenu {
                            Button {
                                onQuote?()
                            } label: {
                                Label(t.t("forum.quote"), systemImage: "text.quote")
                            }

                            if onEdit != nil {
                                Button {
                                    onEdit?()
                                } label: {
                                    Label(t.t("common.edit"), systemImage: "pencil")
                                }
                            }

                            Button {
                                UIPasteboard.general.string = comment.content
                                HapticManager.light()
                            } label: {
                                Label(t.t("common.copy"), systemImage: "doc.on.doc")
                            }
                        }

                    if isContentTranslated {
                        TranslatedIndicator()
                    }
                }
                .autoTranslate(
                    original: comment.content,
                    contentType: "forum_comment",
                    translated: $displayContent,
                    isTranslated: $isContentTranslated,
                )

                // Reactions and actions row
                HStack(spacing: Spacing.sm) {
                    // Quick emoji reactions
                    ForEach([ReactionType.like, .love, .helpful], id: \.id) { reactionType in
                        let reactionCount = reactionsSummary.reactions.first { $0.reactionType.id == reactionType.id }
                        let count = reactionCount?.count ?? 0
                        let isSelected = reactionsSummary.userReactionTypeIds.contains(reactionType.id)

                        GlassReactionButton(
                            emoji: reactionType.emoji,
                            count: count,
                            isSelected: isSelected,
                        ) {
                            Task { await toggleReaction(reactionType) }
                        }
                    }

                    Spacer()

                    // Like button with count
                    Button {
                        Task { await toggleLike() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(isLiked
                                    ? Color.DesignSystem.brandPink
                                    : Color.DesignSystem.textSecondary)
                            if localLikeCount > 0 {
                                Text("\(localLikeCount)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .contentTransition(.numericText())
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isLiked ? Color.DesignSystem.brandPink.opacity(0.12) : Color.clear),
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: isLiked)
                    .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: localLikeCount)

                    if comment.canReply {
                        Button {
                            onReply?()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrowshape.turn.up.left")
                                Text(t.t("common.reply"))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .font(.DesignSystem.captionSmall)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, CGFloat(comment.depth) * Spacing.lg)
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(comment.isBestAnswer
                    ? Color.DesignSystem.success.opacity(0.1)
                    : Color.DesignSystem.glassBackground),
        )
        .task {
            localLikeCount = comment.likesCount
            await loadReactions()
        }
    }

    private func loadReactions() async {
        guard let repository, let userId else { return }

        do {
            reactionsSummary = try await repository.fetchCommentReactions(commentId: comment.id, profileId: userId)
        } catch {
            // Silently fail
        }
    }

    private func toggleReaction(_ reactionType: ReactionType) async {
        guard let repository, let userId else { return }

        let wasReacted = reactionsSummary.userReactionTypeIds.contains(reactionType.id)
        let oldSummary = reactionsSummary

        // Optimistic update
        var newReactions = reactionsSummary.reactions.map { rc -> ReactionCount in
            if rc.reactionType.id == reactionType.id {
                return ReactionCount(
                    reactionType: rc.reactionType,
                    count: wasReacted ? max(0, rc.count - 1) : rc.count + 1,
                    hasUserReacted: !wasReacted,
                )
            }
            return rc
        }

        if !newReactions.contains(where: { $0.reactionType.id == reactionType.id }) {
            newReactions.append(ReactionCount(
                reactionType: reactionType,
                count: 1,
                hasUserReacted: true,
            ))
        }

        var newUserReactionIds = reactionsSummary.userReactionTypeIds
        if wasReacted {
            newUserReactionIds.removeAll { $0 == reactionType.id }
        } else {
            newUserReactionIds.append(reactionType.id)
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            reactionsSummary = ReactionsSummary(
                totalCount: wasReacted ? reactionsSummary.totalCount - 1 : reactionsSummary.totalCount + 1,
                reactions: newReactions,
                userReactionTypeIds: newUserReactionIds,
            )
        }

        do {
            let updatedSummary = try await repository.toggleCommentReaction(
                commentId: comment.id,
                reactionTypeId: reactionType.id,
                profileId: userId,
            )
            withAnimation {
                reactionsSummary = updatedSummary
            }
        } catch {
            withAnimation {
                reactionsSummary = oldSummary
            }
            HapticManager.error()
        }
    }

    private func toggleLike() async {
        guard let repository, let userId else { return }

        // Optimistic update
        let wasLiked = isLiked
        let previousCount = localLikeCount

        isLiked.toggle()
        localLikeCount += isLiked ? 1 : -1

        // Haptic feedback
        if isLiked {
            HapticManager.medium()
        } else {
            HapticManager.light()
        }

        do {
            // Toggle like via repository
            let newLikedState = try await repository.toggleCommentLike(commentId: comment.id, profileId: userId)

            // Update state with server response
            isLiked = newLikedState

            // Fetch updated count
            // Note: The repository doesn't return count, so we keep optimistic count
            // In a real implementation, you'd want to refetch the comment or have the API return the count

        } catch {
            // Revert on error
            isLiked = wasLiked
            localLikeCount = previousCount
            HapticManager.error()
        }
    }
}

// MARK: - Liquid Glass Action Button Style

struct LiquidGlassActionButtonStyle: ButtonStyle {
    let isActive: Bool
    let activeColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.DesignSystem.bodySmall)
            .fontWeight(.medium)
            .foregroundColor(isActive ? activeColor : .DesignSystem.text)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Group {
                    if isActive {
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(activeColor.opacity(0.15))
                    } else {
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(.ultraThinMaterial)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(
                            isActive ? activeColor.opacity(0.3) : Color.DesignSystem.glassBorder,
                            lineWidth: 1,
                        ),
                ),
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Legacy support
struct GlassActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.DesignSystem.bodySmall)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                    ),
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Reply Comment Sheet

struct ReplyCommentSheet: View {
    @Environment(\.translationService) private var t
    let parentComment: ForumComment?
    let quotedText: String?
    let isSubmitting: Bool
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @State private var replyText = ""
    @FocusState private var isTextFieldFocused: Bool

    private var isQuoteReply: Bool {
        quotedText != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.DesignSystem.background
                    .ignoresSafeArea()

                VStack(spacing: Spacing.md) {
                    // Quote preview (if quoting)
                    if let quoted = quotedText {
                        QuotePreviewCard(quotedText: quoted) {
                            // Remove quote - clear the prefilled text
                            replyText = ""
                        }
                    }

                    // Parent comment preview (if not quoting)
                    if !isQuoteReply, let parent = parentComment {
                        parentCommentPreview(parent)
                    }

                    // Reply input
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(isQuoteReply ? t.t("forum.your_response") : t.t("forum.your_reply"))
                            .font(.DesignSystem.labelMedium)
                            .foregroundStyle(Color.DesignSystem.textSecondary)

                        TextEditor(text: $replyText)
                            .font(.DesignSystem.bodyMedium)
                            .foregroundStyle(Color.DesignSystem.text)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                            .padding(Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.medium)
                                    .fill(Color.DesignSystem.glassBackground),
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.medium)
                                    .stroke(
                                        isTextFieldFocused
                                            ? Color.DesignSystem.primary.opacity(0.5)
                                            : Color.DesignSystem.glassBorder,
                                        lineWidth: 1,
                                    ),
                            )
                            .focused($isTextFieldFocused)

                        // Character count
                        HStack {
                            Spacer()
                            Text("\(replyText.count)/500")
                                .font(.DesignSystem.captionSmall)
                                .foregroundStyle(
                                    replyText.count > 500
                                        ? Color.DesignSystem.error
                                        : Color.DesignSystem.textTertiary,
                                )
                        }
                    }

                    Spacer()

                    // Submit button
                    GlassButton(
                        isQuoteReply ? t.t("forum.post_quote_reply") : t.t("forum.post_reply"),
                        icon: "paperplane.fill",
                        style: .primary,
                        isLoading: isSubmitting,
                    ) {
                        // If quoting, prepend the quote block
                        let finalText = if let quoted = quotedText {
                            "> \(quoted.replacingOccurrences(of: "\n", with: "\n> "))\n\n\(replyText)"
                        } else {
                            replyText
                        }
                        onSubmit(finalText)
                    }
                    .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || replyText
                        .count > 500)
                }
                .padding(Spacing.md)
            }
            .navigationTitle(isQuoteReply ? t.t("forum.quote_reply") : t.t("common.reply"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t.t("common.cancel")) {
                        onCancel()
                    }
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            isTextFieldFocused = true
        }
    }

    private func parentCommentPreview(_ comment: ForumComment) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Text(t.t("forum.replying_to"))
                    .font(.DesignSystem.captionSmall)
                    .foregroundStyle(Color.DesignSystem.textTertiary)

                Text("@\(comment.author?.displayName ?? t.t("common.anonymous"))")
                    .font(.DesignSystem.captionSmall)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.DesignSystem.primary)
            }

            HStack(alignment: .top, spacing: Spacing.sm) {
                // Thread indicator
                Rectangle()
                    .fill(Color.DesignSystem.primary.opacity(0.3))
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 2))

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    // Author info
                    HStack(spacing: Spacing.xs) {
                        AsyncImage(url: comment.author?.avatarURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle().fill(Color.DesignSystem.glassBackground)
                        }
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())

                        Text(comment.author?.displayName ?? t.t("common.anonymous"))
                            .font(.DesignSystem.bodySmall)
                            .fontWeight(.medium)

                        Text("•")
                            .foregroundStyle(Color.DesignSystem.textTertiary)

                        Text(comment.commentCreatedAt, style: .relative)
                            .font(.DesignSystem.captionSmall)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    // Comment content (truncated)
                    Text(comment.content)
                        .font(.DesignSystem.bodySmall)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(Color.DesignSystem.glassBackground.opacity(0.5)),
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .stroke(Color.DesignSystem.glassBorder, lineWidth: 0.5),
        )
    }
}

// MARK: - Load More Replies Button

private struct LoadMoreRepliesButton: View {
    @Environment(\.translationService) private var t
    let remainingCount: Int
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 12))
                }

                Text(isLoading
                    ? t.t("common.loading")
                    : t.t("forum.load_more_replies", args: ["count": String(remainingCount)]))
                    .font(.DesignSystem.captionSmall)
                    .fontWeight(.medium)
            }
            .foregroundStyle(Color.DesignSystem.primary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(Color.DesignSystem.primary.opacity(0.1)),
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

// MARK: - Quote Preview Card

private struct QuotePreviewCard: View {
    @Environment(\.translationService) private var t
    let quotedText: String
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            // Quote indicator line
            Rectangle()
                .fill(Color.DesignSystem.primary)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Image(systemName: "text.quote")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.DesignSystem.primary)

                    Text(t.t("forum.quoting"))
                        .font(.DesignSystem.captionSmall)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.DesignSystem.primary)

                    Spacer()

                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.DesignSystem.textTertiary)
                    }
                    .buttonStyle(.plain)
                }

                Text(quotedText)
                    .font(.DesignSystem.bodySmall)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .lineLimit(3)
                    .italic()
            }
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(Color.DesignSystem.primary.opacity(0.05)),
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .stroke(Color.DesignSystem.primary.opacity(0.2), lineWidth: 1),
        )
    }
}

// MARK: - Edit Comment Sheet

struct EditCommentSheet: View {
    @Environment(\.translationService) private var t
    let comment: ForumComment?
    let isSubmitting: Bool
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @State private var editedText = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.DesignSystem.background
                    .ignoresSafeArea()

                VStack(spacing: Spacing.md) {
                    // Original comment info
                    if let comment {
                        HStack(spacing: Spacing.sm) {
                            AsyncImage(url: comment.author?.avatarURL) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle().fill(Color.DesignSystem.glassBackground)
                            }
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(comment.author?.displayName ?? t.t("common.you"))
                                    .font(.DesignSystem.bodySmall)
                                    .fontWeight(.medium)

                                HStack(spacing: Spacing.xxs) {
                                    Text(t.t("forum.posted"))
                                    Text(comment.commentCreatedAt, style: .relative)
                                }
                                .font(.DesignSystem.captionSmall)
                                .foregroundStyle(Color.DesignSystem.textSecondary)
                            }

                            Spacer()
                        }
                        .padding(Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.small)
                                .fill(Color.DesignSystem.glassBackground.opacity(0.5)),
                        )
                    }

                    // Edit input
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(t.t("forum.edit_comment"))
                            .font(.DesignSystem.labelMedium)
                            .foregroundStyle(Color.DesignSystem.textSecondary)

                        TextEditor(text: $editedText)
                            .font(.DesignSystem.bodyMedium)
                            .foregroundStyle(Color.DesignSystem.text)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                            .padding(Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.medium)
                                    .fill(Color.DesignSystem.glassBackground),
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.medium)
                                    .stroke(
                                        isTextFieldFocused
                                            ? Color.DesignSystem.primary.opacity(0.5)
                                            : Color.DesignSystem.glassBorder,
                                        lineWidth: 1,
                                    ),
                            )
                            .focused($isTextFieldFocused)

                        // Character count
                        HStack {
                            Text(t.t("forum.edited_indicator_notice"))
                                .font(.DesignSystem.captionSmall)
                                .foregroundStyle(Color.DesignSystem.textTertiary)

                            Spacer()

                            Text("\(editedText.count)/500")
                                .font(.DesignSystem.captionSmall)
                                .foregroundStyle(
                                    editedText.count > 500
                                        ? Color.DesignSystem.error
                                        : Color.DesignSystem.textTertiary,
                                )
                        }
                    }

                    Spacer()

                    // Submit button
                    GlassButton(
                        t.t("common.save_changes"),
                        icon: "checkmark.circle.fill",
                        style: .primary,
                        isLoading: isSubmitting,
                    ) {
                        onSubmit(editedText)
                    }
                    .disabled(
                        editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            editedText.count > 500 ||
                            editedText == comment?.content,
                    )
                }
                .padding(Spacing.md)
            }
            .navigationTitle(t.t("forum.edit_comment"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t.t("common.cancel")) {
                        onCancel()
                    }
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            editedText = comment?.content ?? ""
            isTextFieldFocused = true
        }
    }
}
