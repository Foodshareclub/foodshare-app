//
//  GlassPollCard.swift
//  Foodshare
//
//  Glassmorphism poll card component for forum voting
//  Part of Liquid Glass Design System v26
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Glass Poll Card

/// A glassmorphism poll card with voting functionality
struct GlassPollCard: View {
    // MARK: - Properties

    let poll: ForumPoll
    let onVote: ([UUID]) async -> Void
    let onRemoveVote: (UUID) async -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.translationService) private var t

    @State private var selectedOptions: Set<UUID> = []
    @State private var isVoting = false
    @State private var showResults = false
    @State private var animatedPercentages: [UUID: Double] = [:]

    // MARK: - Initialization

    init(
        poll: ForumPoll,
        onVote: @escaping ([UUID]) async -> Void,
        onRemoveVote: @escaping (UUID) async -> Void = { _ in },
    ) {
        self.poll = poll
        self.onVote = onVote
        self.onRemoveVote = onRemoveVote
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Poll header
            pollHeader

            // Poll options
            VStack(spacing: Spacing.sm) {
                if let options = poll.options {
                    ForEach(options.sorted { $0.sortOrder < $1.sortOrder }) { option in
                        PollOptionRow(
                            option: option,
                            poll: poll,
                            isSelected: selectedOptions.contains(option.id),
                            showResults: poll.shouldShowResults || showResults,
                            animatedPercentage: animatedPercentages[option.id] ?? 0,
                            onTap: { handleOptionTap(option) },
                        )
                    }
                }
            }

            // Vote button (if not yet voted and poll is active)
            if poll.canVote, !selectedOptions.isEmpty, !poll.hasVoted {
                voteButton
            }

            // Poll footer
            pollFooter
        }
        .padding(Spacing.md)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusLG))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusLG)
                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
        )
        .shadow(
            color: .black.opacity(0.15),
            radius: 20,
            x: 0,
            y: 8,
        )
        .onAppear {
            // Initialize selected options from user votes
            if let userVotes = poll.userVotes {
                selectedOptions = Set(userVotes)
            }
            // Animate percentages on appear
            animatePercentages()
        }
        .onChange(of: poll.options) { _, _ in
            animatePercentages()
        }
    }

    // MARK: - Poll Header

    private var pollHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.DesignSystem.brandGreen)

                Text("Poll")
                    .font(.DesignSystem.labelMedium)
                    .foregroundStyle(Color.DesignSystem.brandGreen)

                Spacer()

                // Poll type indicator
                Label(poll.pollType.displayName, systemImage: poll.pollType.iconName)
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            Text(poll.question)
                .font(.DesignSystem.headlineSmall)
                .foregroundStyle(Color.DesignSystem.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Vote Button

    private var voteButton: some View {
        Button {
            Task {
                await submitVote()
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                if isVoting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                }
                Text("Vote")
                    .fontWeight(.semibold)
            }
            .font(.DesignSystem.labelMedium)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: Spacing.radiusMD)
                    .fill(Color.DesignSystem.primary),
            )
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.97, haptic: .light))
        .disabled(isVoting)
    }

    // MARK: - Poll Footer

    private var pollFooter: some View {
        HStack(spacing: Spacing.md) {
            // Total votes
            Label(t.t("poll.votes_count", args: ["count": String(poll.totalVotes)]), systemImage: "person.2.fill")
                .font(.DesignSystem.caption)
                .foregroundStyle(Color.DesignSystem.textSecondary)

            Spacer()

            // Time remaining or ended status
            if poll.hasEnded {
                Label(t.t("poll.ended"), systemImage: "clock.badge.checkmark.fill")
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textTertiary)
            } else if let timeText = poll.timeRemainingText {
                Label(timeText, systemImage: "clock.fill")
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.brandOrange)
            }

            // Anonymous indicator
            if poll.isAnonymous {
                Label(t.t("common.anonymous"), systemImage: "eye.slash.fill")
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textTertiary)
            }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var cardBackground: some View {
        if reduceTransparency {
            Color(uiColor: .secondarySystemBackground)
        } else {
            Color.clear
                .background(.ultraThinMaterial)
        }
    }

    // MARK: - Actions

    private func handleOptionTap(_ option: ForumPollOption) {
        guard poll.canVote || poll.pollType == .multiple else { return }

        HapticManager.light()

        if poll.pollType == .single {
            // Single choice: replace selection
            if poll.hasVoted {
                // Already voted in single-choice poll, can't change
                return
            }
            selectedOptions = [option.id]
        } else {
            // Multiple choice: toggle selection
            if selectedOptions.contains(option.id) {
                selectedOptions.remove(option.id)
                // If user already voted and is deselecting, remove the vote
                if poll.userVotes?.contains(option.id) == true {
                    Task {
                        await onRemoveVote(option.id)
                    }
                }
            } else {
                selectedOptions.insert(option.id)
            }
        }
    }

    private func submitVote() async {
        guard !selectedOptions.isEmpty else { return }

        isVoting = true
        defer { isVoting = false }

        await onVote(Array(selectedOptions))
        HapticManager.success()

        // Show results after voting
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showResults = true
        }
        animatePercentages()
    }

    private func animatePercentages() {
        guard let options = poll.options else { return }

        // Reset to zero first
        for option in options {
            animatedPercentages[option.id] = 0
        }

        // Animate to actual percentages
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
            for option in options {
                animatedPercentages[option.id] = option.votePercentage(totalVotes: poll.totalVotes)
            }
        }
    }
}

