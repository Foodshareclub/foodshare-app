import Foundation

// MARK: - Forum Comment Model

/// Represents a comment from the `comments` table
struct ForumComment: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let userId: UUID
    let forumId: Int?
    let parentId: Int?
    let comment: String?
    let depth: Int
    let isEdited: Bool
    let updatedAt: Date?
    let likesCount: Int
    let repliesCount: Int
    let reportsCount: Int
    let isBestAnswer: Bool
    let isPinned: Bool
    let commentCreatedAt: Date

    // Joined data
    var author: ForumAuthor?
    var replies: [ForumComment]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case forumId = "forum_id"
        case parentId = "parent_id"
        case comment
        case depth
        case isEdited = "is_edited"
        case updatedAt = "updated_at"
        case likesCount = "likes_count"
        case repliesCount = "replies_count"
        case reportsCount = "reports_count"
        case isBestAnswer = "is_best_answer"
        case isPinned = "is_pinned"
        case commentCreatedAt = "comment_created_at"
        case author
        case replies
    }

    // MARK: - Custom Decoder (handles nullable database fields)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        forumId = try container.decodeIfPresent(Int.self, forKey: .forumId)
        parentId = try container.decodeIfPresent(Int.self, forKey: .parentId)
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
        depth = try container.decodeIfPresent(Int.self, forKey: .depth) ?? 0
        isEdited = try container.decodeIfPresent(Bool.self, forKey: .isEdited) ?? false
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        likesCount = try container.decodeIfPresent(Int.self, forKey: .likesCount) ?? 0
        repliesCount = try container.decodeIfPresent(Int.self, forKey: .repliesCount) ?? 0
        reportsCount = try container.decodeIfPresent(Int.self, forKey: .reportsCount) ?? 0
        isBestAnswer = try container.decodeIfPresent(Bool.self, forKey: .isBestAnswer) ?? false
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        commentCreatedAt = try container.decodeIfPresent(Date.self, forKey: .commentCreatedAt) ?? Date()
        author = try container.decodeIfPresent(ForumAuthor.self, forKey: .author)
        replies = try container.decodeIfPresent([ForumComment].self, forKey: .replies)
    }

    // MARK: - Memberwise Initializer (for fixtures)

    init(
        id: Int,
        userId: UUID,
        forumId: Int?,
        parentId: Int?,
        comment: String?,
        depth: Int,
        isEdited: Bool,
        updatedAt: Date?,
        likesCount: Int,
        repliesCount: Int,
        reportsCount: Int,
        isBestAnswer: Bool,
        isPinned: Bool,
        commentCreatedAt: Date,
        author: ForumAuthor?,
        replies: [ForumComment]?
    ) {
        self.id = id
        self.userId = userId
        self.forumId = forumId
        self.parentId = parentId
        self.comment = comment
        self.depth = depth
        self.isEdited = isEdited
        self.updatedAt = updatedAt
        self.likesCount = likesCount
        self.repliesCount = repliesCount
        self.reportsCount = reportsCount
        self.isBestAnswer = isBestAnswer
        self.isPinned = isPinned
        self.commentCreatedAt = commentCreatedAt
        self.author = author
        self.replies = replies
    }

    // MARK: - Computed Properties

    var content: String {
        comment ?? ""
    }

    var isTopLevel: Bool {
        parentId == nil
    }

    var hasReplies: Bool {
        repliesCount > 0
    }

    var canReply: Bool {
        depth < 2 // Max nesting level is 2
    }
}

// MARK: - Create Comment Request

struct CreateCommentRequest: Codable, Sendable {
    let userId: UUID
    let forumId: Int
    let parentId: Int?
    let comment: String
    let depth: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case forumId = "forum_id"
        case parentId = "parent_id"
        case comment
        case depth
    }

    init(userId: UUID, forumId: Int, parentId: Int? = nil, comment: String) {
        self.userId = userId
        self.forumId = forumId
        self.parentId = parentId
        self.comment = comment
        depth = parentId == nil ? 0 : 1
    }
}

// Note: ForumReaction and ReactionType are defined in ForumReaction.swift

// MARK: - Fixtures

#if DEBUG
    extension ForumComment {
        static func fixture(
            id: Int = 1,
            userId: UUID = UUID(),
            forumId: Int = 1,
            comment: String = "Great post! I learned so much.",
        ) -> ForumComment {
            ForumComment(
                id: id,
                userId: userId,
                forumId: forumId,
                parentId: nil,
                comment: comment,
                depth: 0,
                isEdited: false,
                updatedAt: nil,
                likesCount: 3,
                repliesCount: 0,
                reportsCount: 0,
                isBestAnswer: false,
                isPinned: false,
                commentCreatedAt: Date(),
                author: ForumAuthor.fixture(),
                replies: nil,
            )
        }
    }
#endif
