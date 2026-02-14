//
//  ForumRealtimeService.swift
//  Foodshare
//
//  Real-time service for forum features
//  Supports live updates for posts, comments, and reactions
//

import Foundation
@preconcurrency import Realtime
import Supabase

// MARK: - Real-time Change Types

/// Types of real-time changes for forum content
enum ForumRealtimeChange<T: Sendable>: Sendable {
    case inserted(T)
    case updated(T)
    case deleted(Int)
}

/// Subscription identifier for managing multiple subscriptions
struct ForumSubscriptionId: Hashable, Sendable {
    let type: SubscriptionType
    let targetId: Int?

    enum SubscriptionType: Hashable, Sendable {
        case allPosts
        case post(Int)
        case comments(forumId: Int)
        case reactions(forumId: Int)
        case commentReactions(commentId: Int)
    }
}

// MARK: - Forum Realtime Service Protocol

/// Protocol for forum real-time operations
protocol ForumRealtimeService: Sendable {
    /// Subscribe to all forum post changes
    func subscribeToAllPosts() async throws -> AsyncStream<ForumRealtimeChange<ForumPost>>

    /// Subscribe to changes for a specific post
    func subscribeToPost(forumId: Int) async throws -> AsyncStream<ForumRealtimeChange<ForumPost>>

    /// Subscribe to comments for a specific post
    func subscribeToComments(forumId: Int) async throws -> AsyncStream<ForumRealtimeChange<ForumComment>>

    /// Subscribe to reactions for a specific post
    func subscribeToPostReactions(forumId: Int) async throws -> AsyncStream<ForumRealtimeChange<ForumReaction>>

    /// Subscribe to reactions for a specific comment
    func subscribeToCommentReactions(commentId: Int) async throws
        -> AsyncStream<ForumRealtimeChange<ForumCommentReaction>>

    /// Unsubscribe from a specific subscription
    func unsubscribe(from subscriptionId: ForumSubscriptionId) async

    /// Unsubscribe from all forum subscriptions
    func unsubscribeAll() async
}

// Note: ForumReaction and ForumCommentReaction are defined in ForumReaction.swift

// MARK: - Supabase Implementation

