//
//  ForumReaction.swift
//  Foodshare
//
//  Forum reaction models for emoji reactions on posts and comments
//  Maps to reaction_types, forum_reactions, forum_comment_reactions tables
//

import Foundation

// MARK: - Reaction Type

/// Represents a type of reaction (emoji) available in the forum
struct ReactionType: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let emoji: String
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case emoji
        case sortOrder = "sort_order"
    }

    // MARK: - Preset Reactions

    static let like = ReactionType(id: 1, name: "like", emoji: "👍", sortOrder: 1)
    static let love = ReactionType(id: 2, name: "love", emoji: "❤️", sortOrder: 2)
    static let celebrate = ReactionType(id: 3, name: "celebrate", emoji: "🎉", sortOrder: 3)
    static let helpful = ReactionType(id: 4, name: "helpful", emoji: "💡", sortOrder: 4)
    static let insightful = ReactionType(id: 5, name: "insightful", emoji: "🤔", sortOrder: 5)
    static let funny = ReactionType(id: 6, name: "funny", emoji: "😄", sortOrder: 6)

    /// All available reaction types
    static let all: [ReactionType] = [like, love, celebrate, helpful, insightful, funny]
}

// MARK: - Forum Reaction

/// Represents a user's reaction on a forum post
struct ForumReaction: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let forumId: Int
    let profileId: UUID
    let reactionTypeId: Int
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case forumId = "forum_id"
        case profileId = "profile_id"
        case reactionTypeId = "reaction_type_id"
        case createdAt = "created_at"
    }
}

// MARK: - Forum Comment Reaction

/// Represents a user's reaction on a forum comment
struct ForumCommentReaction: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let commentId: Int
    let profileId: UUID
    let reactionTypeId: Int
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case commentId = "comment_id"
        case profileId = "profile_id"
        case reactionTypeId = "reaction_type_id"
        case createdAt = "created_at"
    }
}

// MARK: - Reaction Count

/// Represents aggregated reaction counts for display
struct ReactionCount: Codable, Identifiable, Hashable, Sendable {
    let reactionType: ReactionType
    let count: Int
    let hasUserReacted: Bool

    var id: Int { reactionType.id }

    init(reactionType: ReactionType, count: Int, hasUserReacted: Bool = false) {
        self.reactionType = reactionType
        self.count = count
        self.hasUserReacted = hasUserReacted
    }
}

// MARK: - Reactions Summary

/// Summary of all reactions for a post or comment
struct ReactionsSummary: Codable, Sendable {
    let totalCount: Int
    let reactions: [ReactionCount]
    let userReactionTypeIds: [Int]

    /// The most popular reaction (highest count)
    var topReaction: ReactionCount? {
        reactions.max(by: { $0.count < $1.count })
    }

    /// Filtered reactions with at least one count
    var activeReactions: [ReactionCount] {
        reactions.filter { $0.count > 0 }
    }

    /// Check if user has reacted with a specific type
    func hasUserReacted(typeId: Int) -> Bool {
        userReactionTypeIds.contains(typeId)
    }

    init(totalCount: Int = 0, reactions: [ReactionCount] = [], userReactionTypeIds: [Int] = []) {
        self.totalCount = totalCount
        self.reactions = reactions
        self.userReactionTypeIds = userReactionTypeIds
    }

    /// Create from JSONB reactions_count data and user reactions
    static func from(reactionsCount: [String: Int], userReactionTypeIds: [Int]) -> ReactionsSummary {
        var total = 0
        let reactionCounts = ReactionType.all.map { type in
            let count = reactionsCount[type.name] ?? 0
            total += count
            return ReactionCount(
                reactionType: type,
                count: count,
                hasUserReacted: userReactionTypeIds.contains(type.id),
            )
        }

        return ReactionsSummary(
            totalCount: total,
            reactions: reactionCounts,
            userReactionTypeIds: userReactionTypeIds,
        )
    }
}

// MARK: - Toggle Reaction Request

/// Request model for toggling a reaction
struct ToggleReactionRequest: Codable, Sendable {
    let forumId: Int?
    let commentId: Int?
    let reactionTypeId: Int
    let profileId: UUID

    enum CodingKeys: String, CodingKey {
        case forumId = "forum_id"
        case commentId = "comment_id"
        case reactionTypeId = "reaction_type_id"
        case profileId = "profile_id"
    }

    init(forumId: Int, reactionTypeId: Int, profileId: UUID) {
        self.forumId = forumId
        commentId = nil
        self.reactionTypeId = reactionTypeId
        self.profileId = profileId
    }

    init(commentId: Int, reactionTypeId: Int, profileId: UUID) {
        forumId = nil
        self.commentId = commentId
        self.reactionTypeId = reactionTypeId
        self.profileId = profileId
    }
}

// MARK: - Toggle Reaction Result

/// Result of toggling a reaction
struct ToggleReactionResult: Codable, Sendable {
    let added: Bool
    let updatedSummary: ReactionsSummary
}

// MARK: - Test Fixtures

#if DEBUG
    extension ReactionType {
        static func fixture(
            id: Int = 1,
            name: String = "like",
            emoji: String = "👍",
            sortOrder: Int = 1,
        ) -> ReactionType {
            ReactionType(
                id: id,
                name: name,
                emoji: emoji,
                sortOrder: sortOrder,
            )
        }
    }

    extension ForumReaction {
        static func fixture(
            id: UUID = UUID(),
            forumId: Int = 1,
            profileId: UUID = UUID(),
            reactionTypeId: Int = 1,
        ) -> ForumReaction {
            ForumReaction(
                id: id,
                forumId: forumId,
                profileId: profileId,
                reactionTypeId: reactionTypeId,
                createdAt: Date(),
            )
        }
    }

    extension ReactionCount {
        static func fixture(
            reactionType: ReactionType = .like,
            count: Int = 5,
            hasUserReacted: Bool = false,
        ) -> ReactionCount {
            ReactionCount(
                reactionType: reactionType,
                count: count,
                hasUserReacted: hasUserReacted,
            )
        }
    }

    extension ReactionsSummary {
        static func fixture(
            totalCount: Int = 15,
            userReactionTypeIds: [Int] = [1],
        ) -> ReactionsSummary {
            let reactions = [
                ReactionCount(reactionType: .like, count: 8, hasUserReacted: userReactionTypeIds.contains(1)),
                ReactionCount(reactionType: .love, count: 4, hasUserReacted: userReactionTypeIds.contains(2)),
                ReactionCount(reactionType: .celebrate, count: 2, hasUserReacted: userReactionTypeIds.contains(3)),
                ReactionCount(reactionType: .helpful, count: 1, hasUserReacted: userReactionTypeIds.contains(4)),
                ReactionCount(reactionType: .insightful, count: 0, hasUserReacted: userReactionTypeIds.contains(5)),
                ReactionCount(reactionType: .funny, count: 0, hasUserReacted: userReactionTypeIds.contains(6))
            ]

            return ReactionsSummary(
                totalCount: totalCount,
                reactions: reactions,
                userReactionTypeIds: userReactionTypeIds,
            )
        }
    }
#endif
