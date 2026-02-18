//
//  ForumSheets.swift
//  FoodShare
//
//  Type-safe sheet presentation for Forum feature.
//  Centralizes all forum-related sheet state.
//


#if !SKIP
import SwiftUI

// MARK: - Forum Sheet Types

/// Type-safe enum for all sheets presentable from ForumView
enum ForumSheet: SheetPresentable {
    case filters(
        filters: Binding<ForumFilters>,
        categories: [ForumCategory],
        onApply: () -> Void,
        onSavedPostsTap: (() -> Void)?,
        onNotificationsTap: (() -> Void)?,
        unreadNotificationCount: Int
    )
    case postDetail(ForumPost, ForumRepository)
    case notifications(ForumRepository, profileId: UUID)
    case createPost(ForumRepository, categories: [ForumCategory], onCreate: (ForumPost) -> Void)
    case savedPosts(ForumRepository)
    case authorPreview(ForumAuthor, ForumRepository, onViewProfile: () -> Void)
    case appInfo

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        switch self {
        case .filters:
            hasher.combine("filters")
        case let .postDetail(post, _):
            hasher.combine("postDetail")
            hasher.combine(post.id)
        case let .notifications(_, profileId):
            hasher.combine("notifications")
            hasher.combine(profileId)
        case .createPost:
            hasher.combine("createPost")
        case .savedPosts:
            hasher.combine("savedPosts")
        case let .authorPreview(author, _, _):
            hasher.combine("authorPreview")
            hasher.combine(author.id)
        case .appInfo:
            hasher.combine("appInfo")
        }
    }

    static func == (lhs: ForumSheet, rhs: ForumSheet) -> Bool {
        switch (lhs, rhs) {
        case (.filters, .filters):
            return true
        case (.postDetail(let lPost, _), .postDetail(let rPost, _)):
            return lPost.id == rPost.id
        case (.notifications(_, let lId), .notifications(_, let rId)):
            return lId == rId
        case (.createPost, .createPost):
            return true
        case (.savedPosts, .savedPosts):
            return true
        case (.authorPreview(let lAuthor, _, _), .authorPreview(let rAuthor, _, _)):
            return lAuthor.id == rAuthor.id
        case (.appInfo, .appInfo):
            return true
        default:
            return false
        }
    }

    // MARK: - Content Builder

    @MainActor @ViewBuilder
    func makeContent() -> some View {
        switch self {
        case let .filters(filters, categories, onApply, onSavedPostsTap, onNotificationsTap, unreadCount):
            ForumFiltersSheet(
                filters: filters,
                categories: categories,
                onApply: onApply,
                onSavedPostsTap: onSavedPostsTap,
                onNotificationsTap: onNotificationsTap,
                unreadNotificationCount: unreadCount
            )
            .glassSheet()

        case let .postDetail(post, repository):
            ForumPostDetailView(post: post, repository: repository)
                .glassSheet()

        case let .notifications(repository, profileId):
            ForumNotificationsView(repository: repository, profileId: profileId)
                .glassSheet()

        case let .createPost(repository, categories, onCreate):
            CreateForumPostView(
                repository: repository,
                categories: categories,
                onPostCreated: onCreate
            )

        case let .savedPosts(repository):
            SavedPostsView(repository: repository)

        case let .authorPreview(author, repository, onViewProfile):
            AuthorPreviewSheet(
                author: author,
                repository: repository,
                onViewProfile: onViewProfile
            )

        case .appInfo:
            AppInfoSheet()
        }
    }
}

// MARK: - Simplified Forum Sheets

/// Simpler sheet enum for common forum actions that don't need complex closures
enum ForumSimpleSheet: SheetPresentable {
    case postDetail(ForumPost, ForumRepository)
    case authorPreview(ForumAuthor, ForumRepository)
    case appInfo

    func hash(into hasher: inout Hasher) {
        switch self {
        case let .postDetail(post, _):
            hasher.combine("postDetail")
            hasher.combine(post.id)
        case let .authorPreview(author, _):
            hasher.combine("authorPreview")
            hasher.combine(author.id)
        case .appInfo:
            hasher.combine("appInfo")
        }
    }

    static func == (lhs: ForumSimpleSheet, rhs: ForumSimpleSheet) -> Bool {
        switch (lhs, rhs) {
        case (.postDetail(let lPost, _), .postDetail(let rPost, _)):
            return lPost.id == rPost.id
        case (.authorPreview(let lAuthor, _), .authorPreview(let rAuthor, _)):
            return lAuthor.id == rAuthor.id
        case (.appInfo, .appInfo):
            return true
        default:
            return false
        }
    }

    @MainActor @ViewBuilder
    func makeContent() -> some View {
        switch self {
        case let .postDetail(post, repository):
            ForumPostDetailView(post: post, repository: repository)
                .glassSheet()
        case let .authorPreview(author, repository):
            AuthorPreviewSheet(author: author, repository: repository, onViewProfile: {})
        case .appInfo:
            AppInfoSheet()
        }
    }
}

#endif
