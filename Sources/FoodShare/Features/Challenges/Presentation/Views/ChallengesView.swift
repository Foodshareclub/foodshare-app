//
//  ChallengesView.swift
//  Foodshare
//
//  Main challenges view with Liquid Glass v26 design
//  Refactored into smaller components
//


#if !SKIP
import Supabase
import SwiftUI

#if DEBUG
    import Inject
#endif

// MARK: - View Mode Enum

enum ChallengesViewMode: CaseIterable {
    case deck, list, leaderboard

    var icon: String {
        switch self {
        case .deck: "square.stack.3d.up.fill"
        case .list: "list.bullet"
        case .leaderboard: "trophy.fill"
        }
    }

    @MainActor
    func title(using t: EnhancedTranslationService) -> String {
        switch self {
        case .deck: t.t("challenges.view.deck")
        case .list: t.t("challenges.view.list")
        case .leaderboard: t.t("challenges.view.leaderboard")
        }
    }
}

struct ChallengesView: View {
    @State private var viewModel: ChallengesViewModel
    @State private var selectedViewMode: ChallengesViewMode = .deck
    @State private var selectedChallengeForDetail: Challenge?
    @State private var shuffleTrigger = false
    @State private var showSignInPrompt = false
    @State private var showSubscriptionPaywall = false

    /// Feature flag manager - using @State to observe changes
    @State private var featureFlagManager = FeatureFlagManager.shared

    #if !SKIP
    @Namespace private var modeAnimation
    #endif
    @Environment(AppState.self) private var appState
    @Environment(GuestManager.self) private var guestManager
    @Environment(\.translationService) private var t

    /// Premium access - checks feature flag first, then StoreKit/admin status
    private var isPremium: Bool {
        // Free premium trial flag bypasses all premium gates
        if featureFlagManager.isFreePremiumTrialEnabled {
            return true
        }
        // Otherwise check StoreKit subscription or admin status
        return StoreKitService.shared.isPremium
            || AdminAuthorizationService.shared.isAdminUser
            || AdminAuthorizationService.shared.isSuperAdminUser
    }

