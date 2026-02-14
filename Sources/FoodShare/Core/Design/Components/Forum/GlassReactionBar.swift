//
//  GlassReactionBar.swift
//  Foodshare
//
//  Glassmorphism reaction bar component for forum emoji reactions
//  Part of Liquid Glass Design System v26
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Glass Reaction Bar

/// A glassmorphism reaction bar displaying emoji reactions with counts
struct GlassReactionBar: View {
    // MARK: - Properties

    let summary: ReactionsSummary
    let onReactionTap: (ReactionType) async -> Void
    let onLongPress: (() -> Void)?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showingPicker = false
    @State private var selectedReaction: ReactionType?
    @State private var animatingReactionId: Int?

    // MARK: - Initialization

    init(
        summary: ReactionsSummary,
        onReactionTap: @escaping (ReactionType) async -> Void,
        onLongPress: (() -> Void)? = nil,
    ) {
        self.summary = summary
        self.onReactionTap = onReactionTap
        self.onLongPress = onLongPress
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: Spacing.xs) {
            // Active reactions
            ForEach(summary.activeReactions.prefix(5)) { reaction in
                ReactionChip(
                    reaction: reaction,
                    isAnimating: animatingReactionId == reaction.id,
                    onTap: {
                        Task {
                            await handleReactionTap(reaction.reactionType)
                        }
                    },
                )
            }

            // Add reaction button (if there are unused reactions)
            if summary.activeReactions.count < ReactionType.all.count {
                AddReactionButton {
                    HapticManager.light()
                    showingPicker = true
                }
            }

            // Total count (if more than visible)
            if summary.totalCount > 0 {
                Spacer()
                totalCountView
            }
        }
        .popover(isPresented: $showingPicker) {
            ReactionPicker(
                reactions: ReactionType.all,
                userReactions: summary.userReactionTypeIds,
                onSelect: { reactionType in
                    showingPicker = false
                    Task {
                        await handleReactionTap(reactionType)
                    }
                },
            )
            .presentationCompactAdaptation(.popover)
        }
    }

    // MARK: - Total Count View

    private var totalCountView: some View {
        Text("\(summary.totalCount)")
            .font(.DesignSystem.caption)
            .fontWeight(.medium)
            .foregroundStyle(Color.DesignSystem.textSecondary)
            .contentTransition(.numericText())
            .monospacedDigit()
    }

    // MARK: - Actions

    private func handleReactionTap(_ reactionType: ReactionType) async {
        // Start animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            animatingReactionId = reactionType.id
        }

        HapticManager.light()

        await onReactionTap(reactionType)

        // End animation
        try? await Task.sleep(nanoseconds: 200_000_000)
        withAnimation {
            animatingReactionId = nil
        }
    }
}

// MARK: - Reaction Chip

private struct ReactionChip: View {
    let reaction: ReactionCount
    let isAnimating: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showParticles = false
    @State private var animationPhase: CGFloat = 0

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Particle burst overlay
                if showParticles {
                    ParticleBurstView(emoji: reaction.reactionType.emoji)
                        .allowsHitTesting(false)
                }

                HStack(spacing: 4) {
                    Text(reaction.reactionType.emoji)
                        .font(.system(size: 16))
                        .scaleEffect(isAnimating ? 1.4 : 1.0)
                        .rotationEffect(.degrees(isAnimating ? 15 : 0))
                        .animation(
                            reduceMotion ? .none : .spring(response: 0.25, dampingFraction: 0.4, blendDuration: 0.1),
                            value: isAnimating,
                        )

                    if reaction.count > 0 {
                        Text("\(reaction.count)")
                            .font(.DesignSystem.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(
                                reaction.hasUserReacted
                                    ? Color.DesignSystem.primary
                                    : Color.DesignSystem.textSecondary,
                            )
                            .contentTransition(.numericText())
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(chipBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            reaction.hasUserReacted
                                ? Color.DesignSystem.primary.opacity(0.5)
                                : Color.DesignSystem.glassBorder,
                            lineWidth: reaction.hasUserReacted ? 1.5 : 1,
                        ),
                )
                .overlay(
                    // Glow effect when animating
                    Capsule()
                        .fill(Color.DesignSystem.primary.opacity(isAnimating ? 0.3 : 0))
                        .blur(radius: 8)
                        .animation(.easeOut(duration: 0.3), value: isAnimating),
                )
            }
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.95, haptic: .none))
        .accessibilityLabel("\(reaction.reactionType.name), \(reaction.count) reactions")
        .accessibilityAddTraits(reaction.hasUserReacted ? .isSelected : [])
        .onChange(of: isAnimating) { _, newValue in
            if newValue && !reduceMotion {
                triggerParticles()
            }
        }
    }

    @ViewBuilder
    private var chipBackground: some View {
        if reaction.hasUserReacted {
            Color.DesignSystem.primary.opacity(0.15)
        } else {
            Color.DesignSystem.glassBackground
        }
    }

    private func triggerParticles() {
        showParticles = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            showParticles = false
        }
    }
}

