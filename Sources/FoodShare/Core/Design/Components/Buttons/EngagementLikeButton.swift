//
//  EngagementLikeButton.swift
//  Foodshare
//
//  Unified like button for all engagement domains (Posts, Forums, Challenges)
//  Instagram/Twitter-style animations with particle bursts & heart pop effects
//  ProMotion 120Hz optimized with interpolating springs
//


#if !SKIP
import SwiftUI

#if !SKIP

// MARK: - Engagement Domain

/// Represents the different content domains that support likes
enum EngagementDomain: Sendable {
    case post(id: Int)
    case forum(id: Int)
    case challenge(id: Int)

    var id: Int {
        switch self {
        case let .post(id), let .forum(id), let .challenge(id):
            id
        }
    }

    var accessibilityContext: String {
        switch self {
        case .post: "post"
        case .forum: "forum post"
        case .challenge: "challenge"
        }
    }
}

// MARK: - Engagement Like Button

/// Instagram/Twitter-style animated heart button with particle burst effects
/// Features optimistic updates, 120Hz animations, and delightful micro-interactions
struct EngagementLikeButton: View {
    // MARK: - Properties

    let domain: EngagementDomain
    let initialLikeCount: Int
    let initialIsLiked: Bool
    let size: Size
    let showCount: Bool
    var onToggle: ((Bool, Int) -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - State

    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var isAnimating = false
    @State private var isLoading = false
    @State private var showParticles = false
    @State private var ringScale: CGFloat = 0
    @State private var ringOpacity: Double = 0
    @State private var heartScale: CGFloat = 1.0
    @State private var bounceOffset: CGFloat = 0

    // MARK: - Size

    enum Size {
        case small // Compact
        case medium // Default - matches GlassStatPill
        case large // Larger touch target

        var iconSize: CGFloat {
            switch self {
            case .small: 10
            case .medium: 12 // Match GlassStatPill
            case .large: 16
            }
        }

        var font: Font {
            switch self {
            case .small: .DesignSystem.captionSmall
            case .medium: .DesignSystem.bodyMedium // Match GlassStatPill
            case .large: .DesignSystem.bodyLarge
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: Spacing.xs
            case .medium: Spacing.sm // Match GlassStatPill
            case .large: Spacing.md
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: Spacing.xxs
            case .medium: Spacing.xs // Match GlassStatPill
            case .large: Spacing.sm
            }
        }

        var particleSize: CGFloat {
            switch self {
            case .small: 3
            case .medium: 4
            case .large: 5
            }
        }

        var ringSize: CGFloat {
            switch self {
            case .small: 24
            case .medium: 32
            case .large: 44
            }
        }
    }

    // MARK: - Initialization

    init(
        domain: EngagementDomain,
        initialLikeCount: Int = 0,
        initialIsLiked: Bool = false,
        size: Size = .medium,
        showCount: Bool = true,
        onToggle: ((Bool, Int) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
    ) {
        self.domain = domain
        self.initialLikeCount = initialLikeCount
        self.initialIsLiked = initialIsLiked
        self.size = size
        self.showCount = showCount
        self.onToggle = onToggle
        self.onError = onError

        _isLiked = State(initialValue: initialIsLiked)
        _likeCount = State(initialValue: initialLikeCount)
    }

    // MARK: - Body

    var body: some View {
        Button(action: toggleLike) {
            HStack(spacing: Spacing.xs) {
                // Heart with particle effects
                ZStack {
                    // Expanding ring effect
                    Circle()
                        .stroke(Color.DesignSystem.brandPink.opacity(ringOpacity), lineWidth: 1.5)
                        .frame(width: size.ringSize * ringScale, height: size.ringSize * ringScale)

                    // Particle burst
                    if showParticles {
                        HeartParticleBurstView(
                            particleCount: 6,
                            particleSize: size.particleSize,
                            burstRadius: size.iconSize * 1.5,
                            colors: [.DesignSystem.brandPink, .DesignSystem.error, .pink, .red.opacity(0.8)],
                        )
                    }

                    // Heart icon with beautiful animation
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: size.iconSize, weight: .medium))
                        .foregroundColor(isLiked ? .DesignSystem.brandPink : .DesignSystem.textSecondary)
                        .scaleEffect(heartScale)
                        .offset(y: bounceOffset)
                        #if !SKIP
                        .symbolEffect(.bounce, value: isLiked)
                        #endif
                }
                .frame(width: size.iconSize + 4, height: size.iconSize + 4)

                // Like count (matches GlassStatPill text style)
                if showCount {
                    Text(formattedCount)
                        .font(size.font)
                        .fontWeight(.semibold)
                        .foregroundColor(isLiked ? .DesignSystem.brandPink : .DesignSystem.text)
                        #if !SKIP
                        .contentTransition(.numericText())
                        #endif
                        .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: likeCount)
                }
            }
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(backgroundView)
        }
        .buttonStyle(HeartButtonStyle())
        .disabled(isLoading)
        .accessibilityLabel(isLiked ? "Unlike \(domain.accessibilityContext)" : "Like \(domain.accessibilityContext)")
        .accessibilityValue("\(likeCount) likes")
    }

    // MARK: - Subviews

    private var heartGradient: some ShapeStyle {
        if isLiked {
            AnyShapeStyle(
                LinearGradient(
                    colors: [.DesignSystem.brandPink, .red.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                ),
            )
        } else {
            AnyShapeStyle(Color.DesignSystem.textSecondary)
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        if isLiked {
            Capsule()
                .fill(Color.DesignSystem.brandPink.opacity(0.12))
                .overlay(
                    Capsule()
                        .stroke(Color.DesignSystem.brandPink.opacity(0.25), lineWidth: 1),
                )
        } else {
            // Match GlassStatPill background exactly
            Capsule()
                .fill(Color.DesignSystem.glassBackground)
        }
    }

    private var formattedCount: String {
        if likeCount >= 1_000_000 {
            return String(format: "%.1fM", Double(likeCount) / 1_000_000)
        } else if likeCount >= 1000 {
            return String(format: "%.1fK", Double(likeCount) / 1000)
        }
        return "\(likeCount)"
    }

    // MARK: - Actions

    private func toggleLike() {
        guard !isLoading else { return }

        // Optimistic update
        let wasLiked = isLiked
        let previousCount = likeCount

        isLiked.toggle()
        likeCount += isLiked ? 1 : -1

        // Trigger beautiful animation sequence
        if isLiked {
            triggerLikeAnimation()
        } else {
            triggerUnlikeAnimation()
        }

        // Perform actual toggle
        isLoading = true

        Task {
            do {
                let result = try await performToggle()

                await MainActor.run {
                    // Update with server response
                    isLiked = result.isLiked
                    likeCount = result.likeCount
                    isLoading = false

                    onToggle?(result.isLiked, result.likeCount)
                }
            } catch {
                await MainActor.run {
                    // Revert on error
                    isLiked = wasLiked
                    likeCount = previousCount
                    isLoading = false

                    HapticManager.error()
                    onError?(error)
                }
            }
        }
    }

    // MARK: - Animation Sequences

    private func triggerLikeAnimation() {
        // Strong haptic for like
        HapticManager.success()

        // Phase 1: Quick scale up with bounce
        withAnimation(.interpolatingSpring(stiffness: 400, damping: 8)) {
            heartScale = 1.4
            bounceOffset = -4
        }

        // Phase 2: Show ring burst
        withAnimation(.easeOut(duration: 0.15)) {
            ringScale = 0.6
            ringOpacity = 1.0
        }

        Task { @MainActor in
            // Phase 3: Particles appear
            #if SKIP
            try? await Task.sleep(nanoseconds: UInt64(50 * 1_000_000))
            #else
            try? await Task.sleep(for: .milliseconds(50))
            #endif
            showParticles = true

            // Phase 4: Ring expands and fades
            #if SKIP
            try? await Task.sleep(nanoseconds: UInt64(50 * 1_000_000))
            #else
            try? await Task.sleep(for: .milliseconds(50))
            #endif
            withAnimation(.easeOut(duration: 0.4)) {
                ringScale = 1.5
                ringOpacity = 0
            }

            // Phase 5: Heart bounces back with overshoot
            #if SKIP
            try? await Task.sleep(nanoseconds: UInt64(20 * 1_000_000))
            #else
            try? await Task.sleep(for: .milliseconds(20))
            #endif
            withAnimation(.interpolatingSpring(stiffness: 350, damping: 12)) {
                heartScale = 0.85
                bounceOffset = 2
            }

            // Phase 6: Settle to normal
            #if SKIP
            try? await Task.sleep(nanoseconds: UInt64(100 * 1_000_000))
            #else
            try? await Task.sleep(for: .milliseconds(100))
            #endif
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 14)) {
                heartScale = 1.0
                bounceOffset = 0
            }

            // Phase 7: Hide particles
            #if SKIP
            try? await Task.sleep(nanoseconds: UInt64(280 * 1_000_000))
            #else
            try? await Task.sleep(for: .milliseconds(280))
            #endif
            showParticles = false
            ringScale = 0
        }
    }

    private func triggerUnlikeAnimation() {
        // Light haptic for unlike
        HapticManager.light()

        // Subtle shrink and bounce
        withAnimation(.interpolatingSpring(stiffness: 400, damping: 15)) {
            heartScale = 0.8
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 12)) {
                heartScale = 1.0
            }
        }
    }

    /// Performs the toggle operation on the appropriate service
    private func performToggle() async throws -> (isLiked: Bool, likeCount: Int) {
        switch domain {
        case let .post(id):
            try await PostEngagementService.shared.toggleLike(postId: id)
        case let .forum(id):
            try await ForumEngagementService.shared.toggleLike(forumId: id)
        case let .challenge(id):
            try await ChallengeEngagementService.shared.toggleLike(challengeId: id)
        }
    }
}

