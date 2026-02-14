//
//  ShareNowView.swift
//  Foodshare
//
//  Beautiful Liquid Glass "Share Now" view with auth-aware UX
//  Allows creating all post types including Forum and Challenges
//  Some content types require admin review before publishing
//

import SwiftUI
import FoodShareDesignSystem



// MARK: - Create Content Type

enum CreateContentType: Identifiable, CaseIterable {
    case food
    case thing
    case borrow
    case wanted
    case zerowaste
    case vegan
    case forum
    case challenge

    var id: String { rawKey }

    private var rawKey: String {
        switch self {
        case .food: return "food"
        case .thing: return "thing"
        case .borrow: return "borrow"
        case .wanted: return "wanted"
        case .zerowaste: return "zerowaste"
        case .vegan: return "vegan"
        case .forum: return "forum"
        case .challenge: return "challenge"
        }
    }

    @MainActor
    func title(using t: EnhancedTranslationService) -> String {
        switch self {
        case .food: return t.t("create.type.food")
        case .thing: return t.t("create.type.things")
        case .borrow: return t.t("create.type.borrow")
        case .wanted: return t.t("create.type.wanted")
        case .zerowaste: return t.t("create.type.zerowaste")
        case .vegan: return t.t("create.type.vegan")
        case .forum: return t.t("create.type.forum")
        case .challenge: return t.t("create.type.challenge")
        }
    }

    @MainActor
    func subtitle(using t: EnhancedTranslationService) -> String {
        switch self {
        case .food: return t.t("create.type.food_desc")
        case .thing: return t.t("create.type.things_desc")
        case .borrow: return t.t("create.type.borrow_desc")
        case .wanted: return t.t("create.type.wanted_desc")
        case .zerowaste: return t.t("create.type.zerowaste_desc")
        case .vegan: return t.t("create.type.vegan_desc")
        case .forum: return t.t("create.type.forum_desc")
        case .challenge: return t.t("create.type.challenge_desc")
        }
    }

    var icon: String {
        switch self {
        case .food: return "leaf.fill"
        case .thing: return "gift.fill"
        case .borrow: return "arrow.triangle.2.circlepath"
        case .wanted: return "magnifyingglass"
        case .zerowaste: return "arrow.3.trianglepath"
        case .vegan: return "carrot.fill"
        case .forum: return "bubble.left.and.bubble.right.fill"
        case .challenge: return "trophy.fill"
        }
    }

    var color: Color {
        switch self {
        case .food: return .DesignSystem.brandGreen
        case .thing: return .DesignSystem.brandOrange
        case .borrow: return .DesignSystem.brandBlue
        case .wanted: return .purple
        case .zerowaste: return .green
        case .vegan: return .mint
        case .forum: return .DesignSystem.blueLight
        case .challenge: return .yellow
        }
    }

    var requiresReview: Bool {
        switch self {
        case .challenge: return true
        default: return false
        }
    }

    var listingCategory: ListingCategory? {
        switch self {
        case .food: return .food
        case .thing: return .thing
        case .borrow: return .borrow
        case .wanted: return .wanted
        case .zerowaste: return .zerowaste
        case .vegan: return .vegan
        case .forum: return .forum
        case .challenge: return .challenge
        }
    }

    // Grouped categories
    static var sharingTypes: [CreateContentType] {
        [.food, .thing, .borrow, .wanted]
    }

    static var lifestyleTypes: [CreateContentType] {
        [.zerowaste, .vegan]
    }

    static var communityTypes: [CreateContentType] {
        [.forum, .challenge]
    }
}

// MARK: - ShareNowView

struct ShareNowView: View {
    
    @Environment(\.translationService) private var t
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var hasAppeared = false
    @State private var selectedContentType: CreateContentType?
    @State private var showCreateListing = false
    @State private var showCreateForum = false
    @State private var showCreateChallenge = false
    @State private var heroScale: CGFloat = 0.8
    @State private var heroOpacity: Double = 0

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated background
                ShareNowBackground()