// MARK: - Particle Burst View

private struct ParticleBurstView: View {
    let emoji: String

    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        let angle: Double
        let distance: CGFloat
        let delay: Double
        let scale: CGFloat
    }

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Text(emoji)
                    .font(.system(size: 12 * particle.scale))
                    .offset(
                        x: cos(particle.angle) * particle.distance,
                        y: sin(particle.angle) * particle.distance
                    )
                    .opacity(particle.distance > 0 ? 0.8 : 0)
                    .animation(
                        .easeOut(duration: 0.5).delay(particle.delay),
                        value: particle.distance
                    )
            }
        }
        .onAppear {
            createParticles()
        }
    }

    private func createParticles() {
        particles = (0..<6).map { index in
            Particle(
                angle: Double(index) * (.pi / 3) + .random(in: -0.3...0.3),
                distance: CGFloat.random(in: 20...35),
                delay: Double.random(in: 0...0.1),
                scale: CGFloat.random(in: 0.6...1.0)
            )
        }
    }
}

// MARK: - Add Reaction Button

private struct AddReactionButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "face.smiling")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.DesignSystem.textTertiary)
                .frame(width: 32, height: 28)
                .background(Color.DesignSystem.glassBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                )
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.95, haptic: .none))
        .accessibilityLabel("Add reaction")
    }
}

// MARK: - Reaction Picker

private struct ReactionPicker: View {
    let reactions: [ReactionType]
    let userReactions: [Int]
    let onSelect: (ReactionType) -> Void

    @State private var hoveredId: Int?

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(reactions) { reaction in
                ReactionPickerItem(
                    reaction: reaction,
                    isSelected: userReactions.contains(reaction.id),
                    isHovered: hoveredId == reaction.id,
                    onTap: { onSelect(reaction) },
                    onHover: { isHovered in
                        hoveredId = isHovered ? reaction.id : nil
                    },
                )
            }
        }
        .padding(Spacing.sm)
        .background(Color.DesignSystem.glassBackground)
        .clipShape(Capsule())
    }
}

// MARK: - Reaction Picker Item

private struct ReactionPickerItem: View {
    let reaction: ReactionType
    let isSelected: Bool
    let isHovered: Bool
    let onTap: () -> Void
    let onHover: (Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            Text(reaction.emoji)
                .font(.system(size: isHovered ? 28 : 24))
                .scaleEffect(isHovered ? 1.2 : 1.0)
                .offset(y: isHovered ? -4 : 0)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.25, dampingFraction: 0.6),
                    value: isHovered,
                )
        }
        .buttonStyle(.plain)
        .frame(width: 36, height: 36)
        .background(
            Circle()
                .fill(isSelected ? Color.DesignSystem.primary.opacity(0.2) : Color.clear),
        )
        .onHover(perform: onHover)
        .accessibilityLabel(reaction.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Compact Reaction Bar

/// A more compact reaction display for use in lists
struct GlassReactionBarCompact: View {
    let summary: ReactionsSummary
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 2) {
                // Show top 3 emojis
                ForEach(summary.activeReactions.prefix(3)) { reaction in
                    Text(reaction.reactionType.emoji)
                        .font(.system(size: 14))
                }

                if summary.totalCount > 0 {
                    Text("\(summary.totalCount)")
                        .font(.DesignSystem.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                        .padding(.leading, 2)
                }
            }
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 4)
            .background(Color.DesignSystem.glassBackground.opacity(0.6))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(summary.totalCount) reactions")
    }
}

