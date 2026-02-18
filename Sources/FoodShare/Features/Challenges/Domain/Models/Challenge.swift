//
//  Challenge.swift
//  Foodshare
//
//  Challenge domain model - Maps to `challenges` table in Supabase
//



#if !SKIP
import Foundation

/// Represents a community challenge
/// Maps to `challenges` table in Supabase
struct Challenge: Codable, Identifiable, Sendable, Hashable {
    let id: Int
    let profileId: UUID?
    let challengeTitle: String
    let challengeDescription: String
    let challengeDifficulty: ChallengeDifficulty
    let challengeAction: String
    let challengeScore: Int
    let challengedPeople: Int
    let challengeImage: String
    let challengeViews: Int
    let challengePublished: Bool
    let challengeLikesCounter: Int
    let challengeCreatedAt: Date
    let challengeUpdatedAt: Date

    // MARK: - Translation Fields (from BFF)

    /// Pre-translated title (populated when locale != "en")
    var titleTranslated: String?
    /// Pre-translated description (populated when locale != "en")
    var descriptionTranslated: String?
    /// The locale of the translation (e.g., "ru", "de", "es")
    var translationLocale: String?

    /// CodingKeys removed - BaseSupabaseRepository uses .convertFromSnakeCase
    /// which automatically converts snake_case JSON keys to camelCase property names
    enum CodingKeys: String, CodingKey {
        case id, profileId, challengeTitle, challengeDescription
        case challengeDifficulty, challengeAction, challengeScore
        case challengedPeople, challengeImage, challengeViews
        case challengePublished, challengeLikesCounter
        case challengeCreatedAt, challengeUpdatedAt
        case titleTranslated, descriptionTranslated, translationLocale
    }

    // MARK: - Custom Decoder (handles nullable database fields)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        profileId = try container.decodeIfPresent(UUID.self, forKey: .profileId)
        challengeTitle = try container.decodeIfPresent(String.self, forKey: .challengeTitle) ?? ""
        challengeDescription = try container.decodeIfPresent(String.self, forKey: .challengeDescription) ?? ""
        challengeDifficulty = try container
            .decodeIfPresent(ChallengeDifficulty.self, forKey: .challengeDifficulty) ?? .medium
        challengeAction = try container.decodeIfPresent(String.self, forKey: .challengeAction) ?? ""
        challengeScore = try container.decodeIfPresent(Int.self, forKey: .challengeScore) ?? 0
        challengedPeople = try container.decodeIfPresent(Int.self, forKey: .challengedPeople) ?? 0
        challengeImage = try container.decodeIfPresent(String.self, forKey: .challengeImage) ?? ""
        challengeViews = try container.decodeIfPresent(Int.self, forKey: .challengeViews) ?? 0
        challengePublished = try container.decodeIfPresent(Bool.self, forKey: .challengePublished) ?? true
        challengeLikesCounter = try container.decodeIfPresent(Int.self, forKey: .challengeLikesCounter) ?? 0
        challengeCreatedAt = try container.decodeIfPresent(Date.self, forKey: .challengeCreatedAt) ?? Date()
        challengeUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .challengeUpdatedAt) ?? Date()
        titleTranslated = try container.decodeIfPresent(String.self, forKey: .titleTranslated)
        descriptionTranslated = try container.decodeIfPresent(String.self, forKey: .descriptionTranslated)
        translationLocale = try container.decodeIfPresent(String.self, forKey: .translationLocale)
    }

    // MARK: - Memberwise Initializer (for fixtures)

    init(
        id: Int,
        profileId: UUID?,
        challengeTitle: String,
        challengeDescription: String,
        challengeDifficulty: ChallengeDifficulty,
        challengeAction: String,
        challengeScore: Int,
        challengedPeople: Int,
        challengeImage: String,
        challengeViews: Int,
        challengePublished: Bool,
        challengeLikesCounter: Int,
        challengeCreatedAt: Date,
        challengeUpdatedAt: Date,
        titleTranslated: String? = nil,
        descriptionTranslated: String? = nil,
        translationLocale: String? = nil,
    ) {
        self.id = id
        self.profileId = profileId
        self.challengeTitle = challengeTitle
        self.challengeDescription = challengeDescription
        self.challengeDifficulty = challengeDifficulty
        self.challengeAction = challengeAction
        self.challengeScore = challengeScore
        self.challengedPeople = challengedPeople
        self.challengeImage = challengeImage
        self.challengeViews = challengeViews
        self.challengePublished = challengePublished
        self.challengeLikesCounter = challengeLikesCounter
        self.challengeCreatedAt = challengeCreatedAt
        self.challengeUpdatedAt = challengeUpdatedAt
        self.titleTranslated = titleTranslated
        self.descriptionTranslated = descriptionTranslated
        self.translationLocale = translationLocale
    }

    // MARK: - Computed Properties

    /// Display title - uses translated version if available
    var displayTitle: String {
        titleTranslated ?? challengeTitle
    }

    /// Display description - uses translated version if available
    var displayDescription: String {
        descriptionTranslated ?? challengeDescription
    }

    /// Whether this challenge has been translated
    var isTranslated: Bool {
        titleTranslated != nil || descriptionTranslated != nil
    }

    /// Original title (always English)
    var originalTitle: String {
        challengeTitle
    }

    /// Original description (always English)
    var originalDescription: String {
        challengeDescription
    }

    var imageUrl: URL? {
        URL(string: challengeImage)
    }

    @MainActor
    func localizedFormattedScore(using t: EnhancedTranslationService) -> String {
        t.t("challenge.score_pts", args: ["count": String(challengeScore)])
    }

    @MainActor
    func localizedFormattedParticipants(using t: EnhancedTranslationService) -> String {
        t.t("challenge.joined", args: ["count": String(challengedPeople)])
    }
}

