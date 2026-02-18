//
//  FeedbackView.swift
//  Foodshare
//
//  View for submitting feedback
//


#if !SKIP
import SwiftUI



struct FeedbackView: View {
    
    @Environment(\.translationService) private var t
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: FeedbackViewModel

    init(viewModel: FeedbackViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Success Banner
                    if viewModel.isSuccess {
                        successBanner
                    }

                    // Error Banner
                    if viewModel.showError, let error = viewModel.error {
                        errorBanner(error)
                    }

                    // Form Card
                    formCard
                }
                .padding(.vertical, Spacing.md)
            }
            .background(Color.DesignSystem.background)
            .navigationTitle(t.t("feedback.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t.t("common.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Success Banner

    private var successBanner: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.DesignSystem.brandGreen)

            Text(t.t("feedback.success_message"))
                .font(.DesignSystem.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(.DesignSystem.text)

            Spacer()

            Button {
                viewModel.dismissSuccess()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.DesignSystem.textSecondary)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.DesignSystem.brandGreen.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.DesignSystem.brandGreen.opacity(0.3), lineWidth: 1),
                ),
        )
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: AppError) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(Color.DesignSystem.error)

            Text(error.localizedDescription)
                .font(.DesignSystem.bodySmall)
                .foregroundColor(Color.DesignSystem.error)

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.DesignSystem.error.opacity(0.1)),
        )
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Form Card

    private var formCard: some View {
        VStack(spacing: Spacing.lg) {
            // Feedback Type
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(t.t("feedback.type._title"))
                    .font(.DesignSystem.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundColor(.DesignSystem.text)

                Menu {
                    ForEach(FeedbackType.allCases, id: \.self) { type in
                        Button {
                            viewModel.feedbackType = type
                        } label: {
                            Label(type.localizedDisplayName(using: t), systemImage: type.icon)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: viewModel.feedbackType.icon)
                            .foregroundColor(.DesignSystem.brandGreen)
                        Text(viewModel.feedbackType.localizedDisplayName(using: t))
                            .foregroundColor(.DesignSystem.text)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.DesignSystem.textSecondary)
                    }
                    .padding(Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            #if !SKIP
                            .fill(.ultraThinMaterial)
                            #else
                            .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                            #endif
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.medium)
                                    .stroke(Color.DesignSystem.glassStroke, lineWidth: 1),
                            ),
                    )
                }
            }

            // Name & Email Row
            HStack(spacing: Spacing.md) {
                // Name
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(t.t("common.name"))
                        .font(.DesignSystem.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundColor(.DesignSystem.text)

                    GlassTextField(t.t("feedback.placeholder.name"), text: $viewModel.name, icon: "person")
                }

                // Email
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(t.t("common.email"))
                        .font(.DesignSystem.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundColor(.DesignSystem.text)

                    GlassTextField(t.t("feedback.placeholder.email"), text: $viewModel.email, icon: "envelope")
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                }
            }

            // Subject
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(t.t("feedback.subject"))
                    .font(.DesignSystem.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundColor(.DesignSystem.text)

                GlassTextField(t.t("feedback.placeholder.subject"), text: $viewModel.subject, icon: "text.alignleft")
            }

            // Message
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(t.t("feedback.message"))
                    .font(.DesignSystem.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundColor(.DesignSystem.text)

                TextEditor(text: $viewModel.message)
                    .font(.DesignSystem.bodyMedium)
                    .frame(minHeight: 120)
                    .padding(Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            #if !SKIP
                            .fill(.ultraThinMaterial)
                            #else
                            .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                            #endif
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.medium)
                                    .stroke(Color.DesignSystem.glassStroke, lineWidth: 1),
                            ),
                    )
            }

            // Submit Button
            GlassButton(
                viewModel.isSubmitting ? t.t("feedback.sending") : t.t("feedback.send"),
                icon: viewModel.isSubmitting ? nil : "paperplane.fill",
                style: .primary,
                isLoading: viewModel.isSubmitting,
            ) {
                Task {
                    await viewModel.submitFeedback()
                }
            }
            .disabled(!viewModel.canSubmit)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                #if !SKIP
                .fill(.ultraThinMaterial)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassStroke, lineWidth: 1),
                ),
        )
        .padding(.horizontal, Spacing.md)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    FeedbackView(
        viewModel: FeedbackViewModel(
            repository: MockFeedbackRepository(),
            userId: UUID(),
            defaultName: "John Doe",
            defaultEmail: "john@example.com",
        ),
    )
}
#endif

#endif
