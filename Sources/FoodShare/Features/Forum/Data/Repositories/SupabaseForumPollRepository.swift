
#if !SKIP
import Foundation
import OSLog
import Supabase

// MARK: - Supabase Forum Poll Repository

/// Handles forum polls, voting, and results
@MainActor
final class SupabaseForumPollRepository: BaseSupabaseRepository, @unchecked Sendable {
    init(supabase: Supabase.SupabaseClient) {
        super.init(supabase: supabase, subsystem: "com.flutterflow.foodshare", category: "ForumPollRepository")
    }

    // MARK: - Polls

    func fetchPoll(forumId: Int) async throws -> ForumPoll? {
        let response: [ForumPoll] = try await supabase
            .from("forum_polls")
            .select("""
                *,
                options:forum_poll_options(*)
            """)
            .eq("forum_id", value: forumId)
            .limit(1)
            .execute()
            .value

        return response.first
    }

    func fetchPollWithOptions(pollId: UUID, profileId: UUID) async throws -> ForumPoll {
        // Fetch poll with options
        var poll: ForumPoll = try await supabase
            .from("forum_polls")
            .select("""
                *,
                options:forum_poll_options(*)
            """)
            .eq("id", value: pollId)
            .single()
            .execute()
            .value

        // Fetch user's votes for this poll
        let votes: [ForumPollVote] = try await supabase
            .from("forum_poll_votes")
            .select()
            .eq("poll_id", value: pollId)
            .eq("profile_id", value: profileId)
            .execute()
            .value

        poll.userVotes = votes.map(\.optionId)
        return poll
    }

    func votePoll(pollId: UUID, optionIds: [UUID], profileId: UUID) async throws -> ForumPoll {
        // Use atomic backend RPC - handles auth.uid() automatically
        // Single call: validates poll, removes old votes (single-choice), inserts new, updates counts
        let result: CastPollVoteResult = try await supabase
            .rpc("cast_poll_vote", params: CastPollVoteParams(
                p_poll_id: pollId.uuidString,
                p_option_ids: optionIds.map(\.uuidString),
            ))
            .execute()
            .value

        // Fetch the base poll to get immutable fields (question, type, etc.)
        let basePoll: ForumPoll = try await supabase
            .from("forum_polls")
            .select()
            .eq("id", value: pollId)
            .single()
            .execute()
            .value

        // Construct updated poll with RPC results (ForumPoll has let properties)
        let updatedOptions = result.options.map { option in
            ForumPollOption(
                id: option.id,
                pollId: pollId,
                optionText: option.optionText,
                votesCount: option.votesCount,
                sortOrder: 0,
                createdAt: nil,
            )
        }

        return ForumPoll(
            id: basePoll.id,
            forumId: basePoll.forumId,
            question: basePoll.question,
            pollType: basePoll.pollType,
            endsAt: basePoll.endsAt,
            isAnonymous: basePoll.isAnonymous,
            showResultsBeforeVote: basePoll.showResultsBeforeVote,
            totalVotes: result.totalVotes,
            createdAt: basePoll.createdAt,
            updatedAt: basePoll.updatedAt,
            options: updatedOptions,
            userVotes: result.userVotes,
        )
    }

    func removeVote(pollId: UUID, optionId: UUID, profileId: UUID) async throws {
        try await supabase
            .from("forum_poll_votes")
            .delete()
            .eq("poll_id", value: pollId)
            .eq("option_id", value: optionId)
            .eq("profile_id", value: profileId)
            .execute()

        // Decrement vote count
        try await supabase.rpc(
            "decrement_poll_option_votes",
            params: ["option_id": optionId.uuidString],
        ).execute()

        // Update total votes
        try await supabase.rpc(
            "update_poll_total_votes",
            params: ["p_poll_id": pollId.uuidString],
        ).execute()
    }

