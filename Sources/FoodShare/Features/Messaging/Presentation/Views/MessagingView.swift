//
//  MessagingView.swift
//  Foodshare
//
//  Messaging view with Liquid Glass v26 design
//  Enhanced with search, filters, and conversation management
//



#if !SKIP
import SwiftUI

#if DEBUG
    import Inject
#endif

struct MessagingView: View {

    @Environment(\.translationService) private var t
    @Environment(AppState.self) private var appState
    @State private var viewModel: MessagingViewModel
    @State private var hasAppeared = false
    @State private var showDeleteConfirmation = false
    @State private var roomToDelete: Room?
    @State private var isSearchActive = false
    @State private var searchText = ""
    @State private var showFilters = false
    @State private var showAppInfo = false
    @State private var showNotifications = false
    @State private var notificationsViewModel: NotificationsViewModel?
    @State private var unreadNotificationCount = 0
    @FocusState private var isSearchFocused: Bool

    init(viewModel: MessagingViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [
                        Color.DesignSystem.background,
                        Color.DesignSystem.surface.opacity(0.5),
                    ],
                    startPoint: .top,
                    endPoint: .bottom,
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search header with archive toggle (matching Explore tab pattern)
                    searchHeader
                        .staggeredAppearance(index: 0, baseDelay: 0.1)

                    // Filter chips
                    filterChips
                        .staggeredAppearance(index: 1, baseDelay: 0.1)

                    // Content
                    Group {
                        if viewModel.isLoading, viewModel.rooms.isEmpty {
                            loadingView
                        } else if viewModel.hasRooms {
                            roomsList
                        } else {
                            emptyState
                        }
                    }
                }
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
            }
            .navigationBarHidden(true)
            .navigationTitle(t.t("tabs.chats"))
            .task {
                await viewModel.loadRooms()
                setupViewModels()
                await refreshNotificationCount()
                await subscribeToNotificationUpdates()
            }
            .onDisappear { viewModel.cleanup() }
            .refreshable { await viewModel.refresh() }
            #if !SKIP
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Refresh notification count when returning from background
                Task { await refreshNotificationCount() }
            }
            #endif
            .sheet(isPresented: $showFilters) {
                ChatsFilterSheet(viewModel: viewModel)
                    .presentationDetents([PresentationDetent.medium])
                    #if !SKIP
                    .presentationDragIndicator(.visible)
                    #endif
            }
            .sheet(isPresented: $showAppInfo) {
                AppInfoSheet()
            }
            .sheet(isPresented: $showNotifications) {
                if let viewModel = notificationsViewModel {
                    NotificationsView(viewModel: viewModel)
                }
            }
            .onChange(of: showNotifications) { _, isShowing in
                // Refresh notification count when sheet closes (user may have marked as read)
                if !isShowing {
                    Task { await refreshNotificationCount() }
                }
            }
            .alert(t.t("common.error.title"), isPresented: $viewModel.showError) {
                Button(t.t("common.ok")) { viewModel.dismissError() }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
            .alert(t.t("messaging.delete_conversation"), isPresented: $showDeleteConfirmation) {
                Button(t.t("common.cancel"), role: .cancel) { roomToDelete = nil }
                Button(t.t("common.delete"), role: .destructive) {
                    if let room = roomToDelete {
                        Task { await viewModel.deleteRoom(room) }
                    }
                    roomToDelete = nil
                }
            } message: {
                Text(t.t("messaging.delete_confirmation_message"))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
            }
        }
    }

    // MARK: - Setup

    private func setupViewModels() {
        // Setup NotificationsViewModel
        if notificationsViewModel == nil, let userId = appState.currentUser?.id {
            notificationsViewModel = NotificationsViewModel(
                repository: appState.dependencies.notificationRepository,
                userId: userId,
            )
        }
    }

    // MARK: - Refresh Notification Count

    private func refreshNotificationCount() async {
        guard let userId = appState.currentUser?.id else { return }

        do {
            unreadNotificationCount = try await appState.dependencies.notificationRepository
                .fetchUnreadCount(for: userId)
        } catch {
            await AppLogger.shared.error("Failed to fetch notification count", error: error)
        }
    }

    // MARK: - Real-Time Notification Subscription

    /// Subscribe to real-time notifications via Supabase Realtime.
    /// Updates the badge count when new notifications arrive.
    private func subscribeToNotificationUpdates() async {
        guard let userId = appState.currentUser?.id else { return }

        await appState.dependencies.notificationRepository.subscribeToNotifications(
            for: userId,
        ) { [self] notification in
            // Increment count for new unread notifications
            if !notification.isRead {
                unreadNotificationCount += 1
            }
        }
    }

    // MARK: - Search Header (using unified TabSearchHeader)

    private var searchHeader: some View {
        TabSearchHeader(
            searchText: $searchText,
            isSearchActive: $isSearchActive,
            isSearchFocused: $isSearchFocused,
            placeholder: t.t("messaging.search_placeholder"),
            showAppInfo: $showAppInfo,
            onSearchTextChange: { newValue in
                viewModel.searchQuery = newValue
            },
            onSearchClear: {
                viewModel.searchQuery = ""
            },
        ) {
            GlassActionButtonWithNotification(
                icon: "slider.horizontal.3",
                unreadCount: unreadNotificationCount,
                accessibilityLabel: t.t("common.filter"),
                onButtonTap: {
                    showFilters = true
                },
                onNotificationTap: {
                    showNotifications = true
                },
            )
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(MessagingViewModel.ConversationFilter.allCases, id: \.self) { filter in
                    ConversationFilterChip(
                        filter: filter,
                        isSelected: viewModel.selectedFilter == filter,
                        unreadCount: filter == .unread ? viewModel.unreadCount : nil,
                    ) {
                        viewModel.setFilter(filter)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        #if !SKIP
        .scrollBounceBehavior(.basedOnSize)
        .fixedSize(horizontal: false, vertical: true)
        #endif
    }

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: Spacing.sm) {
                ForEach(0 ..< 5, id: \.self) { index in
                    MessageSkeletonRow()
                        .staggeredAppearance(index: index)
                }
            }
            .padding(Spacing.md)
        }
    }

    private var roomsList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                // Stats header when not searching
                if viewModel.searchQuery.isEmpty, !viewModel.showArchived {
                    conversationStatsHeader
                        .staggeredAppearance(index: 0, baseDelay: 0.05)
                }

                // Group by date
                ForEach(Array(viewModel.roomsByDate.keys.sorted().enumerated()), id: \.element) { index, dateKey in
                    if let rooms = viewModel.roomsByDate[dateKey] {
                        Section {
                            ForEach(rooms) { room in
                                NavigationLink {
                                    ChatRoomView(
                                        room: room,
                                        currentUserId: viewModel.currentUserId,
                                        repository: viewModel.repository,
                                    )
                                } label: {
                                    RoomRow(
                                        room: room,
                                        currentUserId: viewModel.currentUserId,
                                        isTyping: viewModel.isUserTyping(in: room.id),
                                        isOnline: viewModel
                                            .isUserOnline(room
                                                .otherParticipant(currentUserId: viewModel.currentUserId)),
                                    )
                                }
                                #if !SKIP
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        HapticManager.warning()
                                        roomToDelete = room
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label(t.t("common.delete"), systemImage: "trash")
                                    }

                                    Button {
                                        HapticManager.medium()
                                        Task {
                                            if viewModel.showArchived {
                                                await viewModel.unarchiveRoom(room)
                                            } else {
                                                await viewModel.archiveRoom(room)
                                            }
                                            HapticManager.success()
                                        }
                                    } label: {
                                        Label(
                                            viewModel.showArchived
                                                ? t.t("messaging.unarchive")
                                                : t.t("messaging.archive"),
                                            systemImage: viewModel.showArchived ? "tray.and.arrow.up" : "archivebox",
                                        )
                                    }
                                    .tint(Color.DesignSystem.brandBlue)
                                }
                                .swipeActions(edge: .leading) {
                                    if room.hasUnreadMessages(for: viewModel.currentUserId) {
                                        Button {
                                            HapticManager.light()
                                            Task {
                                                await viewModel.markRoomAsRead(room)
                                                HapticManager.success()
                                            }
                                        } label: {
                                            Label(t.t("messaging.mark_read"), systemImage: "envelope.open")
                                        }
                                        .tint(Color.DesignSystem.brandGreen)
                                    }
                                }
                                #endif
                            }
                        } header: {
                            Text(dateKey)
                                .font(.DesignSystem.labelSmall)
                                .foregroundColor(.DesignSystem.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, index > 0 ? Spacing.sm : 0)
                        }
                    }
                }
            }
            .padding(Spacing.md)
        }
    }

    // MARK: - Conversation Stats Header

    private var conversationStatsHeader: some View {
        HStack(spacing: Spacing.md) {
            ConversationStatPill(
                icon: "tray.full",
                value: "\(viewModel.rooms.count)",
                label: t.t("messaging.stats.total"),
                color: .DesignSystem.brandBlue,
            )

            ConversationStatPill(
                icon: "envelope.badge",
                value: "\(viewModel.unreadCount)",
                label: t.t("messaging.stats.unread"),
                color: .DesignSystem.brandGreen,
            )

            ConversationStatPill(
                icon: "archivebox",
                value: "\(viewModel.archivedRooms.count)",
                label: t.t("messaging.stats.archived"),
                color: .DesignSystem.textSecondary,
            )
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                #if !SKIP
                .fill(.ultraThinMaterial)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Spacer(minLength: Spacing.xxl)

                // Animated icon with glass background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.brandGreen.opacity(0.15),
                                    Color.DesignSystem.brandBlue.opacity(0.1),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .frame(width: 120.0, height: 120)

                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                }

                VStack(spacing: Spacing.sm) {
                    Text(t.t("messages.empty"))
                        .font(.DesignSystem.displaySmall)
                        .foregroundColor(.DesignSystem.text)

                    Text(t.t("messages.empty_description"))
                        .font(.DesignSystem.bodyMedium)
                        .foregroundColor(.DesignSystem.textSecondary)
                        .multilineTextAlignment(.center)
                }

                GlassButton(
                    t.t("messaging.explore_food"),
                    icon: "magnifyingglass",
                    style: .secondary,
                ) {
                    // Navigate to explore
                }
                .frame(maxWidth: 200)
                .padding(.top, Spacing.md)

                Spacer(minLength: Spacing.xxl)
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.xl)
        }
    }
}

