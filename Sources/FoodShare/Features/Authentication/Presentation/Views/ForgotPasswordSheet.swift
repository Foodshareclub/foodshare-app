//
//  ForgotPasswordSheet.swift
//  Foodshare
//
//  Forgot Password sheet with Liquid Glass v26 design
//

import SwiftUI
import FoodShareDesignSystem

struct ForgotPasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.translationService) private var t
    @Environment(AuthViewModel.self) var authViewModel
    @State private var email = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var showError = false
    @FocusState private var isEmailFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AuthBackground(style: .nature)

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Icon
                        iconSection
                            .padding(.top, Spacing.xxl)

                        // Content
                        if showSuccess {
                            successContent
                        } else {
                            formContent
                        }

                        Spacer(minLength: Spacing.xl)
                    }
                    .padding(.horizontal, Spacing.lg)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(t.t("auth.reset_password"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(t.t("common.cancel")) {
                        dismiss()
                    }
                    .foregroundColor(.DesignSystem.textSecondary)
                }
            }
        }
    }

    // MARK: - Icon Section

    private var iconSection: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: showSuccess ? "checkmark.circle.fill" : "lock.rotation")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: showSuccess
                            ? [.DesignSystem.success, .DesignSystem.brandGreen]
                            : [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
                .shadow(
                    color: (showSuccess ? Color.DesignSystem.success : Color.DesignSystem.brandGreen).opacity(0.4),
                    radius: 20,
                    y: 8,
                )

            Text(showSuccess ? t.t("auth.email_sent") : t.t("auth.forgot_password"))
                .font(.LiquidGlass.headlineLarge)
                .foregroundColor(.white)

            Text(showSuccess
                ? t.t("auth.check_inbox_instructions")
                : t.t("auth.enter_email_reset"))
                .font(.LiquidGlass.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Form Content

    private var formContent: some View {
        VStack(spacing: Spacing.lg) {
            // Email Field
            GlassTextField(t.t("common.email"), text: $email, icon: "envelope.fill")
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .focused($isEmailFocused)
                .submitLabel(.send)
                .onSubmit { sendResetEmail() }

            // Error Message
            if showError, let errorMessage {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(errorMessage)
                }
                .font(.DesignSystem.caption)
                .foregroundColor(.DesignSystem.error)
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(Color.DesignSystem.error.opacity(0.15)),
                )
            }

            // Send Button
            GlassButton(
                t.t("auth.send_reset_link"),
                icon: "paperplane.fill",
                style: .primary,
                isLoading: isLoading,
            ) {
                sendResetEmail()
            }
            .disabled(!isFormValid || isLoading)
        }
        .padding(Spacing.lg)
        .glassEffect(cornerRadius: CornerRadius.xl)
    }

    // MARK: - Success Content

    private var successContent: some View {
        VStack(spacing: Spacing.lg) {
            Text(t.t("auth.sent_reset_link_to"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)

            Text(email)
                .font(.DesignSystem.bodyLarge)
                .foregroundColor(.white)
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(Color.white.opacity(0.1)),
                )

            Text(t.t("auth.didnt_receive_email"))
                .font(.DesignSystem.caption)
                .foregroundColor(.DesignSystem.textTertiary)
                .multilineTextAlignment(.center)

            GlassButton(t.t("common.done"), icon: "checkmark.circle.fill", style: .primary) {
                dismiss()
            }
            .padding(.top, Spacing.md)

            GlassButton(t.t("common.try_again"), icon: "arrow.counterclockwise", style: .ghost) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showSuccess = false
                    email = ""
                }
            }
        }
        .padding(Spacing.lg)
        .glassEffect(cornerRadius: CornerRadius.xl)
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .opacity,
        ))
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func sendResetEmail() {
        guard isFormValid else { return }

        isEmailFocused = false
        isLoading = true
        errorMessage = nil
        showError = false

        Task {
            await authViewModel.resetPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
            await MainActor.run {
                // Check if AuthViewModel set an error that indicates failure
                if let message = authViewModel.errorMessage, message.contains("Failed") {
                    errorMessage = message
                    showError = true
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showSuccess = true
                    }
                }
                isLoading = false
            }
        }
    }
}

#Preview {
    ForgotPasswordSheet()
        .environment(AuthViewModel(supabase: .init(
            supabaseURL: URL(string: "https://api.foodshare.club")!,
            supabaseKey: "example-key"
        )))
}