// MARK: - Heart Particle Burst View

/// Instagram-style particle explosion effect for like button
struct HeartParticleBurstView: View {
    let particleCount: Int
    let particleSize: CGFloat
    let burstRadius: CGFloat
    let colors: [Color]

    @State private var particles: [ParticleState] = []
    @State private var hasAnimated = false

    struct ParticleState: Identifiable {
        let id = UUID()
        var angle: Double
        var distance: CGFloat
        var opacity: Double
        var scale: CGFloat
        var color: Color
        var shape: ParticleShape
    }

    enum ParticleShape {
        case heart
        case circle
        case star
    }

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                particleView(for: particle)
                    .scaleEffect(particle.scale)
                    .opacity(particle.opacity)
                    .offset(
                        x: cos(particle.angle) * particle.distance,
                        y: sin(particle.angle) * particle.distance,
                    )
            }
        }
        .onAppear {
            if !hasAnimated {
                createAndAnimateParticles()
                hasAnimated = true
            }
        }
    }

    @ViewBuilder
    private func particleView(for particle: ParticleState) -> some View {
        switch particle.shape {
        case .heart:
            Image(systemName: "heart.fill")
                .font(.system(size: particleSize))
                .foregroundColor(particle.color)
        case .circle:
            Circle()
                .fill(particle.color)
                .frame(width: particleSize, height: particleSize)
        case .star:
            Image(systemName: "sparkle")
                .font(.system(size: particleSize * 0.8))
                .foregroundColor(particle.color)
        }
    }

    private func createAndAnimateParticles() {
        // Create particles
        let angleStep = (2 * Double.pi) / Double(particleCount)
        let shapes: [ParticleShape] = [.heart, .circle, .star, .circle]

        particles = (0 ..< particleCount).map { i in
            let baseAngle = angleStep * Double(i)
            let angleVariation = Double.random(in: -0.3 ... 0.3)
            return ParticleState(
                angle: baseAngle + angleVariation,
                distance: 0,
                opacity: 1.0,
                scale: 0.3,
                color: colors[i % colors.count],
                shape: shapes[i % shapes.count],
            )
        }

        // Animate outward burst
        withAnimation(.interpolatingSpring(stiffness: 200, damping: 12)) {
            for i in particles.indices {
                particles[i].distance = burstRadius + CGFloat.random(in: -5 ... 10)
                particles[i].scale = CGFloat.random(in: 0.8 ... 1.2)
            }
        }

        // Fade out
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeOut(duration: 0.3)) {
                for i in particles.indices {
                    particles[i].opacity = 0
                    particles[i].distance = burstRadius * 1.5
                    particles[i].scale = 0.2
                }
            }
        }
    }
}

