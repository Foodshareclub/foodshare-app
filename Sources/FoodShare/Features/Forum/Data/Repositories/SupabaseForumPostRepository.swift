#if !SKIP
import CoreData
#endif
import FoodShareArchitecture
import FoodShareRepository
import Foundation
import OSLog
import Supabase

// MARK: - Supabase Forum Post Repository

/// Handles forum posts CRUD, search, trending, and pinned posts
@MainActor
final class SupabaseForumPostRepository: BaseSupabaseRepository, @unchecked Sendable {
    private let coreDataStack: CoreDataStack
    private let networkMonitor: NetworkMonitor
    private let apiService: ForumAPIService

    /// Allowed cursor columns for pagination (SQL injection prevention)
    private static let allowedCursorColumns: Set<String> = [
        "created_at", "updated_at", "id", "forum_views", "forum_comments_count",
        "forum_like_counter", "last_activity_at", "timestamp",
    ]

    /// Cache configuration for forum posts
    private let cacheConfiguration = CacheConfiguration(
        maxAge: 3600, // 1 hour - forum posts are less time-sensitive than messages
        maxItems: 200,
        syncOnLaunch: true,
        backgroundSync: true,
    )

    init(
        supabase: Supabase.SupabaseClient,
        coreDataStack: CoreDataStack = .shared,
        networkMonitor: NetworkMonitor = .shared,
        apiService: ForumAPIService = .shared
    ) {
        self.coreDataStack = coreDataStack
        self.networkMonitor = networkMonitor
        self.apiService = apiService
        super.init(supabase: supabase, subsystem: "com.flutterflow.foodshare", category: "ForumPostRepository")
    }

    // MARK: - Cache Policy Selection

    /// Determines the appropriate cache policy based on network state
    private var currentCachePolicy: CachePolicy {
        if networkMonitor.isOffline {
            .cacheOnly
        } else if networkMonitor.isConstrained {
            .cacheFirst
        } else {
            .cacheFallback
        }
    }

    /// Validates cursor column to prevent SQL injection
    private func validateCursorColumn(_ column: String) throws {
        guard Self.allowedCursorColumns.contains(column) else {
            throw AppError.validationError("Invalid cursor column: \(column)")
        }
    }

    // MARK: - Posts

    func fetchPosts(
        categoryId: Int?,
        postType: ForumPostType?,
        sortBy: ForumSortOption,
        pagination: CursorPaginationParams,
    ) async throws -> [ForumPost] {
        var queryParams: [(String, String)] = [
            ("limit", String(pagination.limit)),
            ("sortBy", sortBy.apiValue),
        ]
        
        if let categoryId {
            queryParams.append(("categoryId", String(categoryId)))
        }
        
        if let postType {
            queryParams.append(("postType", postType.rawValue))
        }
        
        if let cursor = pagination.cursor {
            queryParams.append(("cursor", cursor))
            queryParams.append(("direction", pagination.direction == .backward ? "backward" : "forward"))
        }

        let response = try await supabase.functions.invoke(
            "api-v1-forum",
            options: FunctionInvokeOptions(
                method: .get,
                query: queryParams
            )
        )

        return try decoder.decode([ForumPost].self, from: response.data)
    }

    func fetchPosts(
        categoryId: Int?,
        postType: ForumPostType?,
        sortBy: ForumSortOption,
        limit: Int,
        offset: Int,
    ) async throws -> [ForumPost] {
        logger.debug("📋 fetchPosts - limit=\(limit), offset=\(offset)")
        
        let posts = try await apiService.getFeed(
            categoryId: categoryId,
            postType: postType?.rawValue,
            sortBy: sortBy.apiValue,
            limit: limit,
            offset: offset
        )
        
        logger.info("✅ Loaded \(posts.count) forum posts via API")
        return posts
    }

    /// Offline-first fetch for forum posts with cache policy awareness
    func fetchPostsOfflineFirst(
        categoryId: Int?,
        postType: ForumPostType?,
        sortBy: ForumSortOption,
        limit: Int,
        offset: Int,
    ) async throws -> OfflineDataResult<ForumPost> {
        let dataSource = OfflineFirstDataSource<ForumPost, ForumPost>(
            configuration: cacheConfiguration,
            fetchLocal: { [coreDataStack] in
                try await coreDataStack.fetchCachedForumPosts(
                    categoryId: categoryId,
                    postType: postType,
                    limit: limit,
                    offset: offset,
                )
            },
            fetchRemote: { [supabase] in
                var query = supabase
                    .from("forum")
                    .select("""
                        *,
                        author:profiles!forum_profile_id_profiles_fkey(id, nickname, avatar_url, is_verified),
                        category:forum_categories(id, name, slug, color, icon_name, sort_order, is_active, posts_count)
                    """)
                    .eq("forum_published", value: true)

                if let categoryId {
                    query = query.eq("category_id", value: categoryId)
                }

                if let postType {
                    query = query.eq("post_type", value: postType.rawValue)
                }

                return try await query
                    .order(sortBy.orderColumn, ascending: sortBy.ascending)
                    .range(from: offset, to: offset + limit - 1)
                    .execute()
                    .value
            },
            saveToCache: { [coreDataStack] posts in
                try await coreDataStack.cacheForumPosts(posts)
            },
        )

        return try await dataSource.fetch(policy: currentCachePolicy)
    }