// MARK: - Conversation Filter Chip

struct ConversationFilterChip: View {
    @Environment(\.translationService) private var t
    let filter: MessagingViewModel.ConversationFilter
    let isSelected: Bool
    var unreadCount: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: filter.icon)
                    .font(.system(size: 12, weight: .medium))

                Text(filter.localizedDisplayName(using: t))
                    .font(.DesignSystem.labelSmall)
                    .fontWeight(isSelected ? .semibold : .medium)

                if let count = unreadCount, count > 0 {
                    Text("\(count)")
                        .font(.DesignSystem.captionSmall)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.DesignSystem.brandGreen),
                        )
                }
            }
            .foregroundColor(isSelected ? .white : .DesignSystem.text)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected
                        ? LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        )
                        : LinearGradient(
                            colors: [Color.DesignSystem.glassBackground],
                            startPoint: .top,
                            endPoint: .bottom,
                        ))
                    .overlay(
                        Capsule()
                            .stroke(
                                isSelected ? Color.clear : Color.DesignSystem.glassBorder,
                                lineWidth: 1,
                            ),
                    ),
            )
            .shadow(color: isSelected ? .DesignSystem.brandGreen.opacity(0.3) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.95, haptic: .none))
    }
}

// MARK: - Conversation Stat Pill

