//
//  ForumContainerView.swift
//  Foodshare
//
//  Container view that sets up ForumView with proper dependencies
//  Liquid Glass v26 premium loading experience
//

import OSLog
import SwiftUI
import FoodShareDesignSystem

#if DEBUG
    import Inject
#endif

private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "ForumContainer")

/// Container view that initializes ForumView with proper dependencies
struct ForumContainerView: View {
    
    @Environment(\.translationService) private var t
    @Environment(AppState.self) private var appState
    @State private var viewModel: ForumViewModel?
    @State private var showContent = false
    @State private var rotationDegrees: Double = 0
    @State private var hasInitialized = false

    var body: some View {
        ZStack {
            Color.backgroundGradient
                .ignoresSafeArea()

            if let viewModel, showContent {
                ForumView(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity,
                    ))
            } else {
                forumLoadingView
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showContent)
        .onAppear {
            logger.info("🟢 ForumContainerView.onAppear - hasInitialized=\(hasInitialized)")
            // Only initialize once - prevent re-initialization on tab switches
            guard !hasInitialized else {
                logger.debug("⏭️ ForumContainerView already initialized, skipping")
                return
            }
            hasInitialized = true
            logger.info("🚀 ForumContainerView initializing for first time...")

            Task {
                await setupViewModel()
            }
        }
    }

    // MARK: - Premium Forum Loading View

    private var forumLoadingView: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Header skeleton
                headerSkeleton

                // Category chips skeleton
                categoryChipsSkeleton

                // Forum posts skeleton
                ForEach(0 ..< 4, id: \.self) { index in
                    ForumPostSkeletonCard()
                        .staggeredAppearance(index: index)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
        }
        .scrollDisabled(true)
        .overlay(
            loadingOverlay,
        )
    }

    private var headerSkeleton: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Title placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.DesignSystem.textTertiary.opacity(0.2))
                    .frame(width: 180, height: 28)
                    .shimmer()

                // Subtitle placeholder
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.DesignSystem.textTertiary.opacity(0.15))
                    .frame(width: 120, height: 16)
                    .shimmer()
            }

            Spacer()

            // Create button placeholder
            Circle()
                .fill(Color.DesignSystem.brandGreen.opacity(0.3))
                .frame(width: 44, height: 44)
                .shimmer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder.opacity(0.5), lineWidth: 1),
                ),
        )
    }

    private var categoryChipsSkeleton: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(0 ..< 5, id: \.self) { index in
                    Capsule()
                        .fill(Color.DesignSystem.textTertiary.opacity(0.2))
                        .frame(width: CGFloat.random(in: 60 ... 100), height: 32)
                        .shimmer(duration: 1.2, bounce: false)
                        .staggeredAppearance(index: index, baseDelay: 0.05)
                }
            }
            .padding(.horizontal, Spacing.sm)
        }
    }

    private var loadingOverlay: some View {
        VStack(spacing: Spacing.md) {
            // Animated loading indicator
            ZStack {
                Circle()
                    .stroke(Color.DesignSystem.brandGreen.opacity(0.2), lineWidth: 3)
                    .frame(width: 50, height: 50)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.brandGreen,
                                Color.DesignSystem.brandCyan
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round),
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(rotationDegrees))
            }
            .shadow(color: Color.DesignSystem.brandGreen.opacity(0.4), radius: 10, y: 4)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.0)
                        .repeatForever(autoreverses: false),
                ) {
                    rotationDegrees = 360
                }
            }

            Text(t.t("forum.loading.title"))
                .font(.DesignSystem.labelLarge)
                .foregroundColor(.DesignSystem.text)

            Text(t.t("forum.loading.subtitle"))
                .font(.DesignSystem.captionMedium)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .padding(Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.extraLarge)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.extraLarge)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.glassHighlight,
                                    Color.DesignSystem.glassBorder
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                            lineWidth: 1,
                        ),
                ),
        )
        .shadow(color: Color.black.opacity(0.15), radius: 20, y: 10)
    }

    private func setupViewModel() async {
        logger.info("⚙️ setupViewModel() called")
        let repository = SupabaseForumRepository(supabase: appState.authService.supabase)
        logger.debug("📦 Repository created")
        viewModel = ForumViewModel(repository: repository)
        logger.info("✅ ForumViewModel created successfully")

        // Small delay to show the beautiful loading state
        try? await Task.sleep(for: .milliseconds(300))

        withAnimation {
            showContent = true
        }
        logger.info("📺 showContent set to true - ForumView should now appear")
    }
}

// MARK: - Forum Post Skeleton Card

private struct ForumPostSkeletonCard: View {
    @State private var shimmerPhase: CGFloat = -200

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Author row
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(skeletonGradient)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(width: 100, height: 14)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(skeletonGradient.opacity(0.7))
                        .frame(width: 70, height: 12)
                }

                Spacer()

                // Category badge
                Capsule()
                    .fill(skeletonGradient)
                    .frame(width: 60, height: 22)
            }

            // Title
            RoundedRectangle(cornerRadius: 6)
                .fill(skeletonGradient)
                .frame(height: 20)

            // Content preview
            VStack(alignment: .leading, spacing: Spacing.xs) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient.opacity(0.8))
                    .frame(height: 14)

                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient.opacity(0.6))
                        .frame(width: geometry.size.width * 0.6, height: 14)
                }
                .frame(height: 14)
            }

            // Stats row
            HStack(spacing: Spacing.lg) {
                ForEach(0 ..< 3, id: \.self) { _ in
                    HStack(spacing: Spacing.xxs) {
                        Circle()
                            .fill(skeletonGradient.opacity(0.5))
                            .frame(width: 16, height: 16)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(skeletonGradient.opacity(0.5))
                            .frame(width: 24, height: 12)
                    }
                }

                Spacer()
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder.opacity(0.5), lineWidth: 1),
                ),
        )
        .overlay(shimmerOverlay)
    }

    private var skeletonGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.DesignSystem.textTertiary.opacity(0.25),
                Color.DesignSystem.textTertiary.opacity(0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        )
    }

    private var shimmerOverlay: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.12),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing,
            )
            .frame(width: 120)
            .offset(x: shimmerPhase)
            .onAppear {
                shimmerPhase = -120
                withAnimation(
                    .linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                ) {
                    shimmerPhase = geometry.size.width + 120
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
}

#Preview {
    ForumContainerView()
        .environment(AppState())
}
