//
//  UserReviewsView.swift
//  Foodshare
//
//  Full list of reviews received by a user
//  Enhanced with search, rating filters, and better analytics
//  Liquid Glass v26 design system
//


#if !SKIP
import SwiftUI

#if DEBUG
    import Inject
#endif

struct UserReviewsView: View {
    
    @Environment(\.translationService) private var t
    let reviews: [Review]
    let userName: String
    let averageRating: Double

    @State private var sortOption: SortOption = .newest
    @State private var searchText = ""
    @State private var selectedRatingFilter: Int?
    @State private var showShareSheet = false

    enum SortOption: String, CaseIterable {
        case newest
        case oldest
        case highestRating
        case lowestRating

        var titleKey: String {
            switch self {
            case .newest: "reviews.sort.newest"
            case .oldest: "reviews.sort.oldest"
            case .highestRating: "reviews.sort.highest_rating"
            case .lowestRating: "reviews.sort.lowest_rating"
            }
        }

        var icon: String {
            switch self {
            case .newest: "arrow.down.circle"
            case .oldest: "arrow.up.circle"
            case .highestRating: "star.circle.fill"
            case .lowestRating: "star.circle"
            }
        }
    }

    private var filteredReviews: [Review] {
        var result = reviews

        // Apply search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { review in
                review.feedback.lowercased().contains(query) ||
                    (review.reviewer?.displayName.lowercased().contains(query) ?? false)
            }
        }

        // Apply rating filter
        if let rating = selectedRatingFilter {
            result = result.filter { $0.reviewedRating == rating }
        }

        return result
    }

    private var sortedReviews: [Review] {
        switch sortOption {
        case .newest:
            filteredReviews.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            filteredReviews.sorted { $0.createdAt < $1.createdAt }
        case .highestRating:
            filteredReviews.sorted { $0.reviewedRating > $1.reviewedRating }
        case .lowestRating:
            filteredReviews.sorted { $0.reviewedRating < $1.reviewedRating }
        }
    }

    private var ratingDistribution: [Int: Int] {
        var distribution: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
        for review in reviews {
            distribution[review.reviewedRating, default: 0] += 1
        }
        return distribution
    }

    // Sentiment analysis
    private var sentimentSummary: (positive: Int, neutral: Int, negative: Int) {
        var positive = 0
        var neutral = 0
        var negative = 0

        for review in reviews {
            switch review.reviewedRating {
            case 4 ... 5: positive += 1
            case 3: neutral += 1
            default: negative += 1
            }
        }

        return (positive, neutral, negative)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Rating Summary Card
                ratingSummaryCard

                // Search bar
                searchBar

                // Rating filter chips
                ratingFilterChips

                // Sort Options
                sortPicker

                // Reviews List
                if sortedReviews.isEmpty, !searchText.isEmpty {
                    noResultsView
                } else {
                    reviewsList
                }
            }
            .padding(Spacing.md)
        }
        .background(Color.backgroundGradient)
        .navigationTitle(t.t("profile.reviews"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    shareReviewsSummary()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .foregroundColor(.DesignSystem.text)
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.DesignSystem.textSecondary)
                .font(.system(size: 16))

            TextField(t.t("reviews.search.placeholder"), text: $searchText)
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.text)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    HapticManager.light()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.DesignSystem.textSecondary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
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
    }

    // MARK: - Rating Filter Chips

    private var ratingFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                // All filter
                RatingFilterChip(
                    rating: nil,
                    count: reviews.count,
                    isSelected: selectedRatingFilter == nil,
                    onTap: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedRatingFilter = nil
                        }
                        HapticManager.selection()
                    },
                )

                // Individual rating filters
                ForEach((1 ... 5).reversed(), id: \.self) { rating in
                    let count = ratingDistribution[rating] ?? 0
                    if count > 0 {
                        RatingFilterChip(
                            rating: rating,
                            count: count,
                            isSelected: selectedRatingFilter == rating,
                            onTap: {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedRatingFilter = selectedRatingFilter == rating ? nil : rating
                                }
                                HapticManager.selection()
                            },
                        )
                    }
                }
            }
        }
        #if !SKIP
        .scrollBounceBehavior(.basedOnSize)
        .fixedSize(horizontal: false, vertical: true)
        #endif
    }

    // MARK: - No Results View

    private var noResultsView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.DesignSystem.textSecondary)

            Text(t.t("reviews.empty.no_results"))
                .font(.DesignSystem.headlineSmall)
                .foregroundColor(.DesignSystem.text)

            Text(t.t("reviews.empty.try_adjusting"))
                .font(.DesignSystem.bodySmall)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }

    // MARK: - Share Summary

    private func shareReviewsSummary() {
        let sentiment = sentimentSummary
        let summary = """
        ⭐ \(userName)'s Reviews Summary

        📊 Overall Rating: \(String(format: "%.1f", averageRating))/5.0
        📝 Total Reviews: \(reviews.count)

        😊 Positive: \(sentiment.positive)
        😐 Neutral: \(sentiment.neutral)
        😔 Negative: \(sentiment.negative)

        🌱 Shared via Foodshare
        """

        #if !SKIP
        let activityVC = UIActivityViewController(
            activityItems: [summary],
            applicationActivities: nil,
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #endif
        HapticManager.success()
    }

    // MARK: - Rating Summary Card

    private var ratingSummaryCard: some View {
        VStack(spacing: Spacing.md) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(userName)
                        .font(.DesignSystem.headlineMedium)
                        .foregroundColor(.DesignSystem.text)
                        .lineLimit(1)

                    Text(t.t("reviews.count", args: ["count": "\(reviews.count)"]))
                        .font(.DesignSystem.bodySmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                }

                Spacer()
            }

            Divider()
                .background(Color.DesignSystem.glassBorder)

            // Rating Overview
            HStack(spacing: Spacing.xl) {
                // Average Rating
                VStack(spacing: Spacing.xs) {
                    Text(String(format: "%.1f", averageRating))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )

                    StarRatingView(rating: averageRating, size: 16)
                }

                // Rating Distribution
                VStack(spacing: Spacing.xs) {
                    ForEach((1 ... 5).reversed(), id: \.self) { star in
                        ratingBar(star: star)
                    }
                }
            }
        }
        .padding(Spacing.lg)
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
    }

    // MARK: - Rating Bar

    private func ratingBar(star: Int) -> some View {
        let count = ratingDistribution[star] ?? 0
        let percentage = reviews.isEmpty ? 0.0 : Double(count) / Double(reviews.count)

        return HStack(spacing: Spacing.sm) {
            Text("\(star)")
                .font(.DesignSystem.captionSmall)
                .foregroundColor(.DesignSystem.textSecondary)
                .frame(width: 12.0)

            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundColor(.yellow)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.DesignSystem.glassBackground)
                        .frame(height: 6.0)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing,
                            ),
                        )
                        .frame(width: geometry.size.width * percentage, height: 6)
                }
            }
            .frame(height: 6.0)

            Text("\(count)")
                .font(.DesignSystem.captionSmall)
                .foregroundColor(.DesignSystem.textTertiary)
                .frame(width: 24.0, alignment: .trailing)
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
                            Text(t.t(option.titleKey))
                            if sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text(t.t(sortOption.titleKey))
                        .font(.DesignSystem.labelMedium)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.DesignSystem.brandGreen)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule()
                        #if !SKIP
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                        #else
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                        #endif
                        .overlay(
                            Capsule()
                                .stroke(Color.DesignSystem.brandGreen.opacity(0.3), lineWidth: 1),
                        ),
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
                        removal: .opacity,
                    ))
            }
        }
    }
}

