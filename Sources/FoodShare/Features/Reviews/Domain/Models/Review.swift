//
//  Review.swift
//  Foodshare
//
//  Review domain model - Maps to `reviews` table in Supabase
//


#if !SKIP
import Foundation

/// Represents a user review
/// Maps to `reviews` table in Supabase
struct Review: Codable, Identifiable, Sendable, Hashable {
    let id: Int // bigint primary key
    let profileId: UUID // profile_id (reviewer)
    let postId: Int? // post_id (optional - for post reviews)
    let forumId: Int? // forum_id (optional - for forum reviews)
    let challengeId: Int? // challenge_id (optional - for challenge reviews)
    let reviewedRating: Int // reviewed_rating (1-5)
    let feedback: String // feedback text
    let notes: String // additional notes
    let createdAt: Date // created_at timestamp
    let reviewer: ReviewerProfile? // Embedded profile from JOIN (profiles relation)

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case postId = "post_id"
        case forumId = "forum_id"
        case challengeId = "challenge_id"
        case reviewedRating = "reviewed_rating"
        case feedback
        case notes
        case createdAt = "created_at"
        case reviewer = "profiles"
    }

    // Custom decoder to handle missing reviewer (when not JOINed) and nullable fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        profileId = try container.decode(UUID.self, forKey: .profileId)
        postId = try container.decodeIfPresent(Int.self, forKey: .postId)
        forumId = try container.decodeIfPresent(Int.self, forKey: .forumId)
        challengeId = try container.decodeIfPresent(Int.self, forKey: .challengeId)
        reviewedRating = try container.decodeIfPresent(Int.self, forKey: .reviewedRating) ?? 0
        feedback = try container.decodeIfPresent(String.self, forKey: .feedback) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        reviewer = try container.decodeIfPresent(ReviewerProfile.self, forKey: .reviewer)
    }

    // Memberwise initializer for testing/fixtures
    init(
        id: Int,
        profileId: UUID,
        postId: Int?,
        forumId: Int?,
        challengeId: Int?,
        reviewedRating: Int,
        feedback: String,
        notes: String,
        createdAt: Date = Date(),
        reviewer: ReviewerProfile? = nil,
    ) {
        self.id = id
        self.profileId = profileId
        self.postId = postId
        self.forumId = forumId
        self.challengeId = challengeId
        self.reviewedRating = reviewedRating
        self.feedback = feedback
        self.notes = notes
        self.createdAt = createdAt
        self.reviewer = reviewer
    }

    // MARK: - Computed Properties

    var rating: Int { reviewedRating }

    var formattedDate: String {
        createdAt.formatted(date: .abbreviated, time: .omitted)
    }

    var reviewType: ReviewType {
        if postId != nil { return .post }
        if forumId != nil { return .forum }
        if challengeId != nil { return .challenge }
        return .unknown
    }
}

/// Type of review
enum ReviewType: String, Codable, Sendable {
    case post
    case forum
    case challenge
    case unknown
}

/// Lightweight profile for embedded reviewer info in reviews
/// Maps to `profiles` table fields when JOINed
struct ReviewerProfile: Codable, Sendable, Hashable {
    let id: UUID
    let nickname: String?
    let avatarUrl: String?
    let isVerified: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case avatarUrl = "avatar_url"
        case isVerified = "is_verified"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
    }

    init(id: UUID, nickname: String?, avatarUrl: String?, isVerified: Bool) {
        self.id = id
        self.nickname = nickname
        self.avatarUrl = avatarUrl
        self.isVerified = isVerified
    }

    var displayName: String {
        nickname ?? "Anonymous"
    }

    var avatarURL: URL? {
        guard let urlString = avatarUrl else { return nil }
        return URL(string: urlString)
    }
}

/// Review with additional profile info for display
struct ReviewWithProfile: Identifiable, Sendable {
    let review: Review
    let reviewerProfile: UserProfile?

    var id: Int { review.id }

    var reviewerName: String {
        reviewerProfile?.nickname ?? "Anonymous"
    }

    var reviewerAvatar: String? {
        reviewerProfile?.avatarUrl
    }
}

/// Request to create a new review
struct CreateReviewRequest: Encodable, Sendable {
    let profileId: UUID
    let postId: Int?
    let forumId: Int?
    let challengeId: Int?
    let reviewedRating: Int
    let feedback: String
    let notes: String

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case postId = "post_id"
        case forumId = "forum_id"
        case challengeId = "challenge_id"
        case reviewedRating = "reviewed_rating"
        case feedback
        case notes
    }

    /// Create a post review request
    static func forPost(
        profileId: UUID,
        postId: Int,
        rating: Int,
        feedback: String,
        notes: String = "",
    ) -> CreateReviewRequest {
        CreateReviewRequest(
            profileId: profileId,
            postId: postId,
            forumId: nil,
            challengeId: nil,
            reviewedRating: rating,
            feedback: feedback,
            notes: notes,
        )
    }
}

// MARK: - Test Fixtures

#if DEBUG

    extension Review {
        static func fixture(
            id: Int = 1,
            profileId: UUID = UUID(),
            postId: Int? = 1,
            forumId: Int? = nil,
            challengeId: Int? = nil,
            reviewedRating: Int = 5,
            feedback: String = "Great experience! Food was fresh and pickup was easy.",
            notes: String = "",
            createdAt: Date = Date(),
            reviewer: ReviewerProfile? = .fixture(),
        ) -> Review {
            Review(
                id: id,
                profileId: profileId,
                postId: postId,
                forumId: forumId,
                challengeId: challengeId,
                reviewedRating: reviewedRating,
                feedback: feedback,
                notes: notes,
                createdAt: createdAt,
                reviewer: reviewer,
            )
        }

        static let sampleReviews: [Review] = [
            .fixture(
                id: 1,
                reviewedRating: 5,
                feedback: "Amazing! Will definitely use again.",
                reviewer: .fixture(nickname: "FoodSaver123"),
            ),
            .fixture(
                id: 2,
                reviewedRating: 4,
                feedback: "Good experience overall.",
                reviewer: .fixture(nickname: "GreenEater"),
            ),
            .fixture(
                id: 3,
                reviewedRating: 5,
                feedback: "So grateful for this community!",
                reviewer: .fixture(nickname: "LocalHelper", isVerified: true),
            )
        ]
    }

    extension ReviewerProfile {
        static func fixture(
            id: UUID = UUID(),
            nickname: String? = "TestUser",
            avatarUrl: String? = nil,
            isVerified: Bool = false,
        ) -> ReviewerProfile {
            ReviewerProfile(
                id: id,
                nickname: nickname,
                avatarUrl: avatarUrl,
                isVerified: isVerified,
            )
        }
    }

#endif

#endif
