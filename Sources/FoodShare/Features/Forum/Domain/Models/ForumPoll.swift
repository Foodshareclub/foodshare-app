//
//  ForumPoll.swift
//  Foodshare
//
//  Forum poll models for voting functionality
//  Maps to forum_polls, forum_poll_options, forum_poll_votes tables
//

import Foundation

// MARK: - Forum Poll

/// Represents a poll attached to a forum post
struct ForumPoll: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let forumId: Int
    let question: String
    let pollType: PollType
    let endsAt: Date?
    let isAnonymous: Bool
    let showResultsBeforeVote: Bool
    let totalVotes: Int
    let createdAt: Date?
    let updatedAt: Date?

    // Joined data
    var options: [ForumPollOption]?
    var userVotes: [UUID]? // Option IDs the current user voted for

    enum CodingKeys: String, CodingKey {
        case id
        case forumId = "forum_id"
        case question
        case pollType = "poll_type"
        case endsAt = "ends_at"
        case isAnonymous = "is_anonymous"
        case showResultsBeforeVote = "show_results_before_vote"
        case totalVotes = "total_votes"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case options
        case userVotes = "user_votes"
    }

    // MARK: - Computed Properties

    /// Whether the poll has ended
    var hasEnded: Bool {
        guard let endsAt else { return false }
        return Date() > endsAt
    }

    /// Whether the poll is currently active
    var isActive: Bool {
        !hasEnded
    }

    /// Time remaining until poll ends (nil if no end date or already ended)
    var timeRemaining: TimeInterval? {
        guard let endsAt, !hasEnded else { return nil }
        return endsAt.timeIntervalSince(Date())
    }

    /// Whether user has already voted
    var hasVoted: Bool {
        guard let votes = userVotes else { return false }
        return !votes.isEmpty
    }

    /// Whether to show results (either voted, ended, or allowed before voting)
    var shouldShowResults: Bool {
        hasVoted || hasEnded || showResultsBeforeVote
    }

    /// Whether user can vote (active poll, not already voted for single-choice, or multiple-choice)
    var canVote: Bool {
        guard isActive else { return false }
        if pollType == .single {
            return !hasVoted
        }
        return true // Multiple choice allows changing votes
    }

    /// Formatted time remaining string
    var timeRemainingText: String? {
        guard let remaining = timeRemaining else { return nil }

        let hours = Int(remaining / 3600)
        let days = hours / 24

        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s") left"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") left"
        } else {
            let minutes = Int(remaining / 60)
            return "\(max(1, minutes)) minute\(minutes == 1 ? "" : "s") left"
        }
    }
}

// MARK: - Poll Type

enum PollType: String, Codable, CaseIterable, Sendable {
    case single
    case multiple

    var displayName: String {
        switch self {
        case .single: "Single Choice"
        case .multiple: "Multiple Choice"
        }
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .single: t.t("forum.poll_type.single")
        case .multiple: t.t("forum.poll_type.multiple")
        }
    }

    var iconName: String {
        switch self {
        case .single: "circle.inset.filled"
        case .multiple: "checkmark.square"
        }
    }
}

// MARK: - Forum Poll Option

/// Represents an option in a forum poll
struct ForumPollOption: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let pollId: UUID
    let optionText: String
    let votesCount: Int
    let sortOrder: Int
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case pollId = "poll_id"
        case optionText = "option_text"
        case votesCount = "votes_count"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }

    // MARK: - Computed Properties

    /// Calculate percentage of votes for this option
    func votePercentage(totalVotes: Int) -> Double {
        guard totalVotes > 0 else { return 0 }
        return Double(votesCount) / Double(totalVotes) * 100
    }

    /// Formatted percentage string
    func formattedPercentage(totalVotes: Int) -> String {
        let percentage = votePercentage(totalVotes: totalVotes)
        return String(format: "%.0f%%", percentage)
    }
}

// MARK: - Forum Poll Vote

/// Represents a user's vote on a poll option
struct ForumPollVote: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let pollId: UUID
    let optionId: UUID
    let profileId: UUID
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case pollId = "poll_id"
        case optionId = "option_id"
        case profileId = "profile_id"
        case createdAt = "created_at"
    }
}

// MARK: - Create Poll Request

/// Request model for creating a new poll
struct CreatePollRequest: Codable, Sendable {
    let forumId: Int
    let question: String
    let pollType: PollType
    let options: [String]
    let endsAt: Date?
    let isAnonymous: Bool
    let showResultsBeforeVote: Bool

    enum CodingKeys: String, CodingKey {
        case forumId = "forum_id"
        case question
        case pollType = "poll_type"
        case options
        case endsAt = "ends_at"
        case isAnonymous = "is_anonymous"
        case showResultsBeforeVote = "show_results_before_vote"
    }

    init(
        forumId: Int,
        question: String,
        pollType: PollType = .single,
        options: [String],
        endsAt: Date? = nil,
        isAnonymous: Bool = false,
        showResultsBeforeVote: Bool = false,
    ) {
        self.forumId = forumId
        self.question = question
        self.pollType = pollType
        self.options = options
        self.endsAt = endsAt
        self.isAnonymous = isAnonymous
        self.showResultsBeforeVote = showResultsBeforeVote
    }
}

// MARK: - Vote Request

/// Request model for voting on a poll
struct VotePollRequest: Codable, Sendable {
    let pollId: UUID
    let optionIds: [UUID]
    let profileId: UUID

    enum CodingKeys: String, CodingKey {
        case pollId = "poll_id"
        case optionIds = "option_ids"
        case profileId = "profile_id"
    }
}