    init(viewModel: ChallengesViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var isAuthenticated: Bool {
        appState.isAuthenticated
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // View mode toggle
                viewModeToggle

                // Filter picker (only in list mode)
                if selectedViewMode == .list {
                    ChallengeFiltersBar(viewModel: viewModel) {
                        // No additional action needed - viewModel handles the filter change
                    }
                }

                // Animated Content Transitions
                mainContent
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedViewMode)
            }
            .background(Color.backgroundGradient)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedChallengeForDetail) { challenge in
                ChallengeDetailView(challenge: challenge, viewModel: viewModel)
            }
            .task {
                // Load admin status and feature flags for premium check
                try? await AdminAuthorizationService.shared.refresh()
                try? await featureFlagManager.refresh()
                print(
                    "🚩 [FLAGS] Loaded in ChallengesView - isLoaded=\(featureFlagManager.isLoaded), freePremiumTrial=\(featureFlagManager.isFreePremiumTrialEnabled)",
                )
                await viewModel.loadChallenges()
            }
            .alert(t.t("common.error.title"), isPresented: $viewModel.showError) {
                Button(t.t("common.ok")) { viewModel.dismissError() }
            } message: {
                Text(viewModel.localizedErrorMessage(using: t))
            }
            .fullScreenCover(isPresented: $showSignInPrompt) {
                signInPromptSheet
            }
            .sheet(isPresented: $showSubscriptionPaywall) {
                SubscriptionView()
                    .environment(appState)
            }
        }
    }

    // MARK: - Sign In Prompt Sheet

    private var signInPromptSheet: some View {
        ZStack {
            Color.backgroundGradient.ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        showSignInPrompt = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.DesignSystem.textSecondary)
                    }
                }
                .padding()

                Spacer()

                SignInPromptView.challenges()
                    .environment(appState)

                Spacer()
            }
        }
    }

    // MARK: - Premium View Mode Selector

    private var viewModeToggle: some View {
        HStack(spacing: 0) {
            ForEach(ChallengesViewMode.allCases, id: \.self) { mode in
                viewModeButton(for: mode)
            }
        }
        #if !SKIP
        .fixedSize(horizontal: false, vertical: true)
        #endif
        .padding(Spacing.xs)
        .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.DesignSystem.glassBorder, lineWidth: 0.5),
        )
        .padding(Edge.Set.horizontal, Spacing.md)
        .padding(Edge.Set.top, Spacing.sm)
    }

    @ViewBuilder
    private func viewModeButton(for mode: ChallengesViewMode) -> some View {
        let isListLocked = mode == .list && !isPremium
        let isSelected = selectedViewMode == mode

        Button {
            if isListLocked {
                showSubscriptionPaywall = true
                HapticManager.medium()
                return
            }

            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedViewMode = mode
            }
            HapticManager.light()
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: mode.icon)
                    #if !SKIP
                    .symbolEffect(.bounce, value: isSelected)
                    #endif
                Text(mode.title(using: t))
            }
            .font(.DesignSystem.labelSmall)
            .fontWeight(isSelected ? .bold : .medium)
            .foregroundColor(isSelected ? .white : .DesignSystem.textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Group {
                    if isSelected {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing,
                                ),
                            )
                            #if !SKIP
                            .matchedGeometryEffect(id: "activePill", in: modeAnimation)
                            #endif
                            .shadow(color: .DesignSystem.brandGreen.opacity(0.4), radius: 8, y: 2)
                    }
                },
            )
            .overlay(alignment: .topTrailing) {
                if isListLocked {
                    premiumBadge
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// Premium badge overlay for locked features
    private var premiumBadge: some View {
        Text("PRO")
            .font(.system(size: 8, weight: .black))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                LinearGradient(
                    colors: [.DesignSystem.brandPink, .DesignSystem.brandPurple],
                    startPoint: .leading,
                    endPoint: .trailing,
                ),
            )
            .clipShape(Capsule())
            .shadow(color: .DesignSystem.brandPink.opacity(0.5), radius: 4, y: 2)
    }

    // MARK: - Animated Main Content

    private var mainContent: some View {
        Group {
            switch selectedViewMode {
            case .deck:
                if viewModel.isLoading, viewModel.publishedChallenges.isEmpty {
                    deckLoadingSkeleton
                } else if viewModel.publishedChallenges.isEmpty {
                    emptyView
                } else {
                    cardDeckView
                }
            case .list:
                if viewModel.isLoading, viewModel.publishedChallenges.isEmpty {
                    LoadingStateView(t.t("status.loading_challenges"))
                } else if viewModel.filteredChallenges.isEmpty {
                    emptyView
                } else {
                    ChallengesListSection(
                        viewModel: viewModel,
                        onChallengeSelected: { challenge in
                            HapticManager.medium()
                            selectedChallengeForDetail = challenge
                        }
                    )
                }
            case .leaderboard:
                ChallengeLeaderboardSection(viewModel: viewModel)
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity),
        ))
    }

    // MARK: - Premium Loading Skeleton

    private var deckLoadingSkeleton: some View {
        GeometryReader { geometry in
            let skeletonCardSize = calculateSkeletonCardSize(from: geometry.size)

            VStack(spacing: Spacing.lg) {
                Spacer()

                // Stacked skeleton cards with depth effect
                ZStack {
                    ForEach(0 ..< 3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: CornerRadius.xl)
                            .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                            .frame(width: skeletonCardSize.width, height: skeletonCardSize.height)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.xl)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1),
                            )
                            .overlay(
                                VStack(spacing: Spacing.md) {
                                    // Card content skeleton
                                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                                        .fill(Color.DesignSystem.glassBackground.opacity(0.5))
                                        .frame(height: skeletonCardSize.height * 0.52)

                                    VStack(alignment: .leading, spacing: Spacing.sm) {
                                        SkeletonView()
                                            .frame(width: min(180, skeletonCardSize.width * 0.5), height: 20)
                                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

                                        SkeletonView()
                                            .frame(width: min(220, skeletonCardSize.width * 0.63), height: 14)
                                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

                                        SkeletonView()
                                            .frame(width: min(140, skeletonCardSize.width * 0.4), height: 14)
                                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                                    }
                                    .padding(.horizontal, Spacing.md)

                                    Spacer()
                                }
                                .padding(.top, Spacing.md),
                            )
                            .scaleEffect(1.0 - CGFloat(index) * 0.05)
                            .offset(y: CGFloat(index) * 12)
                            .rotation3DEffect(
                                Angle.degrees(Double(index) * 2),
                                axis: (x: 1, y: 0, z: 0),
                                perspective: 0.5,
                            )
                            .zIndex(Double(3 - index))
                            .opacity(1.0 - Double(index) * 0.2)
                    }
                }
                .frame(height: skeletonCardSize.height + 60)

                // Skeleton shuffle button
                SkeletonView()
                    .frame(width: 140.0, height: 48)
                    .clipShape(Capsule())

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal)
    }

    /// Calculate skeleton card size matching the deck's adaptive algorithm
    private func calculateSkeletonCardSize(from size: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else {
            return CGSize(width: 350.0, height: 540.0)
        }

        let aspectRatio: CGFloat = 350.0 / 540.0
        let availableWidth = size.width - Spacing.md * 2
        let availableHeight = size.height - 140

        let maxCardHeight = availableHeight - 40
        var cardWidth = maxCardHeight * aspectRatio

        let maxWidth = min(availableWidth - 40, 600)
        cardWidth = min(cardWidth, maxWidth)
        cardWidth = max(cardWidth, 320)

        let cardHeight = cardWidth / aspectRatio

        return CGSize(width: cardWidth, height: cardHeight)
    }

    // MARK: - Card Deck View

    private var cardDeckView: some View {
        GeometryReader { geometry in
            VStack(spacing: Spacing.lg) {
                Spacer()

                // Card deck with adaptive sizing
                ChallengeCardDeck(
                    challenges: viewModel.publishedChallenges.map(\.self),
                    userStatusProvider: { viewModel.userStatus(for: $0) },
                    onChallengeSelected: { challenge in
                        HapticManager.medium()
                        selectedChallengeForDetail = challenge
                    },
                    onSwipeRight: { _ in
                        // Swipe right = accept/like - requires auth
                        if !isAuthenticated {
                            showSignInPrompt = true
                        }
                    },
                    onSwipeLeft: { _ in
                        // Swipe left = skip/decline - requires auth
                        if !isAuthenticated {
                            showSignInPrompt = true
                        }
                    },
                    shuffleTrigger: shuffleTrigger,
                    availableSize: CGSize(
                        width: geometry.size.width - Spacing.md * 2,
                        height: geometry.size.height - 140,
                    ),
                )

                // Shuffle button
                ShuffleButton {
                    shuffleTrigger.toggle()
                }
                .padding(.bottom, Spacing.md)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal)
    }

    private var emptyView: some View {
        EmptyStateView(
            icon: "trophy",
            title: t.t("challenges.empty.title"),
            message: viewModel.selectedFilter == .joined
                ? t.t("challenges.empty.joined")
                : t.t("challenges.empty.available"),
        )
    }
}

#if DEBUG
    #Preview {
        ChallengesView(viewModel: ChallengesViewModel(repository: MockChallengeRepository()))
            .environment(AppState())
    }
#endif

#endif
