//
//  OnboardingView.swift
//  Foodshare
//
//  Onboarding view with legal disclaimers following CareEcho pattern exactly
//  Uses @AppStorage for persistence like CareEcho's MainView
//

import SwiftUI
import FoodShareDesignSystem

#if DEBUG
    import Inject
#endif

// MARK: - Legal Document Model (for future BFF integration)
// Note: LegalDocumentService.swift exists but needs to be added to Xcode project

private struct LegalDocument: Codable, Sendable {
    let type: String
    let locale: String
    let title: String
    let content: String
    let version: String
    let effectiveDate: Date?

    enum CodingKeys: String, CodingKey {
        case type, locale, title, content, version
        case effectiveDate = "effective_date"
    }
}

struct OnboardingView: View {
    
    // CareEcho pattern: Use @AppStorage directly instead of OnboardingManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    // Translation service for localization
    @Environment(\.translationService) private var t

    @State private var hasConfirmedAge = false
    @State private var hasAcceptedTerms = false
    @State private var showFullDisclaimer = false
    @State private var showTermsSheet = false
    @State private var showPrivacySheet = false

    // Legal document fetching state
    @State private var termsDocument: LegalDocument?
    @State private var privacyDocument: LegalDocument?
    @State private var isLoadingTerms = false
    @State private var isLoadingPrivacy = false
    @State private var legalDocError: String?

    // MARK: - Liquid Glass Background

    private var backgroundGradient: some View {
        ZStack {
            // Base gradient - using design tokens
            Color.DesignSystem.darkAuthGradient

            // Accent gradient overlay (Nature Green/Blue theme)
            Color.DesignSystem.natureAccentGradient
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 40) {
                    Spacer().frame(height: 80)

                    heroSection
                    welcomeSection
                    disclaimerCard
                    confirmationSection
                    getStartedButton

                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, 28)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showFullDisclaimer) {
            fullDisclaimerSheet
        }
        .sheet(isPresented: $showTermsSheet) {
            termsSheet
        }
        .sheet(isPresented: $showPrivacySheet) {
            privacySheet
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        // Logo icon with glow (Nature Green/Blue theme)
        ZStack {
            // Animated glow behind logo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.DesignSystem.brandGreen.opacity(0.5),
                            Color.DesignSystem.brandGreen.opacity(0.25),
                            Color.DesignSystem.brandBlue.opacity(0.1),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 35,
                        endRadius: 95,
                    ),
                )
                .frame(width: 150, height: 150)
                .blur(radius: 25)

