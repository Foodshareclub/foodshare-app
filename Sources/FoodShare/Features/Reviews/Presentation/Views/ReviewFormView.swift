//
//  ReviewFormView.swift
//  Foodshare
//
//  Form for submitting a review
//


#if !SKIP
import SwiftUI

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


#endif