                if appState.isAuthenticated {
                    authenticatedContent
                } else {
                    unauthenticatedContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    closeButton
                }
            }
        }
        .sheet(isPresented: $showCreateListing) {
            if let contentType = selectedContentType,
               let category = contentType.listingCategory {
                CreateListingView(
                    viewModel: CreateListingViewModel(
                        repository: SupabaseListingRepository(supabase: SupabaseManager.shared.client),
                        initialCategory: category
                    )
                )
            }
        }
        .sheet(isPresented: $showCreateForum) {
            CreateForumPostView(
                repository: SupabaseForumRepository(supabase: SupabaseManager.shared.client),
                categories: ForumCategory.defaultCategories
            )
            .environment(appState)
        }
        .sheet(isPresented: $showCreateChallenge) {
            // TODO: CreateChallengeView when implemented
            CreateChallengeView()
                .environment(appState)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
                heroScale = 1.0
                heroOpacity = 1.0
            }
        }
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button {
            HapticManager.light()
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.DesignSystem.text)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                        )
                )
        }
    }

    // MARK: - Authenticated Content

    private var authenticatedContent: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Hero section
                heroSection
                    .staggeredAppearance(index: 0, baseDelay: 0.1)

                // Share Items section
                shareItemsSection
                    .staggeredAppearance(index: 1, baseDelay: 0.1)

                // Lifestyle section
                lifestyleSection
                    .staggeredAppearance(index: 2, baseDelay: 0.1)

                // Community section (Forum & Challenges with review notice)
                communitySection
                    .staggeredAppearance(index: 3, baseDelay: 0.1)

                // Bottom spacing
                Color.clear.frame(height: Spacing.lg)
            }
            .padding(.horizontal, Spacing.lg)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 30)
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: Spacing.md) {
            // Animated hero icon
            ZStack {
                // Outer glow rings
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.brandGreen.opacity(0.3 - Double(index) * 0.1),
                                    Color.DesignSystem.brandBlue.opacity(0.2 - Double(index) * 0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 100 + CGFloat(index) * 25, height: 100 + CGFloat(index) * 25)
                        .opacity(heroOpacity * (1 - Double(index) * 0.25))
                        .scaleEffect(heroScale + CGFloat(index) * 0.03)
                }

                // Main icon container
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.brandGreen.opacity(0.9),
                                    Color.DesignSystem.brandBlue.opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.DesignSystem.brandGreen.opacity(0.5), radius: 25, y: 8)

                    // Glass overlay
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.clear,
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)

                    Image(systemName: "plus")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.white)
                }
                .scaleEffect(heroScale)
                .opacity(heroOpacity)
            }
            .floating(distance: 5, duration: 3)

            // Welcome text
            VStack(spacing: Spacing.xs) {
                Text(t.t("create.title"))
                    .font(.LiquidGlass.displayMedium)
                    .foregroundColor(.DesignSystem.text)

                Text(t.t("create.subtitle"))
                    .font(.LiquidGlass.bodyMedium)
                    .foregroundColor(.DesignSystem.textSecondary)
            }
        }
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Share Items Section

    private var shareItemsSection: some View {
        ContentSection(
            title: t.t("create.section.share_items"),
            icon: "square.and.arrow.up.fill",
            iconColors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue]
        ) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: Spacing.md),
                GridItem(.flexible(), spacing: Spacing.md)
            ], spacing: Spacing.md) {
                ForEach(CreateContentType.sharingTypes) { type in
                    ContentTypeCard(type: type) {
                        handleContentTypeSelection(type)
                    }
                }
            }
        }
    }

    // MARK: - Lifestyle Section

    private var lifestyleSection: some View {
        ContentSection(
            title: t.t("create.section.lifestyle"),
            icon: "leaf.circle.fill",
            iconColors: [.green, .mint]
        ) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: Spacing.md),
                GridItem(.flexible(), spacing: Spacing.md)
            ], spacing: Spacing.md) {
                ForEach(CreateContentType.lifestyleTypes) { type in
                    ContentTypeCard(type: type) {
                        handleContentTypeSelection(type)
                    }
                }
            }
        }
    }

    // MARK: - Community Section

    private var communitySection: some View {
        ContentSection(
            title: t.t("create.section.community"),
            icon: "person.3.fill",
            iconColors: [.DesignSystem.brandPink, .DesignSystem.brandOrange],
            showReviewNotice: false
        ) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: Spacing.md),
                GridItem(.flexible(), spacing: Spacing.md)
            ], spacing: Spacing.md) {
                ForEach(CreateContentType.communityTypes) { type in
                    ContentTypeCard(type: type, showReviewBadge: type.requiresReview) {
                        handleContentTypeSelection(type)
                    }
                }
            }

            // Review notice only for challenges
            HStack(spacing: Spacing.xs) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.DesignSystem.brandOrange)

                Text(t.t("create.challenge_review_notice"))
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }
            .padding(.top, Spacing.sm)
        }
    }

    // MARK: - Content Type Selection Handler

    private func handleContentTypeSelection(_ type: CreateContentType) {
        HapticManager.selection()
        selectedContentType = type

        switch type {
        case .forum:
            showCreateForum = true
        case .challenge:
            showCreateChallenge = true
        default:
            showCreateListing = true
        }
    }

    // MARK: - Unauthenticated Content

    private var unauthenticatedContent: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Hero icon for sign-in
            shareSignInIcon
                .scaleEffect(heroScale)
                .opacity(heroOpacity)

            // Sign-in message
            VStack(spacing: Spacing.md) {
                Text(t.t("create.sign_in_title"))
                    .font(.LiquidGlass.displayMedium)
                    .foregroundColor(.DesignSystem.text)
                    .multilineTextAlignment(.center)

                Text(t.t("create.sign_in_subtitle"))
                    .font(.LiquidGlass.bodyMedium)
                    .foregroundColor(.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            // Benefits list
            benefitsList
                .padding(.top, Spacing.md)

            // Sign in button
            signInButton
                .padding(.top, Spacing.lg)

            // Browse as guest option
            Button {
                HapticManager.light()
                dismiss()
            } label: {
                Text(t.t("create.browse_as_guest"))
                    .font(.LiquidGlass.labelMedium)
                    .foregroundColor(.DesignSystem.textSecondary)
            }
            .padding(.top, Spacing.sm)

            Spacer()
        }
        .padding(Spacing.lg)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 30)
    }

    // MARK: - Sign In Icon

    private var shareSignInIcon: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.DesignSystem.brandGreen.opacity(0.3),
                            Color.DesignSystem.brandBlue.opacity(0.15),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)

            // Glass circle
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 120, height: 120)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.DesignSystem.brandGreen.opacity(0.3), radius: 25)

            // Icon
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shimmer(duration: 3.0)
        }
        .floating(distance: 8, duration: 3)
    }

    // MARK: - Benefits List

    private var benefitsList: some View {
        VStack(spacing: Spacing.md) {
            ShareBenefitRow(icon: "leaf.fill", text: t.t("create.benefit.share_food"))
            ShareBenefitRow(icon: "bubble.left.and.bubble.right.fill", text: t.t("create.benefit.discussions"))
            ShareBenefitRow(icon: "trophy.fill", text: t.t("create.benefit.challenges"))
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

    // MARK: - Sign In Button

    private var signInButton: some View {
        Button {
            HapticManager.medium()
            appState.showAuthentication = true
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 22))

                Text(t.t("create.sign_in_button"))
                    .font(.LiquidGlass.labelLarge)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: 280)
            .padding(.vertical, Spacing.md)
            .background(
                LinearGradient(
                    colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: Color.DesignSystem.brandGreen.opacity(0.5), radius: 20, y: 10)
        }
        .pressAnimation()
    }
}

