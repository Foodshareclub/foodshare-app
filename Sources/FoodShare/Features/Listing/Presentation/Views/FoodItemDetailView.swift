//
//  FoodItemDetailView.swift
//  Foodshare
//
//  Detailed view for a food listing with actions
//  Liquid Glass v26 design system
//



#if !SKIP
import MapKit
import Supabase
import SwiftUI

#if DEBUG
    import Inject
#endif

struct FoodItemDetailView: View {

    @Environment(\.translationService) private var t
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss: DismissAction
    @State private var viewModel: FoodItemDetailViewModel
    @State private var showContactSheet = false
    @State private var showReportSheet = false
    @State private var showBlockUserSheet = false
    @State private var showShareSheet = false
    @State private var showEditSheet = false
    @State private var showReviewSheet = false
    @State private var currentImageIndex = 0
    @State private var navigateToChatRoom: Room?
    @State private var reviewViewModel: ReviewViewModel?
    @State private var reviews: [Review] = []
    @State private var isLoadingReviews = false
    @State private var isLiked = false
    @State private var likeCount = 0
    @State private var displayDescription = ""
    @State private var isDescriptionTranslated = false
    @State private var showImageViewer = false
    @State private var sectionsAppeared = false
    @State private var isLoading = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    init(item: FoodItem) {
        _displayDescription = State(initialValue: FoodItem.cleanDescription(item.postDescription))
        _viewModel = State(initialValue: FoodItemDetailViewModel(item: item))
    }