/// Supabase Realtime implementation for forum features
actor SupabaseForumRealtimeService: ForumRealtimeService {
    private let client: SupabaseClient
    private var channels: [ForumSubscriptionId: RealtimeChannelV2] = [:]
    private var continuations: [ForumSubscriptionId: Any] = [:]

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - All Posts Subscription

    func subscribeToAllPosts() async throws -> AsyncStream<ForumRealtimeChange<ForumPost>> {
        let subscriptionId = ForumSubscriptionId(type: .allPosts, targetId: nil)

        // Unsubscribe from existing if any
        await unsubscribe(from: subscriptionId)

        let channel = client.realtimeV2.channel("forum_posts_all")

        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "forum",
        )

        let updates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "forum",
        )

        let deletions = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "forum",
        )

        try await channel.subscribeWithError()
        channels[subscriptionId] = channel

        return AsyncStream { [weak self] continuation in
            Task { [weak self] in
                await self?.storeContinuation(continuation, for: subscriptionId)
            }

            // Handle insertions
            Task {
                for await insertion in insertions {
                    if let post = try? insertion.decodeRecord(as: ForumPost.self, decoder: .forumDecoder) {
                        continuation.yield(.inserted(post))
                    }
                }
            }

            // Handle updates
            Task {
                for await update in updates {
                    if let post = try? update.decodeRecord(as: ForumPost.self, decoder: .forumDecoder) {
                        continuation.yield(.updated(post))
                    }
                }
            }

            // Handle deletions
            Task {
                for await deletion in deletions {
                    if let id = deletion.oldRecord["id"]?.intValue {
                        continuation.yield(.deleted(id))
                    }
                }
            }

            continuation.onTermination = { @Sendable [weak self] _ in
                Task { [weak self] in
                    await self?.unsubscribe(from: subscriptionId)
                }
            }
        }
    }

    // MARK: - Single Post Subscription

    func subscribeToPost(forumId: Int) async throws -> AsyncStream<ForumRealtimeChange<ForumPost>> {
        let subscriptionId = ForumSubscriptionId(type: .post(forumId), targetId: forumId)

        await unsubscribe(from: subscriptionId)

        let channel = client.realtimeV2.channel("forum_post_\(forumId)")

        let updates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "forum",
            filter: "id=eq.\(forumId)",
        )

        let deletions = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "forum",
            filter: "id=eq.\(forumId)",
        )

        try await channel.subscribeWithError()
        channels[subscriptionId] = channel

        return AsyncStream { [weak self] continuation in
            Task { [weak self] in
                await self?.storeContinuation(continuation, for: subscriptionId)
            }

            Task {
                for await update in updates {
                    if let post = try? update.decodeRecord(as: ForumPost.self, decoder: .forumDecoder) {
                        continuation.yield(.updated(post))
                    }
                }
            }

            Task {
                for await deletion in deletions {
                    if let id = deletion.oldRecord["id"]?.intValue {
                        continuation.yield(.deleted(id))
                    }
                }
            }

            continuation.onTermination = { @Sendable [weak self] _ in
                Task { [weak self] in
                    await self?.unsubscribe(from: subscriptionId)
                }
            }
        }
    }

    // MARK: - Comments Subscription

    func subscribeToComments(forumId: Int) async throws -> AsyncStream<ForumRealtimeChange<ForumComment>> {
        let subscriptionId = ForumSubscriptionId(type: .comments(forumId: forumId), targetId: forumId)

        await unsubscribe(from: subscriptionId)

        let channel = client.realtimeV2.channel("forum_comments_\(forumId)")

        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "comments",
            filter: "forum_id=eq.\(forumId)",
        )

        let updates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "comments",
            filter: "forum_id=eq.\(forumId)",
        )

        let deletions = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "comments",
            filter: "forum_id=eq.\(forumId)",
        )

        try await channel.subscribeWithError()
        channels[subscriptionId] = channel

        return AsyncStream { [weak self] continuation in
            Task { [weak self] in
                await self?.storeContinuation(continuation, for: subscriptionId)
            }

            Task {
                for await insertion in insertions {
                    if let comment = try? insertion.decodeRecord(as: ForumComment.self, decoder: .forumDecoder) {
                        continuation.yield(.inserted(comment))
                    }
                }
            }

            Task {
                for await update in updates {
                    if let comment = try? update.decodeRecord(as: ForumComment.self, decoder: .forumDecoder) {
                        continuation.yield(.updated(comment))
                    }
                }
            }

            Task {
                for await deletion in deletions {
                    if let id = deletion.oldRecord["id"]?.intValue {
                        continuation.yield(.deleted(id))
                    }
                }
            }

            continuation.onTermination = { @Sendable [weak self] _ in
                Task { [weak self] in
                    await self?.unsubscribe(from: subscriptionId)
                }
            }
        }
    }

    // MARK: - Post Reactions Subscription

    func subscribeToPostReactions(forumId: Int) async throws -> AsyncStream<ForumRealtimeChange<ForumReaction>> {
        let subscriptionId = ForumSubscriptionId(type: .reactions(forumId: forumId), targetId: forumId)

        await unsubscribe(from: subscriptionId)

        let channel = client.realtimeV2.channel("forum_reactions_\(forumId)")

        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "forum_reactions",
            filter: "forum_id=eq.\(forumId)",
        )

        let deletions = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "forum_reactions",
            filter: "forum_id=eq.\(forumId)",
        )

        try await channel.subscribeWithError()
        channels[subscriptionId] = channel

        return AsyncStream { [weak self] continuation in
            Task { [weak self] in
                await self?.storeContinuation(continuation, for: subscriptionId)
            }

            Task {
                for await insertion in insertions {
                    if let reaction = try? insertion.decodeRecord(as: ForumReaction.self, decoder: .forumDecoder) {
                        continuation.yield(.inserted(reaction))
                    }
                }
            }

            Task {
                for await deletion in deletions {
                    // ForumReaction uses UUID for id
                    if let idString = deletion.oldRecord["id"]?.stringValue,
                       let uuid = UUID(uuidString: idString) {
                        // Convert UUID hash to Int for the change type
                        continuation.yield(.deleted(uuid.hashValue))
                    }
                }
            }

            continuation.onTermination = { @Sendable [weak self] _ in
                Task { [weak self] in
                    await self?.unsubscribe(from: subscriptionId)
                }
            }
        }
    }

    // MARK: - Comment Reactions Subscription

    func subscribeToCommentReactions(commentId: Int) async throws
        -> AsyncStream<ForumRealtimeChange<ForumCommentReaction>> {
        let subscriptionId = ForumSubscriptionId(type: .commentReactions(commentId: commentId), targetId: commentId)

        await unsubscribe(from: subscriptionId)

        let channel = client.realtimeV2.channel("forum_comment_reactions_\(commentId)")

        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "forum_comment_reactions",
            filter: "comment_id=eq.\(commentId)",
        )

        let deletions = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "forum_comment_reactions",
            filter: "comment_id=eq.\(commentId)",
        )

        try await channel.subscribeWithError()
        channels[subscriptionId] = channel

        return AsyncStream { [weak self] continuation in
            Task { [weak self] in
                await self?.storeContinuation(continuation, for: subscriptionId)
            }

            Task {
                for await insertion in insertions {
                    if let reaction = try? insertion.decodeRecord(
                        as: ForumCommentReaction.self,
                        decoder: .forumDecoder,
                    ) {
                        continuation.yield(.inserted(reaction))
                    }
                }
            }

            Task {
                for await deletion in deletions {
                    // ForumCommentReaction uses UUID for id
                    if let idString = deletion.oldRecord["id"]?.stringValue,
                       let uuid = UUID(uuidString: idString) {
                        continuation.yield(.deleted(uuid.hashValue))
                    }
                }
            }

            continuation.onTermination = { @Sendable [weak self] _ in
                Task { [weak self] in
                    await self?.unsubscribe(from: subscriptionId)
                }
            }
        }
    }

    // MARK: - Unsubscribe

    func unsubscribe(from subscriptionId: ForumSubscriptionId) async {
        if let channel = channels[subscriptionId] {
            await channel.unsubscribe()
            channels.removeValue(forKey: subscriptionId)
        }
        continuations.removeValue(forKey: subscriptionId)
    }

    func unsubscribeAll() async {
        for (_, channel) in channels {
            await channel.unsubscribe()
        }
        channels.removeAll()
        continuations.removeAll()
    }

    // MARK: - Private Helpers

    private func storeContinuation(
        _ continuation: AsyncStream<ForumRealtimeChange<some Any>>.Continuation,
        for subscriptionId: ForumSubscriptionId,
    ) {
        continuations[subscriptionId] = continuation
    }
}