// MARK: - Heart Button Style

/// Custom button style with smooth press animation
struct HeartButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.interpolatingSpring(stiffness: 400, damping: 15), value: configuration.isPressed)
    }
}

// MARK: - Compact Engagement Like Button

/// Minimal like button for tight spaces (icon only) with beautiful animations
struct CompactEngagementLikeButton: View {
    let domain: EngagementDomain
    let initialIsLiked: Bool
    var onToggle: ((Bool) -> Void)?
    var onError: ((Error) -> Void)?

    @State private var isLiked: Bool
    @State private var isAnimating = false
    @State private var showParticles = false
    @State private var heartScale: CGFloat = 1.0
    @State private var ringScale: CGFloat = 0
    @State private var ringOpacity: Double = 0

    init(
        domain: EngagementDomain,
        initialIsLiked: Bool = false,
        onToggle: ((Bool) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
    ) {
        self.domain = domain
        self.initialIsLiked = initialIsLiked
        self.onToggle = onToggle
        self.onError = onError
        _isLiked = State(initialValue: initialIsLiked)
    }

    var body: some View {
        Button(action: toggleLike) {
            ZStack {
                // Expanding ring
                Circle()
                    .stroke(Color.DesignSystem.brandPink.opacity(ringOpacity), lineWidth: 2)
                    .frame(width: 40.0 * ringScale, height: 40 * ringScale)

                // Particles
                if showParticles {
                    HeartParticleBurstView(
                        particleCount: 6,
                        particleSize: 4,
                        burstRadius: 20,
                        colors: [.DesignSystem.brandPink, .red, .pink],
                    )
                }

                // Heart
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(
                        isLiked
                            ? AnyShapeStyle(LinearGradient(
                                colors: [.DesignSystem.brandPink, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ))
                            : AnyShapeStyle(Color.DesignSystem.textSecondary),
                    )
                    .scaleEffect(heartScale)
            }
            .frame(width: 44.0, height: 44)
        }
        .buttonStyle(HeartButtonStyle())
        .accessibilityLabel(isLiked ? "Unlike" : "Like")
    }

    private func toggleLike() {
        let wasLiked = isLiked
        isLiked.toggle()

        if isLiked {
            // Like animation
            HapticManager.success()

            withAnimation(.interpolatingSpring(stiffness: 400, damping: 8)) {
                heartScale = 1.35
            }

            withAnimation(.easeOut(duration: 0.15)) {
                ringScale = 0.6
                ringOpacity = 1.0
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                showParticles = true

                try? await Task.sleep(for: .milliseconds(50))
                withAnimation(.easeOut(duration: 0.4)) {
                    ringScale = 1.5
                    ringOpacity = 0
                }

                try? await Task.sleep(for: .milliseconds(50))
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 12)) {
                    heartScale = 1.0
                }

                try? await Task.sleep(for: .milliseconds(350))
                showParticles = false
                ringScale = 0
            }
        } else {
            // Unlike animation
            HapticManager.light()

            withAnimation(.interpolatingSpring(stiffness: 400, damping: 15)) {
                heartScale = 0.8
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 12)) {
                    heartScale = 1.0
                }
            }
        }

        Task {
            do {
                let result = try await performToggle()
                await MainActor.run {
                    isLiked = result.isLiked
                    onToggle?(result.isLiked)
                }
            } catch {
                await MainActor.run {
                    isLiked = wasLiked
                    HapticManager.error()
                    onError?(error)
                }
            }
        }
    }

    private func performToggle() async throws -> (isLiked: Bool, likeCount: Int) {
        switch domain {
        case let .post(id):
            try await PostEngagementService.shared.toggleLike(postId: id)
        case let .forum(id):
            try await ForumEngagementService.shared.toggleLike(forumId: id)
        case let .challenge(id):
            try await ChallengeEngagementService.shared.toggleLike(challengeId: id)
        }
    }
}