    var body: some View {
        Group {
            if isLoading {
                GlassDetailSkeleton(style: .foodItem, showImage: true)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Image Carousel
                        imageCarousel

                        // Content
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            // Title and Status
                            titleSection

                            // Stats Row
                            statsRow

                            // Details Section
                            detailsSection

                            // Location Section (uses stripped address for privacy)
                            if viewModel.item.displayAddress != nil {
                                locationSection
                            }

                            // Reviews Section
                            if !reviews.isEmpty || viewModel.item.isArranged {
                                reviewsSection
                            }

                            // Action Buttons
                            actionButtons
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.lg)
                    }
                }
            }
        }
        .background(Color.background)
        .detailNavigationBar()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showShareSheet = true
                    } label: {
                        Label(t.t("common.share"), systemImage: "square.and.arrow.up")
                    }

                    if appState.currentUser?.id != viewModel.item.profileId {
                        Button(role: .destructive) {
                            showReportSheet = true
                        } label: {
                            Label(t.t("common.report"), systemImage: "exclamationmark.triangle")
                        }

                        // Block user option (only for other users' listings)
                        if viewModel.item.profileId != appState.currentUser?.id {
                            Button(role: .destructive) {
                                showBlockUserSheet = true
                            } label: {
                                Label(t.t("profile.block_user"), systemImage: "hand.raised.fill")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showContactSheet) {
            ContactSellerSheet(item: viewModel.item) { room in
                navigateToChatRoom = room
            }
        }
        .navigationDestination(item: $navigateToChatRoom) { room in
            if let userId = appState.currentUser?.id {
                ChatRoomView(
                    room: room,
                    currentUserId: userId,
                    repository: SupabaseMessagingRepository(supabase: appState.authService.supabase),
                )
            }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportItemSheet(itemId: viewModel.item.id)
        }
        .sheet(isPresented: $showBlockUserSheet) {
            EmptyView()
        }
        .sheet(isPresented: $showEditSheet) {
            CreateListingView(
                viewModel: CreateListingViewModel(
                    repository: SupabaseListingRepository(supabase: appState.authService.supabase),
                    editingItem: viewModel.item,
                ),
            )
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = URL(string: "https://foodshare.club/food/\(viewModel.item.id)") {
                ShareSheet(items: [url, viewModel.item.postName])
            }
        }
        .sheet(isPresented: $showReviewSheet) {
            if let vm = reviewViewModel {
                ReviewFormView(
                    viewModel: vm,
                    postId: viewModel.item.id,
                ) {
                    showReviewSheet = false
                    // Reload reviews after submission
                    Task { await loadReviews() }
                }
            }
        }
        .task {
            // Brief skeleton display for smooth transition
            #if SKIP
            try? await Task.sleep(nanoseconds: UInt64(300 * 1_000_000))
            #else
            try? await Task.sleep(for: .milliseconds(300))
            #endif
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                isLoading = false
            }

            // Record view using dedicated service (handles deduplication)
            await PostViewService.shared.recordView(postId: viewModel.item.id)
            setupReviewViewModel()
            await loadReviews()

            // Load initial like status - use model value as fallback
            let initialLikeCount = viewModel.item.postLikeCounter ?? 0
            likeCount = initialLikeCount

            // DIAGNOSTIC: Log initial state from model
            await AppLogger.shared.info(
                "[LIKES DEBUG] Post \(viewModel.item.id) '\(viewModel.item.postName)' - Model values: postLikeCounter=\(viewModel.item.postLikeCounter.map { String($0) } ?? "nil"), postViews=\(viewModel.item.postViews), initialLikeCount=\(initialLikeCount)",
            )

            do {
                let status = try await PostEngagementService.shared.checkLiked(postId: viewModel.item.id)
                isLiked = status.isLiked
                likeCount = status.likeCount

                // DIAGNOSTIC: Log service response
                await AppLogger.shared.info(
                    "[LIKES DEBUG] Post \(viewModel.item.id) - Service response: isLiked=\(status.isLiked), likeCount=\(status.likeCount)",
                )
            } catch {
                // Log actual error for debugging - keep model value as fallback (already set above)
                await AppLogger.shared.error(
                    "[LIKES DEBUG] Post \(viewModel.item.id) - Service FAILED: \(error)",
                )
            }

            // Trigger staggered section entrance animations
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8).delay(0.15)) {
                sectionsAppeared = true
            }
        }
    }

    // MARK: - Image Carousel (Enhanced with GlassImageCarousel)

    private var imageCarousel: some View {
        #if !SKIP
        GlassImageCarousel(
            imageURLs: viewModel.item.imageURLs,
            height: 320,
            emptyStateIcon: "photo.stack",
            emptyStateMessage: t.t("listing.no_images"),
            errorStateMessage: t.t("listing.image_unavailable"),
            onTap: { index in
                currentImageIndex = index
                showImageViewer = true
            },
        )
        .glassImageViewer(
            images: viewModel.item.imageURLs,
            selectedIndex: $currentImageIndex,
            isPresented: $showImageViewer,
        )
        #else
        // Simple fallback for Android (Skip) — uses AsyncImage instead of Kingfisher
        TabView(selection: $currentImageIndex) {
            ForEach(Array(viewModel.item.imageURLs.enumerated()), id: \.offset) { index, url in
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Rectangle()
                            .fill(Color.DesignSystem.glassBackground)
                            .overlay {
                                ProgressView()
                            }
                    }
                }
                .frame(height: 320.0)
                .clipped()
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 320.0)
        #endif
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(viewModel.item.postName)
                    .font(.DesignSystem.headlineLarge)
                    .foregroundColor(.DesignSystem.text)

                Spacer()

                // Status Badge with glass background
                Text(viewModel.item.status.localizedDisplayName(using: t))
                    .font(.DesignSystem.captionSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        Capsule()
                            .fill(statusColor)
                            .shadow(color: statusColor.opacity(0.4), radius: 6, y: 2),
                    )
            }

            if let originalDescription = viewModel.item.postDescription {
                let cleanedDesc = FoodItem.cleanDescription(originalDescription)
                if !cleanedDesc.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(displayDescription.isEmpty ? cleanedDesc : displayDescription)
                            .font(.DesignSystem.bodyLarge)
                            .foregroundColor(.DesignSystem.textSecondary)
                            .lineSpacing(4)

                        if isDescriptionTranslated {
                            TranslatedIndicator()
                        }
                    }
                    .autoTranslate(
                        original: cleanedDesc,
                        contentType: "listing",
                        translated: $displayDescription,
                        isTranslated: $isDescriptionTranslated,
                    )
                }
            }
        }
        .detailSection(index: 0, sectionsAppeared: $sectionsAppeared)
    }

    private var statusColor: Color {
        switch viewModel.item.status {
        case .available: .DesignSystem.brandGreen
        case .arranged: .orange
        case .inactive: .gray
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: Spacing.md) {
            // Views stat pill - use convenience initializer for clean display
            GlassStatPill.views(viewModel.item.postViews, animate: true)

            // Likes - interactive button
            LikeButton(
                postId: viewModel.item.id,
                initialLikeCount: likeCount,
                initialIsLiked: isLiked,
                size: EngagementLikeButton.Size.medium,
                showCount: true,
            ) { isLikedNow, count in
                isLiked = isLikedNow
                likeCount = count
            }

            Spacer()

            // Distance stat pill
            if let distance = viewModel.item.distanceDisplay {
                GlassStatPill.distance(distance)
            }
        }
        .detailSection(index: 1, sectionsAppeared: $sectionsAppeared)
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header with icon
            GlassSectionHeader.details(t.t("listing.details"))

            VStack(spacing: Spacing.sm) {
                // Pickup Time
                if let pickupTime = viewModel.item.pickupTime {
                    GlassDetailRow(
                        icon: "clock.fill",
                        iconColor: .orange,
                        label: t.t("listing.detail.available"),
                        value: pickupTime,
                    )
                }

                // Available Hours (for fridges)
                if let availableHours = viewModel.item.availableHours {
                    GlassDetailRow(
                        icon: "calendar",
                        iconColor: .DesignSystem.brandGreen,
                        label: t.t("listing.detail.hours"),
                        value: availableHours,
                    )
                }

                // Post Type
                GlassDetailRow(
                    icon: PostType(rawValue: viewModel.item.postType)?.icon ?? "leaf.fill",
                    iconColor: .DesignSystem.brandGreen,
                    label: t.t("listing.detail.type"),
                    value: PostType(rawValue: viewModel.item.postType)?.displayName ?? viewModel.item.postType
                        .capitalized,
                )

                // Food Status (for fridges)
                if let foodStatus = viewModel.item.foodStatusDisplay {
                    GlassDetailRow(
                        icon: "battery.75percent",
                        iconColor: .DesignSystem.brandBlue,
                        label: t.t("listing.detail.food_level"),
                        value: foodStatus,
                    )
                }

                // Posted date
                GlassDetailRow(
                    icon: "calendar.badge.clock",
                    iconColor: .DesignSystem.textSecondary,
                    label: t.t("listing.detail.posted"),
                    value: viewModel.item.createdAt.formatted(date: .abbreviated, time: .omitted),
                )
            }
        }
        .detailSection(index: 2, sectionsAppeared: $sectionsAppeared)
    }

    // MARK: - Location Section

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header with icon
            GlassSectionHeader.location(t.t("listing.pickup_location"))

            // Map preview with address and directions
            #if !SKIP
            if let coordinate = viewModel.item.coordinate {
                // TODO: Replace with standard MapKit view
                // GlassMapPreview(
                //     coordinate: coordinate,
                //     title: viewModel.item.postName,
                //     address: viewModel.item.displayAddress,
                //     onDirections: {
                //         openInMaps(coordinate: coordinate, name: viewModel.item.postName)
                //     },
                // )

                // Temporary simple map view
                Map {
                    Marker(viewModel.item.postName, coordinate: coordinate)
                }
                .mapStyle(.standard)
                .frame(height: 200.0)
                .cornerRadius(CornerRadius.medium)
            }
            #endif
        }
        .detailSection(index: 3, sectionsAppeared: $sectionsAppeared)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: Spacing.md) {
            if viewModel.item.isAvailable {
                // Request Item Button
                if appState.currentUser != nil {
                    if appState.currentUser?.id != viewModel.item.profileId {
                        GlassButton(
                            t.t("listing.action.request_item"),
                            icon: "hand.raised.fill",
                            style: .primary,
                        ) {
                            showContactSheet = true
                        }
                    } else {
                        // Owner's own listing
                        GlassButton(
                            t.t("listing.action.edit_listing"),
                            icon: "pencil",
                            style: .secondary,
                        ) {
                            showEditSheet = true
                        }
                    }
                } else {
                    // Not logged in
                    GlassButton(
                        t.t("listing.action.sign_in_request"),
                        icon: "person.fill",
                        style: .secondary,
                    ) {
                        appState.showAuthentication = true
                    }
                }
            } else if viewModel.item.isArranged {
                // Already arranged
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.orange)
                    Text(t.t("listing.arranged"))
                        .font(.DesignSystem.bodyMedium)
                        .foregroundColor(.DesignSystem.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.md)
                #if !SKIP
                .background(.ultraThinMaterial)
                #else
                .background(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Reviews Section

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header with leave review action
            GlassSectionHeader.reviews(
                t.t("listing.reviews"),
                action: (viewModel.item.isArranged && appState.currentUser?.id != viewModel.item.profileId)
                    ? {
                        showReviewSheet = true
                    }
                    : nil,
                actionLabel: t.t("listing.leave_review"),
                actionIcon: "star.fill",
            )

            if isLoadingReviews {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Spacer()
                }
                .padding(Spacing.xl)
            } else if reviews.isEmpty {
                // Empty state with glass background
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "star.leadinghalf.filled")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow.opacity(0.5), .orange.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                    Text(t.t("reviews.empty._title"))
                        .font(.DesignSystem.bodyMedium)
                        .foregroundColor(.DesignSystem.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(Color.DesignSystem.glassBackground),
                )
            } else {
                // Average rating pill
                HStack(spacing: Spacing.sm) {
                    StarRatingView(rating: averageRating)
                    Text(String(format: "%.1f", averageRating))
                        .font(.DesignSystem.headlineSmall)
                        .fontWeight(.bold)
                        .foregroundColor(.DesignSystem.text)
                    Text("•")
                        .foregroundColor(.DesignSystem.textTertiary)
                    Text(t.t("reviews.review_count", args: ["count": String(reviews.count)]))
                        .font(.DesignSystem.bodySmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        #if !SKIP
                        .fill(.ultraThinMaterial)
                        #else
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                        #endif
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [.yellow.opacity(0.3), .orange.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing,
                                    ),
                                    lineWidth: 1,
                                ),
                        ),
                )

                // Review cards
                ForEach(reviews.prefix(3)) { review in
                    ReviewCard(review: review)
                }

                // See all button if more than 3 reviews
                if reviews.count > 3 {
                    NavigationLink {
                        AllReviewsView(
                            postId: viewModel.item.id,
                            postName: viewModel.item.postName,
                            reviews: reviews,
                        )
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Text(t.t("reviews.see_all_count", args: ["count": String(reviews.count)]))
                            Image(systemName: "chevron.right")
                        }
                        .font(.DesignSystem.labelMedium)
                        .foregroundColor(.DesignSystem.brandBlue)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, Spacing.sm)
                    #if !SKIP
                    .simultaneousGesture(TapGesture().onEnded { HapticManager.light() })
                    #endif
                }
            }
        }
        .detailSection(index: 4, sectionsAppeared: $sectionsAppeared)
    }

    private var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        let total = reviews.reduce(0) { $0 + $1.reviewedRating }
        return Double(total) / Double(reviews.count)
    }

    // MARK: - Helpers

    private func setupReviewViewModel() {
        guard let userId = appState.currentUser?.id else { return }

        let repository = SupabaseReviewRepository(supabase: appState.authService.supabase)
        let fetchUseCase = FetchReviewsUseCase(repository: repository)
        let submitUseCase = SubmitReviewUseCase(repository: repository)

        reviewViewModel = ReviewViewModel(
            fetchReviewsUseCase: fetchUseCase,
            submitReviewUseCase: submitUseCase,
            currentUserId: userId,
        )
    }

    private func loadReviews() async {
        isLoadingReviews = true
        defer { isLoadingReviews = false }

        let repository = SupabaseReviewRepository(supabase: appState.authService.supabase)

        do {
            reviews = try await repository.fetchReviews(forPostId: viewModel.item.id)
        } catch {
            await AppLogger.shared.error("Failed to load reviews", error: error)
        }
    }

    #if !SKIP
    private func openInMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?q=\(encodedName)&ll=\(coordinate.latitude),\(coordinate.longitude)") {
            UIApplication.shared.open(url)
        }
    }
    #endif
}

