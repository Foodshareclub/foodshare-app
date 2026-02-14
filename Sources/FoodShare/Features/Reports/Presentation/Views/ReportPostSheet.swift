//
//  ReportPostSheet.swift
//  Foodshare
//
//  Sheet for reporting a post with reason selection
//

import SwiftUI
import FoodShareDesignSystem

struct ReportPostSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.translationService) private var t
    @State private var viewModel: ReportViewModel

    init(viewModel: ReportViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isSuccess {
                    successView
                } else if viewModel.hasAlreadyReported {
                    alreadyReportedView
                } else {
                    reportForm
                }
            }
            .navigationTitle(t.t("navigation.report_post"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t.t("common.cancel")) {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.checkIfAlreadyReported()
            }
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )

            Text(t.t("report.submitted"))
                .font(.DesignSystem.headlineLarge)
                .foregroundColor(.DesignSystem.text)

            Text(t.t("report.submitted_message"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Spacer()

            GlassButton(t.t("common.done"), style: .primary) {
                dismiss()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
    }

    // MARK: - Already Reported View

    private var alreadyReportedView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(Color.DesignSystem.warning)

            Text(t.t("report.already_reported"))
                .font(.DesignSystem.headlineLarge)
                .foregroundColor(.DesignSystem.text)

            Text(t.t("report.already_reported_message"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Spacer()

            GlassButton(t.t("common.close"), style: .secondary) {
                dismiss()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
    }

    // MARK: - Report Form

    private var reportForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color.DesignSystem.warning)
                        Text(t.t("report.report_title", args: ["name": viewModel.postName]))
                            .font(.DesignSystem.bodyLarge)
                            .fontWeight(.medium)
                            .foregroundColor(.DesignSystem.text)
                            .lineLimit(1)
                    }

                    Text(t.t("report.help_understand"))
                        .font(.DesignSystem.bodySmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                }
                .padding(.horizontal, Spacing.md)

                // Reason Selection
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(t.t("report.select_reason"))
                        .font(.DesignSystem.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(.DesignSystem.text)
                        .padding(.horizontal, Spacing.md)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: Spacing.sm) {
                        ForEach(ReportReason.allCases, id: \.self) { reason in
                            ReasonButton(
                                reason: reason,
                                isSelected: viewModel.selectedReason == reason,
                            ) {
                                withAnimation(.interpolatingSpring(stiffness: 300, damping: 24)) {
                                    viewModel.selectedReason = reason
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }

                // Description
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(t.t("report.additional_details"))
                        .font(.DesignSystem.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(.DesignSystem.text)

                    TextEditor(text: $viewModel.description)
                        .font(.DesignSystem.bodyMedium)
                        .foregroundStyle(Color.DesignSystem.text)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 100)
                        .padding(Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                                        .stroke(Color.DesignSystem.glassStroke, lineWidth: 1),
                                ),
                        )
                        .onChange(of: viewModel.description) { _, newValue in
                            if newValue.count > viewModel.maxDescriptionLength {
                                viewModel.description = String(newValue.prefix(viewModel.maxDescriptionLength))
                            }
                        }

                    Text("\(viewModel.descriptionCharacterCount)/\(viewModel.maxDescriptionLength)")
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textTertiary)
                }
                .padding(.horizontal, Spacing.md)

                // Error
                if viewModel.showError, let error = viewModel.error {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(Color.DesignSystem.error)
                        Text(error.localizedDescription)
                            .font(.DesignSystem.bodySmall)
                            .foregroundColor(Color.DesignSystem.error)
                    }
                    .padding(Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(Color.DesignSystem.error.opacity(0.1)),
                    )
                    .padding(.horizontal, Spacing.md)
                }

                // Submit Button
                GlassButton(
                    viewModel.isSubmitting ? t.t("report.submitting") : t.t("report.submit"),
                    icon: viewModel.isSubmitting ? nil : "flag.fill",
                    style: .primary,
                    isLoading: viewModel.isSubmitting,
                ) {
                    Task {
                        await viewModel.submitReport()
                    }
                }
                .disabled(!viewModel.canSubmit)
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
            }
            .padding(.vertical, Spacing.md)
        }
    }
}

// MARK: - Reason Button

private struct ReasonButton: View {
    let reason: ReportReason
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: reason.icon)
                    .font(.body)
                    .foregroundColor(isSelected ? .white : .DesignSystem.textSecondary)

                Text(reason.displayName)
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(isSelected ? .white : .DesignSystem.text)

                Spacer()
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(isSelected ? Color.DesignSystem.brandGreen : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(
                                isSelected ? Color.DesignSystem.brandGreen : Color.DesignSystem.glassStroke,
                                lineWidth: isSelected ? 2 : 1,
                            ),
                    ),
            )
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(.ultraThinMaterial),
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ReportPostSheet(
        viewModel: ReportViewModel(
            postId: 1,
            postName: "Fresh Apples",
            repository: MockReportRepository(),
            userId: UUID(),
        ),
    )
}

// MARK: - Mock Repository

private final class MockReportRepository: ReportRepository, @unchecked Sendable {
    func submitReport(_ input: CreateReportInput, reporterId: UUID) async throws -> Report {
        try await Task.sleep(for: .seconds(1))
        return Report(
            id: 1,
            postId: input.postId,
            reporterId: reporterId,
            reason: input.reason,
            description: input.description,
            status: .pending,
            createdAt: Date(),
        )
    }

    func hasUserReportedPost(postId: Int, userId: UUID) async throws -> Bool {
        false
    }
}