// MARK: - Content Section

struct ContentSection<Content: View>: View {
    @Environment(\.translationService) private var t
    let title: String
    let icon: String
    let iconColors: [Color]
    var showReviewNotice: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: iconColors.map { $0.opacity(0.2) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)

                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: iconColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text(title)
                    .font(.DesignSystem.headlineSmall)
                    .foregroundColor(.DesignSystem.text)

                Spacer()
            }

            // Review notice for community content
            if showReviewNotice {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 12))
                        .foregroundColor(.DesignSystem.brandOrange)

                    Text(t.t("create.content_review_notice"))
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(Color.DesignSystem.brandOrange.opacity(0.1))
                )
            }

            // Content grid
            content()
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
        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
    }
}

// MARK: - Content Type Card

struct ContentTypeCard: View {
    @Environment(\.translationService) private var t
    let type: CreateContentType
    var showReviewBadge: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {
                // Icon with review badge
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        type.color.opacity(0.2),
                                        type.color.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)

                        Image(systemName: type.icon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [type.color, type.color.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    // Review badge
                    if showReviewBadge {
                        Image(systemName: "clock.badge")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.DesignSystem.brandOrange)
                            .offset(x: 4, y: -4)
                    }
                }

                // Title
                Text(type.title(using: t))
                    .font(.DesignSystem.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(.DesignSystem.text)
                    .lineLimit(1)

                // Subtitle
                Text(type.subtitle(using: t))
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Color.DesignSystem.glassBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        type.color.opacity(0.3),
                                        Color.DesignSystem.glassBorder
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.96, haptic: .none))
    }
}

