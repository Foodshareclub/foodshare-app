//
//  ChallengeDetailSheet.swift
//  Foodshare
//
//  Extracted challenge detail view
//


#if !SKIP
import SwiftUI

struct ChallengeDetailView: View {

    let challenge: Challenge
    @Bindable var viewModel: ChallengesViewModel

    @Environment(AppState.self) private var appState
    @Environment(\.translationService) private var t
    @State private var showSignInPrompt = false
    @State private var animateHeader = false
    @State private var confettiCounter = 0

    private var isAuthenticated: Bool {
        appState.isAuthenticated
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Header
                    challengeHeader

                    // User status section (only show if authenticated)
                    if isAuthenticated, let selected = viewModel.selectedChallenge {
                        userStatusSection(selected)
                    }

                    // Leaderboard
                    leaderboardSection

                    // Bottom padding for sticky button
                    Color.clear.frame(height: 100.0)
                }
                .padding()
            }
            .coordinateSpace(name: "scroll")

            // Sticky action buttons at bottom
            if isAuthenticated || !isAuthenticated {
                stickyActionButtons
            }
        }
        .navigationTitle(challenge.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.backgroundGradient)
        .task {
            await viewModel.selectChallenge(challenge)
            await viewModel.checkLikeStatus(for: challenge.id)
        }
        .fullScreenCover(isPresented: $showSignInPrompt) {
            signInPromptSheet
        }
        // .confettiCannon(counter: $confettiCounter, num: 50, radius: 400) // Commented out - requires external package
    }

    // MARK: - Sticky Action Buttons

    private var stickyActionButtons: some View {
        VStack(spacing: 0) {
            // Gradient fade effect
            Rectangle()
                .fill(Color.clear)
                .frame(height: 20.0)
                .frame(height: 40.0)

            // Action buttons container
            VStack(spacing: Spacing.sm) {
                actionButtonsContent
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(
                Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */,
                in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous),
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
            )
            .padding(Edge.Set.horizontal, Spacing.md)
            .padding(Edge.Set.bottom, Spacing.md)
            .shadow(color: Color.black.opacity(0.1), radius: 20, y: -5)
        }
    }

    @ViewBuilder
    private var actionButtonsContent: some View {
        // Show sign-in button for unauthenticated users
        if !isAuthenticated {
            Button {
                HapticManager.medium()
                showSignInPrompt = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                    Text(t.t("challenge.action.sign_in_accept"))
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56.0)
                .background(
                    LinearGradient(
                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                        startPoint: .leading,
                        endPoint: .trailing,
                    ),
                )
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                .shadow(color: .DesignSystem.brandGreen.opacity(0.5), radius: 16, y: 8)
            }
            .pressAnimation()
        } else if let selected = viewModel.selectedChallenge {
            if selected.hasCompleted {
                // Completed state - celebration style
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.DesignSystem.brandGreen, .DesignSystem.brandGreen.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        #if !SKIP
                        .symbolEffect(.bounce, value: selected.hasCompleted)
                        #endif

                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.t("challenge.action.completed"))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.DesignSystem.brandGreen)
                        Text("Great job! 🎉")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.DesignSystem.textSecondary)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56.0)
                .padding(.horizontal, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        #if !SKIP
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                        #else
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                        #endif
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.large)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            .DesignSystem.brandGreen.opacity(0.5),
                                            .DesignSystem.brandGreen.opacity(0.2),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing,
                                    ),
                                    lineWidth: 2,
                                ),
                        ),
                )
            } else if selected.hasAccepted {
                // In progress - show complete button
                Button {
                    HapticManager.success()
                    Task {
                        await viewModel.completeChallenge(challenge.id)
                    }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.2)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                        }
                        Text(t.t("challenge.action.mark_complete"))
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56.0)
                    .background(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandGreen.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing,
                        ),
                    )
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                    .shadow(color: .DesignSystem.brandGreen.opacity(0.5), radius: 16, y: 8)
                }
                .disabled(viewModel.isLoading)
                .opacity(viewModel.isLoading ? 0.7 : 1.0)
                .pressAnimation()
            } else {
                // Not joined - show accept button
                Button {
                    HapticManager.medium()
                    Task {
                        await viewModel.acceptChallenge(challenge.id)
                    }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        if viewModel.isJoining {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.2)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                        }
                        Text(t.t("challenge.action.accept"))
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56.0)
                    .background(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                            startPoint: .leading,
                            endPoint: .trailing,
                        ),
                    )
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                    .shadow(color: .DesignSystem.brandGreen.opacity(0.5), radius: 16, y: 8)
                }
                .disabled(viewModel.isJoining)
                .opacity(viewModel.isJoining ? 0.7 : 1.0)
                .pressAnimation()
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

    private var challengeHeader: some View {
        VStack(spacing: 0) {
            // Hero Image Section - Full width banner with parallax
            GeometryReader { geometry in
                let minY = geometry.frame(in: .named("scroll")).minY
                let imageOffset = minY > 0 ? -minY * 0.5 : 0
                let imageScale = minY > 0 ? 1 + (minY / 1000) : 1

                ZStack(alignment: .bottomLeading) {
                    if let imageUrl = challenge.imageUrl {
                        AsyncImage(url: imageUrl) { phase in
                            switch phase {
                            case let .success(image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width, height: 320)
                                    .offset(y: imageOffset)
                                    .scaleEffect(imageScale)
                                    .blur(radius: animateHeader ? 0 : 20)
                                    .animation(.easeOut(duration: 0.8), value: animateHeader)
                            case .failure, .empty:
                                heroImagePlaceholder
                                    .frame(width: geometry.size.width, height: 320)
                            @unknown default:
                                heroImagePlaceholder
                                    .frame(width: geometry.size.width, height: 320)
                            }
                        }
                    } else {
                        heroImagePlaceholder
                            .frame(width: geometry.size.width, height: 320)
                    }

                    // Multi-layer gradient overlay for depth
                    ZStack {
                        // Bottom gradient for text readability
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.black.opacity(0.2),
                                Color.black.opacity(0.6),
                            ],
                            startPoint: .top,
                            endPoint: .bottom,
                        )

                        // Subtle vignette effect
                        RadialGradient(
                            colors: [Color.clear, Color.black.opacity(0.3)],
                            center: .center,
                            startRadius: 100,
                            endRadius: 400,
                        )
                    }

                    // Floating difficulty badge with enhanced styling
                    HStack {
                        difficultyBadgeOverlay
                        Spacer()
                    }
                    .padding(Spacing.md)
                }
                .frame(width: geometry.size.width, height: 320)
                .clipped()
            }
            .frame(height: 320.0)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl)
                    .stroke(
                        LinearGradient(
                            colors: [
                                difficultyColor.opacity(0.6),
                                difficultyColor.opacity(0.2),
                                Color.clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                        lineWidth: 2,
                    ),
            )
            .shadow(color: difficultyColor.opacity(0.4), radius: 25, y: 12)
            .scaleEffect(animateHeader ? 1.0 : 0.92)
            .opacity(animateHeader ? 1 : 0)
            .animation(Animation.spring(response: 0.7, dampingFraction: 0.75), value: animateHeader)

            // Content section below hero
            VStack(spacing: Spacing.lg) {
                // Title and description with enhanced typography
                VStack(spacing: Spacing.md) {
                    Text(challenge.displayTitle)
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.DesignSystem.textPrimary, .DesignSystem.textPrimary.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

                    VStack(spacing: Spacing.sm) {
                        Text(challenge.displayDescription)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.DesignSystem.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(5)
                            .lineSpacing(4)
                            .padding(.horizontal, Spacing.lg)

                        if challenge.isTranslated {
                            TranslatedIndicator()
                        }
                    }
                }
                .opacity(animateHeader ? 1 : 0)
                .offset(y: animateHeader ? 0 : 30)
                .animation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.15), value: animateHeader)

                // Progress ring for accepted challenges
                // Commented out - AnimatedProgressRing component not available
                /*
                 if isAuthenticated, let selected = viewModel.selectedChallenge, selected.hasAccepted && !selected.hasCompleted {
                     AnimatedProgressRing(
                         progress: 0.65,
                         difficulty: challenge.challengeDifficulty,
                         gradient: difficultyGradient
                     )
                     .frame(height: 140.0)
                     .opacity(animateHeader ? 1 : 0)
                     .scaleEffect(animateHeader ? 1 : 0.8)
                     .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.25), value: animateHeader)
                 }
                 */

                // Enhanced stats cards - Horizontal scroll with premium design
                // Commented out - PremiumStatCard component not available
                /*
                 ScrollView(.horizontal, showsIndicators: false) {
                     HStack(spacing: Spacing.md) {
                         // Stats would go here
                     }
                     .padding(.horizontal, Spacing.md)
                 }
                 .frame(height: 140.0)
                 */
            }
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.xl)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
        .padding(.horizontal, Spacing.md)
        .onAppear {
            withAnimation {
                animateHeader = true
            }
        }
    }

    /// Hero image placeholder with beautiful gradient
    private var heroImagePlaceholder: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    difficultyColor.opacity(0.6),
                    difficultyColor.opacity(0.3),
                    difficultyColor.opacity(0.1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )

            // Animated circles pattern
            GeometryReader { geometry in
                ForEach(0 ..< 5) { index in
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: CGFloat(80 + index * 40), height: CGFloat(80 + index * 40))
                        .position(
                            x: geometry.size.width * 0.7,
                            y: geometry.size.height * 0.3,
                        )
                        .scaleEffect(animateHeader ? 1.0 : 0.8)
                        .opacity(animateHeader ? 0.3 : 0)
                        .animation(
                            .easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: animateHeader,
                        )
                }
            }

            // Large icon
            VStack(spacing: Spacing.md) {
                Image(systemName: challenge.challengeDifficulty.icon)
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    .shimmer(duration: 3.0)

                Text(challenge.challengeAction)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
            }
        }
    }

    /// Floating difficulty badge
    private var difficultyBadgeOverlay: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: challenge.challengeDifficulty.icon)
                .font(.system(size: 14, weight: .bold))
            Text(challenge.challengeDifficulty.localizedDisplayName(using: t))
                .font(.system(size: 14, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            ZStack {
                Capsule()
                    .fill(difficultyGradient)
                    .shadow(color: difficultyColor.opacity(0.6), radius: 12, y: 4)

                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.5), Color.white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                        lineWidth: 1.5,
                    )
            },
        )
        .scaleEffect(animateHeader ? 1.0 : 0.8)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: animateHeader)
    }

    private func userStatusSection(_ status: ChallengeWithStatus) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: status.status.icon)
                    .foregroundStyle(difficultyGradient)
                Text(t.t("challenge.your_status"))
                    .font(.LiquidGlass.headlineSmall)
                    .fontWeight(.semibold)
            }

            HStack {
                Text(status.status.localizedDisplayName(using: t))
                    .font(.LiquidGlass.bodyLarge)
                    .fontWeight(.semibold)

                Spacer()

                if status.hasCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.DesignSystem.brandGreen)
                        #if !SKIP
                        .symbolEffect(.bounce, value: status.hasCompleted)
                        #endif
                }
            }
        }
        .padding(Spacing.md)
        .glassEffect(cornerRadius: CornerRadius.large)
    }

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Enhanced header with trophy animation
            HStack(spacing: Spacing.sm) {
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.DesignSystem.medalGold.opacity(0.3), Color.clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 25,
                            ),
                        )
                        .frame(width: 40.0, height: 40)

                    Image(systemName: "trophy.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.DesignSystem.medalGold)
                        .shadow(color: .DesignSystem.medalGold.opacity(0.5), radius: 8)
                }

                Text(t.t("challenge.completed_by"))
                    .font(.LiquidGlass.headlineSmall)
                    .fontWeight(.semibold)

                Spacer()

                // Completion count badge
                if !viewModel.leaderboard.isEmpty {
                    Text("\(viewModel.leaderboard.count)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandGreen.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing,
                                    ),
                                ),
                        )
                        .shadow(color: .DesignSystem.brandGreen.opacity(0.4), radius: 4, y: 2)
                }
            }

            if viewModel.isLoadingLeaderboard {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if viewModel.leaderboard.isEmpty {
                // Enhanced empty state
                VStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .DesignSystem.brandGreen.opacity(0.2),
                                        .DesignSystem.brandGreen.opacity(0.05),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                            )
                            .frame(width: 80.0, height: 80)

                        Image(systemName: "person.3.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                            )
                    }

                    VStack(spacing: Spacing.xs) {
                        Text(t.t("challenge.no_completions"))
                            .font(.LiquidGlass.bodyLarge)
                            .fontWeight(.semibold)
                            .foregroundColor(.DesignSystem.textPrimary)

                        Text(t.t("challenge.be_first"))
                            .font(.LiquidGlass.bodyMedium)
                            .foregroundColor(.DesignSystem.brandGreen)
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
            } else {
                VStack(spacing: Spacing.lg) {
                    // Top 3 Podium Display
                    if viewModel.leaderboard.count >= 3 {
                        PodiumView(
                            first: viewModel.leaderboard[0],
                            second: viewModel.leaderboard[1],
                            third: viewModel.leaderboard[2],
                        )
                        .padding(.vertical, Spacing.md)
                    } else if viewModel.leaderboard.count == 2 {
                        // Show first two on podium
                        HStack(alignment: .bottom, spacing: Spacing.md) {
                            PodiumPosition(entry: viewModel.leaderboard[1], rank: 2)
                            PodiumPosition(entry: viewModel.leaderboard[0], rank: 1)
                        }
                        .padding(.vertical, Spacing.md)
                    } else if viewModel.leaderboard.count == 1 {
                        // Show only winner
                        PodiumPosition(entry: viewModel.leaderboard[0], rank: 1)
                            .padding(.vertical, Spacing.md)
                    }

                    // Remaining users (4+)
                    if viewModel.leaderboard.count > 3 {
                        VStack(spacing: Spacing.xs) {
                            ForEach(
                                Array(viewModel.leaderboard.dropFirst(3).prefix(7).enumerated()),
                                id: \.element.id,
                            ) { index, entry in
                                EnhancedLeaderboardRow(entry: entry, rank: index + 4)
                                    .staggeredAnimation(index: index)
                            }
                        }
                    }

                    // Show more indicator if there are more than 10
                    if viewModel.leaderboard.count > 10 {
                        HStack {
                            Spacer()
                            Text("+\(viewModel.leaderboard.count - 10) more")
                                .font(.DesignSystem.caption)
                                .foregroundColor(.DesignSystem.textSecondary)
                            Spacer()
                        }
                        .padding(.top, Spacing.xs)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .glassEffect(cornerRadius: CornerRadius.large)
    }

    private var difficultyColor: Color {
        switch challenge.challengeDifficulty {
        case .easy: .DesignSystem.brandGreen
        case .medium: .DesignSystem.accentOrange
        case .hard: .DesignSystem.error
        case .extreme: .DesignSystem.accentPurple
        }
    }

    private var difficultyGradient: LinearGradient {
        switch challenge.challengeDifficulty {
        case .easy:
            LinearGradient(
                colors: [.DesignSystem.brandGreen, .DesignSystem.brandGreen.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        case .medium:
            LinearGradient(
                colors: [.DesignSystem.accentOrange, .DesignSystem.accentYellow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        case .hard:
            LinearGradient(
                colors: [.DesignSystem.error, .DesignSystem.accentOrange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        case .extreme:
            LinearGradient(
                colors: [.DesignSystem.accentPurple, .DesignSystem.accentPink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        }
    }
}

// MARK: - Podium View

private struct PodiumView: View {
    let first: ChallengeLeaderboardEntry
    let second: ChallengeLeaderboardEntry
    let third: ChallengeLeaderboardEntry

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            // Second place (left)
            PodiumPosition(entry: second, rank: 2)

            // First place (center, tallest)
            PodiumPosition(entry: first, rank: 1)

            // Third place (right)
            PodiumPosition(entry: third, rank: 3)
        }
    }
}

// MARK: - Podium Position

private struct PodiumPosition: View {
    let entry: ChallengeLeaderboardEntry
    let rank: Int

    var body: some View {
        VStack(spacing: Spacing.xs) {
            // Avatar with medal overlay
            ZStack(alignment: .topTrailing) {
                if let avatarUrl = entry.avatarUrl, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(rankGradient)
                    }
                    .frame(width: rank == 1 ? 70 : 56, height: rank == 1 ? 70 : 56)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(rankGradient, lineWidth: 3),
                    )
                    .shadow(color: rankColor.opacity(0.5), radius: 12, y: 6)
                } else {
                    Circle()
                        .fill(rankGradient)
                        .frame(width: rank == 1 ? 70 : 56, height: rank == 1 ? 70 : 56)
                        .overlay {
                            Text(entry.nickname.prefix(1).uppercased())
                                .font(.system(size: rank == 1 ? 28 : 22, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .shadow(color: rankColor.opacity(0.5), radius: 12, y: 6)
                }

                // Medal emoji
                Text(rankEmoji)
                    .font(.system(size: rank == 1 ? 32 : 24))
                    .offset(x: 8, y: -8)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            }

            // Name
            Text(entry.nickname)
                .font(.system(size: rank == 1 ? 14 : 12, weight: rank == 1 ? .bold : .semibold))
                .foregroundColor(.DesignSystem.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: 90)

            // Podium base
            VStack(spacing: 0) {
                // Rank number
                Text("#\(rank)")
                    .font(.system(size: rank == 1 ? 20 : 16, weight: .black))
                    .foregroundColor(.white)
                    .padding(.vertical, Spacing.xs)

                // Podium height varies by rank
                Rectangle()
                    .fill(rankGradient)
                    .frame(height: rank == 1 ? 100 : rank == 2 ? 70 : 50)
            }
            .frame(width: rank == 1 ? 100 : 80)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.5), Color.white.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom,
                        ),
                        lineWidth: 2,
                    ),
            )
            .shadow(color: rankColor.opacity(0.4), radius: 12, y: 6)
        }
    }

    private var rankEmoji: String {
        switch rank {
        case 1: "🥇"
        case 2: "🥈"
        case 3: "🥉"
        default: ""
        }
    }

    private var rankColor: Color {
        switch rank {
        case 1: .DesignSystem.medalGold
        case 2: .DesignSystem.medalSilver
        case 3: .DesignSystem.accentOrange
        default: .DesignSystem.textSecondary
        }
    }

    private var rankGradient: LinearGradient {
        switch rank {
        case 1:
            LinearGradient(
                colors: [.DesignSystem.medalGold, .DesignSystem.accentOrange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        case 2:
            LinearGradient(
                colors: [.DesignSystem.medalSilver, .DesignSystem.medalSilver.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        case 3:
            LinearGradient(
                colors: [.DesignSystem.accentOrange, .DesignSystem.accentBrown],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        default:
            LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom)
        }
    }
}

// MARK: - Enhanced Leaderboard Row

private struct EnhancedLeaderboardRow: View {
    let entry: ChallengeLeaderboardEntry
    let rank: Int

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Enhanced rank badge with medals for top 3
            ZStack {
                if rank <= 3 {
                    Circle()
                        .fill(rankGradient)
                        .frame(width: 40.0, height: 40)
                        .shadow(color: rankColor.opacity(0.5), radius: 6, y: 3)

                    Text(rankEmoji)
                        .font(.system(size: 20))
                } else {
                    Circle()
                        #if !SKIP
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                        #else
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                        #endif
                        .frame(width: 40.0, height: 40)
                        .overlay(
                            Circle()
                                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                        )

                    Text("#\(rank)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.DesignSystem.textSecondary)
                }
            }

            // Avatar with enhanced styling
            if let avatarUrl = entry.avatarUrl,
               let url = URL(string: avatarUrl)
            {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(Color.DesignSystem.glassBackground)
                }
                .frame(width: 44.0, height: 44)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            rank <= 3
                                ? rankGradient
                                : LinearGradient(
                                    colors: [.DesignSystem.glassBorder],
                                    startPoint: .top,
                                    endPoint: .bottom,
                                ),
                            lineWidth: rank <= 3 ? 2.5 : 1,
                        ),
                )
                .shadow(color: rank <= 3 ? rankColor.opacity(0.3) : Color.clear, radius: 4, y: 2)
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen.opacity(0.3), .DesignSystem.brandBlue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .frame(width: 44.0, height: 44)
                    .overlay {
                        Text(entry.nickname.prefix(1).uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .overlay(
                        Circle()
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                    )
            }

            // Name and completion badge
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.nickname)
                    .font(.LiquidGlass.bodyMedium)
                    .fontWeight(rank <= 3 ? .semibold : .regular)
                    .foregroundColor(.DesignSystem.text)

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.DesignSystem.brandGreen)
                    Text("Completed")
                        .font(.system(size: 11))
                        .foregroundColor(.DesignSystem.textSecondary)
                }
            }

            Spacer()

            // Completion checkmark with animation
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 20))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandGreen.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
                #if !SKIP
                .symbolEffect(.bounce, value: rank)
                #endif
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.sm)
        .background {
            if rank <= 3 {
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    #if !SKIP
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(rankColor.opacity(0.3), lineWidth: 1),
                    )
            }
        }
    }

    private var rankEmoji: String {
        switch rank {
        case 1: "🥇"
        case 2: "🥈"
        case 3: "🥉"
        default: ""
        }
    }

    private var rankColor: Color {
        switch rank {
        case 1: .DesignSystem.medalGold
        case 2: .DesignSystem.medalSilver
        case 3: .DesignSystem.accentOrange
        default: .DesignSystem.textSecondary
        }
    }

    private var rankGradient: LinearGradient {
        switch rank {
        case 1:
            LinearGradient(
                colors: [.DesignSystem.medalGold, .DesignSystem.accentOrange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        case 2:
            LinearGradient(
                colors: [.DesignSystem.medalSilver, .DesignSystem.medalSilver.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        case 3:
            LinearGradient(
                colors: [.DesignSystem.accentOrange, .DesignSystem.accentBrown],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        default:
            LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom)
        }
    }
}

// MARK: - Leaderboard Row


#endif
