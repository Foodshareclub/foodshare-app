//
//  ChallengeCardDeck.swift
//  Foodshare
//
//  Premium card deck with cinematic animations
//  Liquid Glass v26 design with ProMotion 120Hz optimization
//


#if !SKIP
import Kingfisher
import SwiftUI

// MARK: - Shuffle Phase

private enum ShufflePhase: CaseIterable {
    case idle
    case rise // Cards lift up
    case fan // Cards fan out in arc
    case spin // Cards spin while shuffling
    case riffle // Riffle shuffle effect
    case cascade // Cards cascade back down
    case settle // Final settle with bounce
}

// MARK: - Card Entrance Phase

private enum EntrancePhase {
    case hidden, entering, visible
}

// MARK: - Swipe Indicator

private struct SwipeIndicator: View {
    @Environment(\.translationService) private var t
    enum IndicatorType { case accept, decline }
    let type: IndicatorType
    let intensity: CGFloat

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Glow background
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(
                    RadialGradient(
                        colors: [
                            (type == .accept ? Color.DesignSystem.brandGreen : Color.DesignSystem.error)
                                .opacity(0.4 * intensity),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 80,
                    ),
                )
                .frame(width: 120.0, height: 60)
                .scaleEffect(isPulsing ? 1.2 : 1.0)

            // Main badge
            HStack(spacing: Spacing.xs) {
                Image(systemName: type == .accept ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                Text(type == .accept ? t.t("challenge.action.join") : t.t("challenge.action.skip"))
                    .font(.DesignSystem.headlineMedium)
                    .fontWeight(.black)
            }
            .foregroundColor(.white)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: type == .accept
                                ? [Color.DesignSystem.brandGreen, Color.DesignSystem.brandGreen.opacity(0.8)]
                                : [Color.DesignSystem.error, Color.DesignSystem.error.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    ),
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2),
            )
            .shadow(
                color: (type == .accept ? Color.DesignSystem.brandGreen : Color.DesignSystem.error).opacity(0.6),
                radius: 15,
                y: 5,
            )
            .scaleEffect(0.8 + (intensity * 0.4))
        }
        .rotationEffect(.degrees(type == .accept ? 12 : -12))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Challenge Card Deck

struct ChallengeCardDeck: View {
    let challenges: [Challenge]
    let userStatusProvider: (Challenge) -> ChallengeUserStatus
    let onChallengeSelected: (Challenge) -> Void
    var onSwipeRight: ((Challenge) -> Void)?
    var onSwipeLeft: ((Challenge) -> Void)?
    var shuffleTrigger = false
    var availableSize: CGSize = .zero

    @State private var currentIndex = 0
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var isShuffling = false
    @State private var shuffledChallenges: [Challenge] = []
    @State private var shufflePhase: ShufflePhase = .idle
    @State private var crossedThreshold = false
    @State private var entrancePhase: EntrancePhase = .hidden
    @State private var cardAngles: [Int: Double] = [:]
    @State private var showSparkles = false
    @State private var topCardFlipped = false

    private let maxVisibleCards = 5
    private let cardSpacing: CGFloat = 12
    private let cardScaleDecrement: CGFloat = 0.06
    private let swipeThreshold: CGFloat = 100

    // MARK: - Adaptive Card Size Calculation

    private var cardSize: CGSize {
        calculateCardSize(from: availableSize)
    }

    private func calculateCardSize(from size: CGSize) -> CGSize {
        // Default fallback size
        guard size.width > 0, size.height > 0 else {
            return CGSize(width: 350.0, height: 540.0)
        }

        let aspectRatio: CGFloat = 350.0 / 540.0 // 0.648

        // Calculate max card height (leave padding for shuffle button area)
        let maxCardHeight = size.height - 40

        // Calculate width from height maintaining aspect ratio
        var cardWidth = maxCardHeight * aspectRatio

        // Clamp to available width with margins
        let maxWidth = min(size.width - 40, 600) // 600pt max
        cardWidth = min(cardWidth, maxWidth)
        cardWidth = max(cardWidth, 320) // 320pt min

        let cardHeight = cardWidth / aspectRatio

        return CGSize(width: cardWidth, height: cardHeight)
    }

