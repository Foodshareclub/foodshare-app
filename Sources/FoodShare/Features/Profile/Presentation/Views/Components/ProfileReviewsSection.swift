//
//  ProfileReviewsSection.swift
//  FoodShare
//
//  Displays user reviews with star ratings and summary.
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Reviews Section

struct ProfileReviewsSection: View {
    @Environment(\.translationService) private var t
    let viewModel: ProfileViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            headerRow

            if viewModel.isLoadingReviews {
                loadingState
            } else if viewModel.reviews.isEmpty {
                ReviewsEmptyState()
            } else {
                ReviewsContent(viewModel: viewModel)
            }
        }
        .padding(Spacing.md)
        .glassEffect(cornerRadius: CornerRadius.large)
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "star.bubble.fill")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(t.t("profile.reviews"))
                    .font(.LiquidGlass.headlineSmall)
                    .foregroundStyle(Color.DesignSystem.text)
            }

            Spacer()

            if !viewModel.reviews.isEmpty {
                Text("\(viewModel.reviewCount)")
                    .font(.LiquidGlass.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            NavigationLink(value: ProfileDestination.reviews(
                reviews: viewModel.reviews,
                userName: viewModel.localizedDisplayName(using: t),
                rating: viewModel.profile?.ratingAverage ?? 0
            )) {
                Image(systemName: "chevron.right")
                    .font(.LiquidGlass.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        HStack {
            Spacer()
            ProgressView().scaleEffect(0.8)
            Spacer()
        }
        .padding(.vertical, Spacing.md)
    }
}

// MARK: - Reviews Empty State

struct ReviewsEmptyState: View {
    @Environment(\.translationService) private var t

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "star.leadinghalf.filled")
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow.opacity(0.5), .orange.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(t.t("profile.no_reviews"))
                .font(.LiquidGlass.caption)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
    }
}

// MARK: - Reviews Content

struct ReviewsContent: View {
    @Environment(\.translationService) private var t
    let viewModel: ProfileViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ratingSummary

            ForEach(viewModel.reviews.prefix(2)) { review in
                ReviewCard(review: review)
            }

            if viewModel.reviewCount > 2 {
                seeAllButton
            }
        }
    }

    // MARK: - Rating Summary

    private var ratingSummary: some View {
        HStack(spacing: Spacing.sm) {
            StarRatingView(rating: viewModel.profile?.ratingAverage ?? 0, size: 14)

            Text(String(format: "%.1f", viewModel.profile?.ratingAverage ?? 0))
                .font(.LiquidGlass.headlineSmall)
                .fontWeight(.bold)
                .foregroundStyle(Color.DesignSystem.text)

            Text("•")
                .foregroundStyle(Color.DesignSystem.textTertiary)

            Text(t.t("profile.review_count", args: ["count": "\(viewModel.reviewCount)"]))
                .font(.LiquidGlass.caption)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
    }

    // MARK: - See All Button

    private var seeAllButton: some View {
        NavigationLink(value: ProfileDestination.reviews(
            reviews: viewModel.reviews,
            userName: viewModel.localizedDisplayName(using: t),
            rating: viewModel.profile?.ratingAverage ?? 0
        )) {
            HStack(spacing: Spacing.xs) {
                Text(t.t("profile.see_all_reviews", args: ["count": "\(viewModel.reviewCount)"]))
                Image(systemName: "chevron.right")
            }
            .font(.LiquidGlass.labelMedium)
            .foregroundStyle(Color.DesignSystem.themed.primary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, Spacing.xs)
    }
}

// MARK: - Review Card

struct ReviewCard: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                if let avatarUrl = review.reviewer?.avatarUrl, let url = URL(string: avatarUrl) {
                    GlassAsyncImage.avatar(url: url, size: 32, borderWidth: 1)
                } else {
                    Circle()
                        .fill(Color.DesignSystem.glassBackground)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.DesignSystem.textSecondary)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(review.reviewer?.nickname ?? "Anonymous")
                        .font(.LiquidGlass.labelMedium)
                        .foregroundStyle(Color.DesignSystem.text)

                    StarRatingView(rating: Double(review.rating), size: 10)
                }

                Spacer()

                Text(review.formattedDate)
                    .font(.LiquidGlass.captionSmall)
                    .foregroundStyle(Color.DesignSystem.textTertiary)
            }

            Text(review.feedback)
                .font(.LiquidGlass.bodySmall)
                .foregroundStyle(Color.DesignSystem.textSecondary)
                .lineLimit(3)
        }
        .padding(Spacing.sm)
        .background(Color.DesignSystem.glassBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
}

// MARK: - Star Rating View

struct StarRatingView: View {
    let rating: Double
    let size: CGFloat
    let spacing: CGFloat

    init(rating: Double, size: CGFloat = 16, spacing: CGFloat = 2) {
        self.rating = rating
        self.size = size
        self.spacing = spacing
    }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...5, id: \.self) { index in
                starImage(for: index)
                    .font(.system(size: size))
                    .foregroundStyle(starColor(for: index))
            }
        }
    }

    private func starImage(for index: Int) -> Image {
        let value = Double(index)
        if rating >= value {
            return Image(systemName: "star.fill")
        } else if rating >= value - 0.5 {
            return Image(systemName: "star.leadinghalf.filled")
        } else {
            return Image(systemName: "star")
        }
    }

    private func starColor(for index: Int) -> Color {
        let value = Double(index)
        if rating >= value - 0.5 {
            return .yellow
        } else {
            return Color.DesignSystem.textTertiary
        }
    }
}