// MARK: - Inline Reaction Button

/// A simple inline reaction button for comment rows
struct GlassReactionButton: View {
    let emoji: String
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isAnimating = false
    @State private var showMicroParticles = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                isAnimating = true
            }
            HapticManager.light()
            onTap()

            if !reduceMotion {
                showMicroParticles = true
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    showMicroParticles = false
                }
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                    isAnimating = false
                }
            }
        }) {
            ZStack {
                // Micro particles for inline button
                if showMicroParticles {
                    MicroParticleView(emoji: emoji)
                        .allowsHitTesting(false)
                }

                HStack(spacing: 4) {
                    Text(emoji)
                        .font(.system(size: 14))
                        .scaleEffect(isAnimating ? 1.5 : 1.0)
                        .rotationEffect(.degrees(isAnimating ? -10 : 0))

                    if count > 0 {
                        Text("\(count)")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(
                                isSelected
                                    ? Color.DesignSystem.primary
                                    : Color.DesignSystem.textTertiary,
                            )
                            .contentTransition(.numericText())
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, 4)
                .background(
                    isSelected
                        ? Color.DesignSystem.primary.opacity(0.1)
                        : Color.clear,
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                                ? Color.DesignSystem.primary.opacity(0.3)
                                : Color.clear,
                            lineWidth: 1,
                        ),
                )
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Micro Particle View

private struct MicroParticleView: View {
    let emoji: String

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Text(emoji)
                    .font(.system(size: 8))
                    .offset(
                        x: cos(Double(index) * .pi / 2) * 15,
                        y: sin(Double(index) * .pi / 2) * 15
                    )
                    .opacity(0.6)
            }
        }
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Reaction Bar - Active Reactions") {
    VStack(spacing: Spacing.lg) {
        GlassReactionBar(
            summary: ReactionsSummary.fixture(totalCount: 25),
            onReactionTap: { _ in },
        )

        GlassReactionBar(
            summary: ReactionsSummary(
                totalCount: 8,
                reactions: [
                    ReactionCount(reactionType: .like, count: 5, hasUserReacted: true),
                    ReactionCount(reactionType: .love, count: 3, hasUserReacted: false)
                ],
                userReactionTypeIds: [1],
            ),
            onReactionTap: { _ in },
        )

        GlassReactionBar(
            summary: ReactionsSummary(totalCount: 0, reactions: [], userReactionTypeIds: []),
            onReactionTap: { _ in },
        )
    }
    .padding()
    .background(Color.DesignSystem.background)
}

#Preview("Reaction Bar - Compact") {
    VStack(spacing: Spacing.md) {
        GlassReactionBarCompact(
            summary: ReactionsSummary.fixture(totalCount: 42),
            onTap: {},
        )

        GlassReactionBarCompact(
            summary: ReactionsSummary(
                totalCount: 156,
                reactions: [
                    ReactionCount(reactionType: .like, count: 100, hasUserReacted: false),
                    ReactionCount(reactionType: .love, count: 50, hasUserReacted: false),
                    ReactionCount(reactionType: .celebrate, count: 6, hasUserReacted: false)
                ],
                userReactionTypeIds: [],
            ),
            onTap: {},
        )
    }
    .padding()
    .background(Color.DesignSystem.background)
}

#Preview("Inline Reaction Buttons") {
    HStack(spacing: Spacing.sm) {
        GlassReactionButton(emoji: "👍", count: 12, isSelected: true, onTap: {})
        GlassReactionButton(emoji: "❤️", count: 5, isSelected: false, onTap: {})
        GlassReactionButton(emoji: "🎉", count: 0, isSelected: false, onTap: {})
    }
    .padding()
    .background(Color.DesignSystem.background)
}
#endif