// MARK: - Challenge Difficulty

enum ChallengeDifficulty: String, Codable, Sendable, CaseIterable {
    case easy
    case medium
    case hard
    case extreme

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .easy: t.t("challenge.difficulty.easy")
        case .medium: t.t("challenge.difficulty.medium")
        case .hard: t.t("challenge.difficulty.hard")
        case .extreme: t.t("challenge.difficulty.extreme")
        }
    }

    var icon: String {
        switch self {
        case .easy: "leaf.fill"
        case .medium: "flame.fill"
        case .hard: "bolt.fill"
        case .extreme: "star.fill"
        }
    }

    var color: String {
        switch self {
        case .easy: "green"
        case .medium: "orange"
        case .hard: "red"
        case .extreme: "purple"
        }
    }
}

// MARK: - Challenge Activity

/// User's participation in a challenge
/// Maps to `challenge_activities` table in Supabase
struct ChallengeActivity: Codable, Identifiable, Sendable {
    let id: Int
    let challengeId: Int
    let createdAt: Date
    let userAcceptedChallenge: UUID?
    let userRejectedChallenge: UUID?
    let userCompletedChallenge: UUID?

    /// CodingKeys removed - BaseSupabaseRepository uses .convertFromSnakeCase
    enum CodingKeys: String, CodingKey {
        case id, challengeId, createdAt
        case userAcceptedChallenge, userRejectedChallenge, userCompletedChallenge
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        challengeId = try container.decode(Int.self, forKey: .challengeId)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        userAcceptedChallenge = try container.decodeIfPresent(UUID.self, forKey: .userAcceptedChallenge)
        userRejectedChallenge = try container.decodeIfPresent(UUID.self, forKey: .userRejectedChallenge)
        userCompletedChallenge = try container.decodeIfPresent(UUID.self, forKey: .userCompletedChallenge)
    }

    init(
        id: Int,
        challengeId: Int,
        createdAt: Date,
        userAcceptedChallenge: UUID?,
        userRejectedChallenge: UUID?,
        userCompletedChallenge: UUID?,
    ) {
        self.id = id
        self.challengeId = challengeId
        self.createdAt = createdAt
        self.userAcceptedChallenge = userAcceptedChallenge
        self.userRejectedChallenge = userRejectedChallenge
        self.userCompletedChallenge = userCompletedChallenge
    }

    /// Check if a specific user has accepted this challenge
    func isAccepted(by userId: UUID) -> Bool {
        userAcceptedChallenge == userId
    }

    /// Check if a specific user has completed this challenge
    func isCompleted(by userId: UUID) -> Bool {
        userCompletedChallenge == userId
    }