            // App logo (circular)
            AppLogoView(size: .large, showGlow: false, circular: true)
        }
    }

    // MARK: - Welcome Section

    private var welcomeSection: some View {
        VStack(spacing: Spacing.md) {
            VStack(spacing: Spacing.xs) {
                Text(t.t("onboarding.welcome"))
                    .font(.DesignSystem.headlineLarge)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color.DesignSystem.brandBlue],
                            startPoint: .leading,
                            endPoint: .trailing,
                        ),
                    )
                    .shadow(color: Color.DesignSystem.brandGreen.opacity(0.4), radius: 4, x: 0, y: 2)

                Text(t.t("onboarding.tagline"))
                    .font(.DesignSystem.bodyLarge)
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                OnboardingFeatureRow(icon: "leaf.fill", text: t.t("onboarding.feature_share"))
                OnboardingFeatureRow(icon: "location.fill", text: t.t("onboarding.feature_find"))
                OnboardingFeatureRow(icon: "heart.fill", text: t.t("onboarding.feature_community"))
            }
        }
    }

    // MARK: - Disclaimer Card

    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "info.circle.fill")
                    .font(.DesignSystem.headlineSmall)
                    .foregroundColor(Color.DesignSystem.warning)

                Text(t.t("onboarding.important_info"))
                    .font(.DesignSystem.titleLarge)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                DisclaimerPoint(
                    icon: "person.2.fill",
                    title: t.t("onboarding.disclaimer.community_title"),
                    description: t.t("onboarding.disclaimer.community_desc"),
                )

                DisclaimerPoint(
                    icon: "checkmark.shield.fill",
                    title: t.t("onboarding.disclaimer.safety_title"),
                    description: t.t("onboarding.disclaimer.safety_desc"),
                )

                DisclaimerPoint(
                    icon: "flag.fill",
                    title: t.t("onboarding.disclaimer.report_title"),
                    description: t.t("onboarding.disclaimer.report_desc"),
                )
            }

            Button(action: {
                showFullDisclaimer = true
            }) {
                HStack(spacing: Spacing.xxs) {
                    Text(t.t("onboarding.read_disclaimer"))
                        .font(.DesignSystem.labelLarge)
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.DesignSystem.bodyLarge)
                }
                .foregroundColor(Color.DesignSystem.brandGreen)
            }
            .padding(.top, Spacing.xxxs)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(Color.DesignSystem.glassBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.warning.opacity(0.5), lineWidth: 1.5),
                ),
        )
        .shadow(color: Color.DesignSystem.warning.opacity(0.2), radius: Spacing.sm, x: 0, y: Spacing.xxs)
    }

    // MARK: - Confirmation Section

    private var confirmationSection: some View {
        VStack(spacing: Spacing.sm) {
            OnboardingCheckboxRow(
                isChecked: $hasConfirmedAge,
                text: t.t("onboarding.confirm_age"),
            )

            VStack(alignment: .leading, spacing: Spacing.xs) {
                OnboardingCheckboxRow(
                    isChecked: $hasAcceptedTerms,
                    text: t.t("onboarding.agree_terms"),
                )

                HStack(spacing: Spacing.xs) {
                    Button(action: { showTermsSheet = true }) {
                        Text(t.t("onboarding.terms"))
                            .font(.DesignSystem.caption)
                            .foregroundColor(Color.DesignSystem.brandGreen)
                    }

                    Text("•")
                        .foregroundColor(.white.opacity(0.3))
                        .font(.DesignSystem.caption)

                    Button(action: { showPrivacySheet = true }) {
                        Text(t.t("onboarding.privacy"))
                            .font(.DesignSystem.caption)
                            .foregroundColor(Color.DesignSystem.brandGreen)
                    }

                    Text("•")
                        .foregroundColor(.white.opacity(0.3))
                        .font(.DesignSystem.caption)

                    Button(action: {
                        if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text(t.t("onboarding.apple_eula"))
                            .font(.DesignSystem.caption)
                            .foregroundColor(Color.DesignSystem.brandGreen)
                    }
                }
                .padding(.leading, Spacing.lg)
            }
        }
        .padding(.horizontal, Spacing.xxs)
    }

    // MARK: - Get Started Button

    private var getStartedButton: some View {
        GlassButton(t.t("common.get_started"), icon: "leaf.circle.fill", style: .nature) {
            handleGetStarted()
        }
        .disabled(!canProceed)
    }

    // MARK: - Sheets

    private var fullDisclaimerSheet: some View {
        NavigationView {
            ZStack {
                backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.DesignSystem.headlineLarge)
                                .foregroundColor(Color.DesignSystem.warning)

                            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                                Text(t.t("onboarding.platform_disclaimer"))
                                    .font(.DesignSystem.headlineSmall)
                                    .foregroundColor(.white)
                                Text(t.t("onboarding.legal_info"))
                                    .font(.DesignSystem.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(.bottom, Spacing.xxs)

                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            DisclaimerSection(
                                title: t.t("onboarding.disclaimer.section.community_title"),
                                content: t.t("onboarding.disclaimer.section.community_content"),
                            )
                            DisclaimerSection(
                                title: t.t("onboarding.disclaimer.section.food_safety_title"),
                                content: t.t("onboarding.disclaimer.section.food_safety_content"),
                            )
                            DisclaimerSection(
                                title: t.t("onboarding.disclaimer.section.no_warranties_title"),
                                content: t.t("onboarding.disclaimer.section.no_warranties_content"),
                            )
                            DisclaimerSection(
                                title: t.t("onboarding.disclaimer.section.user_verification_title"),
                                content: t.t("onboarding.disclaimer.section.user_verification_content"),
                            )
                            DisclaimerSection(
                                title: t.t("onboarding.disclaimer.section.allergen_title"),
                                content: t.t("onboarding.disclaimer.section.allergen_content"),
                            )
                            DisclaimerSection(
                                title: t.t("onboarding.disclaimer.section.liability_title"),
                                content: t.t("onboarding.disclaimer.section.liability_content"),
                            )
                        }
                        .padding(.vertical, Spacing.xs)

                        Text(t.t("onboarding.disclaimer.acknowledgement"))
                            .font(.DesignSystem.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .italic()
                            .padding(.top, Spacing.xxs)
                    }
                    .padding(Spacing.md)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(t.t("common.close")) {
                        showFullDisclaimer = false
                    }
                    .foregroundColor(Color.DesignSystem.brandGreen)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var termsSheet: some View {
        NavigationView {
            ZStack {
                backgroundGradient.ignoresSafeArea()
                legalDocumentContent(
                    document: termsDocument,
                    isLoading: isLoadingTerms,
                    fallbackText: termsOfServiceText,
                )
            }
            .navigationTitle(t.t("onboarding.terms_of_service"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(t.t("common.close")) {
                        showTermsSheet = false
                    }
                    .foregroundColor(Color.DesignSystem.brandGreen)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await fetchTermsDocument()
        }
    }

    private var privacySheet: some View {
        NavigationView {
            ZStack {
                backgroundGradient.ignoresSafeArea()
                legalDocumentContent(
                    document: privacyDocument,
                    isLoading: isLoadingPrivacy,
                    fallbackText: privacyPolicyText,
                )
            }
            .navigationTitle(t.t("onboarding.privacy_policy"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(t.t("common.close")) {
                        showPrivacySheet = false
                    }
                    .foregroundColor(Color.DesignSystem.brandGreen)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await fetchPrivacyDocument()
        }
    }

    @ViewBuilder
    private func legalDocumentContent(
        document: LegalDocument?,
        isLoading: Bool,
        fallbackText: String,
    ) -> some View {
        if isLoading {
            VStack {
                Spacer()
                ProgressView()
                    .tint(.white)
                Text(t.t("common.loading"))
                    .font(.DesignSystem.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, Spacing.xs)
                Spacer()
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if let doc = document {
                        // Version and effective date
                        HStack {
                            Text("\(t.t("onboarding.version")): \(doc.version)")
                            Spacer()
                            if let date = doc.effectiveDate {
                                Text(date, style: .date)
                            }
                        }
                        .font(.DesignSystem.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.bottom, Spacing.xs)

                        Text(doc.content)
                            .font(.DesignSystem.bodyMedium)
                            .foregroundColor(.white.opacity(0.85))
                    } else {
                        // Fallback to hardcoded text if fetch failed
                        Text(fallbackText)
                            .font(.DesignSystem.bodyMedium)
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .padding(Spacing.md)
            }
        }
    }

    // MARK: - Legal Document Fetching

    private func fetchTermsDocument() async {
        // TODO: Implement BFF fetch when LegalDocumentService is added to project
        // For now, use the localized hardcoded text (termsOfServiceText)
        // The BFF endpoint and legal_documents table are ready in Supabase
        // Just need to add LegalDocumentService.swift to Xcode project
    }

    private func fetchPrivacyDocument() async {
        // TODO: Implement BFF fetch when LegalDocumentService is added to project
        // For now, use the localized hardcoded text (privacyPolicyText)
        // The BFF endpoint and legal_documents table are ready in Supabase
        // Just need to add LegalDocumentService.swift to Xcode project
    }

    // MARK: - Helpers

    private var canProceed: Bool {
        hasConfirmedAge && hasAcceptedTerms
    }

    private func handleGetStarted() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            // CareEcho pattern: Set @AppStorage directly
            hasCompletedOnboarding = true
        }
        HapticManager.success()
    }
}

// MARK: - Supporting Views

private struct OnboardingFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.DesignSystem.titleLarge)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.DesignSystem.brandGreen, Color.DesignSystem.brandBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
                .frame(width: Spacing.md)

            Text(text)
                .font(.DesignSystem.labelLarge)
                .foregroundColor(.white.opacity(0.85))
        }
    }
}

private struct DisclaimerPoint: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.DesignSystem.bodyLarge)
                .foregroundColor(Color.DesignSystem.warning)
                .frame(width: Spacing.md)

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(title)
                    .font(.DesignSystem.labelLarge)
                    .foregroundColor(.white)

                Text(description)
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct OnboardingCheckboxRow: View {
    @Binding var isChecked: Bool
    let text: String

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isChecked.toggle()
            }
            HapticManager.light()
        }) {
            HStack(spacing: Spacing.xs) {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(isChecked ? Color.DesignSystem.brandGreen.opacity(0.2) : Color.clear)
                        .frame(width: 26, height: 26)

                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .stroke(
                            isChecked
                                ? LinearGradient(
                                    colors: [Color.DesignSystem.brandGreen, Color.DesignSystem.brandBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                )
                                : LinearGradient(
                                    colors: [Color.DesignSystem.glassBorder, Color.DesignSystem.glassBackground],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                            lineWidth: 2,
                        )
                        .frame(width: 26, height: 26)

                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.DesignSystem.bodyMedium)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.DesignSystem.brandGreen, Color.DesignSystem.brandBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(text)
                    .font(.DesignSystem.labelLarge)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(.vertical, Spacing.xxxs)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct DisclaimerSection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(.DesignSystem.titleMedium)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(content)
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, Spacing.xxs)
    }
}