// MARK: - Double Tap Like Overlay

/// Instagram-style double-tap to like overlay for images
struct DoubleTapLikeOverlay: View {
    @Binding var isLiked: Bool
    @State private var showHeart = false
    @State private var heartScale: CGFloat = 0
    @State private var heartOpacity: Double = 0

    let onLike: () -> Void

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                if !isLiked {
                    isLiked = true
                    onLike()
                }
                triggerHeartAnimation()
            }
            .overlay {
                if showHeart {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 80, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .DesignSystem.brandPink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .scaleEffect(heartScale)
                        .opacity(heartOpacity)
                        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                }
            }
    }

    private func triggerHeartAnimation() {
        showHeart = true
        HapticManager.success()

        // Bounce in
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 10)) {
            heartScale = 1.2
            heartOpacity = 1.0
        }

        Task { @MainActor in
            // Settle
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 15)) {
                heartScale = 1.0
            }

            // Fade out
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeOut(duration: 0.3)) {
                heartOpacity = 0
                heartScale = 1.3
            }

            try? await Task.sleep(for: .milliseconds(300))
            showHeart = false
            heartScale = 0
        }
    }
}

// MARK: - Type Aliases for Backward Compatibility

/// Type alias for Posts - maintains backward compatibility
typealias LikeButton = PostLikeButtonWrapper

