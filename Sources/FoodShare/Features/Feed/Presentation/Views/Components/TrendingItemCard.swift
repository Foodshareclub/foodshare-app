//
//  TrendingItemCard.swift
//  Foodshare
//
//  Compact card for displaying trending food items
//  Enhanced with Instagram-style like button animations
//

import FoodShareDesignSystem
import SwiftUI

// MARK: - Trending Item Card

struct TrendingItemCard: View {
    let item: FoodItem
    @Environment(\.translationService) private var t

    @State private var isLiked = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Image with like overlay
            ZStack(alignment: .topTrailing) {
                // Double-tap to like on image
                ZStack {
                    AsyncImage(url: URL(string: item.primaryImageUrl ?? "")) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            Color.DesignSystem.glassBackground
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 24))
                                        .foregroundColor(.DesignSystem.textTertiary),
                                )
                        @unknown default:
                            Color.DesignSystem.glassBackground
                        }
                    }

                    // Instagram-style double-tap to like
                    DoubleTapLikeOverlay(isLiked: $isLiked) {
                        Task {
                            try? await PostEngagementService.shared.toggleLike(postId: item.id)
                        }
                    }
                }
                .frame(width: 140, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))

                // Top overlay: Like button + Trending badge
                VStack {
                    HStack {
                        Spacer()

                        // Compact like button
                        CompactEngagementLikeButton(
                            domain: .post(id: item.id),
                            initialIsLiked: isLiked,
                            onToggle: { liked in
                                isLiked = liked
                            },
                        )
                        .scaleEffect(0.7)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 28, height: 28),
                        )
                    }
                    .padding(4)

                    Spacer()

                    // Trending badge (bottom-left)
                    HStack {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 8))
                            Text("\(item.postViews)")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.DesignSystem.warning),
                        )

                        Spacer()
                    }
                    .padding(4)
                }
            }

            // Title
            Text(item.title)
                .font(.DesignSystem.labelSmall)
                .fontWeight(.medium)
                .foregroundColor(.DesignSystem.text)
                .lineLimit(1)

            // Location (uses stripped address for privacy)
            HStack(spacing: 2) {
                Image(systemName: "location.fill")
                    .font(.system(size: 8))
                Text(item.displayAddress ?? t.t("map.nearby"))
                    .font(.DesignSystem.captionSmall)
                    .lineLimit(1)
            }
            .foregroundColor(.DesignSystem.textTertiary)
        }
        .frame(width: 140)
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
        .task {
            // Fetch actual like status from server
            do {
                let status = try await PostEngagementService.shared.checkLiked(postId: item.id)
                isLiked = status.isLiked
            } catch {
                // Silently fail - engagement is non-critical
            }
        }
    }
}

// MARK: - Feed Stat Pill

struct FeedStatPill: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = .DesignSystem.brandGreen

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)

            Text(value)
                .font(.DesignSystem.labelSmall)
                .fontWeight(.semibold)
                .foregroundColor(.DesignSystem.text)

            Text(label)
                .font(.DesignSystem.captionSmall)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(
            Capsule()
                .fill(.ultraThinMaterial),
        )
    }
}