// MARK: - Rating Filter Chip

struct RatingFilterChip: View {
    @Environment(\.translationService) private var t
    let rating: Int?
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.xs) {
                if let rating {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .white : .yellow)

                    Text("\(rating)")
                        .font(.DesignSystem.labelSmall)
                        .fontWeight(.semibold)
                } else {
                    Text(t.t("reviews.filter.all"))
                        .font(.DesignSystem.labelSmall)
                        .fontWeight(.semibold)
                }

                Text("(\(count))")
                    .font(.DesignSystem.captionSmall)
            }
            .foregroundColor(isSelected ? .white : .DesignSystem.text)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill(isSelected ? Color.DesignSystem.brandGreen : Color.DesignSystem.glassBackground),
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.DesignSystem.glassBorder, lineWidth: 1),
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        UserReviewsView(
            reviews: [
                Review(
                    id: 1,
                    profileId: UUID(),
                    postId: 1,
                    forumId: nil,
                    challengeId: nil,
                    reviewedRating: 5,
                    feedback: "Great food sharer! Everything was fresh and exactly as described. Highly recommend!",
                    notes: "",
                    createdAt: Date(),
                    reviewer: nil,
                ),
                Review(
                    id: 2,
                    profileId: UUID(),
                    postId: 2,
                    forumId: nil,
                    challengeId: nil,
                    reviewedRating: 4,
                    feedback: "Very friendly and the pickup was super easy. Would definitely get food from them again.",
                    notes: "",
                    createdAt: Date().addingTimeInterval(-86400),
                    reviewer: nil,
                ),
                Review(
                    id: 3,
                    profileId: UUID(),
                    postId: 3,
                    forumId: nil,
                    challengeId: nil,
                    reviewedRating: 5,
                    feedback: "Amazing experience! The vegetables were so fresh.",
                    notes: "",
                    createdAt: Date().addingTimeInterval(-172_800),
                    reviewer: nil,
                )
            ],
            userName: "John Doe",
            averageRating: 4.7,
        )
    }
}

#endif
