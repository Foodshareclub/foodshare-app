//
//  ChatViewModel.swift
//  Foodshare
//
//  ViewModel for individual chat conversation
//  Enhanced with typing indicators and read receipts
//

import Foundation
import Observation
import Supabase

/// Read receipt status for messages
enum ReadReceiptStatus: Sendable {
    case sent // Single gray checkmark
    case delivered // Double gray checkmarks
    case read // Double blue/green checkmarks
}

@MainActor
@Observable
final class ChatViewModel {
    // MARK: - State

    var messages: [Message] = []
    var messageText = ""
    var isLoading = false
    var isSending = false
    var error: String?
    var showError = false

    // MARK: - Presence State

    /// Whether the other user is currently typing
    var isOtherUserTyping = false

    /// Online status of the other user
    var otherUserOnlineStatus: OnlineStatus = .offline

    /// Read receipt status for the last message
    var lastMessageReadStatus: ReadReceiptStatus = .sent

    // MARK: - Room Info

    let room: Room
    let currentUserId: UUID

    // MARK: - Dependencies

    private let repository: MessagingRepository
    private let sendMessageUseCase: SendMessageUseCase
    private let markSeenUseCase: MarkMessagesSeenUseCase
    private let presenceService: ChatPresenceService

    // MARK: - Private State