/// Type alias for Forums - maintains backward compatibility
typealias ForumLikeButton = ForumLikeButtonWrapper

/// Type alias for Challenges - maintains backward compatibility
typealias ChallengeLikeButton = ChallengeLikeButtonWrapper

// MARK: - Backward Compatibility Wrappers

/// Wrapper to maintain LikeButton API compatibility
struct PostLikeButtonWrapper: View {
    let postId: Int
    let initialLikeCount: Int
    let initialIsLiked: Bool
    let size: EngagementLikeButton.Size
    let showCount: Bool
    var onToggle: ((Bool, Int) -> Void)?

    init(
        postId: Int,
        initialLikeCount: Int = 0,
        initialIsLiked: Bool = false,
        size: EngagementLikeButton.Size = .medium,
        showCount: Bool = true,
        onToggle: ((Bool, Int) -> Void)? = nil,
    ) {
        self.postId = postId
        self.initialLikeCount = initialLikeCount
        self.initialIsLiked = initialIsLiked
        self.size = size
        self.showCount = showCount
        self.onToggle = onToggle
    }

    var body: some View {
        EngagementLikeButton(
            domain: .post(id: postId),
            initialLikeCount: initialLikeCount,
            initialIsLiked: initialIsLiked,
            size: size,
            showCount: showCount,
            onToggle: onToggle,
        )
    }
}

/// Wrapper to maintain ForumLikeButton API compatibility
struct ForumLikeButtonWrapper: View {
    let forumId: Int
    let initialLikeCount: Int
    let initialIsLiked: Bool
    let size: EngagementLikeButton.Size
    let showCount: Bool
    var onToggle: ((Bool, Int) -> Void)?

    init(
        forumId: Int,
        initialLikeCount: Int = 0,
        initialIsLiked: Bool = false,
        size: EngagementLikeButton.Size = .medium,
        showCount: Bool = true,
        onToggle: ((Bool, Int) -> Void)? = nil,
    ) {
        self.forumId = forumId
        self.initialLikeCount = initialLikeCount
        self.initialIsLiked = initialIsLiked
        self.size = size
        self.showCount = showCount
        self.onToggle = onToggle
    }

    var body: some View {
        EngagementLikeButton(
            domain: .forum(id: forumId),
            initialLikeCount: initialLikeCount,
            initialIsLiked: initialIsLiked,
            size: size,
            showCount: showCount,
            onToggle: onToggle,
        )
    }
}

/// Wrapper to maintain ChallengeLikeButton API compatibility
struct ChallengeLikeButtonWrapper: View {
    let challengeId: Int
    let initialLikeCount: Int
    let initialIsLiked: Bool
    let size: EngagementLikeButton.Size
    let showCount: Bool
    var onToggle: ((Bool, Int) -> Void)?

