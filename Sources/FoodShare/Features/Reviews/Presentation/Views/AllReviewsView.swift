//
//  AllReviewsView.swift
//  Foodshare
//
//  Full list of reviews for a food item
//  Liquid Glass v26 design system
//

import SwiftUI
import FoodShareDesignSystem



struct AllReviewsView: View {
    
    @Environment(\.translationService) private var t
    let postId: Int
    let postName: String
    let reviews: [Review]

    @State private var sortOption: SortOption = .newest

    enum SortOption: String, CaseIterable {
        case newest
        case oldest
        case highestRating = "highest_rating"
        case lowestRating = "lowest_rating"

        @MainActor
        func displayName(_ t: TranslationService) -> String {
            t.t("reviews.sort.\(rawValue)")
        }
    }

    private var sortedReviews: [Review] {
        switch sortOption {
        case .newest:
            return reviews.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            return reviews.sorted { $0.createdAt < $1.createdAt }
        case .highestRating:
            return reviews.sorted { $0.reviewedRating > $1.reviewedRating }
        case .lowestRating:
            return reviews.sorted { $0.reviewedRating < $1.reviewedRating }
        }
    }

    private var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        let total = reviews.reduce(0) { $0 + $1.reviewedRating }
        return Double(total) / Double(reviews.count)
    }

    private var ratingDistribution: [Int: Int] {
        var distribution: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
        for review in reviews {
            distribution[review.reviewedRating, default: 0] += 1
        }
        return distribution
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                ratingSummaryCard
                sortPicker
                reviewsList
            }
            .padding(Spacing.md)
        }
        .background(Color.backgroundGradient)
        .navigationTitle(t.t("reviews.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Rating Summary Card

    private var ratingSummaryCard: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(postName)
                        .font(.DesignSystem.headlineMedium)
                        .foregroundColor(.DesignSystem.text)
                        .lineLimit(2)

                    Text(t.t("reviews.review_count", args: ["count": "\(reviews.count)"]))
                        .font(.DesignSystem.bodySmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                }
                Spacer()
            }

            Divider()
                .background(Color.DesignSystem.glassBorder)

            HStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.xs) {
                    Text(String(format: "%.1f", averageRating))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    StarRatingView(rating: averageRating, size: 16)
                }

                VStack(spacing: Spacing.xs) {
                    ForEach((1...5).reversed(), id: \.self) { star in
                        ratingBar(star: star)
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                )
        )
    }


    // MARK: - Rating Bar

    private func ratingBar(star: Int) -> some View {
        let count = ratingDistribution[star] ?? 0
        let percentage = reviews.isEmpty ? 0.0 : Double(count) / Double(reviews.count)

        return HStack(spacing: Spacing.sm) {
            Text("\(star)")
                .font(.DesignSystem.captionSmall)
                .foregroundColor(.DesignSystem.textSecondary)
                .frame(width: 12)

            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundColor(.yellow)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.DesignSystem.glassBackground)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * percentage, height: 6)
                }
            }
            .frame(height: 6)

            Text("\(count)")
                .font(.DesignSystem.captionSmall)
                .foregroundColor(.DesignSystem.textTertiary)
                .frame(width: 24, alignment: .trailing)
        }
    }

    // MARK: - Sort Picker

    private var sortPicker: some View {
        HStack {
            Text(t.t("common.sort_by"))
                .font(.DesignSystem.labelMedium)
                .foregroundColor(.DesignSystem.textSecondary)

            Spacer()

            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            sortOption = option
                        }
                        HapticManager.selection()
                    } label: {
                        HStack {
                            Text(option.displayName(t))
                            if sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text(sortOption.displayName(t))
                        .font(.DesignSystem.labelMedium)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.DesignSystem.brandGreen)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(Color.DesignSystem.brandGreen.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, Spacing.sm)
    }

    // MARK: - Reviews List

    private var reviewsList: some View {
        LazyVStack(spacing: Spacing.md) {
            ForEach(sortedReviews) { review in
                ReviewCard(review: review)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AllReviewsView(
            postId: 1,
            postName: "Fresh Vegetables from Garden",
            reviews: [
                Review(
                    id: 1,
                    profileId: UUID(),
                    postId: 1,
                    forumId: nil,
                    challengeId: nil,
                    reviewedRating: 5,
                    feedback: "Amazing fresh produce!",
                    notes: "",
                    createdAt: Date(),
                    reviewer: nil
                )
            ]
        )
    }
}
