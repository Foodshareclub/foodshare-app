//
//  GlassListingCard.swift
//  Foodshare
//
//  Enhanced Liquid Glass listing card with category support
//  Premium glassmorphism effects with advanced animations
//


#if !SKIP
import OSLog
import SwiftUI

struct GlassListingCard: View {
    let item: FoodItem
    let onTap: (() -> Void)?
    let enableAnimations: Bool

    @State private var isPressed = false
    @State private var isHovered = false
    @State private var hasAppeared = false
    @State private var highlightTrigger = false
    @State private var parallaxOffset: CGSize = .zero
    @State private var glowIntensity: Double = 0
    @State private var shimmerPhase: CGFloat = 0

    /// Enable GPU rasterization for smooth 120Hz scrolling performance
    let useGPURasterization: Bool

    /// Enable parallax effect on drag gesture
    let enableParallax: Bool

    /// Card style variant
    let style: CardStyle

    enum CardStyle {
        case standard
        case compact
        case featured
        case modern
    }

    init(
        item: FoodItem,
        enableAnimations: Bool = true,
        useGPURasterization: Bool = false,
        enableParallax: Bool = false,
        style: CardStyle = .standard,
        onTap: (() -> Void)? = nil,
    ) {
        self.item = item
        self.enableAnimations = enableAnimations
        self.useGPURasterization = useGPURasterization
        self.enableParallax = enableParallax
        self.style = style
        self.onTap = onTap
    }

