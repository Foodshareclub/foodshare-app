

#if !SKIP
import Foundation

// MARK: - Forum Post Model

/// Represents a forum post from the `forum` table
struct ForumPost: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let profileId: UUID
    let forumPostName: String?
    let forumPostDescription: String?
    let forumPostImage: String?
    let forumCommentsCounter: Int?
    let forumLikesCounter: Int
    let forumPublished: Bool
    let categoryId: Int?
    let slug: String?
    let viewsCount: Int
    let isPinned: Bool
    let isLocked: Bool
    let isEdited: Bool
    let lastActivityAt: Date?
    let postType: ForumPostType
    let bestAnswerId: Int?
    let hotScore: Double?
    let isFeatured: Bool
    let featuredAt: Date?
    let forumPostCreatedAt: Date
    let forumPostUpdatedAt: Date

    // Joined data (optional)
    var author: ForumAuthor?
    var category: ForumCategory?
    var tags: [ForumTag]?
    var commentsPreview: [ForumComment]?

    // Translation fields (set after fetching from localization service)
    var titleTranslated: String?
    var descriptionTranslated: String?
    var translationLocale: String?

    // MARK: - Memberwise Initializer (required since custom decoder is defined)

    init(
        id: Int,
        profileId: UUID,
        forumPostName: String?,
        forumPostDescription: String?,
        forumPostImage: String?,
        forumCommentsCounter: Int?,
        forumLikesCounter: Int,
        forumPublished: Bool,
        categoryId: Int?,
        slug: String?,
        viewsCount: Int,
        isPinned: Bool,
        isLocked: Bool,
        isEdited: Bool,
        lastActivityAt: Date?,
        postType: ForumPostType,
        bestAnswerId: Int?,
        hotScore: Double?,
        isFeatured: Bool,
        featuredAt: Date?,
        forumPostCreatedAt: Date,
        forumPostUpdatedAt: Date,
        author: ForumAuthor? = nil,
        category: ForumCategory? = nil,
        tags: [ForumTag]? = nil,
        commentsPreview: [ForumComment]? = nil,
        titleTranslated: String? = nil,
        descriptionTranslated: String? = nil,
        translationLocale: String? = nil,
    ) {
        self.id = id
        self.profileId = profileId
        self.forumPostName = forumPostName
        self.forumPostDescription = forumPostDescription
        self.forumPostImage = forumPostImage
        self.forumCommentsCounter = forumCommentsCounter
        self.forumLikesCounter = forumLikesCounter
        self.forumPublished = forumPublished
        self.categoryId = categoryId
        self.slug = slug
        self.viewsCount = viewsCount
        self.isPinned = isPinned
        self.isLocked = isLocked
        self.isEdited = isEdited
        self.lastActivityAt = lastActivityAt
        self.postType = postType
        self.bestAnswerId = bestAnswerId
        self.hotScore = hotScore
        self.isFeatured = isFeatured
        self.featuredAt = featuredAt
        self.forumPostCreatedAt = forumPostCreatedAt
        self.forumPostUpdatedAt = forumPostUpdatedAt
        self.author = author
        self.category = category
        self.tags = tags
        self.commentsPreview = commentsPreview
        self.titleTranslated = titleTranslated
        self.descriptionTranslated = descriptionTranslated
        self.translationLocale = translationLocale
    }

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case forumPostName = "forum_post_name"
        case forumPostDescription = "forum_post_description"
        case forumPostImage = "forum_post_image"
        case forumCommentsCounter = "forum_comments_counter"
        case forumLikesCounter = "forum_likes_counter"
        case forumPublished = "forum_published"
        case categoryId = "category_id"
        case slug
        case viewsCount = "views_count"
        case isPinned = "is_pinned"
        case isLocked = "is_locked"
        case isEdited = "is_edited"
        case lastActivityAt = "last_activity_at"
        case postType = "post_type"
        case bestAnswerId = "best_answer_id"
        case hotScore = "hot_score"
        case isFeatured = "is_featured"
        case featuredAt = "featured_at"
        case forumPostCreatedAt = "forum_post_created_at"
        case forumPostUpdatedAt = "forum_post_updated_at"
        case author
        case category
        case tags
        case commentsPreview = "comments_preview"
    }

    // MARK: - Custom Decoder (handles PostgreSQL numeric as string)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        profileId = try container.decode(UUID.self, forKey: .profileId)
        forumPostName = try container.decodeIfPresent(String.self, forKey: .forumPostName)
        forumPostDescription = try container.decodeIfPresent(String.self, forKey: .forumPostDescription)
        forumPostImage = try container.decodeIfPresent(String.self, forKey: .forumPostImage)

        // Handle forum_comments_counter as either Int or String (PostgreSQL numeric)
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: .forumCommentsCounter) {
            forumCommentsCounter = intValue
        } else if let stringValue = try? container.decodeIfPresent(String.self, forKey: .forumCommentsCounter) {
            forumCommentsCounter = Int(stringValue)
        } else {
            forumCommentsCounter = nil
        }

        // Handle forum_likes_counter as either Int or String
        if let intValue = try? container.decode(Int.self, forKey: .forumLikesCounter) {
            forumLikesCounter = intValue
        } else if let stringValue = try? container.decode(String.self, forKey: .forumLikesCounter) {
            forumLikesCounter = Int(stringValue) ?? 0
        } else {
            forumLikesCounter = 0
        }

        forumPublished = try container.decode(Bool.self, forKey: .forumPublished)
        categoryId = try container.decodeIfPresent(Int.self, forKey: .categoryId)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)

        // Handle views_count as either Int or String (nullable in DB)
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: .viewsCount) {
            viewsCount = intValue ?? 0
        } else if let stringValue = try? container.decodeIfPresent(String.self, forKey: .viewsCount) {
            viewsCount = Int(stringValue) ?? 0
        } else {
            viewsCount = 0
        }

        // Handle nullable boolean fields with defaults
        isPinned = (try? container.decodeIfPresent(Bool.self, forKey: .isPinned)) ?? false
        isLocked = (try? container.decodeIfPresent(Bool.self, forKey: .isLocked)) ?? false
        isEdited = (try? container.decodeIfPresent(Bool.self, forKey: .isEdited)) ?? false
        lastActivityAt = try container.decodeIfPresent(Date.self, forKey: .lastActivityAt)

        // Handle nullable post_type with default
        postType = (try? container.decodeIfPresent(ForumPostType.self, forKey: .postType)) ?? .discussion
        bestAnswerId = try container.decodeIfPresent(Int.self, forKey: .bestAnswerId)

        // Handle hot_score as either Double or String (PostgreSQL numeric)
        if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: .hotScore) {
            hotScore = doubleValue
        } else if let stringValue = try? container.decodeIfPresent(String.self, forKey: .hotScore) {
            hotScore = Double(stringValue)
        } else {
            hotScore = nil
        }

        // Handle nullable is_featured with default
        isFeatured = (try? container.decodeIfPresent(Bool.self, forKey: .isFeatured)) ?? false
        featuredAt = try container.decodeIfPresent(Date.self, forKey: .featuredAt)
        forumPostCreatedAt = try container.decodeIfPresent(Date.self, forKey: .forumPostCreatedAt) ?? Date()
        forumPostUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .forumPostUpdatedAt) ?? Date()

        author = try container.decodeIfPresent(ForumAuthor.self, forKey: .author)
        category = try container.decodeIfPresent(ForumCategory.self, forKey: .category)
        tags = try container.decodeIfPresent([ForumTag].self, forKey: .tags)
        commentsPreview = try container.decodeIfPresent([ForumComment].self, forKey: .commentsPreview)

        // Translation fields (set later from localization service, not from database)
        titleTranslated = nil
        descriptionTranslated = nil
        translationLocale = nil
    }

    // MARK: - Computed Properties

    /// Original title (not translated)
    var title: String {
        forumPostName ?? "Untitled"
    }

    /// Display title - uses translated version if available
    var displayTitle: String {
        titleTranslated ?? forumPostName ?? "Untitled"
    }

    @MainActor
    func localizedTitle(using t: EnhancedTranslationService) -> String {
        titleTranslated ?? forumPostName ?? t.t("common.untitled")
    }

    /// Original description (not translated)
    var description: String {
        forumPostDescription ?? ""
    }

    /// Display description - uses translated version if available
    var displayDescription: String {
        descriptionTranslated ?? forumPostDescription ?? ""
    }

    /// Whether this post has been translated
    var isTranslated: Bool {
        titleTranslated != nil || descriptionTranslated != nil
    }

    var imageUrl: URL? {
        guard let urlString = forumPostImage else { return nil }
        return URL(string: urlString)
    }

    var commentsCount: Int {
        forumCommentsCounter ?? 0
    }

    var likesCount: Int {
        forumLikesCounter
    }

    var isQuestion: Bool {
        postType == .question
    }

    var hasAnswer: Bool {
        bestAnswerId != nil
    }
}