    var body: some View {
        ZStack {
            // Sparkle particles during shuffle
            if showSparkles {
                ShuffleSparkles()
                    .allowsHitTesting(false)
            }

            // Background cards with 3D depth
            ForEach(visibleCardIndices.reversed(), id: \.self) { index in
                if index != currentIndex {
                    deckCard(at: index)
                }
            }

            // Top card with swipe gestures
            if !shuffledChallenges.isEmpty, entrancePhase != .hidden {
                topCard
            }
        }
        .frame(height: cardSize.height + 60) // Adaptive height with padding for effects
        .onAppear {
            if shuffledChallenges.isEmpty {
                shuffledChallenges = challenges.shuffled()
                // Animate entrance
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        entrancePhase = .entering
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        entrancePhase = .visible
                    }
                }
            }
        }
        .onChange(of: shuffleTrigger) {
            shuffle()
        }
    }

    private var visibleCardIndices: [Int] {
        guard !shuffledChallenges.isEmpty else { return [] }
        var indices: [Int] = []
        for i in 0 ..< min(maxVisibleCards, shuffledChallenges.count) {
            let index = (currentIndex + i) % shuffledChallenges.count
            indices.append(index)
        }
        return indices
    }

    private var entranceOffset: CGFloat {
        switch entrancePhase {
        case .hidden: 400
        case .entering: 50
        case .visible: 0
        }
    }

    private var entranceScale: CGFloat {
        switch entrancePhase {
        case .hidden: 0.5
        case .entering: 0.95
        case .visible: 1.0
        }
    }

    // MARK: - Top Card with Enhanced Physics

    private var topCard: some View {
        let challenge = shuffledChallenges[currentIndex]
        let rotationAngle = Double(dragOffset.width / 12)
        let tiltAngle = Double(dragOffset.height / 30)
        let dragProgress = min(1.0, abs(dragOffset.width) / swipeThreshold)

        return ZStack {
            // Card glow effect based on drag direction
            if isDragging, abs(dragOffset.width) > 30 {
                RoundedRectangle(cornerRadius: CornerRadius.xl)
                    .fill(
                        RadialGradient(
                            colors: [
                                shadowColorForDrag.opacity(0.4 * dragProgress),
                                Color.clear,
                            ],
                            center: .center,
                            startRadius: 100,
                            endRadius: 200,
                        ),
                    )
                    .frame(width: cardSize.width + 100, height: cardSize.height + 60)
                    .blur(radius: 20)
            }

            DeckChallengeCard(
                challenge: challenge,
                userStatus: userStatusProvider(challenge),
                isFaceUp: true,
                cardSize: cardSize,
            )

            // Swipe direction indicators
            swipeIndicatorOverlay
        }
        .offset(y: entranceOffset)
        .scaleEffect(entranceScale)
        .offset(dragOffset)
        .rotationEffect(.degrees(rotationAngle))
        // 3D tilt based on vertical drag
        .rotation3DEffect(
            .degrees(tiltAngle),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.4,
        )
        // Lift effect when dragging
        .rotation3DEffect(
            .degrees(isDragging ? 5 : 0),
            axis: (x: -dragOffset.height * 0.01, y: dragOffset.width * 0.01, z: 0),
            perspective: 0.5,
        )
        .scaleEffect(isDragging ? 1.08 : 1.0)
        // Dynamic shadow based on drag direction
        .shadow(
            color: shadowColorForDrag.opacity(isDragging ? 0.7 : 0.3),
            radius: isDragging ? 30 : 15,
            x: dragOffset.width * 0.05,
            y: isDragging ? 20 : 8,
        )
        .gesture(dragGesture)
        .onTapGesture { onChallengeSelected(challenge) }
        .animation(.interpolatingSpring(stiffness: 300, damping: 22), value: dragOffset)
        .animation(.interpolatingSpring(stiffness: 350, damping: 25), value: isDragging)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: entrancePhase)
        .zIndex(100)
    }

    // MARK: - Swipe Indicators Overlay

    @ViewBuilder
    private var swipeIndicatorOverlay: some View {
        let swipeProgress = abs(dragOffset.width) / swipeThreshold

        // Accept indicator (right swipe)
        if dragOffset.width > 20 {
            SwipeIndicator(type: SwipeIndicator.IndicatorType.accept, intensity: min(1.0, swipeProgress))
                .opacity(min(1.0, dragOffset.width / (swipeThreshold * 0.6)))
                .offset(x: -70, y: -120)
                .scaleEffect(0.9 + (swipeProgress * 0.2))
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: dragOffset.width)
        }

        // Decline indicator (left swipe)
        if dragOffset.width < -20 {
            SwipeIndicator(type: SwipeIndicator.IndicatorType.decline, intensity: min(1.0, swipeProgress))
                .opacity(min(1.0, abs(dragOffset.width) / (swipeThreshold * 0.6)))
                .offset(x: 70, y: -120)
                .scaleEffect(0.9 + (swipeProgress * 0.2))
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: dragOffset.width)
        }
    }

    // MARK: - Deck Card with 3D Depth & Parallax

    private func deckCard(at index: Int) -> some View {
        let position = positionInStack(for: index)
        let challenge = shuffledChallenges[index]
        let shuffle3D = shuffle3DRotation(for: position)

        return DeckChallengeCard(
            challenge: challenge,
            userStatus: userStatusProvider(challenge),
            isFaceUp: position == 0 && shufflePhase == .idle,
            cardSize: cardSize,
        )
        .scaleEffect(scaleForPosition(position) * shuffleScale(for: position))
        .offset(y: offsetForPosition(position))
        // Base 3D rotation for depth perception
        .rotation3DEffect(
            .degrees(Double(position) * 3),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.4,
        )
        // Shuffle 3D rotation
        .rotation3DEffect(
            .degrees(shuffle3D.x),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.5,
        )
        .rotation3DEffect(
            .degrees(shuffle3D.y),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5,
        )
        // Subtle Z rotation for visual interest
        .rotationEffect(.degrees(rotationForPosition(position) + shuffleRotation(for: position)))
        // Progressive blur for depth
        .blur(radius: CGFloat(position) * 0.4)
        // Parallax effect when dragging top card
        .offset(x: isDragging ? dragOffset.width * (0.1 * CGFloat(position)) : 0)
        .offset(y: isDragging ? abs(dragOffset.width) * 0.02 * CGFloat(position) : 0)
        .opacity(opacityForPosition(position))
        .zIndex(Double(maxVisibleCards - position))
        // Shuffle phase animations
        .offset(shuffleOffset(for: position))
        .animation(
            .interpolatingSpring(stiffness: 180, damping: 16)
                .delay(Double(position) * 0.04),
            value: currentIndex,
        )
        .animation(
            .spring(response: 0.35, dampingFraction: 0.65)
                .delay(Double(position) * 0.02),
            value: shufflePhase,
        )
        // GPU acceleration for complex effects
        .drawingGroup()
    }

    // MARK: - Position Calculations

    private func positionInStack(for index: Int) -> Int {
        let diff = index - currentIndex
        return diff >= 0 ? diff : shuffledChallenges.count + diff
    }

    private func scaleForPosition(_ position: Int) -> CGFloat {
        let baseScale = max(0.82, 1.0 - (CGFloat(position) * cardScaleDecrement))
        // Extra scale reduction during shuffle spin
        if shufflePhase == .spin {
            return baseScale * 0.95
        }
        return baseScale
    }

    private func offsetForPosition(_ position: Int) -> CGFloat {
        CGFloat(position) * cardSpacing
    }

    private func rotationForPosition(_ position: Int) -> Double {
        let baseRotation = Double(position) * 1.2
        return position % 2 == 0 ? baseRotation : -baseRotation
    }

    private func opacityForPosition(_ position: Int) -> Double {
        position < maxVisibleCards ? 1.0 - (Double(position) * 0.12) : 0
    }

    // MARK: - Shuffle Animation Offsets

    private func shuffleOffset(for position: Int) -> CGSize {
        switch shufflePhase {
        case .idle, .settle:
            return .zero
        case .rise:
            // Cards lift up slightly
            return CGSize(width: 0, height: -30 - CGFloat(position) * 5)
        case .fan:
            // Fan out in a beautiful arc
            let angle = -60.0 + Double(position) * 30
            let distance: CGFloat = 80 + CGFloat(position) * 25
            return CGSize(
                width: cos(angle * .pi / 180) * distance,
                height: sin(angle * .pi / 180) * distance - 20,
            )
        case .spin:
            // Spiral motion
            let spiralAngle = Double(position) * 72 + 180
            let distance: CGFloat = 50 + CGFloat(position) * 15
            return CGSize(
                width: cos(spiralAngle * .pi / 180) * distance,
                height: sin(spiralAngle * .pi / 180) * distance * 0.6,
            )
        case .riffle:
            // Riffle shuffle - cards interleave
            let isLeft = position % 2 == 0
            let horizontalOffset: CGFloat = isLeft ? -100 : 100
            let verticalOffset = CGFloat(position) * -8
            return CGSize(width: horizontalOffset, height: verticalOffset - 40)
        case .cascade:
            // Cascade back with stagger
            let cascadeDelay = CGFloat(position) * 15
            return CGSize(width: 0, height: -cascadeDelay)
        }
    }

    private func shuffleRotation(for position: Int) -> Double {
        switch shufflePhase {
        case .idle, .settle:
            0
        case .rise:
            Double(position % 2 == 0 ? 3 : -3)
        case .fan:
            // Fan rotation follows the arc
            -30.0 + Double(position) * 15
        case .spin:
            // Spinning rotation
            Double(position) * 25 * (position % 2 == 0 ? 1 : -1)
        case .riffle:
            // Tilt during riffle
            position % 2 == 0 ? -15.0 : 15.0
        case .cascade:
            // Slight rotation during cascade
            Double(position) * 3 * (position % 2 == 0 ? 1 : -1)
        }
    }

    private func shuffleScale(for position: Int) -> CGFloat {
        switch shufflePhase {
        case .idle, .settle:
            1.0
        case .rise:
            1.02
        case .fan:
            0.88 + CGFloat(position) * 0.02
        case .spin:
            0.85
        case .riffle:
            0.9
        case .cascade:
            0.95 + CGFloat(position) * 0.01
        }
    }

    private func shuffle3DRotation(for position: Int) -> (x: Double, y: Double, z: Double) {
        switch shufflePhase {
        case .idle, .settle:
            (0, 0, 0)
        case .rise:
            (10, 0, 0)
        case .fan:
            (15, Double(position) * 5, 0)
        case .spin:
            (0, Double(position) * 20, Double(position) * 10)
        case .riffle:
            (position % 2 == 0 ? 20 : -20, 0, 0)
        case .cascade:
            (5, 0, 0)
        }
    }

    // MARK: - Drag Gesture with Enhanced Haptics

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Start haptic on first drag
                if !isDragging {
                    HapticManager.light()
                }
                isDragging = true
                dragOffset = value.translation

                // Threshold crossing haptic
                if abs(value.translation.width) > swipeThreshold, !crossedThreshold {
                    HapticManager.medium()
                    crossedThreshold = true
                } else if abs(value.translation.width) < swipeThreshold, crossedThreshold {
                    // Reset if they pull back
                    crossedThreshold = false
                }
            }
            .onEnded { value in
                isDragging = false
                crossedThreshold = false
                handleDragEnd(translation: value.translation, velocity: value.predictedEndTranslation)
            }
    }

    private func handleDragEnd(translation: CGSize, velocity: CGSize) {
        let velocityThreshold: CGFloat = 300
        let shouldSwipe = abs(translation.width) > swipeThreshold || abs(velocity.width) > velocityThreshold

        if shouldSwipe {
            swipeCard(direction: translation.width > 0 ? .right : .left)
        } else {
            // Snap back with overshoot
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                dragOffset = .zero
            }
        }
    }

    private enum SwipeDirection { case left, right }

    private func swipeCard(direction: SwipeDirection) {
        let currentChallenge = shuffledChallenges[currentIndex]
        let offscreenX: CGFloat = direction == .right ? 500 : -500

        // Trigger callback
        switch direction {
        case .right:
            HapticManager.success()
            onSwipeRight?(currentChallenge)
        case .left:
            HapticManager.light()
            onSwipeLeft?(currentChallenge)
        }

        // Animate card off screen with rotation
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            dragOffset = CGSize(width: offscreenX, height: direction == .right ? -30 : 30)
        }

        // Bring next card forward
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                currentIndex = (currentIndex + 1) % shuffledChallenges.count
                dragOffset = .zero
            }
        }
    }

    // MARK: - Cinematic Shuffle Animation

    private func shuffle() {
        guard !isShuffling, !shuffledChallenges.isEmpty else { return }
        isShuffling = true
        showSparkles = true

        // Phase 1: Rise - cards lift up
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            shufflePhase = .rise
        }
        HapticManager.light()

        // Phase 2: Fan - cards fan out in arc
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                shufflePhase = .fan
            }
            HapticManager.light()
        }

        // Phase 3: Spin - cards spiral
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                shufflePhase = .spin
            }
            HapticManager.medium()
        }

        // Phase 4: Riffle - interleave shuffle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                shufflePhase = .riffle
            }
            shuffledChallenges.shuffle()
            HapticManager.medium()
        }

        // Phase 5: Cascade - cards return
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            currentIndex = 0
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                shufflePhase = .cascade
            }
            HapticManager.light()
        }

        // Phase 6: Settle - final bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                shufflePhase = .settle
            }
        }

        // Phase 7: Idle - done
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                shufflePhase = .idle
            }
            showSparkles = false
            isShuffling = false
            HapticManager.success()
        }
    }

    // MARK: - Dynamic Shadow Color

    private var shadowColorForDrag: Color {
        if dragOffset.width > 50 {
            return Color.DesignSystem.brandGreen
        } else if dragOffset.width < -50 {
            return Color.DesignSystem.error
        }
        return Color.black.opacity(0.3)
    }
}