    /// Check if a specific user has rejected this challenge
    func isRejected(by userId: UUID) -> Bool {
        userRejectedChallenge == userId
    }
}

// MARK: - Challenge with User Status

struct ChallengeWithStatus: Identifiable, Sendable {
    let challenge: Challenge
    let activity: ChallengeActivity?
    let userId: UUID?

    var id: Int {
        challenge.id
    }

    var hasAccepted: Bool {
        guard let userId else { return false }
        return activity?.isAccepted(by: userId) ?? false
    }

    var hasCompleted: Bool {
        guard let userId else { return false }
        return activity?.isCompleted(by: userId) ?? false
    }

    var hasRejected: Bool {
        guard let userId else { return false }
        return activity?.isRejected(by: userId) ?? false
    }

    var status: ChallengeUserStatus {
        if hasCompleted {
            .completed
        } else if hasAccepted {
            .accepted
        } else if hasRejected {
            .rejected
        } else {
            .notJoined
        }
    }
}

enum ChallengeUserStatus: String, Sendable {
    case notJoined
    case accepted
    case completed
    case rejected

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .notJoined: t.t("challenge.status.join")
        case .accepted: t.t("challenge.status.in_progress")
        case .completed: t.t("challenge.status.completed")
        case .rejected: t.t("challenge.status.declined")
        }
    }

    var icon: String {
        switch self {
        case .notJoined: "plus.circle.fill"
        case .accepted: "clock.fill"
        case .completed: "checkmark.circle.fill"
        case .rejected: "xmark.circle.fill"
        }
    }
}

// MARK: - Test Fixtures

#if DEBUG

    extension Challenge {
        static func fixture(
            id: Int = 1,
            profileId: UUID = UUID(),
            challengeTitle: String = "Share 10 Items This Week",
            challengeDescription: String = "Help reduce food waste by sharing 10 items with your community",
            challengeDifficulty: ChallengeDifficulty = .medium,
            challengeAction: String = "share",
            challengeScore: Int = 100,
            challengedPeople: Int = 50,
            challengeImage: String = "https://example.com/challenge.jpg",
            challengeViews: Int = 250,
            challengePublished: Bool = true,
            challengeLikesCounter: Int = 32,
            challengeCreatedAt: Date = Date(),
            challengeUpdatedAt: Date = Date(),
            titleTranslated: String? = nil,
            descriptionTranslated: String? = nil,
            translationLocale: String? = nil,
        ) -> Challenge {
            var challenge = Challenge(
                id: id,
                profileId: profileId,
                challengeTitle: challengeTitle,
                challengeDescription: challengeDescription,
                challengeDifficulty: challengeDifficulty,
                challengeAction: challengeAction,
                challengeScore: challengeScore,
                challengedPeople: challengedPeople,
                challengeImage: challengeImage,
                challengeViews: challengeViews,
                challengePublished: challengePublished,
                challengeLikesCounter: challengeLikesCounter,
                challengeCreatedAt: challengeCreatedAt,
                challengeUpdatedAt: challengeUpdatedAt,
            )
            challenge.titleTranslated = titleTranslated
            challenge.descriptionTranslated = descriptionTranslated
            challenge.translationLocale = translationLocale
            return challenge
        }

        static let sampleChallenges: [Challenge] = [
            .fixture(id: 1, challengeTitle: "Weekly Sharing Goal", challengeScore: 50),
            .fixture(id: 2, challengeTitle: "Community Hero", challengeDifficulty: .hard, challengeScore: 200),
            .fixture(id: 3, challengeTitle: "First Steps", challengeDifficulty: .easy, challengeScore: 25),
        ]
    }

    extension ChallengeActivity {
        static func fixture(
            id: Int = 1,
            challengeId: Int = 1,
            createdAt: Date = Date(),
            userAcceptedChallenge: UUID? = UUID(),
            userRejectedChallenge: UUID? = nil,
            userCompletedChallenge: UUID? = nil,
        ) -> ChallengeActivity {
            ChallengeActivity(
                id: id,
                challengeId: challengeId,
                createdAt: createdAt,
                userAcceptedChallenge: userAcceptedChallenge,
                userRejectedChallenge: userRejectedChallenge,
                userCompletedChallenge: userCompletedChallenge,
            )
        }
    }

#endif


#endif