struct ConversationStatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(color)

                Text(value)
                    .font(.DesignSystem.headlineSmall)
                    .fontWeight(.bold)
                    .foregroundColor(.DesignSystem.text)
            }

            Text(label)
                .font(.DesignSystem.captionSmall)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Room Row (Liquid Glass Enhanced)

struct RoomRow: View {
    @Environment(\.translationService) private var t
    let room: Room
    let currentUserId: UUID
    var isTyping = false
    var isOnline = false

    private var hasUnread: Bool {
        room.hasUnreadMessages(for: currentUserId)
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.brandGreen.opacity(0.2),
                                Color.DesignSystem.brandBlue.opacity(0.15),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .frame(width: 54.0, height: 54)

                Image(systemName: "person.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )

                // Online status indicator with pulse
                if isOnline {
                    ZStack {
                        // Pulse glow
                        Circle()
                            .fill(Color.DesignSystem.success.opacity(0.4))
                            .frame(width: 16.0, height: 16)
                            .blur(radius: 4)

                        Circle()
                            .fill(Color.DesignSystem.success)
                            .frame(width: 12.0, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.DesignSystem.background, lineWidth: 2),
                            )
                    }
                    .proMotionPulse(isActive: true, color: Color.DesignSystem.success, intensity: 0.5)
                    .offset(x: 18, y: 18)
                }

                // Unread indicator with bounce
                if hasUnread {
                    Circle()
                        .fill(Color.DesignSystem.brandGreen)
                        .frame(width: 14.0, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.DesignSystem.background, lineWidth: 2),
                        )
                        .offset(x: 18, y: -18)
                        .transition(AnyTransition.scale.combined(with: AnyTransition.opacity))
                        .animation(ProMotionAnimation.bouncy, value: hasUnread)
                }
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(t.t("messaging.post_number", args: ["id": String(room.postId)]))
                        .font(.DesignSystem.bodyMedium)
                        .fontWeight(hasUnread ? .semibold : .medium)
                        .foregroundColor(.DesignSystem.text)

