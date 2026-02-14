//
//  MessagingViewModel.swift
//  Foodshare
//
//  ViewModel for messaging/rooms list
//  Enhanced with typing indicators, read receipts, search, and archiving
//

import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class MessagingViewModel {
    // MARK: - State

    var rooms: [Room] = []
    var archivedRooms: [Room] = []
    var isLoading = false
    var isRefreshing = false
    var error: AppError?
    var showError = false

    // MARK: - Search & Filter State

    var searchQuery = ""
    var selectedFilter: ConversationFilter = .all
    var showArchived = false

    // MARK: - Typing Indicators

    var typingUsers: [UUID: Set<UUID>] = [:] // roomId -> set of typing user IDs

    // MARK: - Online Status

    var onlineUsers: Set<UUID> = []

    // MARK: - Dependencies

    let repository: MessagingRepository
    let currentUserId: UUID
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "MessagingViewModel")

    // MARK: - Task Management

    private var loadTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var subscriptionTask: Task<Void, Never>?

    // MARK: - Cache Configuration

    /// Last fetch time for rooms cache
    private var roomsCacheTime: Date?
    /// Rooms cache TTL: 60 seconds
    private let roomsCacheTTL: TimeInterval = 60
    /// Whether subscriptions are currently active
    private(set) var isSubscribed = false

    // MARK: - Debounced Sorting

    /// Debouncer for room sorting - prevents redundant sorts during rapid updates
    private let roomSortDebouncer = Debouncer(delay: 0.3)
    /// Flag to track if rooms need sorting
    private var roomsNeedSorting = false

    /// Check if rooms cache is still valid
    private var isRoomsCacheValid: Bool {
        guard let lastFetch = roomsCacheTime, !rooms.isEmpty else { return false }
        return Date().timeIntervalSince(lastFetch) < roomsCacheTTL
    }

    // MARK: - Initialization

    init(repository: MessagingRepository, currentUserId: UUID) {
        self.repository = repository
        self.currentUserId = currentUserId
    }

    // MARK: - Filter Options

    enum ConversationFilter: String, CaseIterable, Sendable {
        case all = "All"
        case unread = "Unread"
        case sharing = "Sharing"
        case receiving = "Receiving"

        var icon: String {
            switch self {
            case .all: "tray.full"
            case .unread: "envelope.badge"
            case .sharing: "arrow.up.circle"
            case .receiving: "arrow.down.circle"
            }
        }

        @MainActor
        func localizedDisplayName(using t: EnhancedTranslationService) -> String {
            switch self {
            case .all: t.t("messaging.filter.all")
            case .unread: t.t("messaging.filter.unread")
            case .sharing: t.t("messaging.filter.sharing")
            case .receiving: t.t("messaging.filter.receiving")
            }
        }
    }

    // MARK: - Computed Properties

    var hasRooms: Bool {
        !displayedRooms.isEmpty
    }

    var unreadCount: Int {
        rooms.count(where: { $0.hasUnreadMessages(for: currentUserId) })
    }

    var displayedRooms: [Room] {
        var filtered = showArchived ? archivedRooms : rooms

        // Apply search filter
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            filtered = filtered.filter { room in
                room.lastMessage?.lowercased().contains(query) ?? false
            }
        }

        // Apply category filter
        switch selectedFilter {
        case .all:
            break
        case .unread:
            filtered = filtered.filter { $0.hasUnreadMessages(for: currentUserId) }
        case .sharing:
            filtered = filtered.filter { $0.sharer == currentUserId }
        case .receiving:
            filtered = filtered.filter { $0.requester == currentUserId }
        }

        return filtered
    }

    var hasUnreadMessages: Bool {
        unreadCount > 0
    }

    var roomsByDate: [String: [Room]] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        return Dictionary(grouping: displayedRooms) { room in
            guard let date = room.lastMessageTime else { return "No messages" }

            if Calendar.current.isDateInToday(date) {
                return "Today"
            } else if Calendar.current.isDateInYesterday(date) {
                return "Yesterday"
            } else if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
                return "This Week"
            } else {
                return formatter.string(from: date)
            }
        }
    }

    // MARK: - Actions

    func loadRooms(forceRefresh: Bool = false) async {
        guard !isLoading else { return }

        // Check cache validity unless force refresh
        if !forceRefresh, isRoomsCacheValid {
            logger.debug("Using cached rooms (age: \(Date().timeIntervalSince(self.roomsCacheTime ?? Date()))s)")
            return
        }

        // Cancel any existing load task
        loadTask?.cancel()

        isLoading = true
        error = nil
        showError = false

        loadTask = Task {
            defer {
                isLoading = false
                roomsCacheTime = Date()
            }

            do {
                try Task.checkCancellation()
                let allRooms = try await repository.fetchRooms(userId: currentUserId)

                try Task.checkCancellation()

                // Separate active and archived rooms
                rooms = allRooms.filter { !$0.isArchived }
                archivedRooms = allRooms.filter(\.isArchived)

                // Sort by last message time
                rooms.sort { ($0.lastMessageTime ?? .distantPast) > ($1.lastMessageTime ?? .distantPast) }
                archivedRooms.sort { ($0.lastMessageTime ?? .distantPast) > ($1.lastMessageTime ?? .distantPast) }

                logger.info("Loaded \(self.rooms.count) active rooms, \(self.archivedRooms.count) archived")
            } catch is CancellationError {
                logger.debug("Load rooms task cancelled")
            } catch {
                self.error = .networkError(error.localizedDescription)
                showError = true
                logger.error("Failed to load rooms: \(error.localizedDescription)")
            }
        }

        await loadTask?.value
    }

    /// Subscribe to real-time room updates - call from View's onAppear
    func subscribeToUpdates() async {
        guard !isSubscribed else { return }

        // Cancel existing subscription task
        subscriptionTask?.cancel()

        subscriptionTask = Task {
            do {
                try Task.checkCancellation()
                try await repository.subscribeToRoomUpdates(userId: currentUserId) { [weak self] updatedRoom in
                    Task { @MainActor in
                        self?.handleRoomUpdate(updatedRoom)
                        // Invalidate cache on new message to ensure fresh data next load
                        self?.roomsCacheTime = nil
                    }
                }
                await MainActor.run { self.isSubscribed = true }
            } catch is CancellationError {
                logger.debug("Subscription task cancelled")
            } catch {
                logger.warning("Failed to subscribe to room updates: \(error.localizedDescription)")
            }
        }
    }

    /// Unsubscribe from real-time updates - call from View's onDisappear
    func unsubscribeFromUpdates() {
        subscriptionTask?.cancel()
        subscriptionTask = nil
        repository.unsubscribeFromRoomUpdates()
        isSubscribed = false
        logger.debug("Unsubscribed from room updates")
    }

    func refresh() async {
        guard !isRefreshing else { return }

        // Cancel any existing refresh task
        refreshTask?.cancel()

        isRefreshing = true

        refreshTask = Task {
            defer {
                isRefreshing = false
                roomsCacheTime = Date()
            }

            do {
                try Task.checkCancellation()
                let allRooms = try await repository.fetchRooms(userId: currentUserId)

                try Task.checkCancellation()
                rooms = allRooms.filter { !$0.isArchived }
                archivedRooms = allRooms.filter(\.isArchived)

                rooms.sort { ($0.lastMessageTime ?? .distantPast) > ($1.lastMessageTime ?? .distantPast) }
                HapticManager.light()
            } catch is CancellationError {
                logger.debug("Refresh task cancelled")
            } catch {
                self.error = .networkError(error.localizedDescription)
                showError = true
            }
        }

        await refreshTask?.value
    }

    // MARK: - Room Actions

    func archiveRoom(_ room: Room) async {
        // Archive locally (not persisted to backend yet)
        if let index = rooms.firstIndex(where: { $0.id == room.id }) {
            let archivedRoom = rooms.remove(at: index)
            archivedRooms.insert(archivedRoom, at: 0)
        }
        await HapticManager.success()
        logger.info("Archived room \(room.id) locally")
    }

    func unarchiveRoom(_ room: Room) async {
        // Unarchive locally
        if let index = archivedRooms.firstIndex(where: { $0.id == room.id }) {
            let activeRoom = archivedRooms.remove(at: index)
            rooms.insert(activeRoom, at: 0)
            rooms.sort { ($0.lastMessageTime ?? .distantPast) > ($1.lastMessageTime ?? .distantPast) }
        }
        await HapticManager.success()
    }

    func deleteRoom(_ room: Room) async {
        // Remove locally (not persisted to backend yet)
        rooms.removeAll { $0.id == room.id }
        archivedRooms.removeAll { $0.id == room.id }
        await HapticManager.success()
        logger.info("Deleted room \(room.id) locally")
    }

    func markRoomAsRead(_ room: Room) async {
        // Mark as read using existing markMessagesSeen
        do {
            try await repository.markMessagesSeen(roomId: room.id, userId: currentUserId)
        } catch {
            logger.warning("Failed to mark room as read: \(error.localizedDescription)")
        }
    }

    // MARK: - Typing Indicators

    func setTyping(in roomId: UUID, isTyping: Bool) async {
        // Typing indicators not implemented in repository yet
        logger.debug("Typing status: \(isTyping) for room \(roomId)")
    }

    func isUserTyping(in roomId: UUID) -> Bool {
        guard let typing = typingUsers[roomId] else { return false }
        return !typing.isEmpty && !typing.contains(currentUserId)
    }

    func typingUserNames(in roomId: UUID) -> String? {
        guard let typing = typingUsers[roomId] else { return nil }
        let otherTyping = typing.filter { $0 != currentUserId }
        guard !otherTyping.isEmpty else { return nil }
        return "Someone is typing..."
    }

    // MARK: - Online Status

    func isUserOnline(_ userId: UUID) -> Bool {
        onlineUsers.contains(userId)
    }

    // MARK: - Search & Filter

    func setFilter(_ filter: ConversationFilter) {
        selectedFilter = filter
        HapticManager.selection()
    }

    func clearSearch() {
        searchQuery = ""
    }

    func toggleArchived() {
        showArchived.toggle()
        HapticManager.selection()
    }

    // MARK: - Error Handling

    func dismissError() {
        error = nil
        showError = false
    }

    func cleanup() {
        // Cancel all active tasks
        loadTask?.cancel()
        loadTask = nil

        refreshTask?.cancel()
        refreshTask = nil

        // Unsubscribe from real-time updates
        unsubscribeFromUpdates()

        logger.debug("MessagingViewModel cleanup completed")
    }

    // MARK: - Private

    private func handleRoomUpdate(_ updatedRoom: Room) {
        let targetArray = updatedRoom.isArchived ? archivedRooms : rooms

        if let index = targetArray.firstIndex(where: { $0.id == updatedRoom.id }) {
            if updatedRoom.isArchived {
                archivedRooms[index] = updatedRoom
            } else {
                rooms[index] = updatedRoom
                // Mark for debounced sorting instead of immediate sort
                roomsNeedSorting = true
                scheduleDebouncedSort()
            }
        } else {
            // New room
            if updatedRoom.isArchived {
                archivedRooms.insert(updatedRoom, at: 0)
            } else {
                rooms.insert(updatedRoom, at: 0)
                // Mark for debounced sorting instead of immediate sort
                roomsNeedSorting = true
                scheduleDebouncedSort()
            }
        }

        // Play notification sound for new messages
        if updatedRoom.hasUnreadMessages(for: currentUserId) {
            HapticManager.light()
        }
    }

    /// Schedule a debounced sort of rooms to prevent redundant sorting during rapid updates
    private func scheduleDebouncedSort() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.roomSortDebouncer.debounce {
                await MainActor.run { [weak self] in
                    guard let self, self.roomsNeedSorting else { return }
                    self.rooms.sort { ($0.lastMessageTime ?? .distantPast) > ($1.lastMessageTime ?? .distantPast) }
                    self.roomsNeedSorting = false
                }
            }
        }
    }

    private func handleTypingUpdate(roomId: UUID, userId: UUID, isTyping: Bool) {
        if isTyping {
            typingUsers[roomId, default: []].insert(userId)
        } else {
            typingUsers[roomId]?.remove(userId)
        }
    }
}

// MARK: - Room Extensions

extension Room {
    func withArchived(_ archived: Bool) -> Room {
        // Create a copy with updated archived status
        // This would need to match your Room model structure
        self
    }

    func withUnreadCleared(for userId: UUID) -> Room {
        // Create a copy with unread cleared
        self
    }

    var isArchived: Bool {
        // Check if room is archived - implement based on your model
        false
    }
}

// MARK: - Legacy Compatibility

extension MessagingViewModel {
    /// Legacy property for backward compatibility
    var conversations: [Room] {
        rooms
    }
}