// MARK: - Share Benefit Row

struct ShareBenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28)

            Text(text)
                .font(.LiquidGlass.bodyMedium)
                .foregroundColor(.DesignSystem.text)

            Spacer()
        }
    }
}

// MARK: - Share Now Background

struct ShareNowBackground: View {
    @State private var phase: Double = 0

    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color.DesignSystem.background,
                    Color.DesignSystem.brandGreen.opacity(0.05),
                    Color.DesignSystem.brandBlue.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Animated mesh gradient orbs
            GeometryReader { geometry in
                ZStack {
                    // Top-left orb
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.DesignSystem.brandGreen.opacity(0.25),
                                    Color.DesignSystem.brandGreen.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 400, height: 400)
                        .blur(radius: 60)
                        .offset(
                            x: -geometry.size.width * 0.3 + sin(phase) * 30,
                            y: -geometry.size.height * 0.2 + cos(phase * 0.8) * 20
                        )

                    // Bottom-right orb
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.DesignSystem.brandBlue.opacity(0.2),
                                    Color.DesignSystem.brandBlue.opacity(0.08),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 250
                            )
                        )
                        .frame(width: 500, height: 500)
                        .blur(radius: 80)
                        .offset(
                            x: geometry.size.width * 0.3 + cos(phase * 0.7) * 25,
                            y: geometry.size.height * 0.3 + sin(phase * 0.9) * 25
                        )

                    // Center accent
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.DesignSystem.brandOrange.opacity(0.15),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .blur(radius: 50)
                        .offset(
                            x: sin(phase * 1.2) * 40,
                            y: cos(phase * 0.6) * 30
                        )
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                        phase = .pi * 2
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Placeholder Views for Forum and Challenge Creation

struct CreateChallengeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.translationService) private var t
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.DesignSystem.background.ignoresSafeArea()

                VStack(spacing: Spacing.xl) {
                    Spacer()

                    // Coming soon icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.yellow.opacity(0.2), .orange.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)

                        Image(systemName: "trophy.fill")
                            .font(.system(size: 52, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .floating(distance: 6, duration: 3)

                    VStack(spacing: Spacing.sm) {
                        Text(t.t("create.challenge_title"))
                            .font(.LiquidGlass.displayMedium)
                            .foregroundColor(.DesignSystem.text)

                        Text(t.t("create.challenge_coming_soon"))
                            .font(.LiquidGlass.bodyMedium)
                            .foregroundColor(.DesignSystem.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, Spacing.xl)

                    // Notice
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "clock.badge.checkmark")
                            .foregroundColor(.DesignSystem.brandOrange)

                        Text(t.t("create.admin_review_required"))
                            .font(.DesignSystem.labelMedium)
                            .foregroundColor(.DesignSystem.textSecondary)
                    }
                    .padding(Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(Color.DesignSystem.brandOrange.opacity(0.1))
                    )

                    Spacer()

                    GlassButton(t.t("common.got_it"), icon: "checkmark.circle.fill", style: .primary) {
                        dismiss()
                    }
                    .frame(maxWidth: 200)
                    .padding(.bottom, Spacing.xl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.DesignSystem.text)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                                    )
                            )
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Authenticated") {
    let appState = AppState()
    return ShareNowView()
        .environment(appState)
}

#Preview("Unauthenticated") {
    ShareNowView()
        .environment(AppState())
}