                    Spacer()

                    if let time = room.lastMessageTime {
                        #if !SKIP
                        Text(time, style: .relative)
                            .font(.DesignSystem.captionSmall)
                            .foregroundColor(hasUnread ? .DesignSystem.brandGreen : .DesignSystem.textTertiary)
                        #else
                        Text(timeAgoString(from: time))
                            .font(.DesignSystem.captionSmall)
                            .foregroundColor(hasUnread ? .DesignSystem.brandGreen : .DesignSystem.textTertiary)
                        #endif
                    }
                }

                if room.isArranged {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                        Text(t.t("listing.arranged"))
                            .font(.DesignSystem.captionSmall)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.DesignSystem.success)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(Color.DesignSystem.success.opacity(0.12)),
                    )
                }

                // Typing indicator or last message
                if isTyping {
                    HStack(spacing: Spacing.xxs) {
                        TypingDotsView()
                        Text(t.t("messages.typing"))
                            .font(.DesignSystem.bodySmall)
                            .foregroundColor(.DesignSystem.brandGreen)
                            .italic()
                    }
                } else if let lastMessage = room.lastMessage {
                    Text(lastMessage)
                        .font(.DesignSystem.bodySmall)
                        .foregroundColor(hasUnread ? .DesignSystem.text : .DesignSystem.textSecondary)
                        .fontWeight(hasUnread ? .medium : .regular)
                        .lineLimit(2)
                }
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.DesignSystem.textTertiary)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                #if !SKIP
                .fill(.ultraThinMaterial)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(
                            hasUnread
                                ? LinearGradient(
                                    colors: [
                                        .DesignSystem.brandGreen.opacity(0.4),
                                        .DesignSystem.brandBlue.opacity(0.2),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                )
                                : LinearGradient(
                                    colors: [Color.DesignSystem.glassBorder],
                                    startPoint: .top,
                                    endPoint: .bottom,
                                ),
                            lineWidth: hasUnread ? 1.5 : 1,
                        ),
                ),
        )
        .shadow(color: hasUnread ? .DesignSystem.brandGreen.opacity(0.1) : .clear, radius: 8, y: 2)
    }

    #if SKIP
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        if hours < 24 { return "\(hours)h ago" }
        return "\(days)d ago"
    }
    #endif
}