// MARK: - Contact Seller Sheet

struct ContactSellerSheet: View {
    @Environment(\.translationService) private var t
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss: DismissAction
    let item: FoodItem
    let onRoomCreated: ((Room) -> Void)?

    @State private var message = ""
    @State private var isSending = false
    @State private var showError = false
    @State private var errorMessage = ""

    init(item: FoodItem, onRoomCreated: ((Room) -> Void)? = nil) {
        self.item = item
        self.onRoomCreated = onRoomCreated
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                // Item preview
                HStack(spacing: Spacing.md) {
                    if let imageUrl = item.displayImageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case let .success(image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            default:
                                Rectangle()
                                    .fill(Color.DesignSystem.glassBackground)
                                    .overlay {
                                        Image(systemName: "photo")
                                            .foregroundColor(.DesignSystem.textSecondary)
                                    }
                            }
                        }
                        .frame(width: 60.0, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    }

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(item.postName)
                            .font(.DesignSystem.headlineSmall)
                            .foregroundColor(.DesignSystem.text)

                        if let distance = item.distanceDisplay {
                            Text(distance + " away")
                                .font(.DesignSystem.bodySmall)
                                .foregroundColor(.DesignSystem.textSecondary)
                        }
                    }

                    Spacer()
                }
                .padding(Spacing.md)
                #if !SKIP
                .background(.ultraThinMaterial)
                #else
                .background(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))

                // Message input
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(t.t("listing.your_message"))
                        .font(.DesignSystem.labelMedium)
                        .foregroundColor(.DesignSystem.textSecondary)

                    TextEditor(text: $message)
                        .frame(height: 120.0)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(Color.DesignSystem.text)
                        .padding(Spacing.sm)
                        #if !SKIP
                        .background(.ultraThinMaterial)
                        #else
                        .background(Color.DesignSystem.glassSurface.opacity(0.15))
                        #endif
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                }

                // Quick messages
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(t.t("listing.quick_messages"))
                        .font(.DesignSystem.labelMedium)
                        .foregroundColor(.DesignSystem.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            QuickMessageChip(text: t.t("listing.quick_message.available")) {
                                message = t.t("listing.quick_message.available")
                            }
                            QuickMessageChip(text: t.t("listing.quick_message.pickup")) {
                                message = t.t("listing.quick_message.pickup")
                            }
                            QuickMessageChip(text: t.t("listing.quick_message.interested")) {
                                message = t.t("listing.quick_message.interested")
                            }
                        }
                    }
                }

                Spacer()

                // Send button
                GlassButton(
                    t.t("listing.send_message"),
                    icon: "paperplane.fill",
                    style: .primary,
                    isLoading: isSending,
                ) {
                    Task {
                        await sendMessage()
                    }
                }
                .disabled(message.isEmpty)
            }
            .padding(Spacing.lg)
            .navigationTitle(t.t("listing.contact_sharer"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t.t("common.cancel")) {
                        dismiss()
                    }
                }
            }
            .alert(t.t("common.error.title"), isPresented: $showError) {
                Button(t.t("common.ok"), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func sendMessage() async {
        guard let currentUser = appState.currentUser else { return }
        guard let sharerId = item.profileId else {
            errorMessage = t.t("common.error.generic")
            showError = true
            return
        }
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }

        isSending = true
        defer { isSending = false }

        do {
            // Create messaging repository
            let repository = SupabaseMessagingRepository(supabase: appState.authService.supabase)

            // Create or find existing room
            let room = try await repository.createRoom(
                postId: item.id,
                sharerId: sharerId,
                requesterId: currentUser.id,
            )

            // Send the initial message
            _ = try await repository.sendMessage(
                roomId: room.id,
                profileId: currentUser.id,
                text: trimmedMessage,
            )

            // Dismiss and optionally navigate to chat
            dismiss()
            onRoomCreated?(room)

        } catch let error as AppError {
            // Elegant error handling for blocked users
            switch error {
            case let .validationError(message):
                if message.contains("blocked") {
                    errorMessage = t.t("messaging.error.user_blocked")
                } else {
                    errorMessage = t.t("common.error.generic")
                }
                showError = true
            case .networkError:
                errorMessage = t.t("common.error.network")
                showError = true
            default:
                errorMessage = t.t("common.error.generic")
                showError = true
            }
            HapticManager.error()
        } catch {
            // Fallback for non-AppError errors
            if error.localizedDescription.lowercased().contains("blocked") {
                errorMessage = t.t("messaging.error.user_blocked")
            } else {
                errorMessage = t.t("common.error.generic")
            }
            showError = true
            HapticManager.error()
        }
    }
}