    var body: some View {
        Button {
            HapticManager.light()
            highlightTrigger = true
            triggerGlowPulse()
            onTap?()
        } label: {
            if useGPURasterization {
                cardContent
                    .drawingGroup()
            } else {
                cardContent
            }
        }
        .buttonStyle(EnhancedCardPressStyle())
        .modifier(CardParallaxModifier(offset: parallaxOffset, enabled: enableParallax))
        .gesture(parallaxGesture)
        .accessibilityLabel(accessibilityDescription)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
            }
            if style == .featured {
                startFeatureShimmer()
            }
        }
        .task {
            // Fetch actual like status from server (for modern layout)
            if style == .modern {
                do {
                    let status = try await PostEngagementService.shared.checkLiked(postId: item.id)
                    isLikedByDoubleTap = status.isLiked
                } catch {
                    // Silently fail - engagement is non-critical
                }
            }
        }
    }

    // MARK: - Parallax Gesture

    private var parallaxGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard enableParallax else { return }
                let maxOffset: CGFloat = 8
                withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.8)) {
                    parallaxOffset = CGSize(
                        width: min(max(value.translation.width * 0.1, -maxOffset), maxOffset),
                        height: min(max(value.translation.height * 0.1, -maxOffset), maxOffset),
                    )
                }
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    parallaxOffset = .zero
                }
            }
    }

    // MARK: - Glow Pulse Effect

    private func triggerGlowPulse() {
        withAnimation(.easeOut(duration: 0.2)) {
            glowIntensity = 1.0
        }
        withAnimation(.easeIn(duration: 0.4).delay(0.2)) {
            glowIntensity = 0.0
        }
    }

    // MARK: - Featured Shimmer

    private func startFeatureShimmer() {
        guard style == .featured else { return }
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            shimmerPhase = 1
        }
    }

    // MARK: - Card Content

    private var cardContent: some View {
        Group {
            switch style {
            case .modern:
                modernLayout
            default:
                standardCardLayout
            }
        }
        .background {
            if style == .modern {
                modernBackground
            } else {
                glassBackground
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
        .overlay(style == .modern ? nil : glassOverlay)
        .overlay(style == .modern ? nil : highlightOverlay)
        .overlay(style == .modern ? nil : featuredBorderOverlay)
        .overlay(style == .modern ? nil : glowOverlay)
        .shadow(
            color: style == .modern ? .black.opacity(0.08) : categoryColor.opacity(0.15 + glowIntensity * 0.3),
            radius: style == .modern ? 8 : 20 + glowIntensity * 10,
            y: style == .modern ? 4 : 10,
        )
        .shadow(
            color: Color.black.opacity(style == .modern ? 0.04 : 0.1),
            radius: style == .modern ? 4 : 12,
            y: style == .modern ? 2 : 6,
        )
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
    }

    // MARK: - Standard Card Layout

    private var standardCardLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            imageSection
            contentSection
        }
    }

    // MARK: - Modern Layout (Square image, user info, minimal design)

    @State private var isLikedByDoubleTap = false

    private var modernLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Square image with overlays
            ZStack {
                // Main image - square aspect ratio
                if let imageUrl = item.displayImageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            modernPlaceholder
                        case let .success(image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            modernPlaceholder
                        @unknown default:
                            modernPlaceholder
                        }
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
                } else {
                    modernPlaceholder
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .clipped()
                }

                // Instagram-style double-tap to like overlay
                DoubleTapLikeOverlay(isLiked: $isLikedByDoubleTap) {
                    // Like action handled by the overlay
                    Task {
                        try? await PostEngagementService.shared.toggleLike(postId: item.id)
                    }
                }

                // Top overlay - Category badge & Like/Save buttons
                VStack {
                    HStack(alignment: .top) {
                        Spacer()

                        // Like & Save buttons (top-right)
                        HStack(spacing: Spacing.xs) {
                            CompactEngagementLikeButton(
                                domain: EngagementDomain.post(id: item.id),
                                initialIsLiked: isLikedByDoubleTap,
                            )
                            .background(
                                Circle()
                                    #if !SKIP
                                    .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                                    #else
                                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                                    #endif
                                    .frame(width: 36.0, height: 36),
                            )

                            BookmarkButton(
                                postId: item.id,
                                initialIsBookmarked: false,
                                size: .small,
                            )
                        }
                    }
                    .padding(Spacing.sm)

                    Spacer()

                    // Bottom overlay - Time posted (bottom-left)
                    HStack {
                        modernTimeBadge
                        Spacer()
                    }
                    .padding(Spacing.sm)
                }
            }
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: cardCornerRadius,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: cardCornerRadius,
                ),
            )

            // Content section
            modernContentSection
                .padding(Spacing.sm)
        }
    }

    // MARK: - Modern Components

    @ViewBuilder
    private var modernImageView: some View {
        if let imageUrl = item.displayImageUrl, let url = URL(string: imageUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    modernPlaceholder
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        #if !SKIP
                        .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                        #endif
                case .failure:
                    modernPlaceholder
                @unknown default:
                    modernPlaceholder
                }
            }
        } else {
            modernPlaceholder
        }
    }

    private var modernPlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        categoryColor.opacity(0.3),
                        categoryColor.opacity(0.5),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                ),
            )
            .overlay(
                Image(systemName: categoryIcon)
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.6)),
            )
    }

    private var modernTimeBadge: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "clock.fill")
                .font(.system(size: 10))
            Text(modernTimeAgo)
                .font(.DesignSystem.captionSmall)
                .fontWeight(.medium)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6)),
        )
    }

    private var modernTimeAgo: String {
        let now = Date()
        let diff = now.timeIntervalSince(item.createdAt)
        let mins = Int(diff / 60)
        let hours = Int(diff / 3600)
        let days = Int(diff / 86400)

        if mins < 1 { return "now" }
        if mins < 60 { return "\(mins)m" }
        if hours < 24 { return "\(hours)h" }
        if days < 7 { return "\(days)d" }
        if days < 30 { return "\(days / 7)w" }
        return "\(days / 30)mo"
    }

    private var modernContentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // User row - Avatar + Name + Distance
            HStack(spacing: Spacing.xs) {
                // User avatar placeholder
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 28.0, height: 28)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(categoryColor),
                    )

                Text("Sharer")
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)

                Spacer()

                // Distance badge
                if let distance = item.distanceDisplay {
                    HStack(spacing: 2) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                        Text(distance)
                            .font(.DesignSystem.captionSmall)
                    }
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                }
            }

            // Title - 2 lines max
            Text(item.title)
                .font(.DesignSystem.headlineSmall)
                .fontWeight(.medium)
                .foregroundStyle(Color.DesignSystem.text)
                .lineLimit(2)

            // Location - single line (uses privacy-friendly stripped address)
            if let address = item.displayAddress {
                Text(address)
                    .font(.DesignSystem.captionSmall)
                    .foregroundStyle(Color.DesignSystem.textTertiary)
                    .lineLimit(1)
            }
        }
    }

    private var modernBackground: some View {
        RoundedRectangle(cornerRadius: cardCornerRadius)
            #if !SKIP
            .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
            #else
            .fill(Color.DesignSystem.glassSurface.opacity(0.15))
            #endif
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
            )
    }

    // MARK: - Style-Based Properties

    private var cardCornerRadius: CGFloat {
        switch style {
        case .standard: CornerRadius.xl
        case .compact: CornerRadius.large
        case .featured: CornerRadius.xxl
        case .modern: CornerRadius.large
        }
    }

    private var imageHeight: CGFloat {
        switch style {
        case .standard: 180
        case .compact: 120
        case .featured: 220
        case .modern: 160
        }
    }

    // MARK: - Glow Overlay (Interactive)

    @ViewBuilder
    private var glowOverlay: some View {
        if glowIntensity > 0 {
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .stroke(categoryColor.opacity(glowIntensity * 0.6), lineWidth: 2)
                .blur(radius: 4)
        }
    }

    // MARK: - Featured Border Overlay (Animated Shimmer)

    @ViewBuilder
    private var featuredBorderOverlay: some View {
        if style == .featured {
            #if !SKIP
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            categoryColor.opacity(0.8),
                            categoryColor.opacity(0.2),
                            Color.white.opacity(0.5),
                            categoryColor.opacity(0.2),
                            categoryColor.opacity(0.8),
                        ]),
                        center: .center,
                        angle: Angle.degrees(shimmerPhase * 360),
                    ),
                    lineWidth: 2,
                )
            #endif
        }
    }

    // MARK: - Glass Background

    private var glassBackground: some View {
        ZStack {
            // Base ultra-thin material
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif

            // Subtle category-tinted gradient at bottom
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            categoryColor.opacity(0.05),
                        ],
                        startPoint: .top,
                        endPoint: .bottom,
                    ),
                )

            // Inner light reflection at top
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.02),
                            Color.clear,
                        ],
                        startPoint: .top,
                        endPoint: .center,
                    ),
                )
        }
    }

    // MARK: - Glass Overlay (Border & Glow)

    private var glassOverlay: some View {
        RoundedRectangle(cornerRadius: cardCornerRadius)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.3),
                        Color.DesignSystem.glassBorder,
                        Color.white.opacity(0.1),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                ),
                lineWidth: 1,
            )
    }

    // MARK: - Highlight Overlay (On Tap)

    @ViewBuilder
    private var highlightOverlay: some View {
        if enableAnimations {
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .fill(Color.clear)
                .glassHighlightSweep(trigger: $highlightTrigger, color: .white)
        }
    }

    // MARK: - Image Section

    private var imageSection: some View {
        ZStack(alignment: .topLeading) {
            // Main Image
            imageView

            // Gradient overlay for text readability
            LinearGradient(
                colors: [.clear, .black.opacity(0.3)],
                startPoint: .center,
                endPoint: .bottom,
            )

            // Badges
            VStack {
                HStack {
                    categoryBadge
                    Spacer()
                    if item.status != .available {
                        statusBadge
                    }
                }
                .padding(Spacing.sm)

                Spacer()

                // Distance badge at bottom
                if let distance = item.distanceDisplay {
                    HStack {
                        Spacer()
                        distanceBadge(distance)
                    }
                    .padding(Spacing.sm)
                }
            }
        }
        .frame(height: imageHeight)
        .clipShape(
            .rect(
                topLeadingRadius: cardCornerRadius,
                topTrailingRadius: cardCornerRadius,
            ),
        )
    }

    @ViewBuilder
    private var imageView: some View {
        if let imageUrl = item.displayImageUrl, let url = URL(string: imageUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    shimmerPlaceholder
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        #if !SKIP
                        .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                        #endif
                case .failure:
                    placeholderImage
                @unknown default:
                    placeholderImage
                }
            }
        } else {
            placeholderImage
        }
    }

    private var shimmerPlaceholder: some View {
        Rectangle()
            .fill(Color.DesignSystem.glassBackground)
            .overlay(
                ShimmerView(),
            )
    }

    private var placeholderImage: some View {
        Rectangle()
            .fill(categoryGradient)
            .overlay(
                Image(systemName: categoryIcon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.white.opacity(0.6)),
            )
    }

    // MARK: - Badges

    private var categoryBadge: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: categoryIcon)
                .font(.system(size: 10, weight: .semibold))
            Text(categoryName)
                .font(.DesignSystem.captionSmall)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(categoryColor.opacity(0.9))
                .background(
                    Capsule()
                        #if !SKIP
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                        #else
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                        #endif
                ),
        )
    }

    private var statusBadge: some View {
        Text(item.status.displayName)
            .font(.DesignSystem.captionSmall)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.9)),
            )
    }

    private func distanceBadge(_ distance: String) -> some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "location.fill")
                .font(.system(size: 10))
            Text(distance)
                .font(.DesignSystem.captionSmall)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(.black.opacity(0.5))
                .background(
                    Capsule()
                        #if !SKIP
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                        #else
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                        #endif
                ),
        )
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Title
            Text(item.title)
                .font(.DesignSystem.headlineSmall)
                .fontWeight(.semibold)
                .foregroundColor(.DesignSystem.text)
                .lineLimit(2)

            // Description
            if let description = item.description, !description.isEmpty {
                Text(description)
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
                    .lineLimit(2)
            }

            // Metadata row
            metadataRow
        }
        .padding(Spacing.md)
    }

    private var metadataRow: some View {
        HStack(spacing: Spacing.md) {
            // Pickup time or available hours
            if let time = item.pickupTime ?? item.availableHours {
                Label {
                    Text(time)
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "clock.fill")
                }
                .font(.DesignSystem.caption)
                .foregroundColor(.DesignSystem.textSecondary)
            }

            Spacer()

            // Views count
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "eye.fill")
                Text("\(item.postViews)")
            }
            .font(.DesignSystem.caption)
            .foregroundColor(.DesignSystem.textTertiary)

            // Likes
            if let likes = item.postLikeCounter, likes > 0 {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "heart.fill")
                    Text("\(likes)")
                }
                .font(.DesignSystem.caption)
                .foregroundColor(.DesignSystem.error.opacity(0.8))
            }
        }
    }

    // MARK: - Category Helpers

    private var category: ListingCategory {
        ListingCategory(rawValue: item.postType) ?? .food
    }

    private var categoryIcon: String {
        category.icon
    }

    private var categoryName: String {
        category.displayName
    }

    private var categoryColor: Color {
        category.color
    }

    private var categoryGradient: LinearGradient {
        category.gradient
    }

    private var statusColor: Color {
        switch item.status {
        case .available: .DesignSystem.success
        case .arranged: .DesignSystem.warning
        case .inactive: .gray
        }
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var description = "\(item.title). \(categoryName)"

        if let itemDescription = item.description, !itemDescription.isEmpty {
            description += ". \(itemDescription)"
        }

        if let distance = item.distanceDisplay {
            description += ". \(distance) away"
        }

        if item.status != .available {
            description += ". Status: \(item.status.displayName)"
        }

        if let time = item.pickupTime ?? item.availableHours {
            description += ". Available \(time)"
        }

        if let likes = item.postLikeCounter, likes > 0 {
            description += ". \(likes) likes"
        }

        description += ". \(item.postViews) views"

        return description
    }
}