// MARK: - Chat Room View (Liquid Glass Enhanced)

struct ChatRoomView: View {
    @Environment(\.translationService) private var t
    @State private var viewModel: ChatViewModel
    @FocusState private var isInputFocused: Bool

    init(room: Room, currentUserId: UUID, repository: MessagingRepository) {
        _viewModel = State(initialValue: ChatViewModel(
            room: room,
            currentUserId: currentUserId,
            repository: repository,
            supabaseClient: SupabaseManager.shared.client,
        ))
    }

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color.DesignSystem.background,
                    Color.DesignSystem.surface.opacity(0.3),
                ],
                startPoint: .top,
                endPoint: .bottom,
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: Spacing.md) {
                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(
                                    message: message,
                                    isFromCurrentUser: viewModel.isFromCurrentUser(message),
                                    readStatus: viewModel.readStatus(for: message),
                                )
                                .id(message.id)
                            }

                            // Typing indicator
                            if viewModel.isOtherUserTyping {
                                TypingIndicatorView()
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            }
                        }
                        .padding(Spacing.md)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation(.spring(response: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.isOtherUserTyping) { _, isTyping in
                        if isTyping {
                            withAnimation(.spring(response: 0.3)) {
                                proxy.scrollTo("typing-indicator", anchor: .bottom)
                            }
                        }
                    }
                }

                // Input bar
                messageInputBar
            }
        }
        .navigationTitle(t.t("navigation.chat"))
        .navigationBarTitleDisplayMode(.inline)
        #if !SKIP
        #if !SKIP
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        #endif
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                chatHeader
            }
        }
        .task {
            await viewModel.loadMessages()
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .alert(t.t("common.error.title"), isPresented: $viewModel.showError) {
            Button(t.t("common.ok")) { viewModel.dismissError() }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }

    // MARK: - Chat Header with Online Status

    private var chatHeader: some View {
        VStack(spacing: 2) {
            Text(t.t("messages.chat"))
                .font(.DesignSystem.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(.DesignSystem.text)

            HStack(spacing: Spacing.xxs) {
                // Online status indicator
                Circle()
                    .fill(onlineStatusColor)
                    .frame(width: 8.0, height: 8)

                Text(onlineStatusText)
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }
        }
    }

    private var onlineStatusColor: Color {
        switch viewModel.otherUserOnlineStatus {
        case .online:
            Color.DesignSystem.success
        case .away:
            Color.DesignSystem.warning
        case .offline:
            Color.DesignSystem.textTertiary
        }
    }

    private var onlineStatusText: String {
        if viewModel.isOtherUserTyping {
            return t.t("messaging.status.typing")
        }
        switch viewModel.otherUserOnlineStatus {
        case .online:
            return t.t("messaging.status.online")
        case .away:
            return t.t("messaging.status.away")
        case .offline:
            return t.t("messaging.status.offline")
        }
    }

    private var messageInputBar: some View {
        HStack(spacing: Spacing.sm) {
            // Glass message input
            HStack(spacing: Spacing.sm) {
                Image(systemName: "text.bubble.fill")
                    .foregroundColor(.DesignSystem.textSecondary)
                    .font(.body)

                TextField(t.t("messaging.type_message"), text: $viewModel.messageText)
                    .font(.DesignSystem.bodyMedium)
                    .focused($isInputFocused)
                    .onChange(of: viewModel.messageText) { _, _ in
                        viewModel.onTextChange()
                    }
                    .onSubmit {
                        Task { await viewModel.sendMessage() }
                    }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    #if !SKIP
                    .fill(.ultraThinMaterial)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                    ),
            )

            // Send button with glass effect
            Button {
                HapticManager.light()
                Task { await viewModel.sendMessage() }
            } label: {
                Group {
                    if viewModel.isSending {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .frame(width: 40.0, height: 40)
                .background(
                    Circle()
                        .fill(
                            viewModel.canSend
                                ? LinearGradient(
                                    colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                )
                                : LinearGradient(
                                    colors: [
                                        Color.DesignSystem.accentGray.opacity(0.4),
                                        Color.DesignSystem.accentGray.opacity(0.3),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                        )
                        .shadow(
                            color: viewModel.canSend ? .DesignSystem.brandGreen.opacity(0.3) : .clear,
                            radius: 8, y: 4,
                        ),
                )
                .foregroundColor(.white)
            }
            .disabled(!viewModel.canSend)
            .animation(.spring(response: 0.3), value: viewModel.canSend)
        }
        .padding(Spacing.md)
        .background(
            Rectangle()
                #if !SKIP
                .fill(.ultraThinMaterial)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .ignoresSafeArea(edges: .bottom),
        )
    }
}

// MARK: - Typing Dots View (Compact for RoomRow)

struct TypingDotsView: View {
    var body: some View {
        #if !SKIP
        TimelineView(.animation(minimumInterval: 0.4)) { timeline in
            let phase = Int(timeline.date.timeIntervalSinceReferenceDate * 2.5) % 3

            HStack(spacing: 2) {
                ForEach(0 ..< 3, id: \.self) { index in
                    Circle()
                        .fill(Color.DesignSystem.brandGreen)
                        .frame(width: 4.0, height: 4)
                        .scaleEffect(phase == index ? 1.3 : 0.8)
                        .opacity(phase == index ? 1.0 : 0.5)
                        .animation(.interpolatingSpring(stiffness: 300, damping: 24), value: phase)
                }
            }
        }
        #else
        HStack(spacing: 2) {
            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .fill(Color.DesignSystem.brandGreen)
                    .frame(width: 4.0, height: 4)
                    .opacity(0.6)
            }
        }
        #endif
    }
}

// MARK: - Typing Indicator View

struct TypingIndicatorView: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            #if !SKIP
            TimelineView(.animation(minimumInterval: 0.4)) { timeline in
                let phase = Int(timeline.date.timeIntervalSinceReferenceDate * 2.5) % 3

                HStack(spacing: 4) {
                    ForEach(0 ..< 3, id: \.self) { index in
                        Circle()
                            .fill(Color.DesignSystem.textSecondary)
                            .frame(width: 8.0, height: 8)
                            .scaleEffect(phase == index ? 1.2 : 0.8)
                            .opacity(phase == index ? 1.0 : 0.5)
                            .animation(.interpolatingSpring(stiffness: 300, damping: 24), value: phase)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    #if !SKIP
                    .fill(.ultraThinMaterial)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                    ),
            )
            #else
            HStack(spacing: 4) {
                ForEach(0 ..< 3, id: \.self) { index in
                    Circle()
                        .fill(Color.DesignSystem.textSecondary)
                        .frame(width: 8.0, height: 8)
                        .opacity(0.6)
                }
            }
            .padding(Edge.Set.horizontal, Spacing.md)
            .padding(Edge.Set.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    #if !SKIP
                    .fill(.ultraThinMaterial)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                    ),
            )
            #endif

            Spacer(minLength: 100)
        }
        .id("typing-indicator")
    }
}

