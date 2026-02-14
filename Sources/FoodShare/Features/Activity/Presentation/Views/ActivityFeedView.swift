//
//  ActivityFeedView.swift
//  Foodshare
//
//  Activity Feed with Liquid Glass design
//

import SwiftUI
import FoodShareDesignSystem

#if DEBUG
    import Inject
#endif

struct ActivityFeedView: View {
    
    @Environment(\.translationService) private var t
    @State private var viewModel: ActivityViewModel

    init(viewModel: ActivityViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            Color.DesignSystem.background.ignoresSafeArea()

            Group {
                if viewModel.isLoading, !viewModel.hasActivities {
                    loadingView
                } else if viewModel.hasActivities {
                    activityList
                } else {
                    emptyState
                }
            }
        }
        .navigationTitle(t.t("activity.title"))
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadActivities()
            await viewModel.subscribeToRealTimeUpdates()
        }
        .onDisappear {
            Task {
                await viewModel.unsubscribeFromRealTimeUpdates()
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .alert(t.t("common.error.title"), isPresented: $viewModel.showError) {
            Button(t.t("common.ok")) { viewModel.dismissError() }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: Spacing.sm) {
                ForEach(0 ..< 6, id: \.self) { index in
                    ActivitySkeletonRow()
                        .staggeredAppearance(index: index)
                }
            }
            .padding(Spacing.md)
        }
    }

    // MARK: - Activity List

    private var activityList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(viewModel.activities) { activity in
                    ActivityCard(activity: activity)
                }

                if viewModel.hasMorePages {
                    loadMoreTrigger
                }
            }
            .padding(Spacing.md)
        }
    }

    private var loadMoreTrigger: some View {
        Group {
            if viewModel.isLoadingMore {
                ProgressView()
                    .padding(Spacing.lg)
            } else {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        Task { await viewModel.loadMore() }
                    }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.DesignSystem.brandGreen.opacity(0.2),
                                Color.DesignSystem.brandBlue.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80,
                        ),
                    )
                    .frame(width: 160, height: 160)

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .shimmer(duration: 3.0, bounce: false)
            }

            Text(t.t("activity.empty_title"))
                .font(.DesignSystem.headlineLarge)
                .foregroundColor(.DesignSystem.text)

            Text(t.t("activity.empty_desc"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
    }
}

// MARK: - Activity Card

struct ActivityCard: View {
    let activity: ActivityItem

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            // Type Icon
            ZStack {
                Circle()
                    .fill(activity.type.color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: activity.type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(activity.type.color)
            }

            // Content
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Title Row
                HStack {
                    Text(activity.title)
                        .font(.DesignSystem.labelLarge)
                        .fontWeight(.semibold)
                        .foregroundColor(.DesignSystem.text)
                        .lineLimit(1)

                    Spacer()

                    Text(activity.timeAgo)
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textTertiary)
                }

                // Subtitle
                if !activity.subtitle.isEmpty {
                    Text(activity.subtitle)
                        .font(.DesignSystem.bodySmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                        .lineLimit(2)
                }

                // Actor Info
                if let actorName = activity.actorName {
                    HStack(spacing: Spacing.xs) {
                        // Avatar
                        if let avatarURL = activity.actorAvatarURL {
                            AsyncImage(url: avatarURL) { phase in
                                switch phase {
                                case let .success(image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                        .transition(.opacity.animation(.interpolatingSpring(stiffness: 300, damping: 24)))
                                default:
                                    defaultAvatar
                                }
                            }
                            .frame(width: 20, height: 20)
                            .clipShape(Circle())
                        } else {
                            defaultAvatar
                                .frame(width: 20, height: 20)
                        }

                        Text(actorName)
                            .font(.DesignSystem.captionSmall)
                            .foregroundColor(.DesignSystem.textTertiary)
                    }
                }

                // Type Badge
                Text(activity.type.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(activity.type.color)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 2)
                    .background(activity.type.color.opacity(0.1))
                    .clipShape(Capsule())
            }

            // Thumbnail (if available) with fade transition
            if let imageURL = activity.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .transition(.opacity.animation(.interpolatingSpring(stiffness: 300, damping: 24)))
                    default:
                        Rectangle()
                            .fill(Color.DesignSystem.glassBackground)
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
        )
    }

    private var defaultAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.DesignSystem.brandGreen.opacity(0.3), .DesignSystem.brandBlue.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                ),
            )
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.DesignSystem.textSecondary),
            )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ActivityFeedView(
            viewModel: ActivityViewModel(
                repository: SupabaseActivityRepository(supabase: AuthenticationService.shared.supabase),
                client: AuthenticationService.shared.supabase
            )
        )
    }
}

// MARK: - Activity Skeleton Row

private struct ActivitySkeletonRow: View {
    @State private var shimmerPhase: CGFloat = -200

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            // Icon skeleton
            Circle()
                .fill(skeletonGradient)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    // Title skeleton
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(width: 150, height: 16)

                    Spacer()

                    // Time skeleton
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(width: 40, height: 12)
                }

                // Subtitle skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(width: 100, height: 12)

                // Badge skeleton
                Capsule()
                    .fill(skeletonGradient)
                    .frame(width: 70, height: 18)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(Color.DesignSystem.glassBorder.opacity(0.5), lineWidth: 1),
        )
        .overlay(shimmerOverlay)
    }

    private var skeletonGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.DesignSystem.textTertiary.opacity(0.3),
                Color.DesignSystem.textTertiary.opacity(0.2)
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
                    Color.white.opacity(0.15),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing,
            )
            .frame(width: 150)
            .offset(x: shimmerPhase)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                ) {
                    shimmerPhase = geometry.size.width + 150
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
}