// MARK: - Poll Results

/// Aggregated poll results
struct ForumPollResults: Codable, Sendable {
    let poll: ForumPoll
    let options: [ForumPollOption]
    let totalVotes: Int
    let voterCount: Int
    let userVotedOptionIds: [UUID]

    /// The winning option (most votes)
    var winningOption: ForumPollOption? {
        options.max(by: { $0.votesCount < $1.votesCount })
    }

    /// Whether there's a clear winner (more than 50%)
    var hasClearWinner: Bool {
        guard let winner = winningOption, totalVotes > 0 else { return false }
        return Double(winner.votesCount) / Double(totalVotes) > 0.5
    }
}

// MARK: - Poll Validation

extension CreatePollRequest {
    /// Validation errors for poll creation requests.
    ///
    /// Thread-safe for Swift 6 concurrency.
    enum ValidationError: LocalizedError, Sendable {
        /// Question is too short (min 5 characters)
        case questionTooShort
        /// Question exceeds maximum length
        case questionTooLong
        /// Not enough options (min 2)
        case tooFewOptions
        /// Too many options (max 10)
        case tooManyOptions
        /// One or more options are empty
        case emptyOption
        /// Options are not unique
        case duplicateOptions
        /// End date is in the past
        case endDateInPast

        var errorDescription: String? {
            switch self {
            case .questionTooShort:
                "Poll question must be at least 5 characters"
            case .questionTooLong:
                "Poll question cannot exceed 200 characters"
            case .tooFewOptions:
                "Poll must have at least 2 options"
            case .tooManyOptions:
                "Poll cannot have more than 10 options"
            case .emptyOption:
                "Poll options cannot be empty"
            case .duplicateOptions:
                "Poll options must be unique"
            case .endDateInPast:
                "Poll end date must be in the future"
            }
        }
    }

    func validate() throws {
        // Question validation
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuestion.count >= 5 else {
            throw ValidationError.questionTooShort
        }
        guard trimmedQuestion.count <= 200 else {
            throw ValidationError.questionTooLong
        }

        // Options validation
        guard options.count >= 2 else {
            throw ValidationError.tooFewOptions
        }
        guard options.count <= 10 else {
            throw ValidationError.tooManyOptions
        }

        let trimmedOptions = options.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard trimmedOptions.allSatisfy({ !$0.isEmpty }) else {
            throw ValidationError.emptyOption
        }

        let uniqueOptions = Set(trimmedOptions.map { $0.lowercased() })
        guard uniqueOptions.count == trimmedOptions.count else {
            throw ValidationError.duplicateOptions
        }

        // End date validation
        if let endsAt, endsAt <= Date() {
            throw ValidationError.endDateInPast
        }
    }
}

// MARK: - Test Fixtures

#if DEBUG
    extension ForumPoll {
        static func fixture(
            id: UUID = UUID(),
            forumId: Int = 1,
            question: String = "What's your favorite food sharing approach?",
            pollType: PollType = .single,
            endsAt: Date? = Date().addingTimeInterval(86400 * 7),
            isAnonymous: Bool = false,
            showResultsBeforeVote: Bool = false,
            totalVotes: Int = 42,
            options: [ForumPollOption]? = nil,
            userVotes: [UUID]? = nil,
        ) -> ForumPoll {
            ForumPoll(
                id: id,
                forumId: forumId,
                question: question,
                pollType: pollType,
                endsAt: endsAt,
                isAnonymous: isAnonymous,
                showResultsBeforeVote: showResultsBeforeVote,
                totalVotes: totalVotes,
                createdAt: Date(),
                updatedAt: Date(),
                options: options ?? [
                    .fixture(pollId: id, optionText: "Door-to-door delivery", votesCount: 15, sortOrder: 0),
                    .fixture(pollId: id, optionText: "Community pickup points", votesCount: 20, sortOrder: 1),
                    .fixture(pollId: id, optionText: "Food lockers", votesCount: 5, sortOrder: 2),
                    .fixture(pollId: id, optionText: "Other", votesCount: 2, sortOrder: 3)
                ],
                userVotes: userVotes,
            )
        }
    }

    extension ForumPollOption {
        static func fixture(
            id: UUID = UUID(),
            pollId: UUID = UUID(),
            optionText: String = "Option",
            votesCount: Int = 10,
            sortOrder: Int = 0,
        ) -> ForumPollOption {
            ForumPollOption(
                id: id,
                pollId: pollId,
                optionText: optionText,
                votesCount: votesCount,
                sortOrder: sortOrder,
                createdAt: Date(),
            )
        }
    }

    extension ForumPollVote {
        static func fixture(
            id: UUID = UUID(),
            pollId: UUID = UUID(),
            optionId: UUID = UUID(),
            profileId: UUID = UUID(),
        ) -> ForumPollVote {
            ForumPollVote(
                id: id,
                pollId: pollId,
                optionId: optionId,
                profileId: profileId,
                createdAt: Date(),
            )
        }
    }

    extension ForumPollResults {
        static func fixture(
            poll: ForumPoll? = nil,
            totalVotes: Int = 42,
            voterCount: Int = 38,
        ) -> ForumPollResults {
            let fixturePoll = poll ?? ForumPoll.fixture()
            return ForumPollResults(
                poll: fixturePoll,
                options: fixturePoll.options ?? [],
                totalVotes: totalVotes,
                voterCount: voterCount,
                userVotedOptionIds: [],
            )
        }
    }
#endif