// MARK: - Deck Challenge Card

struct DeckChallengeCard: View {
    @Environment(\.translationService) private var t
    let challenge: Challenge
    let userStatus: ChallengeUserStatus
    let isFaceUp: Bool
    var cardSize = CGSize(width: 350.0, height: 540.0)

    var body: some View {
        Group {
            if isFaceUp { faceUpCard } else { faceDownCard }
        }
        .frame(width: cardSize.width, height: cardSize.height)
    }

    private var faceUpCard: some View {
        ZStack(alignment: .bottom) {
            // Full background image
            KFImage(challenge.imageUrl)
                .placeholder {
                    // Gradient placeholder while loading
                    LinearGradient(
                        colors: [difficultyColor.opacity(0.6), difficultyColor.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    )
                    .overlay(
                        Image(systemName: challenge.challengeDifficulty.icon)
                            .font(.system(size: 60, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5)),
                    )
                }
                .resizable()
                .aspectRatio(contentMode: ContentMode.fill)
                .frame(width: cardSize.width, height: cardSize.height)
                .clipped()

            // Top badges overlay
            VStack {
                HStack {
                    difficultyBadge
                    Spacer()
                    statusBadge
                }
                .padding(Spacing.md)

                Spacer()
            }

            // Glassmorphic bottom bar
            VStack(spacing: Spacing.sm) {
                Text(challenge.displayTitle)
                    .font(.DesignSystem.headlineMedium)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                Text(challenge.displayDescription)
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if challenge.isTranslated {
                    TranslatedIndicator()
                        .padding(.top, 2)
                }

                statsRow
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    // Blur effect
                    Rectangle()
                        #if !SKIP
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                        #else
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                        #endif

                    // Gradient overlay for depth
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.4),
                            Color.black.opacity(0.6),
                        ],
                        startPoint: .top,
                        endPoint: .bottom,
                    )

                    // Top highlight
                    VStack {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.2), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom,
                                ),
                            )
                            .frame(height: 1.0)
                        Spacer()
                    }
                },
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl))
        .overlay(cardBorder)
    }

    private var faceDownCard: some View {
        ZStack {
            cardBackPattern

            VStack(spacing: Spacing.sm) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.DesignSystem.medalGold, Color.DesignSystem.accentOrange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .shadow(color: Color.DesignSystem.medalGold.opacity(0.5), radius: 10)

                Text(t.t("challenge.card_title"))
                    .font(.DesignSystem.headlineSmall)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .background(cardBackBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl))
        .overlay(cardBorder)
    }

    private var difficultyBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: challenge.challengeDifficulty.icon)
                .font(.caption)
            Text(challenge.challengeDifficulty.localizedDisplayName(using: t))
                .font(.DesignSystem.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(difficultyGradient)
        .clipShape(Capsule())
        .shadow(color: difficultyColor.opacity(0.4), radius: 4, y: 2)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch userStatus {
        case .notJoined:
            Text(t.t("challenge.status.new"))
                .font(.DesignSystem.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(Color.DesignSystem.brandGreen)
                .clipShape(Capsule())
                .shadow(color: Color.DesignSystem.brandGreen.opacity(0.4), radius: 4, y: 2)
        case .accepted:
            HStack(spacing: 2) {
                Image(systemName: "clock.fill").font(.caption2)
                Text(t.t("challenge.status.active"))
            }
            .font(.DesignSystem.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(Color.DesignSystem.accentOrange)
            .clipShape(Capsule())
            .shadow(color: Color.DesignSystem.accentOrange.opacity(0.4), radius: 4, y: 2)
        case .completed:
            HStack(spacing: 2) {
                Image(systemName: "checkmark").font(.caption2)
                Text(t.t("challenge.status.done"))
            }
            .font(.DesignSystem.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(Color.DesignSystem.brandGreen)
            .clipShape(Capsule())
            .shadow(color: Color.DesignSystem.brandGreen.opacity(0.4), radius: 4, y: 2)
        case .rejected:
            EmptyView()
        }
    }

    private var statsRow: some View {
        HStack(spacing: Spacing.lg) {
            StatItem(
                icon: "star.fill",
                value: challenge.localizedFormattedScore(using: t),
                color: .DesignSystem.accentYellow,
                textColor: .white.opacity(0.9),
            )
            StatItem(
                icon: "person.2.fill",
                value: "\(challenge.challengedPeople)",
                color: .DesignSystem.brandBlue,
                textColor: .white.opacity(0.9),
            )
            StatItem(
                icon: "heart.fill",
                value: "\(challenge.challengeLikesCounter)",
                color: .DesignSystem.error,
                textColor: .white.opacity(0.9),
            )
        }
        .font(.DesignSystem.caption)
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CornerRadius.xl).fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .fill(
                    LinearGradient(
                        colors: [difficultyColor.opacity(0.12), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.02), Color.clear],
                        startPoint: .top,
                        endPoint: .center,
                    ),
                )
        }
    }

    private var cardBackBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color.DesignSystem.brandGreen.opacity(0.85), Color.DesignSystem.brandBlue.opacity(0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
            Color.clear.background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */.opacity(0.3))
        }
    }

    private var cardBackPattern: some View {
        GeometryReader { geometry in
            Path { path in
                let spacing: CGFloat = 30
                let size: CGFloat = 15

                for row in stride(from: CGFloat(0), to: geometry.size.height, by: spacing) {
                    for col in stride(from: CGFloat(0), to: geometry.size.width, by: spacing) {
                        let offset = Int(row / spacing) % 2 == 0 ? CGFloat(0) : spacing / 2
                        let x = col + offset
                        let y = row

                        path.move(to: CGPoint(x: x, y: y - size / 2))
                        path.addLine(to: CGPoint(x: x + size / 2, y: y))
                        path.addLine(to: CGPoint(x: x, y: y + size / 2))
                        path.addLine(to: CGPoint(x: x - size / 2, y: y))
                        path.closeSubpath()
                    }
                }
            }
            .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: CornerRadius.xl)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.35), Color.DesignSystem.glassBorder, Color.white.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                ),
                lineWidth: 1.5,
            )
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