    func fetchPost(id: Int) async throws -> ForumPost {
        try await apiService.getPost(id: id)
    }

    func searchPosts(query: String, limit: Int) async throws -> [ForumPost] {
        try await apiService.searchPosts(query: query, limit: limit)
    }

    func fetchTrendingPosts(limit: Int) async throws -> [ForumPost] {
        try await fetchMany(
            from: "forum",
            select: """
                *,
                author:profiles!forum_profile_id_profiles_fkey(id, nickname, avatar_url, is_verified)
            """,
            orderBy: "hot_score",
            ascending: false,
            limit: limit,
        )
    }

    func fetchPinnedPosts(categoryId: Int?) async throws -> [ForumPost] {
        var query = supabase
            .from("forum")
            .select("""
                *,
                author:profiles!forum_profile_id_profiles_fkey(id, nickname, avatar_url, is_verified),
                category:forum_categories(id, name, slug, color, icon_name, sort_order, is_active, posts_count)
            """)
            .eq("forum_published", value: true)
            .eq("is_pinned", value: true)

        if let categoryId {
            query = query.eq("category_id", value: categoryId)
        }

        return try await query
            .order("forum_post_created_at", ascending: false)
            .execute()
            .value
    }

    func createPost(_ request: CreateForumPostRequest) async throws -> ForumPost {
        let post = try await apiService.createPost(
            title: request.title,
            description: request.description,
            categoryId: request.categoryId,
            postType: request.postType.rawValue
        )
        
        // Fetch full post details
        return try await apiService.getPost(id: post.id)
    }

    func updatePost(id: Int, _ request: UpdateForumPostRequest) async throws -> ForumPost {
        try await apiService.updatePost(
            id: id,
            title: request.title,
            description: request.description
        )
    }

    func deletePost(id: Int, profileId: UUID) async throws {
        try await apiService.deletePost(id: id)
    }

    func fetchCategories() async throws -> [ForumCategory] {
        try await apiService.getCategories()
    }

    func fetchPopularTags(limit: Int) async throws -> [ForumTag] {
        try await fetchMany(
            from: "forum_tags",
            orderBy: "usage_count",
            ascending: false,
            limit: limit,
        )
    }
}

// MARK: - Helper Types

/// Result from advanced search_forum RPC with full-text search ranking and author data
private struct ForumSearchResult: Codable {
    let forumId: Int64
    let title: String?
    let description: String?
    let slug: String?
    let categoryId: Int?
    let categoryName: String?
    let authorId: UUID
    let authorNickname: String?
    let authorAvatar: String?
    let likesCount: Int
    let commentsCount: Decimal?
    let viewsCount: Int?
    let createdAt: Date
    let rank: Float

    enum CodingKeys: String, CodingKey {
        case forumId = "forum_id"
        case title
        case description
        case slug
        case categoryId = "category_id"
        case categoryName = "category_name"
        case authorId = "author_id"
        case authorNickname = "author_nickname"
        case authorAvatar = "author_avatar"
        case likesCount = "likes_count"
        case commentsCount = "comments_count"
        case viewsCount = "views_count"
        case createdAt = "created_at"
        case rank
    }

    func toForumPost() -> ForumPost {
        // Build author from search result data
        let author = ForumAuthor(
            id: authorId,
            nickname: authorNickname ?? "Anonymous",
            avatarUrl: authorAvatar,
            isVerified: nil,
        )

        // Build category if name is available
        let category: ForumCategory? = categoryId.flatMap { catId in
            ForumCategory(
                id: catId,
                name: categoryName ?? "Unknown",
                slug: categoryName?.lowercased().replacingOccurrences(of: " ", with: "-") ?? "unknown",
                description: nil,
                iconName: nil,
                color: nil,
                sortOrder: 0,
                isActive: true,
                postsCount: 0,
                createdAt: nil,
                updatedAt: nil,
            )
        }

        return ForumPost(
            id: Int(forumId),
            profileId: authorId,
            forumPostName: title,
            forumPostDescription: description,
            forumPostImage: nil, // Not included in search results
            forumCommentsCounter: commentsCount.map { Int(truncating: $0 as NSNumber) },
            forumLikesCounter: likesCount,
            forumPublished: true,
            categoryId: categoryId,
            slug: slug,
            viewsCount: viewsCount ?? 0,
            isPinned: false,
            isLocked: false,
            isEdited: false,
            lastActivityAt: nil,
            postType: .discussion,
            bestAnswerId: nil,
            hotScore: Double(rank),
            isFeatured: false,
            featuredAt: nil,
            forumPostCreatedAt: createdAt,
            forumPostUpdatedAt: createdAt,
            author: author,
            category: category,
            tags: nil,
            commentsPreview: nil,
        )
    }
}
