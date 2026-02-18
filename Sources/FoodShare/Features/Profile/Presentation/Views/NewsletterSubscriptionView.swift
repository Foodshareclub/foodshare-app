//
//  NewsletterSubscriptionView.swift
//  Foodshare
//
//  Newsletter subscription view with glassmorphism design
//  ProMotion 120Hz optimized with smooth animations
//


#if !SKIP
import SwiftUI



// MARK: - Newsletter Subscription View

/// View for subscribing to the Foodshare newsletter
struct NewsletterSubscriptionView: View {
    
    @Environment(\.translationService) private var t
    @Environment(\.dismiss) private var dismiss: DismissAction

    // MARK: - State

    @State private var viewModel = NewsletterViewModel()

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                heroSection

                if viewModel.isSubscribed {
                    subscribedSection
                } else {
                    subscriptionForm
                }

                benefitsSection
            }
            .padding()
        }
        .background(Color.DesignSystem.background)
        .navigationTitle(t.t("newsletter.title"))
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.checkSubscriptionStatus()
        }
        .alert(t.t("common.error.title"), isPresented: $viewModel.showError) {
            Button(t.t("common.ok")) { viewModel.dismissError() }
        } message: {
            Text(viewModel.localizedErrorMessage(using: t))
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.brandPink.opacity(0.3),
                                Color.DesignSystem.brandTeal.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100.0, height: 100)

                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.DesignSystem.brandPink, Color.DesignSystem.brandTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(t.t("newsletter.hero.title"))
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.DesignSystem.textPrimary)

            Text(t.t("newsletter.hero.description"))
                .font(.subheadline)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Subscription Form

    private var subscriptionForm: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(t.t("newsletter.form.email_label"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.DesignSystem.textSecondary)

                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.DesignSystem.textTertiary)

                    TextField(t.t("newsletter.form.email_placeholder"), text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        #if !SKIP
                        .autocapitalization(.none)
                        #endif
                        .autocorrectionDisabled()
                }
                .padding()
                .background(glassFieldBackground)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(t.t("newsletter.form.name_label"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.DesignSystem.textSecondary)

                    Text(t.t("common.optional"))
                        .font(.caption)
                        .foregroundColor(.DesignSystem.textTertiary)
                }

                HStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .foregroundColor(.DesignSystem.textTertiary)

                    TextField(t.t("newsletter.form.name_placeholder"), text: $viewModel.firstName)
                        .textContentType(.givenName)
                }
                .padding()
                .background(glassFieldBackground)
            }

            GlassButton(
                t.t("newsletter.action.subscribe"),
                icon: "paperplane.fill",
                style: .primary,
                isLoading: viewModel.isLoading
            ) {
                Task { await viewModel.subscribe() }
            }
            .disabled(viewModel.email.isEmpty)

            Text(t.t("newsletter.form.privacy_notice"))
                .font(.caption)
                .foregroundColor(.DesignSystem.textTertiary)
        }
        .padding()
        .background(glassCardBackground)
    }

    private var glassFieldBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }

    private var glassCardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    // MARK: - Subscribed Section

    private var subscribedSection: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.DesignSystem.brandGreen.opacity(0.2))
                    .frame(width: 80.0, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.DesignSystem.brandGreen)
            }

            Text(t.t("newsletter.subscribed.title"))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.DesignSystem.textPrimary)

            Text(t.t("newsletter.subscribed.description", args: ["email": viewModel.email]))
                .font(.subheadline)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await viewModel.unsubscribe() }
            } label: {
                Text(t.t("newsletter.action.unsubscribe"))
                    .font(.subheadline)
                    .foregroundColor(.DesignSystem.textTertiary)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(glassCardBackground)
    }

    // MARK: - Benefits Section

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(t.t("newsletter.benefits.title"))
                .font(.headline)
                .foregroundColor(.DesignSystem.textPrimary)

            NewsletterBenefitRow(
                icon: "leaf.fill",
                iconColor: .DesignSystem.brandGreen,
                title: t.t("newsletter.benefits.tips.title"),
                description: t.t("newsletter.benefits.tips.description")
            )

            NewsletterBenefitRow(
                icon: "person.3.fill",
                iconColor: .DesignSystem.brandTeal,
                title: t.t("newsletter.benefits.stories.title"),
                description: t.t("newsletter.benefits.stories.description")
            )

            NewsletterBenefitRow(
                icon: "chart.line.uptrend.xyaxis",
                iconColor: .DesignSystem.brandPink,
                title: t.t("newsletter.benefits.impact.title"),
                description: t.t("newsletter.benefits.impact.description")
            )

            NewsletterBenefitRow(
                icon: "gift.fill",
                iconColor: .orange,
                title: t.t("newsletter.benefits.features.title"),
                description: t.t("newsletter.benefits.features.description")
            )
        }
        .padding()
        .background(glassCardBackground)
    }
}

// MARK: - Benefit Row

private struct NewsletterBenefitRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 44.0, height: 44)
                .background(iconColor.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.DesignSystem.textPrimary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            Spacer()
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class NewsletterViewModel {
    var email = ""
    var firstName = ""
    var isSubscribed = false
    var isLoading = false
    var error: Error?
    var showError = false

    var errorMessage: String {
        error?.localizedDescription ?? "An error occurred"
    }

    /// Localized error message (use in Views with translation service)
    func localizedErrorMessage(using t: EnhancedTranslationService) -> String {
        error?.localizedDescription ?? t.t("newsletter.load_failed")
    }

    func checkSubscriptionStatus() async {
        isLoading = true

        do {
            let supabase = SupabaseManager.shared.client
            if let session = try? await supabase.auth.session {
                email = session.user.email ?? ""
                firstName = session.user.userMetadata["first_name"] as? String ?? ""

                if !email.isEmpty {
                    isSubscribed = try await NewsletterService.shared.isSubscribed(email: email)
                }
            }
        } catch {
            // Silently fail - user can still subscribe
        }

        isLoading = false
    }

    func subscribe() async {
        guard !email.isEmpty else { return }
        isLoading = true

        do {
            _ = try await NewsletterService.shared.subscribe(
                email: email,
                firstName: firstName.isEmpty ? nil : firstName
            )
            isSubscribed = true
            HapticManager.success()
        } catch {
            self.error = error
            showError = true
        }

        isLoading = false
    }

    func unsubscribe() async {
        isLoading = true

        do {
            try await NewsletterService.shared.unsubscribe(email: email)
            isSubscribed = false
            HapticManager.light()
        } catch {
            self.error = error
            showError = true
        }

        isLoading = false
    }

    func dismissError() {
        showError = false
        error = nil
    }
}

#Preview {
    NavigationStack {
        NewsletterSubscriptionView()
    }
}

#endif