// MARK: - Scale Button Style

private struct OnboardingScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Legal Text Content

private let termsOfServiceText = """
Last Updated: December 2025

1. ACCEPTANCE OF TERMS

By accessing or using Foodshare ("the App"), you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the App.

2. DESCRIPTION OF SERVICE

Foodshare is a community platform that connects people who have surplus food with those who can use it. The App facilitates food sharing within local communities to reduce food waste.

3. NOT A FOOD SERVICE

THE APP IS NOT A FOOD BANK, RESTAURANT, OR FOOD SERVICE PROVIDER. We do NOT inspect, verify, or guarantee the quality, safety, or freshness of any food items listed on our platform. All food sharing is conducted at the users' own risk.

4. USER ELIGIBILITY

You must be at least 18 years old to use this App. By using the App, you represent and warrant that you meet this age requirement.

5. USER RESPONSIBILITIES

You agree to:
• Use the App only for lawful purposes
• Provide accurate information about food items you list
• Not list expired, spoiled, or unsafe food items
• Inspect all food items before consumption
• Meet other users in safe, public locations
• Report any concerns about listings or users

6. FOOD SAFETY

Users are solely responsible for:
• Ensuring food items are safe for consumption
• Proper storage and handling of food items
• Checking for allergens before consumption
• Using their own judgment about food safety

7. PRIVACY AND DATA

Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your personal information.

8. INTELLECTUAL PROPERTY

All content, features, and functionality of the App are owned by Foodshare and are protected by intellectual property laws.

9. LIMITATION OF LIABILITY

TO THE FULLEST EXTENT PERMITTED BY LAW, FOODSHARE SHALL NOT BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES ARISING FROM:
• Your use of the App
• Any food items obtained through the App
• Interactions with other users
• Any illness or injury resulting from food consumption

10. MODIFICATIONS TO TERMS

We reserve the right to modify these terms at any time. Continued use of the App after changes constitutes acceptance of the modified terms.

11. TERMINATION

We reserve the right to terminate or suspend your access to the App at any time, without prior notice, for conduct that we believe violates these Terms or is harmful to other users or the App.

12. GOVERNING LAW

These Terms shall be governed by and construed in accordance with the laws of the United States, without regard to its conflict of law provisions.

13. CONTACT INFORMATION

For questions about these Terms, please contact us at support@foodshare.club.
"""

