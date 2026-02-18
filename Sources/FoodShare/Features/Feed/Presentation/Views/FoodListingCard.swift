//
//  FoodListingCard.swift
//  Foodshare
//
//  Reusable food listing card with Liquid Glass v26 design
//  Enhanced with Instagram-style like button animations
//


#if !SKIP
import SwiftUI

struct FoodListingCard: View {
    @Environment(\.translationService) private var t
    let listing: FoodItem

    @State private var isLiked = false
    @State private var likeCount = 0

    init(listing: FoodItem) {
        self.listing = listing
        _likeCount = State(initialValue: listing.postLikeCounter ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image with double-tap to like
            imageSection

            // Content
            contentSection
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.xl)
                        .stroke(Color.DesignSystem.glassStroke, lineWidth: 1),
                ),
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        .task {
            // Fetch actual like status from server
            do {
                let status = try await PostEngagementService.shared.checkLiked(postId: listing.id)
                isLiked = status.isLiked
                likeCount = status.likeCount
            } catch {
                // Use listing's count as fallback
                likeCount = listing.postLikeCounter ?? 0
            }
        }
    }

    // MARK: - Image Section

    private var imageSection: some View {
        ZStack(alignment: .topTrailing) {
            // Main Image with shimmer loading state
            ZStack {
                if let imageUrl = listing.displayImageUrl {
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            shimmerPlaceholder
                        case let .success(image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .transition(.opacity)
                        case .failure:
                            placeholderImage
                        @unknown default:
                            placeholderImage
                        }
                    }
                } else {
                    placeholderImage
                }

                // Instagram-style double-tap to like overlay
                DoubleTapLikeOverlay(isLiked: $isLiked) {
                    likeCount += 1
                    Task {
                        try? await PostEngagementService.shared.toggleLike(postId: listing.id)
                    }
                }
            }

            // Top-right: Like & Bookmark buttons
            VStack {
                HStack(spacing: Spacing.xs) {
                    Spacer()

                    // Like button with beautiful animation
                    CompactEngagementLikeButton(
                        domain: EngagementDomain.post(id: listing.id),
                        initialIsLiked: isLiked,
                        onToggle: { liked in
                            isLiked = liked
                            likeCount += liked ? 1 : -1
                        },
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

                    // Bookmark button
                    BookmarkButton(
                        postId: listing.id,
                        initialIsBookmarked: false,
                        size: .small,
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
                }
                .padding(Spacing.sm)

                Spacer()
            }

            // Status Badge (bottom-left)
            if listing.status != .available {
                VStack {
                    Spacer()
                    HStack {
                        statusBadge
                        Spacer()
                    }
                    .padding(Spacing.sm)
                }
            }
        }
        .frame(height: 200.0)
        .clipped()
        .clipShape(
            .rect(
                topLeadingRadius: CornerRadius.xl,
                topTrailingRadius: CornerRadius.xl,
            ),
        )
    }

    private var shimmerPlaceholder: some View {
        ImageShimmerPlaceholder()
    }

    private var placeholderImage: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.DesignSystem.brandGreen.opacity(0.3),
                        Color.DesignSystem.brandBlue.opacity(0.3),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                ),
            )
            .overlay(
                Image(systemName: postTypeIcon)
                    .font(.system(size: 50))
                    .foregroundColor(.white.opacity(0.5)),
            )
    }

    private var postTypeIcon: String {
        switch listing.postType {
        case "fridge": "refrigerator.fill"
        case "foodbank": "building.2.fill"
        case "thing": "shippingbox.fill"
        case "volunteer": "person.2.fill"
        default: "leaf.fill"
        }
    }

    private var statusBadge: some View {
        Text(listing.status.localizedDisplayName(using: t))
            .font(.DesignSystem.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill(statusColor),
            )
    }

    private var statusColor: Color {
        switch listing.status {
        case .available: .green
        case .arranged: .orange
        case .inactive: .gray
        }
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Title
            Text(listing.title)
                .font(.DesignSystem.headlineMedium)
                .foregroundColor(.DesignSystem.text)
                .lineLimit(2)

            // Description
            if let description = listing.description {
                Text(description)
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
                    .lineLimit(2)
            }

            // Metadata
            HStack(spacing: Spacing.md) {
                // Pickup Time
                if let pickupTime = listing.pickupTime {
                    Label(pickupTime, systemImage: "clock.fill")
                        .font(.DesignSystem.caption)
                        .foregroundColor(.DesignSystem.textSecondary)
                }

                Spacer()

                // Food Status (for fridges)
                if let foodStatus = listing.foodStatusDisplay {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "battery.50percent")
                        Text(foodStatus)
                    }
                    .font(.DesignSystem.caption)
                    .foregroundColor(.DesignSystem.brandGreen)
                }
            }

            Divider()
                .background(Color.DesignSystem.glassStroke)

            // Footer
            HStack {
                // Address (uses stripped address for privacy)
                if let address = listing.displayAddress {
                    Label(address, systemImage: "location.fill")
                        .font(.DesignSystem.caption)
                        .foregroundColor(.DesignSystem.brandGreen)
                        .lineLimit(1)
                }

                Spacer()

                // Engagement stats
                HStack(spacing: Spacing.md) {
                    // View Count
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "eye.fill")
                        Text("\(listing.postViews)")
                    }
                    .font(.DesignSystem.caption)
                    .foregroundColor(.DesignSystem.textSecondary)

                    // Like Count
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(likeCount > 0 ? .DesignSystem.brandPink : .DesignSystem.textSecondary)
                        Text("\(likeCount)")
                    }
                    .font(.DesignSystem.caption)
                    .foregroundColor(likeCount > 0 ? .DesignSystem.brandPink : .DesignSystem.textSecondary)
                }
            }
        }
        .padding(Spacing.md)
    }
}

// MARK: - Image Shimmer Placeholder

private struct ImageShimmerPlaceholder: View {
    @State private var shimmerPhase: CGFloat = -200

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base gradient
                LinearGradient(
                    colors: [
                        Color.DesignSystem.textTertiary.opacity(0.3),
                        Color.DesignSystem.textTertiary.opacity(0.2),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                )

                // Shimmer overlay
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
        }
    }
}

#if DEBUG
    #Preview {
        VStack(spacing: Spacing.lg) {
            FoodListingCard(listing: .fixture())

            FoodListingCard(listing: .fixture(
                postName: "Community Fridge",
                postDescription: "24/7 access, always stocked",
                postType: "fridge",
                isArranged: true,
            ))
        }
        .padding()
        .background(Color(.systemBackground))
    }
#endif

#endif