// MARK: - Message Bubble (Liquid Glass Enhanced)

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    var readStatus: ReadReceiptStatus = .sent

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            if isFromCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: Spacing.xs) {
                // Image if present
                if let imageURL = message.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: 220, maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                                )
                        case .empty, .failure:
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(Color.DesignSystem.glassBackground)
                                .frame(width: 150.0, height: 150)
                                .overlay(
                                    ProgressView(),
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                }

                // Text content with glass bubble
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.DesignSystem.bodyMedium)
                        .foregroundColor(isFromCurrentUser ? .white : .DesignSystem.text)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            isFromCurrentUser
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing,
                                    ),
                                )
                                : AnyShapeStyle(.ultraThinMaterial),
                        )
                        .clipShape(BubbleShape(isFromCurrentUser: isFromCurrentUser))
                        .overlay(
                            BubbleShape(isFromCurrentUser: isFromCurrentUser)
                                .stroke(
                                    isFromCurrentUser
                                        ? Color.clear
                                        : Color.DesignSystem.glassBorder,
                                    lineWidth: 1,
                                ),
                        )
                        .shadow(
                            color: isFromCurrentUser ? Color.DesignSystem.brandGreen.opacity(0.2) : Color.black.opacity(0.05),
                            radius: 4, y: 2,
                        )
                }

                // Timestamp with read receipts
                HStack(spacing: Spacing.xxs) {
                    Text(message.timestamp, style: .time)
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textTertiary)

                    if isFromCurrentUser {
                        ReadReceiptIcon(status: readStatus)
                    }
                }
            }
            .frame(maxWidth: 280, alignment: isFromCurrentUser ? .trailing : .leading)

            if !isFromCurrentUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Read Receipt Icon