    private var typingDebounceTask: Task<Void, Never>?
    private var presenceTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        room: Room,
        currentUserId: UUID,
        repository: MessagingRepository,
        sendMessageUseCase: SendMessageUseCase,
        markSeenUseCase: MarkMessagesSeenUseCase,
        presenceService: ChatPresenceService,
    ) {
        self.room = room
        self.currentUserId = currentUserId
        self.repository = repository
        self.sendMessageUseCase = sendMessageUseCase
        self.markSeenUseCase = markSeenUseCase
        self.presenceService = presenceService
    }

    // MARK: - Computed Properties

    var otherUserId: UUID {
        room.otherParticipant(currentUserId: currentUserId)
    }

    var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    /// Status text for typing indicator
    var typingStatusText: String? {
        isOtherUserTyping ? "typing..." : nil
    }

    // MARK: - Actions

    func loadMessages() async {
        isLoading = true
        error = nil
        showError = false
        defer { isLoading = false }

        do {
            messages = try await repository.fetchMessages(roomId: room.id, limit: 50, offset: 0)

            // Mark messages as seen
            try await markSeenUseCase.execute(roomId: room.id, userId: currentUserId)

            // Update read status
            updateReadStatus()

            // Subscribe to new messages
            try await repository.subscribeToMessages(roomId: room.id) { [weak self] message in
                Task { @MainActor in
                    self?.handleNewMessage(message)
                }
            }

            // Join presence channel and start observing
            await joinPresenceChannel()

        } catch {
            self.error = error.localizedDescription
            showError = true
            await AppLogger.shared.error("Failed to load messages", error: error)
        }
    }

    // MARK: - Presence

    private func joinPresenceChannel() async {
        do {
            try await presenceService.joinRoom(roomId: room.id, userId: currentUserId)

            // Start observing presence updates
            presenceTask = Task { [weak self] in
                guard let self else { return }
                let stream = await presenceService.presenceUpdates()

                for await presences in stream {
                    guard !Task.isCancelled else { break }
                    await handlePresenceUpdate(presences)
                }
            }
        } catch {
            await AppLogger.shared.error("Failed to join presence channel", error: error)
        }
    }

    private func handlePresenceUpdate(_ presences: [UserPresence]) async {
        // Find the other user's presence
        if let otherPresence = presences.first(where: { $0.userId == otherUserId }) {
            isOtherUserTyping = otherPresence.isTyping
            otherUserOnlineStatus = await presenceService.onlineStatus(for: otherUserId)
        } else {
            isOtherUserTyping = false
            otherUserOnlineStatus = .offline
        }
    }

    func loadMoreMessages() async {
        guard !isLoading, !messages.isEmpty else { return }

        do {
            let olderMessages = try await repository.fetchMessages(
                roomId: room.id,
                limit: 50,
                offset: messages.count,
            )
            messages.insert(contentsOf: olderMessages, at: 0)
        } catch {
            await AppLogger.shared.error("Failed to load more messages", error: error)
        }
    }

    func sendMessage() async {
        guard canSend else { return }

        isSending = true
        let content = messageText
        messageText = ""

        // Stop typing indicator immediately
        await stopTyping()

        defer { isSending = false }

        do {
            let message = try await sendMessageUseCase.execute(
                roomId: room.id,
                profileId: currentUserId,
                text: content,
                image: nil,
            )

            // Message will be added via real-time subscription
            // But add optimistically for immediate feedback
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
            }

            // Update read status (sent)
            lastMessageReadStatus = .sent
        } catch {
            self.error = error.localizedDescription
            showError = true
            messageText = content // Restore message on error
            await AppLogger.shared.error("Failed to send message", error: error)
        }
    }

    func sendImage(_ imageUrl: String) async {
        isSending = true
        defer { isSending = false }

        do {
            let message = try await sendMessageUseCase.execute(
                roomId: room.id,
                profileId: currentUserId,
                text: "",
                image: imageUrl,
            )
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
            }
            lastMessageReadStatus = .sent
        } catch {
            self.error = error.localizedDescription
            showError = true
            await AppLogger.shared.error("Failed to send image", error: error)
        }
    }

    // MARK: - Typing Indicator

    /// Called when user types in the message field
    func onTextChange() {
        // Debounce typing indicator updates
        typingDebounceTask?.cancel()
        typingDebounceTask = Task {
            await startTyping()

            // Auto-stop after delay if no more typing
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            guard !Task.isCancelled else { return }
            await stopTyping()
        }
    }

    private func startTyping() async {
        do {
            try await presenceService.setTyping(true)
        } catch {
            await AppLogger.shared.debug("Failed to set typing status: \(error)")
        }
    }

    private func stopTyping() async {
        typingDebounceTask?.cancel()
        do {
            try await presenceService.setTyping(false)
        } catch {
            await AppLogger.shared.debug("Failed to clear typing status: \(error)")
        }
    }

    // MARK: - Read Receipts

    /// Get read receipt status for a specific message
    func readStatus(for message: Message) -> ReadReceiptStatus {
        // Only show read receipts for messages from current user
        guard message.profileId == currentUserId else {
            return .sent
        }

        // Check if the other user has seen this message
        if let lastSeenBy = room.lastMessageSeenBy,
           lastSeenBy == otherUserId,
           let lastSeenTime = room.lastMessageTime,
           message.timestamp <= lastSeenTime {
            return .read
        }

        // If message was sent successfully, it's at least delivered
        return .delivered
    }

    private func updateReadStatus() {
        guard let lastMessage = messages.last,
              lastMessage.profileId == currentUserId else {
            return
        }

        lastMessageReadStatus = readStatus(for: lastMessage)
    }

    // MARK: - Cleanup

    func dismissError() {
        error = nil
        showError = false
    }

    func cleanup() {
        repository.unsubscribeFromMessages()
        typingDebounceTask?.cancel()
        presenceTask?.cancel()
        presenceTask = nil

        Task {
            await presenceService.leaveRoom()
        }
    }

    // MARK: - Private

    private func handleNewMessage(_ message: Message) {
        // Avoid duplicates
        guard !messages.contains(where: { $0.id == message.id }) else { return }

        messages.append(message)

        // Clear typing indicator when message is received
        if message.profileId == otherUserId {
            isOtherUserTyping = false
        }

        // Mark as seen if from other user
        if message.profileId != currentUserId {
            Task {
                try? await markSeenUseCase.execute(roomId: room.id, userId: currentUserId)
            }
        }

        // Update read status for sent messages
        updateReadStatus()
    }

    /// Check if a message is from the current user
    func isFromCurrentUser(_ message: Message) -> Bool {
        message.profileId == currentUserId
    }
}

// MARK: - Convenience Initializer

extension ChatViewModel {
    /// Convenience initializer with repository only
    convenience init(room: Room, currentUserId: UUID, repository: MessagingRepository, supabaseClient: SupabaseClient) {
        self.init(
            room: room,
            currentUserId: currentUserId,
            repository: repository,
            sendMessageUseCase: SendMessageUseCase(repository: repository),
            markSeenUseCase: MarkMessagesSeenUseCase(repository: repository),
            presenceService: SupabaseChatPresenceService(client: supabaseClient),
        )
    }
}