    func createPoll(_ request: CreatePollRequest) async throws -> ForumPoll {
        // Validate request
        try request.validate()

        // Insert poll
        let pollDTO = PollInsertDTO(
            forum_id: request.forumId,
            question: request.question,
            poll_type: request.pollType.rawValue,
            ends_at: request.endsAt,
            is_anonymous: request.isAnonymous,
            show_results_before_vote: request.showResultsBeforeVote,
        )

        let poll: ForumPoll = try await supabase
            .from("forum_polls")
            .insert(pollDTO)
            .select()
            .single()
            .execute()
            .value

        // Insert options
        let optionDTOs = request.options.enumerated().map { index, text in
            PollOptionInsertDTO(
                poll_id: poll.id.uuidString,
                option_text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                sort_order: index,
            )
        }

        let options: [ForumPollOption] = try await supabase
            .from("forum_poll_options")
            .insert(optionDTOs)
            .select()
            .execute()
            .value

        var pollWithOptions = poll
        pollWithOptions.options = options
        return pollWithOptions
    }

    func fetchPollResults(pollId: UUID, profileId: UUID) async throws -> ForumPollResults {
        // Single RPC call replaces 3 separate queries
        let params = PollResultsParams(pPollId: pollId, pProfileId: profileId)

        let response = try await supabase
            .rpc("get_poll_results", params: params)
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(PollResultsDTO.self, from: response.data)

        // Reconstruct poll with options
        var poll = dto.poll
        poll.options = dto.options
        poll.userVotes = dto.userVotedOptionIds

        return ForumPollResults(
            poll: poll,
            options: dto.options,
            totalVotes: dto.totalVotes,
            voterCount: dto.voterCount,
            userVotedOptionIds: dto.userVotedOptionIds,
        )
    }
}

// MARK: - Poll DTOs

private struct PollInsertDTO: Encodable {
    let forum_id: Int
    let question: String
    let poll_type: String
    let ends_at: Date?
    let is_anonymous: Bool
    let show_results_before_vote: Bool
}

private struct PollOptionInsertDTO: Encodable {
    let poll_id: String
    let option_text: String
    let sort_order: Int
}

/// Params for cast_poll_vote RPC
private struct CastPollVoteParams: Encodable {
    let p_poll_id: String
    let p_option_ids: [String]
}

/// Result from cast_poll_vote RPC
private struct CastPollVoteResult: Codable {
    let pollId: UUID
    let totalVotes: Int
    let userVotes: [UUID]?
    let options: [CastPollVoteOption]

    enum CodingKeys: String, CodingKey {
        case pollId = "poll_id"
        case totalVotes = "total_votes"
        case userVotes = "user_votes"
        case options
    }
}

private struct CastPollVoteOption: Codable {
    let id: UUID
    let optionText: String
    let votesCount: Int
    let percentage: Double

    enum CodingKeys: String, CodingKey {
        case id
        case optionText = "option_text"
        case votesCount = "votes_count"
        case percentage
    }
}

/// Parameters for the get_poll_results RPC
private struct PollResultsParams: Encodable {
    let pPollId: UUID
    let pProfileId: UUID

    enum CodingKeys: String, CodingKey {
        case pPollId = "p_poll_id"
        case pProfileId = "p_profile_id"
    }
}

/// DTO for decoding the get_poll_results RPC response
private struct PollResultsDTO: Decodable {
    let poll: ForumPoll
    let options: [ForumPollOption]
    let totalVotes: Int
    let voterCount: Int
    let userVotedOptionIds: [UUID]

    enum CodingKeys: String, CodingKey {
        case poll
        case options
        case totalVotes = "total_votes"
        case voterCount = "voter_count"
        case userVotedOptionIds = "user_voted_option_ids"
    }
}

// MARK: - Forum Poll Error

/// Errors that can occur during forum poll operations.
///
/// Thread-safe for Swift 6 concurrency.
enum ForumPollError: LocalizedError, Sendable {
    /// Poll does not exist
    case pollNotFound
    /// Poll has expired
    case pollEnded
    /// User has already voted
    case alreadyVoted
    /// Selected option is invalid
    case invalidOption
    /// Exceeded vote limit for single-choice poll
    case voteLimitExceeded

    var errorDescription: String? {
        switch self {
        case .pollNotFound:
            "Poll not found"
        case .pollEnded:
            "This poll has ended"
        case .alreadyVoted:
            "You have already voted in this poll"
        case .invalidOption:
            "Invalid poll option"
        case .voteLimitExceeded:
            "You can only select one option in a single-choice poll"
        }
    }
}

#endif