struct ReadReceiptIcon: View {
    let status: ReadReceiptStatus

    var body: some View {
        HStack(spacing: -4) {
            switch status {
            case .sent:
                // Single gray checkmark
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.DesignSystem.textTertiary)

            case .delivered:
                // Double gray checkmarks
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.DesignSystem.textTertiary)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.DesignSystem.textTertiary)

            case .read:
                // Double colored checkmarks (green/blue gradient feel)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.DesignSystem.brandGreen)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.DesignSystem.brandGreen)
            }
        }
    }
}

// MARK: - Bubble Shape

struct BubbleShape: Shape {
    let isFromCurrentUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let tailSize: CGFloat = 6

        var path = Path()

        if isFromCurrentUser {
            // Sent message bubble (tail on right)
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                control: CGPoint(x: rect.maxX, y: rect.minY),
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius - tailSize))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - radius, y: rect.maxY - tailSize),
                control: CGPoint(x: rect.maxX, y: rect.maxY - tailSize),
            )
            path.addLine(to: CGPoint(x: rect.maxX - radius + tailSize, y: rect.maxY - tailSize))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                control: CGPoint(x: rect.maxX - radius + tailSize, y: rect.maxY),
            )
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                control: CGPoint(x: rect.minX, y: rect.maxY),
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY),
            )
        } else {
            // Received message bubble (tail on left)
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                control: CGPoint(x: rect.maxX, y: rect.minY),
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY),
            )
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius - tailSize, y: rect.maxY - tailSize),
                control: CGPoint(x: rect.minX + radius - tailSize, y: rect.maxY),
            )
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY - tailSize))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - radius - tailSize),
                control: CGPoint(x: rect.minX, y: rect.maxY - tailSize),
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY),
            )
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Message Skeleton Row

private struct MessageSkeletonRow: View {
    @State private var shimmerPhase: CGFloat = -200

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Avatar skeleton
            Circle()
                .fill(skeletonGradient)
                .frame(width: 48.0, height: 48)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                // Name skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(width: 100.0, height: 16)

                // Message skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(width: 180.0, height: 14)
            }

            Spacer()

            // Time skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(skeletonGradient)
                .frame(width: 40.0, height: 12)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                #if !SKIP
                .fill(.ultraThinMaterial)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder.opacity(0.5), lineWidth: 1),
                ),
        )
        .overlay(shimmerOverlay)
    }

    private var skeletonGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.DesignSystem.textTertiary.opacity(0.3),
                Color.DesignSystem.textTertiary.opacity(0.2),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        )
    }

    private var shimmerOverlay: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.15),
                    Color.clear,
                ],
                startPoint: .leading,
                endPoint: .trailing,
            )
            .frame(width: 150.0)
            .offset(x: shimmerPhase)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                ) {
                    shimmerPhase = geometry.size.width + 150
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
}

// MARK: - Chats Filter Sheet

struct ChatsFilterSheet: View {
    @Environment(\.translationService) private var t
    @Bindable var viewModel: MessagingViewModel
    @Environment(\.dismiss) private var dismiss: DismissAction

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Archive Section
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text(t.t("messaging.view"))
                            .font(.DesignSystem.headlineSmall)
                            .foregroundColor(.DesignSystem.text)

