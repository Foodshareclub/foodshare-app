//
//  ProfileStats.swift
//  Foodshare
//
//  User statistics model - Maps to `profile_stats` table in Supabase
//  Separated from profiles for better performance
//

import Foundation

/// User statistics and counters
/// Maps to `profile_stats` table in Supabase
struct ProfileStats: Codable, Sendable, Equatable {
    let profileId: UUID // profile_id (PK, FK to profiles)

    // MARK: - Review Counters

    let reviewsPostCounter: Int // reviews_post_counter
    let reviewsChallengeCounter: Int // reviews_challenge_counter
    let reviewsForumCounter: Int // reviews_forum_counter

    // MARK: - Average Ratings

    let reviewedPostsAverageRating: Int // reviewed_posts_average_rating (0-5)
    let reviewedForumAverageRating: Int // reviewed_forum_average_rating (0-5)
    let reviewedChallengesAverageRating: Int // reviewed_challenges_average_rating (0-5)

    // MARK: - Like Counters

    let likedPostsCounter: Int // liked_posts_counter
    let likedForumsCounter: Int // liked_forums_counter
    let likedChallengesCounter: Int // liked_challenges_counter

    // MARK: - Achievement Flags

    let fourStarsRating: Bool // four_stars_rating
    let fiveStarsRating: Bool // five_stars_rating
    let sharedPostsWithFiveUsers: Bool // shared_posts_with_five_users

    // MARK: - Share Counters

    let sharedPostsCounter: Int // shared_posts_counter
    let sharedForumsCounter: Int // shared_forums_counter
    let sharedChallengesCounter: Int // shared_challenges_counter

    // MARK: - iOS-Specific Stats

    let itemsShared: Int // items_shared
    let itemsReceived: Int // items_received
    let ratingAverage: Double // rating_average (0.0-5.0)
    let ratingCount: Int // rating_count

    // MARK: - Timestamps

    let createdAt: Date // created_at
    let updatedAt: Date // updated_at

    // MARK: - Computed Properties

    /// Total reviews given
    var totalReviews: Int {
        reviewsPostCounter + reviewsChallengeCounter + reviewsForumCounter
    }

    /// Total likes given
    var totalLikes: Int {
        likedPostsCounter + likedForumsCounter + likedChallengesCounter
    }

    /// Total shares
    var totalShares: Int {
        sharedPostsCounter + sharedForumsCounter + sharedChallengesCounter
    }

    /// Has good reputation (4+ stars with 5+ reviews)
    var hasGoodReputation: Bool {
        ratingCount >= 5 && ratingAverage >= 4.0
    }