// MARK: - Forum Post Type

enum ForumPostType: String, Codable, CaseIterable, Sendable {
    case discussion
    case question
    case announcement
    case guide

    var displayName: String {
        switch self {
        case .discussion: "Discussion"
        case .question: "Question"
        case .announcement: "Announcement"
        case .guide: "Guide"
        }
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .discussion: t.t("forum.type.discussion")
        case .question: t.t("forum.type.question")
        case .announcement: t.t("forum.type.announcement")
        case .guide: t.t("forum.type.guide")
        }
    }

    var iconName: String {
        switch self {
        case .discussion: "bubble.left.and.bubble.right"
        case .question: "questionmark.circle"
        case .announcement: "megaphone"
        case .guide: "book"
        }
    }
}

// MARK: - Forum Author (Lightweight Profile)

struct ForumAuthor: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let nickname: String
    let avatarUrl: String?
    let isVerified: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case avatarUrl = "avatar_url"
        case isVerified = "is_verified"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified)
    }

    init(id: UUID, nickname: String, avatarUrl: String?, isVerified: Bool?) {
        self.id = id
        self.nickname = nickname
        self.avatarUrl = avatarUrl
        self.isVerified = isVerified
    }

    var displayName: String {
        nickname.isEmpty ? "Anonymous" : nickname
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        nickname.isEmpty ? t.t("common.anonymous") : nickname
    }

    var avatarURL: URL? {
        guard let urlString = avatarUrl else { return nil }
        return URL(string: urlString)
    }
}