// MARK: - Stat Item

private struct StatItem: View {
    let icon: String
    let value: String
    let color: Color
    var textColor: Color = .DesignSystem.textSecondary

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .foregroundColor(textColor)
        }
    }
}

// MARK: - Shuffle Sparkles

private struct ShuffleSparkles: View {
    @State private var particles: [SparkleParticle] = []
    private let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        #if !SKIP
        Canvas { context, size in
            for particle in particles {
                let rect = CGRect(
                    x: particle.x - particle.size / 2,
                    y: particle.y - particle.size / 2,
                    width: particle.size,
                    height: particle.size,
                )

                context.opacity = particle.opacity
                context.fill(
                    Circle().path(in: rect),
                    with: .color(particle.color),
                )

                // Add glow
                let glowRect = rect.insetBy(dx: -particle.size * 0.5, dy: -particle.size * 0.5)
                context.opacity = particle.opacity * 0.3
                context.fill(
                    Circle().path(in: glowRect),
                    with: .color(particle.color),
                )
            }
        }
        .onAppear {
            for _ in 0 ..< 25 {
                addParticle()
            }
        }
        .onReceive(timer) { _ in
            if particles.count < 40, Bool.random() {
                addParticle()
            }

            particles = particles.compactMap { particle in
                var p = particle
                p.x += p.velocityX
                p.y += p.velocityY
                p.velocityY += 0.08
                p.opacity -= 0.012
                p.size *= 0.985

                if p.opacity <= 0 { return nil }
                return p
            }
        }
        #endif
    }

    private func addParticle() {
        let colors: [Color] = [
            .DesignSystem.brandGreen,
            .DesignSystem.brandBlue,
            .DesignSystem.accentYellow,
            .DesignSystem.accentOrange,
            .white,
        ]

        let particle = SparkleParticle(
            x: CGFloat.random(in: 80 ... 270),
            y: CGFloat.random(in: 80 ... 280),
            velocityX: CGFloat.random(in: -2.5 ... 2.5),
            velocityY: CGFloat.random(in: -4 ... -1),
            size: CGFloat.random(in: 4 ... 12),
            opacity: 1.0,
            color: colors.randomElement() ?? .white,
        )
        particles.append(particle)
    }
}