// MARK: - Poll Option Row

private struct PollOptionRow: View {
    let option: ForumPollOption
    let poll: ForumPoll
    let isSelected: Bool
    let showResults: Bool
    let animatedPercentage: Double
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isUserVote: Bool {
        poll.userVotes?.contains(option.id) == true
    }

    private var isWinning: Bool {
        guard let options = poll.options, poll.totalVotes > 0 else { return false }
        let maxVotes = options.map(\.votesCount).max() ?? 0
        return option.votesCount == maxVotes && option.votesCount > 0
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                // Selection indicator
                selectionIndicator

                // Option text
                Text(option.optionText)
                    .font(.DesignSystem.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                // Results (percentage and count)
                if showResults {
                    resultsView
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(optionBackground)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMD))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusMD)
                    .stroke(borderColor, lineWidth: isSelected || isUserVote ? 2 : 1),
            )
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.98, haptic: .none))
        .disabled(!poll.canVote && poll.pollType == .single)
        .accessibilityLabel("\(option.optionText), \(option.formattedPercentage(totalVotes: poll.totalVotes))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Selection Indicator

    @ViewBuilder
    private var selectionIndicator: some View {
        if poll.pollType == .single {
            // Radio button style
            ZStack {
                Circle()
                    .stroke(
                        isSelected || isUserVote ? Color.DesignSystem.primary : Color.DesignSystem.textTertiary,
                        lineWidth: 2,
                    )
                    .frame(width: 20, height: 20)

                if isSelected || isUserVote {
                    Circle()
                        .fill(Color.DesignSystem.primary)
                        .frame(width: 12, height: 12)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        } else {
            // Checkbox style
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        isSelected || isUserVote ? Color.DesignSystem.primary : Color.DesignSystem.textTertiary,
                        lineWidth: 2,
                    )
                    .frame(width: 20, height: 20)

                if isSelected || isUserVote {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.DesignSystem.primary)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white),
                        )
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Results View

    private var resultsView: some View {
        HStack(spacing: Spacing.xs) {
            Text(option.formattedPercentage(totalVotes: poll.totalVotes))
                .font(.DesignSystem.labelMedium)
                .foregroundStyle(isWinning ? Color.DesignSystem.primary : Color.DesignSystem.textSecondary)
                .contentTransition(.numericText())
                .monospacedDigit()

            if isUserVote {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.DesignSystem.primary)
            }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var optionBackground: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Base background
                Color.DesignSystem.glassBackground

                // Progress bar (shown when results are visible)
                if showResults, animatedPercentage > 0 {
                    RoundedRectangle(cornerRadius: Spacing.radiusSM)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * (animatedPercentage / 100))
                        .animation(
                            reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8),
                            value: animatedPercentage,
                        )
                }
            }
        }
    }

    private var progressColor: Color {
        if isUserVote {
            Color.DesignSystem.primary.opacity(0.3)
        } else if isWinning {
            Color.DesignSystem.primary.opacity(0.15)
        } else {
            Color.DesignSystem.textSecondary.opacity(0.1)
        }
    }

    private var borderColor: Color {
        if isUserVote {
            Color.DesignSystem.primary
        } else if isSelected {
            Color.DesignSystem.primary.opacity(0.6)
        } else {
            Color.DesignSystem.glassBorder
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Poll - Not Voted") {
    ScrollView {
        VStack(spacing: Spacing.md) {
            GlassPollCard(
                poll: .fixture(
                    question: "What's your favorite food sharing approach?",
                    pollType: .single,
                    totalVotes: 42,
                    userVotes: nil,
                ),
                onVote: { _ in },
                onRemoveVote: { _ in },
            )

            GlassPollCard(
                poll: .fixture(
                    question: "Which features would you like to see? (Select all that apply)",
                    pollType: .multiple,
                    totalVotes: 128,
                    userVotes: nil,
                ),
                onVote: { _ in },
                onRemoveVote: { _ in },
            )
        }
        .padding()
    }
    .background(Color.DesignSystem.background)
}

#Preview("Poll - Already Voted") {
    let pollId = UUID()
    let option1 = ForumPollOption.fixture(
        pollId: pollId,
        optionText: "Door-to-door delivery",
        votesCount: 15,
        sortOrder: 0,
    )
    let option2 = ForumPollOption.fixture(
        pollId: pollId,
        optionText: "Community pickup points",
        votesCount: 20,
        sortOrder: 1,
    )

    ScrollView {
        GlassPollCard(
            poll: .fixture(
                id: pollId,
                question: "What's your preferred pickup method?",
                pollType: .single,
                totalVotes: 42,
                options: [option1, option2],
                userVotes: [option2.id],
            ),
            onVote: { _ in },
            onRemoveVote: { _ in },
        )
        .padding()
    }
    .background(Color.DesignSystem.background)
}

#Preview("Poll - Ended") {
    ScrollView {
        GlassPollCard(
            poll: .fixture(
                question: "Should we add weekend deliveries?",
                pollType: .single,
                endsAt: Date().addingTimeInterval(-3600), // Ended 1 hour ago
                totalVotes: 89,
            ),
            onVote: { _ in },
            onRemoveVote: { _ in },
        )
        .padding()
    }
    .background(Color.DesignSystem.background)
}
#endif