    init(
        challengeId: Int,
        initialLikeCount: Int = 0,
        initialIsLiked: Bool = false,
        size: EngagementLikeButton.Size = .medium,
        showCount: Bool = true,
        onToggle: ((Bool, Int) -> Void)? = nil,
    ) {
        self.challengeId = challengeId
        self.initialLikeCount = initialLikeCount
        self.initialIsLiked = initialIsLiked
        self.size = size
        self.showCount = showCount
        self.onToggle = onToggle
    }

    var body: some View {
        EngagementLikeButton(
            domain: .challenge(id: challengeId),
            initialLikeCount: initialLikeCount,
            initialIsLiked: initialIsLiked,
            size: size,
            showCount: showCount,
            onToggle: onToggle,
        )
    }
}

// MARK: - Compact Button Wrappers

/// Wrapper for backward compatibility with CompactLikeButton
struct CompactLikeButton: View {
    let postId: Int
    let initialIsLiked: Bool
    var onToggle: ((Bool) -> Void)?

    init(postId: Int, initialIsLiked: Bool = false, onToggle: ((Bool) -> Void)? = nil) {
        self.postId = postId
        self.initialIsLiked = initialIsLiked
        self.onToggle = onToggle
    }

    var body: some View {
        CompactEngagementLikeButton(
            domain: .post(id: postId),
            initialIsLiked: initialIsLiked,
            onToggle: onToggle,
        )
    }
}

/// Wrapper for backward compatibility with CompactForumLikeButton
struct CompactForumLikeButton: View {
    let forumId: Int
    let initialIsLiked: Bool
    var onToggle: ((Bool) -> Void)?

    init(forumId: Int, initialIsLiked: Bool = false, onToggle: ((Bool) -> Void)? = nil) {
        self.forumId = forumId
        self.initialIsLiked = initialIsLiked
        self.onToggle = onToggle
    }

    var body: some View {
        CompactEngagementLikeButton(
            domain: .forum(id: forumId),
            initialIsLiked: initialIsLiked,
            onToggle: onToggle,
        )
    }
}

/// Wrapper for backward compatibility with CompactChallengeLikeButton
struct CompactChallengeLikeButton: View {
    let challengeId: Int
    let initialIsLiked: Bool
    var onToggle: ((Bool) -> Void)?

    init(challengeId: Int, initialIsLiked: Bool = false, onToggle: ((Bool) -> Void)? = nil) {
        self.challengeId = challengeId
        self.initialIsLiked = initialIsLiked
        self.onToggle = onToggle
    }

    var body: some View {
        CompactEngagementLikeButton(
            domain: .challenge(id: challengeId),
            initialIsLiked: initialIsLiked,
            onToggle: onToggle,
        )
    }
}

// MARK: - Preview

#Preview("Engagement Like Buttons") {
    VStack(spacing: 32) {
        Text("Instagram-Style Like Buttons")
            .font(.headline)
            .foregroundColor(.white)

        HStack(spacing: 24) {
            EngagementLikeButton(domain: .post(id: 1), initialLikeCount: 42, initialIsLiked: false, size: .small)
            EngagementLikeButton(domain: .forum(id: 2), initialLikeCount: 128, initialIsLiked: true, size: .medium)
            EngagementLikeButton(domain: .challenge(id: 3), initialLikeCount: 1500, initialIsLiked: false, size: .large)
        }

        Divider()
            .background(Color.white.opacity(0.2))

        Text("Compact Buttons")
            .font(.headline)
            .foregroundColor(.white)

        HStack(spacing: 24) {
            CompactEngagementLikeButton(domain: .post(id: 7), initialIsLiked: false)
            CompactEngagementLikeButton(domain: .forum(id: 8), initialIsLiked: true)
            CompactEngagementLikeButton(domain: .challenge(id: 9), initialIsLiked: false)
        }

        Divider()
            .background(Color.white.opacity(0.2))

        Text("Tap the hearts to see the animation!")
            .font(.caption)
            .foregroundColor(.white.opacity(0.6))
    }
    .padding()
    .background(Color.black)
}
#endif

#endif