// MARK: - Fixtures

#if DEBUG
    extension ForumPost {
        static func fixture(
            id: Int = 1,
            profileId: UUID = UUID(),
            title: String = "Best food sharing tips",
            description: String = "Share your best tips for food sharing in the community.",
            postType: ForumPostType = .discussion,
        ) -> ForumPost {
            ForumPost(
                id: id,
                profileId: profileId,
                forumPostName: title,
                forumPostDescription: description,
                forumPostImage: nil,
                forumCommentsCounter: 5,
                forumLikesCounter: 12,
                forumPublished: true,
                categoryId: 1,
                slug: "best-food-sharing-tips",
                viewsCount: 150,
                isPinned: false,
                isLocked: false,
                isEdited: false,
                lastActivityAt: Date(),
                postType: postType,
                bestAnswerId: nil,
                hotScore: 2.5,
                isFeatured: false,
                featuredAt: nil,
                forumPostCreatedAt: Date(),
                forumPostUpdatedAt: Date(),
                author: ForumAuthor.fixture(),
                category: nil,
                tags: nil,
                commentsPreview: nil,
                titleTranslated: nil,
                descriptionTranslated: nil,
                translationLocale: nil,
            )
        }
    }

    extension ForumAuthor {
        static func fixture(
            id: UUID = UUID(),
            nickname: String = "FoodLover42",
            avatarUrl: String? = nil,
            isVerified: Bool = false,
        ) -> ForumAuthor {
            ForumAuthor(
                id: id,
                nickname: nickname,
                avatarUrl: avatarUrl,
                isVerified: isVerified,
            )
        }
    }
#endif


#endif