// MARK: - Enhanced Card Press Style

struct EnhancedCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? 0.02 : 0)
            .rotation3DEffect(
                Angle.degrees(configuration.isPressed ? 1 : 0),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.5,
            )
            .animation(Animation.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Legacy Card Press Style (for backward compatibility)

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(Animation.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Compact Listing Row

struct CompactListingRow: View {
    let item: FoodItem
    let isSaved: Bool
    let onSave: () -> Void

    // MARK: - State

    @State private var isLiked = false
    @State private var likeCount = 0
    @State private var isLoadingStatus = true
    @State private var isUpdating = false
    @State private var lastTapTime: Date?

    // MARK: - Logger

    private static let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "CompactListingRow")

    // MARK: - Category Helpers

    private var category: ListingCategory {
        ListingCategory(rawValue: item.postType) ?? .food
    }

    private var categoryColor: Color {
        category.color
    }

    private var categoryIcon: String {
        category.icon
    }

    // MARK: - Init

    init(item: FoodItem, isSaved: Bool, onSave: @escaping () -> Void) {
        self.item = item
        self.isSaved = isSaved
        self.onSave = onSave
        // Initialize with item's like count
        _likeCount = State(initialValue: item.postLikeCounter ?? 0)
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Thumbnail with AsyncImage for proper error handling
            thumbnailView
                .frame(width: 80.0, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                )

            // Content
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                // Title
                Text(item.title)
                    .font(.DesignSystem.labelLarge)
                    .foregroundStyle(Color.DesignSystem.text)
                    .lineLimit(1)

                // Location
                Label(item.postAddress ?? "Nearby", systemImage: "location.fill")
                    .font(.DesignSystem.captionSmall)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .lineLimit(1)

                // Stats row with view count and interactive like button
                HStack(spacing: Spacing.md) {
                    // Views stat
                    HStack(spacing: 3) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 12, weight: .medium))
                        Text("\(item.postViews)")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color.DesignSystem.textTertiary)

                    // Like button with proper state management
                    Button {
                        toggleLike()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(isLiked
                                    ? Color.DesignSystem.brandPink
                                    : Color.DesignSystem.textTertiary)
                                    #if !SKIP
                                    .symbolEffect(.bounce, value: isLiked)
                                    #endif
                            Text("\(likeCount)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(isLiked
                                    ? Color.DesignSystem.brandPink
                                    : Color.DesignSystem.textTertiary)
                                    #if !SKIP
                                    .contentTransition(.numericText())
                                    #endif
                        }
                        .opacity(isLoadingStatus ? 0.5 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .disabled(isUpdating)
                }
            }

            Spacer()

            // Bookmark button
            BookmarkButton(
                postId: item.id,
                initialIsBookmarked: isSaved,
                size: .small,
            )

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.DesignSystem.textTertiary)
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
        .task {
            await fetchLikeStatus()
        }
    }

    // MARK: - Server Communication

    private func fetchLikeStatus() async {
        Self.logger.info("🔍 [LIKE] Fetching status for post \(item.id)")

        do {
            let status = try await PostEngagementService.shared.checkLiked(postId: item.id)
            Self.logger.info("✅ [LIKE] Post \(item.id): liked=\(status.isLiked), count=\(status.likeCount)")
            isLiked = status.isLiked
            likeCount = status.likeCount
        } catch {
            Self.logger.error("❌ [LIKE] Failed to fetch status for post \(item.id): \(error.localizedDescription)")
            // Keep initial values from item
            likeCount = item.postLikeCounter ?? 0
        }

        isLoadingStatus = false
    }

    private func toggleLike() {
        // Debounce rapid taps (0.5s)
        let now = Date()
        if let lastTap = lastTapTime, now.timeIntervalSince(lastTap) < 0.5 {
            Self.logger.debug("🚫 [LIKE] Debounced tap for post \(item.id)")
            return
        }
        lastTapTime = now

        Self.logger.info("❤️ [LIKE] Toggle for post \(item.id), currently: \(isLiked)")

        // Store previous state for rollback
        let wasLiked = isLiked
        let previousCount = likeCount

        // Optimistic update
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1

        // Haptic feedback
        if isLiked {
            HapticManager.success()
        } else {
            HapticManager.light()
        }

        // Server update
        isUpdating = true
        Task {
            do {
                let result = try await PostEngagementService.shared.toggleLike(postId: item.id)
                Self.logger
                    .info(
                        "✅ [LIKE] Server response for post \(item.id): liked=\(result.isLiked), count=\(result.likeCount)",
                    )

                // Reconcile with server
                isLiked = result.isLiked
                likeCount = result.likeCount
            } catch {
                Self.logger.error("❌ [LIKE] Failed to toggle for post \(item.id): \(error.localizedDescription)")

                // Rollback on error
                isLiked = wasLiked
                likeCount = previousCount
                HapticManager.error()
            }
            isUpdating = false
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let imageUrl = item.displayImageUrl, let url = URL(string: imageUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ShimmerView()
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    thumbnailPlaceholder
                @unknown default:
                    thumbnailPlaceholder
                }
            }
        } else {
            thumbnailPlaceholder
        }
    }

    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.DesignSystem.brandGreen.opacity(0.3),
                        Color.DesignSystem.brandGreen.opacity(0.5),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                ),
            )
            .overlay(
                Image(systemName: "leaf.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.6)),
            )
    }
}

// MARK: - Card Parallax Modifier

private struct CardParallaxModifier: ViewModifier {
    let offset: CGSize
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .rotation3DEffect(
                    .degrees(Double(offset.width) * 0.5),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5,
                )
                .rotation3DEffect(
                    .degrees(Double(-offset.height) * 0.5),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.5,
                )
                .offset(x: offset.width * 0.5, y: offset.height * 0.5)
        } else {
            content
        }
    }
}

#if DEBUG
    #Preview {
        ScrollView {
            VStack(spacing: Spacing.md) {
                GlassListingCard(item: .fixture())

                GlassListingCard(item: .fixture(
                    postName: "Community Fridge - Downtown",
                    postDescription: "24/7 access, always stocked with fresh produce",
                    postType: "fridge",
                    foodStatus: "pretty full",
                ))

                GlassListingCard(item: .fixture(
                    postName: "Volunteer Needed",
                    postDescription: "Help distribute food at local shelter",
                    postType: "volunteer",
                    isArranged: true,
                ))
            }
            .padding()
        }
        .background(Color.DesignSystem.background)
    }
#endif

#endif