// MARK: - Quick Message Chip

struct QuickMessageChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.DesignSystem.bodySmall)
                .foregroundColor(.DesignSystem.text)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                #if !SKIP
                .background(.ultraThinMaterial)
                #else
                .background(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .clipShape(Capsule())
        }
    }
}

// MARK: - Report Item Sheet

struct ReportItemSheet: View {
    @Environment(\.translationService) private var t
    @Environment(\.dismiss) private var dismiss: DismissAction
    let itemId: Int
    @State private var selectedReason: ReportReason?
    @State private var additionalInfo = ""
    @State private var isSubmitting = false

    enum ReportReason: String, CaseIterable {
        case spam
        case inappropriate
        case expired
        case scam
        case other

        @MainActor
        func localizedDisplayName(using t: EnhancedTranslationService) -> String {
            switch self {
            case .spam: t.t("Reports.reasons.spam")
            case .inappropriate: t.t("Reports.reasons.inappropriate")
            case .expired: t.t("Reports.reasons.expired")
            case .scam: t.t("Reports.reasons.scam")
            case .other: t.t("Reports.reasons.other")
            }
        }

        var apiValue: String {
            switch self {
            case .spam: "Spam or misleading"
            case .inappropriate: "Inappropriate content"
            case .expired: "Item already expired"
            case .scam: "Suspected scam"
            case .other: "Other"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(t.t("Reports.selectReason")) {
                    ForEach(ReportReason.allCases, id: \.self) { reason in
                        Button {
                            selectedReason = reason
                        } label: {
                            HStack {
                                Text(reason.localizedDisplayName(using: t))
                                    .foregroundColor(.DesignSystem.text)
                                Spacer()
                                if selectedReason == reason {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.DesignSystem.brandGreen)
                                }
                            }
                        }
                    }
                }

                Section(t.t("Reports.additionalDetails")) {
                    TextEditor(text: $additionalInfo)
                        .frame(height: 100.0)
                        .foregroundStyle(Color.DesignSystem.text)
                }
            }
            .navigationTitle(t.t("listing.report_item"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t.t("common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t.t("common.submit")) {
                        Task {
                            await submitReport()
                        }
                    }
                    .disabled(selectedReason == nil || isSubmitting)
                }
            }
        }
    }

    private func submitReport() async {
        guard let reason = selectedReason else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            // Get Supabase client from AuthenticationService
            let supabase = await AuthenticationService.shared.supabase

            // Submit report to reports table
            let report = ReportDTO(
                postId: itemId,
                reason: reason.apiValue,
                additionalInfo: additionalInfo.isEmpty ? nil : additionalInfo,
            )

            try await supabase
                .from("reports")
                .insert(report)
                .execute()

            dismiss()
        } catch {
            // Silently fail - user doesn't need to know about report submission errors
            dismiss()
        }
    }
}