                        // Archive Toggle
                        Button {
                            HapticManager.light()
                            viewModel.toggleArchived()
                        } label: {
                            HStack {
                                Image(systemName: viewModel.showArchived ? "tray.full.fill" : "archivebox")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(viewModel.showArchived
                                        ? .DesignSystem.brandGreen
                                        : .DesignSystem.text)
                                        .frame(width: 40.0, height: 40)
                                        .background(
                                            Circle()
                                                .fill(viewModel.showArchived
                                                    ? Color.DesignSystem.brandGreen.opacity(0.15)
                                                    : Color.DesignSystem.glassBackground),
                                        )

                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(viewModel.showArchived
                                        ? t.t("messaging.archive_section.showing")
                                        : t.t("messaging.archive_section.show"))
                                        .font(.DesignSystem.bodyMedium)
                                        .fontWeight(.medium)
                                        .foregroundColor(.DesignSystem.text)

                                    Text(viewModel.showArchived
                                        ? t.t("messaging.archive_section.tap_active")
                                        : t.t(
                                            "messaging.archive_section.count",
                                            args: ["count": String(viewModel.archivedRooms.count)],
                                        ))
                                        .font(.DesignSystem.caption)
                                        .foregroundColor(.DesignSystem.textSecondary)
                                }

                                Spacer()

                                Image(systemName: viewModel.showArchived ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(viewModel.showArchived
                                        ? .DesignSystem.brandGreen
                                        : .DesignSystem.textTertiary)
                            }
                            .padding(Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.large)
                                    #if !SKIP
                                    .fill(.ultraThinMaterial)
                                    #else
                                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                                    #endif
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.large)
                                            .stroke(
                                                viewModel.showArchived
                                                    ? Color.DesignSystem.brandGreen.opacity(0.5)
                                                    : Color.DesignSystem.glassBorder,
                                                lineWidth: 1,
                                            ),
                                    ),
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Filter Section
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text(t.t("messaging.filter_by"))
                            .font(.DesignSystem.headlineSmall)
                            .foregroundColor(.DesignSystem.text)

                        VStack(spacing: Spacing.sm) {
                            ForEach(MessagingViewModel.ConversationFilter.allCases, id: \.self) { filter in
                                FilterOptionRow(
                                    filter: filter,
                                    isSelected: viewModel.selectedFilter == filter,
                                    unreadCount: filter == .unread ? viewModel.unreadCount : nil,
                                ) {
                                    viewModel.setFilter(filter)
                                }
                            }
                        }
                    }

                    Spacer(minLength: Spacing.xl)
                }
                .padding(Spacing.lg)
            }
            .background(Color.DesignSystem.background)
            .navigationTitle(t.t("navigation.filters_settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t.t("common.done")) {
                        dismiss()
                    }
                    .font(.DesignSystem.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.DesignSystem.brandGreen)
                }
            }
        }
    }
}

// MARK: - Filter Option Row

private struct FilterOptionRow: View {
    @Environment(\.translationService) private var t
    let filter: MessagingViewModel.ConversationFilter
    let isSelected: Bool
    var unreadCount: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: filter.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .DesignSystem.brandGreen : .DesignSystem.text)
                    .frame(width: 36.0, height: 36)
                    .background(
                        Circle()
                            .fill(isSelected
                                ? Color.DesignSystem.brandGreen.opacity(0.15)
                                : Color.DesignSystem.glassBackground),
                    )

                Text(filter.localizedDisplayName(using: t))
                    .font(.DesignSystem.bodyMedium)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(.DesignSystem.text)

                if let count = unreadCount, count > 0 {
                    Text("\(count)")
                        .font(.DesignSystem.captionSmall)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.DesignSystem.brandGreen),
                        )
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .DesignSystem.brandGreen : .DesignSystem.textTertiary)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    #if !SKIP
                    .fill(.ultraThinMaterial)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(
                                isSelected
                                    ? Color.DesignSystem.brandGreen.opacity(0.5)
                                    : Color.DesignSystem.glassBorder,
                                lineWidth: 1,
                            ),
                    ),
            )
        }
        .buttonStyle(.plain)
    }
}


#endif