    /// Display rating as stars
    var ratingStars: String {
        let fullStars = Int(ratingAverage)
        let hasHalfStar = ratingAverage - Double(fullStars) >= 0.5
        var stars = String(repeating: "★", count: fullStars)
        if hasHalfStar, fullStars < 5 {
            stars += "½"
        }
        return stars
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case reviewsPostCounter = "reviews_post_counter"
        case reviewsChallengeCounter = "reviews_challenge_counter"
        case reviewsForumCounter = "reviews_forum_counter"
        case reviewedPostsAverageRating = "reviewed_posts_average_rating"
        case reviewedForumAverageRating = "reviewed_forum_average_rating"
        case reviewedChallengesAverageRating = "reviewed_challenges_average_rating"
        case likedPostsCounter = "liked_posts_counter"
        case likedForumsCounter = "liked_forums_counter"
        case likedChallengesCounter = "liked_challenges_counter"
        case fourStarsRating = "four_stars_rating"
        case fiveStarsRating = "five_stars_rating"
        case sharedPostsWithFiveUsers = "shared_posts_with_five_users"
        case sharedPostsCounter = "shared_posts_counter"
        case sharedForumsCounter = "shared_forums_counter"
        case sharedChallengesCounter = "shared_challenges_counter"
        case itemsShared = "items_shared"
        case itemsReceived = "items_received"
        case ratingAverage = "rating_average"
        case ratingCount = "rating_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Custom Decoder (handles nullable database fields)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profileId = try container.decode(UUID.self, forKey: .profileId)
        reviewsPostCounter = try container.decodeIfPresent(Int.self, forKey: .reviewsPostCounter) ?? 0
        reviewsChallengeCounter = try container.decodeIfPresent(Int.self, forKey: .reviewsChallengeCounter) ?? 0
        reviewsForumCounter = try container.decodeIfPresent(Int.self, forKey: .reviewsForumCounter) ?? 0
        reviewedPostsAverageRating = try container.decodeIfPresent(Int.self, forKey: .reviewedPostsAverageRating) ?? 0
        reviewedForumAverageRating = try container.decodeIfPresent(Int.self, forKey: .reviewedForumAverageRating) ?? 0
        reviewedChallengesAverageRating = try container.decodeIfPresent(Int.self, forKey: .reviewedChallengesAverageRating) ?? 0
        likedPostsCounter = try container.decodeIfPresent(Int.self, forKey: .likedPostsCounter) ?? 0
        likedForumsCounter = try container.decodeIfPresent(Int.self, forKey: .likedForumsCounter) ?? 0
        likedChallengesCounter = try container.decodeIfPresent(Int.self, forKey: .likedChallengesCounter) ?? 0
        fourStarsRating = try container.decodeIfPresent(Bool.self, forKey: .fourStarsRating) ?? false
        fiveStarsRating = try container.decodeIfPresent(Bool.self, forKey: .fiveStarsRating) ?? false
        sharedPostsWithFiveUsers = try container.decodeIfPresent(Bool.self, forKey: .sharedPostsWithFiveUsers) ?? false
        sharedPostsCounter = try container.decodeIfPresent(Int.self, forKey: .sharedPostsCounter) ?? 0
        sharedForumsCounter = try container.decodeIfPresent(Int.self, forKey: .sharedForumsCounter) ?? 0
        sharedChallengesCounter = try container.decodeIfPresent(Int.self, forKey: .sharedChallengesCounter) ?? 0
        itemsShared = try container.decodeIfPresent(Int.self, forKey: .itemsShared) ?? 0
        itemsReceived = try container.decodeIfPresent(Int.self, forKey: .itemsReceived) ?? 0
        ratingAverage = try container.decodeIfPresent(Double.self, forKey: .ratingAverage) ?? 0.0
        ratingCount = try container.decodeIfPresent(Int.self, forKey: .ratingCount) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    // MARK: - Memberwise Initializer (for fixtures)

    init(
        profileId: UUID,
        reviewsPostCounter: Int,
        reviewsChallengeCounter: Int,
        reviewsForumCounter: Int,
        reviewedPostsAverageRating: Int,
        reviewedForumAverageRating: Int,
        reviewedChallengesAverageRating: Int,
        likedPostsCounter: Int,
        likedForumsCounter: Int,
        likedChallengesCounter: Int,
        fourStarsRating: Bool,
        fiveStarsRating: Bool,
        sharedPostsWithFiveUsers: Bool,
        sharedPostsCounter: Int,
        sharedForumsCounter: Int,
        sharedChallengesCounter: Int,
        itemsShared: Int,
        itemsReceived: Int,
        ratingAverage: Double,
        ratingCount: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.profileId = profileId
        self.reviewsPostCounter = reviewsPostCounter
        self.reviewsChallengeCounter = reviewsChallengeCounter
        self.reviewsForumCounter = reviewsForumCounter
        self.reviewedPostsAverageRating = reviewedPostsAverageRating
        self.reviewedForumAverageRating = reviewedForumAverageRating
        self.reviewedChallengesAverageRating = reviewedChallengesAverageRating
        self.likedPostsCounter = likedPostsCounter
        self.likedForumsCounter = likedForumsCounter
        self.likedChallengesCounter = likedChallengesCounter
        self.fourStarsRating = fourStarsRating
        self.fiveStarsRating = fiveStarsRating
        self.sharedPostsWithFiveUsers = sharedPostsWithFiveUsers
        self.sharedPostsCounter = sharedPostsCounter
        self.sharedForumsCounter = sharedForumsCounter
        self.sharedChallengesCounter = sharedChallengesCounter
        self.itemsShared = itemsShared
        self.itemsReceived = itemsReceived
        self.ratingAverage = ratingAverage
        self.ratingCount = ratingCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Test Fixtures

// MARK: - Profile Analytics (from RPC)

/// Server-calculated profile analytics
/// Single source of truth for completion, rank, and impact metrics
struct ProfileAnalytics: Codable, Sendable, Equatable {
    let success: Bool
    let userId: UUID
    let completion: ProfileCompletionData
    let rank: CommunityRankData
    let impact: ImpactMetricsData
    let ratingAverage: Double
    let ratingCount: Int
    let calculatedAt: Date

    enum CodingKeys: String, CodingKey {
        case success
        case userId
        case completion
        case rank
        case impact
        case ratingAverage
        case ratingCount
        case calculatedAt
    }
}

/// Profile completion data from server
struct ProfileCompletionData: Codable, Sendable, Equatable {
    let percentage: Double
    let completedCount: Int
    let totalFields: Int
    let completedFields: [String]
    let missingFields: [String]
    let isComplete: Bool
    let nextStep: String?

    enum CodingKeys: String, CodingKey {
        case percentage
        case completedCount
        case totalFields
        case completedFields
        case missingFields
        case isComplete
        case nextStep
    }
}

/// Community rank data from server
struct CommunityRankData: Codable, Sendable, Equatable {
    let tier: String
    let nextTier: String?
    let progressToNextTier: Int
    let totalExchanges: Int

    enum CodingKeys: String, CodingKey {
        case tier
        case nextTier
        case progressToNextTier
        case totalExchanges
    }
}

/// Environmental impact metrics from server (single source of truth)
struct ImpactMetricsData: Codable, Sendable, Equatable {
    let mealsShared: Int
    let mealsReceived: Int
    let foodSavedKg: Double
    let co2SavedKg: Double
    let waterSavedLiters: Double
    let moneySavedUsd: Double
    let equivalentTrees: Double
    let equivalentCarMiles: Double

    enum CodingKeys: String, CodingKey {
        case mealsShared
        case mealsReceived
        case foodSavedKg
        case co2SavedKg
        case waterSavedLiters
        case moneySavedUsd
        case equivalentTrees
        case equivalentCarMiles
    }

    /// Formatted CO₂ string (e.g., "2.5kg" or "1.2t")
    var formattedCO2: String {
        co2SavedKg >= 1000 ? String(format: "%.1ft", co2SavedKg / 1000) : String(format: "%.1fkg", co2SavedKg)
    }

    /// Formatted water string (e.g., "500L" or "2kL")
    var formattedWater: String {
        waterSavedLiters >= 1000
            ? String(format: "%.0fkL", waterSavedLiters / 1000)
            : String(format: "%.0fL", waterSavedLiters)
    }
}

#if DEBUG

    extension ProfileStats {
        static func fixture(
            profileId: UUID = UUID(),
            itemsShared: Int = 5,
            itemsReceived: Int = 3,
            ratingAverage: Double = 4.8,
            ratingCount: Int = 10,
        ) -> ProfileStats {
            ProfileStats(
                profileId: profileId,
                reviewsPostCounter: 0,
                reviewsChallengeCounter: 0,
                reviewsForumCounter: 0,
                reviewedPostsAverageRating: 0,
                reviewedForumAverageRating: 0,
                reviewedChallengesAverageRating: 0,
                likedPostsCounter: 0,
                likedForumsCounter: 0,
                likedChallengesCounter: 0,
                fourStarsRating: ratingAverage >= 4.0,
                fiveStarsRating: ratingAverage >= 5.0,
                sharedPostsWithFiveUsers: itemsShared >= 5,
                sharedPostsCounter: 0,
                sharedForumsCounter: 0,
                sharedChallengesCounter: 0,
                itemsShared: itemsShared,
                itemsReceived: itemsReceived,
                ratingAverage: ratingAverage,
                ratingCount: ratingCount,
                createdAt: Date(),
                updatedAt: Date(),
            )
        }
    }

#endif
