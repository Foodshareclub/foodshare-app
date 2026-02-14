//
//  ChallengesListSection.swift
//  Foodshare
//
//  Extracted challenges list view with cards
//

import FoodShareDesignSystem
import SwiftUI

struct ChallengesListSection: View {
    @Bindable var viewModel: ChallengesViewModel
    let onChallengeSelected: (Challenge) -> Void
    @Environment(\.translationService) private var t

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                ForEach(Array(viewModel.filteredChallenges.enumerated()), id: \.element.id) { index, challenge in
                    Button {
                        onChallengeSelected(challenge)
                    } label: {
                        ChallengeCard(
                            challenge: challenge,
                            userStatus: viewModel.userStatus(for: challenge),
                            viewModel: viewModel,
                        )
                        .staggeredAnimation(index: index)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}

// MARK: - Challenge Card

struct ChallengeCard: View {
    @Environment(\.translationService) private var t
    let challenge: Challenge
    let userStatus: ChallengeUserStatus
    @Bindable var viewModel: ChallengesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header with image
            HStack {
                // Challenge image or icon
                if let imageUrl = challenge.imageUrl {
                    AsyncImage(url: imageUrl) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        difficultyIcon
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                } else {
                    difficultyIcon
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.displayTitle)
                        .font(.DesignSystem.headlineSmall)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(challenge.challengeDifficulty.localizedDisplayName(using: t))
                        .font(.DesignSystem.caption)
                        .foregroundColor(.DesignSystem.textSecondary)
                }

                Spacer()

                statusBadge
            }

            // Description
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(challenge.displayDescription)
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
                    .lineLimit(2)

                if challenge.isTranslated {
                    TranslatedIndicator()
                }
            }

            // Stats row with GlassStatPill components
            HStack(spacing: Spacing.sm) {
                GlassStatPill(
                    icon: "star.fill",
                    iconColor: .DesignSystem.accentYellow,
                    value: challenge.localizedFormattedScore(using: t),
                    isHighlighted: true,
                )

                GlassStatPill(
                    icon: "person.2.fill",
                    iconColor: .DesignSystem.brandBlue,
                    value: challenge.localizedFormattedParticipants(using: t),
                )

                GlassStatPill.views(challenge.challengeViews)

                Spacer()
            }

            // Challenge Like Button
            ChallengeLikeButton(
                challengeId: challenge.id,
                initialLikeCount: viewModel.likeCount(for: challenge.id),
                initialIsLiked: viewModel.isLiked(challengeId: challenge.id),
                size: .small,
                showCount: true,
            ) { isLiked, likeCount in
                // Update ViewModel state after successful toggle
                Task { @MainActor in
                    viewModel.likeStates[challenge.id] = isLiked
                    viewModel.likeCounts[challenge.id] = likeCount
                }
            }
        }
        .padding(Spacing.md)
        .glassEffect(cornerRadius: CornerRadius.large)
        .pressAnimation()
    }

    private var difficultyIcon: some View {
        ZStack {
            Circle()
                .fill(difficultyGradient)
                .frame(width: 50, height: 50)

            Image(systemName: challenge.challengeDifficulty.icon)
                .font(.title2)
                .foregroundColor(.white)
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

    @ViewBuilder
    private var statusBadge: some View {
        switch userStatus {
        case .notJoined:
            Text(t.t("challenge.status.join"))
                .font(.LiquidGlass.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    LinearGradient(
                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                        startPoint: .leading,
                        endPoint: .trailing,
                    ),
                )
                .clipShape(Capsule())
                .shadow(color: .DesignSystem.brandGreen.opacity(0.4), radius: 4, y: 2)

        case .accepted:
            Text(t.t("challenge.status.in_progress"))
                .font(.LiquidGlass.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    LinearGradient(
                        colors: [.DesignSystem.accentOrange, .DesignSystem.accentYellow],
                        startPoint: .leading,
                        endPoint: .trailing,
                    ),
                )
                .clipShape(Capsule())
                .shadow(color: .DesignSystem.accentOrange.opacity(0.4), radius: 4, y: 2)

        case .completed:
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                Text(t.t("challenge.status.done"))
            }
            .font(.LiquidGlass.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                LinearGradient(
                    colors: [.DesignSystem.brandGreen, .DesignSystem.brandGreen.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing,
                ),
            )
            .clipShape(Capsule())
            .shadow(color: .DesignSystem.brandGreen.opacity(0.4), radius: 4, y: 2)

        case .rejected:
            Text(t.t("challenge.status.declined"))
                .font(.LiquidGlass.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(Color.DesignSystem.textSecondary.opacity(0.6))
                .clipShape(Capsule())
        }
    }
}

#if DEBUG
#Preview {
    ChallengesListSection(
        viewModel: ChallengesViewModel(repository: MockChallengeRepository()),
        onChallengeSelected: { _ in }
    )
}
#endif