private let privacyPolicyText = """
Last Updated: December 2025

1. INTRODUCTION

Foodshare ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.

2. INFORMATION WE COLLECT

Personal Information:
• Email address (for account creation)
• Name (optional)
• Profile photo (optional)
• Location data (for nearby food listings)
• Usage data and analytics

Technical Information:
• Device information
• IP address
• App usage statistics

3. HOW WE USE YOUR INFORMATION

We use your information to:
• Provide and improve our services
• Show relevant food listings in your area
• Facilitate communication between users
• Send important updates and notifications
• Analyze usage patterns to enhance user experience
• Ensure security and prevent fraud

4. LOCATION DATA

Foodshare uses your location to:
• Show food listings near you
• Help donors find nearby recipients
• Calculate distances for pickup arrangements

You can control location permissions in your device settings.

5. DATA SECURITY

We implement appropriate technical and organizational security measures to protect your personal information, including:
• Encryption of data in transit and at rest
• Secure authentication
• Regular security audits
• Access controls

6. DATA RETENTION

We retain your personal information only for as long as necessary to fulfill the purposes outlined in this Privacy Policy, unless a longer retention period is required by law.

7. THIRD-PARTY SERVICES

We use third-party services to operate our App, including:
• Supabase (data storage and authentication)
• Apple Maps (mapping and location services)

These services have their own privacy policies governing the use of your information.

8. YOUR RIGHTS

You have the right to:
• Access your personal information
• Correct inaccurate information
• Request deletion of your data
• Opt-out of certain data processing
• Export your data

9. CHILDREN'S PRIVACY

The App is not intended for users under 18 years of age. We do not knowingly collect information from children.

10. CHANGES TO THIS POLICY

We may update this Privacy Policy from time to time. We will notify you of any significant changes by posting the new policy on this page with an updated "Last Updated" date.

11. CONTACT US

For privacy-related questions or to exercise your rights, contact us at:
• Email: privacy@foodshare.club
• Website: https://foodshare.club
"""

// MARK: - Preview

#Preview {
    OnboardingView()
}