// MARK: - JSON Decoder Extension

extension JSONDecoder {
    fileprivate static var forumDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds first
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Fall back to standard ISO8601
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(dateString)",
            )
        }
        return decoder
    }
}

// MARK: - AnyJSON Extension for Value Extraction

extension AnyJSON {
    fileprivate var intValue: Int? {
        switch self {
        case let .integer(value):
            value
        case let .double(value):
            Int(value)
        case let .string(value):
            Int(value)
        default:
            nil
        }
    }

    fileprivate var stringValue: String? {
        switch self {
        case let .string(value):
            value
        default:
            nil
        }
    }
}

// MARK: - Mock Implementation for Testing

#if DEBUG
    final class MockForumRealtimeService: ForumRealtimeService, @unchecked Sendable {
        nonisolated(unsafe) var mockPostChanges: [ForumRealtimeChange<ForumPost>] = []
        nonisolated(unsafe) var mockCommentChanges: [ForumRealtimeChange<ForumComment>] = []
        nonisolated(unsafe) var mockReactionChanges: [ForumRealtimeChange<ForumReaction>] = []
        nonisolated(unsafe) var mockCommentReactionChanges: [ForumRealtimeChange<ForumCommentReaction>] = []
        nonisolated(unsafe) var subscribeToAllPostsCalled = false
        nonisolated(unsafe) var subscribeToPostCalled = false
        nonisolated(unsafe) var subscribeToCommentsCalled = false
        nonisolated(unsafe) var unsubscribeCalled = false

        func subscribeToAllPosts() async throws -> AsyncStream<ForumRealtimeChange<ForumPost>> {
            subscribeToAllPostsCalled = true
            let changes = mockPostChanges
            return AsyncStream { continuation in
                for change in changes {
                    continuation.yield(change)
                }
            }
        }

        func subscribeToPost(forumId: Int) async throws -> AsyncStream<ForumRealtimeChange<ForumPost>> {
            subscribeToPostCalled = true
            let changes = mockPostChanges
            return AsyncStream { continuation in
                for change in changes {
                    continuation.yield(change)
                }
            }
        }

        func subscribeToComments(forumId: Int) async throws -> AsyncStream<ForumRealtimeChange<ForumComment>> {
            subscribeToCommentsCalled = true
            let changes = mockCommentChanges
            return AsyncStream { continuation in
                for change in changes {
                    continuation.yield(change)
                }
            }
        }

        func subscribeToPostReactions(forumId: Int) async throws -> AsyncStream<ForumRealtimeChange<ForumReaction>> {
            let changes = mockReactionChanges
            return AsyncStream { continuation in
                for change in changes {
                    continuation.yield(change)
                }
            }
        }

        func subscribeToCommentReactions(commentId: Int) async throws
            -> AsyncStream<ForumRealtimeChange<ForumCommentReaction>> {
            let changes = mockCommentReactionChanges
            return AsyncStream { continuation in
                for change in changes {
                    continuation.yield(change)
                }
            }
        }

        func unsubscribe(from subscriptionId: ForumSubscriptionId) async {
            unsubscribeCalled = true
        }

        func unsubscribeAll() async {
            unsubscribeCalled = true
        }
    }
#endif