private struct SparkleParticle {
    var x: CGFloat
    var y: CGFloat
    var velocityX: CGFloat
    var velocityY: CGFloat
    var size: CGFloat
    var opacity: Double
    var color: Color
}

// MARK: - Enhanced Shuffle Button

struct ShuffleButton: View {
    @Environment(\.translationService) private var t
    let action: () -> Void
    @State private var isAnimating = false
    @State private var rotationDegrees: Double = 0
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        Button(action: {
            guard !isAnimating else { return }
            isAnimating = true

            // Multi-rotation effect
            withAnimation(.interpolatingSpring(stiffness: 150, damping: 18)) {
                rotationDegrees += 1080
            }

            // Shimmer animation
            withAnimation(.linear(duration: 0.8)) {
                shimmerOffset = 200
            }

            action()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                isAnimating = false
                shimmerOffset = -200
            }
        }) {
            ZStack {
                // Background glow pulse
                if isAnimating {
                    Capsule()
                        .fill(
                            RadialGradient(
                                colors: [Color.DesignSystem.accentPurple.opacity(0.4), Color.clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 100,
                            ),
                        )
                        .frame(width: 180.0, height: 70)
                        .blur(radius: 15)
                        .scaleEffect(isAnimating ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isAnimating)
                }

                HStack(spacing: Spacing.sm) {
                    ZStack {
                        // Spinning glow
                        if isAnimating {
                            Circle()
                                .fill(Color.white.opacity(0.4))
                                .frame(width: 28.0, height: 28)
                                .blur(radius: 6)
                        }

                        Image(systemName: "shuffle")
                            .rotationEffect(.degrees(rotationDegrees))
                            .scaleEffect(isAnimating ? 1.25 : 1.0)
                    }

                    Text(t.t("challenge.action.shuffle"))
                }
                .font(.DesignSystem.labelMedium)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.md)
                .background(
                    ZStack {
                        // Base gradient
                        LinearGradient(
                            colors: isAnimating
                                ? [.DesignSystem.accentPurple, .DesignSystem.brandBlue, .DesignSystem.brandGreen]
                                : [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                            startPoint: .leading,
                            endPoint: .trailing,
                        )

                        // Shimmer overlay
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.35), .clear],
                            startPoint: .leading,
                            endPoint: .trailing,
                        )
                        .frame(width: 80.0)
                        .offset(x: shimmerOffset)
                        .mask(Capsule())
                    },
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                            lineWidth: 1.5,
                        ),
                )
                .shadow(
                    color: (isAnimating ? Color.DesignSystem.accentPurple : Color.DesignSystem.brandGreen).opacity(0.6),
                    radius: isAnimating ? 20 : 10,
                    y: isAnimating ? 8 : 4,
                )
                .scaleEffect(isAnimating ? 1.08 : 1.0)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isAnimating)
        .pressAnimation()
        .disabled(isAnimating)
    }
}

