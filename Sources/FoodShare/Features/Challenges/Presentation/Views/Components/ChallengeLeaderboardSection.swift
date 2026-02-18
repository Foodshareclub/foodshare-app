//
//  ChallengeLeaderboardSection.swift
//  Foodshare
//
//  Extracted challenge leaderboard section
//


#if !SKIP
import SwiftUI

struct ChallengeLeaderboardSection: View {
    @Bindable var viewModel: ChallengesViewModel
    @Environment(\.translationService) private var t

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Your Progress Stats
                challengeStats
                    .padding(.top, Spacing.md)

                // Leaderboard Header
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.DesignSystem.medalGold, .DesignSystem.accentOrange],
                                startPoint: .top,
                                endPoint: .bottom,
                            ),
                        )

                    Text(t.t("challenge.top_challengers"))
                        .font(.DesignSystem.headlineLarge)
                        .fontWeight(.bold)

                    Spacer()
                }
                .padding(.horizontal, Spacing.md)

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding(.vertical, Spacing.xl)
                } else if viewModel.leaderboard.isEmpty {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.DesignSystem.textSecondary)
                        Text(t.t("challenge.no_leaders"))
                            .font(.DesignSystem.bodyMedium)
                            .foregroundColor(.DesignSystem.textSecondary)
                    }
                    .padding(.vertical, Spacing.xl)
                } else {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.id) { index, entry in
                            LeaderboardRow(entry: entry)
                                .staggeredAnimation(index: index)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }
            }
            .padding(.bottom, Spacing.xl)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Challenge Stats

    private var challengeStats: some View {
        VStack(spacing: Spacing.md) {
            // Header
            HStack(spacing: Spacing.sm) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                            startPoint: .leading,
                            endPoint: .trailing,
                        ),
                    )

                Text(t.t("challenge.your_progress"))
                    .font(.DesignSystem.headlineSmall)
                    .fontWeight(.bold)

                Spacer()
            }

            // Stats Row
            HStack(spacing: Spacing.xl) {
                VStack(spacing: 4) {
                    Text("\(viewModel.publishedChallenges.count)")
                        .font(.DesignSystem.headlineLarge)
                        .fontWeight(.black)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                                startPoint: .leading,
                                endPoint: .trailing,
                            ),
                        )
                        /* contentTransition removed for Skip compatibility */
                        .animation(
                            .spring(response: 0.3, dampingFraction: 0.7),
                            value: viewModel.publishedChallenges.count,
                        )
                    Text(t.t("challenge.status.available"))
                        .font(.DesignSystem.caption)
                        .foregroundColor(.DesignSystem.textSecondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text("\(viewModel.joinedChallengesCount)")
                        .font(.DesignSystem.headlineLarge)
                        .fontWeight(.black)
                        .foregroundColor(.DesignSystem.accentOrange)
                        /* contentTransition removed for Skip compatibility */
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.joinedChallengesCount)
                    Text(t.t("challenge.status.in_progress"))
                        .font(.DesignSystem.caption)
                        .foregroundColor(.DesignSystem.textSecondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text("\(viewModel.completedChallengesCount)")
                        .font(.DesignSystem.headlineLarge)
                        .fontWeight(.black)
                        .foregroundColor(.DesignSystem.brandGreen)
                        /* contentTransition removed for Skip compatibility */
                        .animation(
                            .spring(response: 0.3, dampingFraction: 0.7),
                            value: viewModel.completedChallengesCount,
                        )
                    Text(t.t("challenge.status.completed"))
                        .font(.DesignSystem.caption)
                        .foregroundColor(.DesignSystem.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(Spacing.lg)
        .glassEffect(cornerRadius: CornerRadius.large)
        .padding(.horizontal, Spacing.md)
    }
}

// MARK: - Leaderboard Row

struct LeaderboardRow: View {
    let entry: ChallengeLeaderboardEntry

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Rank badge
            ZStack {
                if entry.rank <= 3 {
                    Circle()
                        .fill(rankGradient)
                        .frame(width: 32.0, height: 32)
                        .shadow(color: rankColor.opacity(0.4), radius: 4, y: 2)
                }
                Text(entry.rank <= 3 ? "\(entry.rank)" : "#\(entry.rank)")
                    .font(entry.rank <= 3 ? .system(size: 14, weight: .bold) : .LiquidGlass.bodySmall)
                    .foregroundColor(entry.rank <= 3 ? .white : .DesignSystem.textSecondary)
            }
            .frame(width: 40.0)

            // Avatar with ring
            if let avatarUrl = entry.avatarUrl,
               let url = URL(string: avatarUrl)
            {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(Color.DesignSystem.glassBackground)
                }
                .frame(width: 36.0, height: 36)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            entry.rank <= 3
                                ? rankGradient
                                : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom),
                            lineWidth: 2,
                        ),
                )
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen.opacity(0.2), .DesignSystem.brandBlue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .frame(width: 36.0, height: 36)
                    .overlay {
                        Text(entry.nickname.prefix(1).uppercased())
                            .font(.LiquidGlass.bodySmall)
                            .fontWeight(.semibold)
                            .foregroundColor(.DesignSystem.primary)
                    }
            }

            // Name
            Text(entry.nickname)
                .font(.LiquidGlass.bodyMedium)
                .foregroundColor(.DesignSystem.text)

            Spacer()

            // Completed badge
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandGreen.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.xs)
    }

    private var rankColor: Color {
        switch entry.rank {
        case 1: .DesignSystem.medalGold
        case 2: .DesignSystem.medalSilver
        case 3: .DesignSystem.medalBronze
        default: .DesignSystem.textSecondary
        }
    }

    private var rankGradient: LinearGradient {
        switch entry.rank {
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

#if DEBUG
#Preview {
    ChallengeLeaderboardSection(
        viewModel: ChallengesViewModel(repository: MockChallengeRepository())
    )
}
#endif

#endif
