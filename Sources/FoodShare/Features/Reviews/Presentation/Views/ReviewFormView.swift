//
//  ReviewFormView.swift
//  Foodshare
//
//  Form for submitting a review
//

import SwiftUI
import FoodShareDesignSystem

#if DEBUG
    import Inject
#endif

struct ReviewFormView: View {
    
    @Environment(\.translationService) private var t
    @Bindable var viewModel: ReviewViewModel
    let postId: Int
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    ratingSection
                    feedbackSection
                    submitButton
                }
                .padding(Spacing.md)
            }
            .background(Color.backgroundGradient)
            .navigationTitle(t.t("reviews.write_review"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(t.t("common.cancel")) { onDismiss() }
                }
            }
            .alert(t.t("common.error.title"), isPresented: $viewModel.showError) {
                Button(t.t("common.ok")) { viewModel.clearError() }
            } message: {
                if let error = viewModel.error {
                    Text(error.errorDescription ?? "Unknown error")
                }
            }
        }
    }

    private var ratingSection: some View {
        VStack(spacing: Spacing.md) {
            Text(t.t("reviews.how_was_experience"))
                .font(.LiquidGlass.headlineMedium)
                .foregroundColor(.DesignSystem.text)

            HStack(spacing: Spacing.md) {
                ForEach(1 ... 5, id: \.self) { star in
                    Button {
                        viewModel.rating = star
                    } label: {
                        Image(systemName: star <= viewModel.rating ? "star.fill" : "star")
                            .font(.title)
                            .foregroundStyle(
                                star <= viewModel.rating
                                    ? Color.DesignSystem.starRatingGradient
                                    : Color.DesignSystem.starEmptyGradient,
                            )
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .glassBackground()
    }

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(t.t("reviews.your_feedback"))
                .font(.LiquidGlass.labelLarge)
                .foregroundColor(.DesignSystem.text)

            TextEditor(text: $viewModel.feedback)
                .frame(minHeight: 120)
                .padding(Spacing.sm)
                .background(Color.DesignSystem.glassBackground)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        }
        .padding(Spacing.md)
        .glassBackground()
    }

    private var submitButton: some View {
        GlassButton(
            viewModel.isSubmitting ? t.t("common.submitting") : t.t("reviews.submit_review"),
            icon: viewModel.isSubmitting ? nil : "paperplane.fill",
            style: .primary,
            isLoading: viewModel.isSubmitting,
        ) {
            Task {
                await viewModel.submitReview(forPostId: postId)
                HapticManager.success()
                onDismiss()
            }
        }
        .disabled(!viewModel.canSubmit)
    }
}

// MARK: - Review Card (Liquid Glass Enhanced)

struct ReviewCard: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header with rating and date
            HStack {
                // Star rating with gradient
                HStack(spacing: 3) {
                    ForEach(1 ... 5, id: \.self) { star in
                        Image(systemName: star <= review.reviewedRating ? "star.fill" : "star")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(
                                star <= review.reviewedRating
                                    ? Color.DesignSystem.starRatingGradient
                                    : Color.DesignSystem.starEmptyGradient,
                            )
                    }
                }

                Spacer()

                // Date
                Text(review.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(.DesignSystem.textTertiary)
            }

            // Feedback text
            Text(review.feedback)
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.text)
                .lineSpacing(4)

            // Reviewer info (if available)
            if let reviewer = review.reviewer {
                HStack(spacing: Spacing.sm) {
                    // Avatar
                    AsyncImage(url: reviewer.avatarURL) { phase in
                        switch phase {
                        case let .success(image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .DesignSystem.brandGreen.opacity(0.3),
                                            .DesignSystem.brandBlue.opacity(0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing,
                                    ),
                                )
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.DesignSystem.textSecondary)
                                }
                        }
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())

                    Text(reviewer.displayName)
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textSecondary)

                    if reviewer.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.DesignSystem.brandGreen)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.DesignSystem.glassBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
    }
}

// MARK: - Star Rating View (Liquid Glass Enhanced)

struct StarRatingView: View {
    let rating: Double
    var size: CGFloat = 14
    var spacing: CGFloat = 3

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1 ... 5, id: \.self) { star in
                let fillLevel = starFillLevel(for: star)
                Image(systemName: starIcon(fillLevel: fillLevel))
                    .font(.system(size: size, weight: .medium))
                    .foregroundStyle(
                        fillLevel == .empty
                            ? Color.DesignSystem.starEmptyGradient
                            : Color.DesignSystem.starRatingGradient,
                    )
            }
        }
    }

    private enum FillLevel {
        case full, half, empty
    }

    private func starFillLevel(for star: Int) -> FillLevel {
        let starDouble = Double(star)
        if starDouble <= rating {
            return .full
        } else if starDouble - 0.5 <= rating {
            return .half
        } else {
            return .empty
        }
    }

    private func starIcon(fillLevel: FillLevel) -> String {
        switch fillLevel {
        case .full: "star.fill"
        case .half: "star.leadinghalf.filled"
        case .empty: "star"
        }
    }
}