// MARK: - Card Deck Header

struct CardDeckHeader: View {
    @Environment(\.translationService) private var t
    let totalChallenges: Int
    let currentIndex: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(t.t("challenge.pick_title"))
                    .font(.DesignSystem.headlineLarge)
                    .fontWeight(.bold)

                Text(t.t("challenge.pick_subtitle"))
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            Spacer()

            // Card counter with animation
            Text("\(currentIndex + 1)/\(totalChallenges)")
                .font(.DesignSystem.labelMedium)
                .fontWeight(.semibold)
                .foregroundColor(.DesignSystem.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                #if !SKIP
                .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .background(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .clipShape(Capsule())
                #if !SKIP
                .contentTransition(.numericText())
                #endif
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentIndex)
        }
    }
}

#if DEBUG
    #Preview("Challenge Card Deck") {
        GeometryReader { geometry in
            ZStack {
                Color.backgroundGradient.ignoresSafeArea()

                VStack(spacing: Spacing.lg) {
                    CardDeckHeader(totalChallenges: 3, currentIndex: 0)
                        .padding(.horizontal)

                    ChallengeCardDeck(
                        challenges: Challenge.sampleChallenges,
                        userStatusProvider: { _ in .notJoined },
                        onChallengeSelected: { _ in },
                        availableSize: CGSize(
                            width: geometry.size.width - Spacing.md * 2,
                            height: geometry.size.height - 200,
                        ),
                    )

                    ShuffleButton {}
                }
                .padding()
            }
        }
        .preferredColorScheme(.dark)
    }
#endif

#endif