// MARK: - Report DTO

private struct ReportDTO: Encodable {
    let postId: Int
    let reason: String
    let additionalInfo: String?

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case reason
        case additionalInfo = "additional_info"
    }
}

// MARK: - Share Sheet

#if !SKIP
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - ViewModel

@MainActor
@Observable
final class FoodItemDetailViewModel {
    let item: FoodItem
    var isLoading = false
    var error: AppError?
    private var hasIncrementedViewCount = false

    init(item: FoodItem) {
        self.item = item
    }

    func incrementViewCount(using repository: ListingRepository) async {
        // Only increment once per view session
        guard !hasIncrementedViewCount else { return }
        hasIncrementedViewCount = true

        do {
            try await repository.incrementViewCount(listingId: item.id)
        } catch {
            // Silently fail - view count is non-critical
            await AppLogger.shared.debug("Failed to increment view count: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        NavigationStack {
            FoodItemDetailView(item: .fixture())
        }
        .environment(AppState())
    }

#endif

#else
// MARK: - Android FoodItemDetailView (Skip)

import SwiftUI

struct FoodItemDetailView: View {
    let item: FoodItem

    @Environment(AppState.self) var appState
    @State private var isArranging = false
    @State private var arrangeSuccess = false
    @State private var isMessaging = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0.0) {
                // Image Gallery
                if let images = item.images, !images.isEmpty {
                    TabView {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, imageUrl in
                            if let url = URL(string: imageUrl) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: ContentMode.fill)
                                    case .failure:
                                        detailImagePlaceholder
                                    default:
                                        ProgressView()
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: 300.0)
                    .tabViewStyle(.page)
                } else if let imageUrl = item.displayImageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: ContentMode.fill)
                                .frame(height: 300.0)
                                .clipped()
                        default:
                            detailImagePlaceholder
                                .frame(height: 300.0)
                        }
                    }
                } else {
                    detailImagePlaceholder
                        .frame(height: 300.0)
                }

                VStack(alignment: .leading, spacing: 16.0) {
                    // Title + Status
                    HStack {
                        Text(item.title)
                            .font(.system(size: 24.0, weight: .bold))
                            .foregroundStyle(Color.white)

                        Spacer()

                        Text(item.status.displayName)
                            .font(.system(size: 12.0, weight: .medium))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 10.0)
                            .padding(.vertical, 4.0)
                            .background(item.isAvailable ? Color(red: 0.18, green: 0.8, blue: 0.44) : Color.orange)
                            .clipShape(Capsule())
                    }

                    // Description
                    if let desc = item.description {
                        Text(desc)
                            .font(.system(size: 15.0))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }

                    // Info Section
                    VStack(alignment: .leading, spacing: 10.0) {
                        if let pickupTime = item.pickupTime {
                            DetailInfoRow(icon: "clock.fill", label: "Pickup", value: pickupTime)
                        }

                        if let address = item.displayAddress {
                            DetailInfoRow(icon: "location.fill", label: "Location", value: address)
                        }

                        if let distance = item.distanceDisplay {
                            DetailInfoRow(icon: "figure.walk", label: "Distance", value: distance)
                        }

                        DetailInfoRow(icon: "eye.fill", label: "Views", value: "\(item.postViews)")

                        if let likes = item.postLikeCounter, likes > 0 {
                            DetailInfoRow(icon: "heart.fill", label: "Likes", value: "\(likes)")
                        }
                    }
                    .padding(16.0)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12.0))

                    // Arrange Button
                    if item.isAvailable && appState.isAuthenticated {
                        Button(action: { Task { await arrangeListing() } }) {
                            HStack {
                                if isArranging {
                                    ProgressView()
                                        .tint(.white)
                                } else if arrangeSuccess {
                                    Image(systemName: "checkmark.circle.fill")
                                } else {
                                    Image(systemName: "hand.raised.fill")
                                }
                                Text(arrangeSuccess ? "Arranged!" : "I'll Take This")
                            }
                            .font(.system(size: 16.0, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14.0)
                        }
                        .background(arrangeSuccess ? Color(red: 0.13, green: 0.6, blue: 0.33) : Color(red: 0.2, green: 0.7, blue: 0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 12.0))
                        .disabled(isArranging || arrangeSuccess)
                    }

                    // Message Button
                    if appState.isAuthenticated {
                        Button(action: { Task { await startChat() } }) {
                            HStack {
                                if isMessaging {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "message.fill")
                                }
                                Text("Message")
                            }
                            .font(.system(size: 16.0, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14.0)
                        }
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12.0))
                        .disabled(isMessaging)
                    }
                }
                .padding(16.0)
            }
        }
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func arrangeListing() async {
        isArranging = true

        let baseURL = AppEnvironment.supabaseURL ?? "https://api.foodshare.club"
        let apiKey = AppEnvironment.supabasePublishableKey ?? ""

        guard let url = URL(string: "\(baseURL)/functions/v1/api-v1-engagement") else {
            isArranging = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthenticationService.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = ["post_id": item.id, "action": "arrange"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 300 {
                arrangeSuccess = true
            } else {
                errorMessage = "Could not arrange pickup. Please try again."
                showError = true
            }
        } catch {
            errorMessage = "Network error. Please check your connection."
            showError = true
        }

        isArranging = false
    }

    private func startChat() async {
        isMessaging = true

        let baseURL = AppEnvironment.supabaseURL ?? "https://api.foodshare.club"
        let apiKey = AppEnvironment.supabasePublishableKey ?? ""

        guard let url = URL(string: "\(baseURL)/functions/v1/api-v1-chat?mode=food&action=create") else {
            isMessaging = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthenticationService.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = ["postId": item.id]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 300 {
                // Chat room created — user can navigate to Chats tab
                // TODO: Navigate directly to the new chat room
            } else {
                errorMessage = "Could not start conversation. Please try again."
                showError = true
            }
        } catch {
            errorMessage = "Network error. Please check your connection."
            showError = true
        }

        isMessaging = false
    }

    private var detailImagePlaceholder: some View {
        ZStack {
            Color.white.opacity(0.05)
            Image(systemName: "leaf.fill")
                .font(.system(size: 48.0))
                .foregroundStyle(Color.white.opacity(0.2))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DetailInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10.0) {
            Image(systemName: icon)
                .font(.system(size: 14.0))
                .foregroundStyle(Color(red: 0.2, green: 0.7, blue: 0.4))
                .frame(width: 20.0)

            Text(label)
                .font(.system(size: 14.0))
                .foregroundStyle(Color.white.opacity(0.5))

            Spacer()

            Text(value)
                .font(.system(size: 14.0))
                .foregroundStyle(Color.white.opacity(0.8))
        }
    }
}

#endif
