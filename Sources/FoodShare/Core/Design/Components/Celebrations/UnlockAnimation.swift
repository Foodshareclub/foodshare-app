//
//  UnlockAnimation.swift
//  FoodShare
//
//  Badge unlock animation with glowing progress ring completion.
//  Optimized for 120Hz ProMotion displays with GPU-accelerated rendering.
//
//  Features:
//  - Progress ring that fills to 100%
//  - Radiant glow effect on completion
//  - Badge icon reveal with scale animation
//  - Particle burst celebration
//  - Haptic feedback integration
//


#if !SKIP
import SwiftUI

#if !SKIP

// MARK: - Unlock State

enum UnlockAnimationState: Equatable, Sendable {
    case locked
    case unlocking(progress: Double)
    case unlocked
}

// MARK: - Unlock Configuration

struct UnlockAnimationConfiguration: Sendable {
    let size: CGFloat
    let ringWidth: CGFloat
    let glowRadius: CGFloat
    let primaryColor: Color
    let secondaryColor: Color
    let backgroundColor: Color
    let unlockDuration: TimeInterval
    let celebrationDuration: TimeInterval
    let showParticles: Bool
    let enableHaptics: Bool

    init(
        size: CGFloat = 80,
        ringWidth: CGFloat = 4,
        glowRadius: CGFloat = 15,
        primaryColor: Color = .DesignSystem.brandGreen,
        secondaryColor: Color = .DesignSystem.brandTeal,
        backgroundColor: Color = .DesignSystem.glassBackground,
        unlockDuration: TimeInterval = 0.8,
        celebrationDuration: TimeInterval = 1.5,
        showParticles: Bool = true,
        enableHaptics: Bool = true,
    ) {
        self.size = size
        self.ringWidth = ringWidth
        self.glowRadius = glowRadius
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.backgroundColor = backgroundColor
        self.unlockDuration = unlockDuration
        self.celebrationDuration = celebrationDuration
        self.showParticles = showParticles
        self.enableHaptics = enableHaptics
    }

    // Presets
    static let `default` = UnlockAnimationConfiguration()

    static let badge = UnlockAnimationConfiguration(
        size: 100,
        ringWidth: 5,
        glowRadius: 20,
    )

    static let achievement = UnlockAnimationConfiguration(
        size: 120,
        ringWidth: 6,
        glowRadius: 25,
        primaryColor: .yellow,
        secondaryColor: .orange,
        celebrationDuration: 2.0,
    )

    static let compact = UnlockAnimationConfiguration(
        size: 50,
        ringWidth: 3,
        glowRadius: 10,
        showParticles: false,
    )

    static let milestone = UnlockAnimationConfiguration(
        size: 140,
        ringWidth: 8,
        glowRadius: 30,
        primaryColor: .DesignSystem.brandPink,
        secondaryColor: .purple,
        celebrationDuration: 2.5,
    )
}

// MARK: - Unlock Animation View

struct UnlockAnimationView<Badge: View>: View {
    let state: UnlockAnimationState
    let config: UnlockAnimationConfiguration
    let badge: Badge
    let onUnlocked: (() -> Void)?

    @State private var progress: Double = 0
    @State private var glowIntensity: Double = 0
    @State private var badgeScale: CGFloat = 0.5
    @State private var badgeOpacity = 0.3
    @State private var ringRotation: Double = 0
    @State private var showParticleBurst = false
    @State private var pulseScale: CGFloat = 1.0

    init(
        state: UnlockAnimationState,
        config: UnlockAnimationConfiguration = .default,
        @ViewBuilder badge: () -> Badge,
        onUnlocked: (() -> Void)? = nil,
    ) {
        self.state = state
        self.config = config
        self.badge = badge()
        self.onUnlocked = onUnlocked
    }

    var body: some View {
        ZStack {
            // Glow effect (behind everything)
            glowLayer

            // Progress ring
            progressRing

            // Badge content
            badgeContent
        }
        .frame(width: config.size, height: config.size)
        .overlay {
            if showParticleBurst, config.showParticles {
                ParticleBurstView(
                    origin: CGPoint(x: config.size / 2, y: config.size / 2),
                    config: .celebration,
                    onComplete: { showParticleBurst = false },
                )
            }
        }
        .onChange(of: state, initial: true) { oldState, newState in
            handleStateChange(from: oldState, to: newState)
        }
    }

    // MARK: - Glow Layer

    private var glowLayer: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        config.primaryColor.opacity(glowIntensity * 0.8),
                        config.primaryColor.opacity(glowIntensity * 0.4),
                        config.primaryColor.opacity(0.0)
                    ],
                    center: .center,
                    startRadius: config.size * 0.3,
                    endRadius: config.size * 0.7 + config.glowRadius,
                ),
            )
            .frame(
                width: config.size + config.glowRadius * 2,
                height: config.size + config.glowRadius * 2,
            )
            .scaleEffect(pulseScale)
            .blur(radius: 2)
    }

    // MARK: - Progress Ring

    private var progressRing: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    config.backgroundColor.opacity(0.3),
                    style: StrokeStyle(lineWidth: config.ringWidth, lineCap: .round),
                )

            // Animated progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [config.primaryColor, config.secondaryColor, config.primaryColor],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270),
                    ),
                    style: StrokeStyle(lineWidth: config.ringWidth, lineCap: .round),
                )
                .rotationEffect(.degrees(-90 + ringRotation))

            // Glow overlay on ring
            if progress > 0 {
                Circle()
                    .trim(from: max(0.0, progress - 0.1), to: progress)
                    .stroke(
                        config.primaryColor,
                        style: StrokeStyle(lineWidth: config.ringWidth + 2, lineCap: .round),
                    )
                    .blur(radius: 4)
                    .rotationEffect(.degrees(-90 + ringRotation))
                    .opacity(glowIntensity)
            }
        }
        .frame(
            width: config.size - config.ringWidth,
            height: config.size - config.ringWidth,
        )
    }

    // MARK: - Badge Content

    private var badgeContent: some View {
        badge
            .frame(width: config.size * 0.6, height: config.size * 0.6)
            .scaleEffect(badgeScale)
            .opacity(badgeOpacity)
    }

    // MARK: - State Handling

    private func handleStateChange(from oldState: UnlockAnimationState, to newState: UnlockAnimationState) {
        switch newState {
        case .locked:
            resetToLocked()

        case let .unlocking(targetProgress):
            animateProgress(to: targetProgress)

        case .unlocked:
            if case .unlocking = oldState {
                completeUnlock()
            } else {
                // Direct transition to unlocked
                showUnlockedState()
            }
        }
    }

    private func resetToLocked() {
        withAnimation(ProMotionAnimation.smooth) {
            progress = 0
            glowIntensity = 0
            badgeScale = 0.5
            badgeOpacity = 0.3
            ringRotation = 0
            pulseScale = 1.0
        }
    }

    private func animateProgress(to targetProgress: Double) {
        withAnimation(ProMotionAnimation.smooth) {
            progress = targetProgress
            glowIntensity = targetProgress * 0.5
            badgeOpacity = 0.3 + targetProgress * 0.4
            badgeScale = 0.5 + targetProgress * 0.3
        }

        // Subtle ring rotation during progress
        withAnimation(ProMotionAnimation.gentle.repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
    }

    private func completeUnlock() {
        // Haptic feedback
        if config.enableHaptics {
            HapticManager.success()
        }

        // Fill to 100%
        withAnimation(ProMotionAnimation.celebration) {
            progress = 1.0
            glowIntensity = 1.0
        }

        // Badge reveal with bounce
        withAnimation(ProMotionAnimation.bouncy.delay(0.2)) {
            badgeScale = 1.0
            badgeOpacity = 1.0
        }

        // Glow pulse
        withAnimation(ProMotionAnimation.gentle.repeatCount(3, autoreverses: true)) {
            pulseScale = 1.15
        }

        // Particle burst
        if config.showParticles {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                showParticleBurst = true
            }
        }

        // Callback
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(config.unlockDuration))
            onUnlocked?()
        }

        // Settle to final state
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(config.celebrationDuration))
            withAnimation(ProMotionAnimation.smooth) {
                pulseScale = 1.0
                glowIntensity = 0.3 // Subtle persistent glow
            }
        }
    }

    private func showUnlockedState() {
        progress = 1.0
        glowIntensity = 0.3
        badgeScale = 1.0
        badgeOpacity = 1.0
    }
}

// MARK: - Convenience Initializers

extension UnlockAnimationView where Badge == Image {
    /// Create an unlock animation with a system icon
    init(
        state: UnlockAnimationState,
        systemIcon: String,
        config: UnlockAnimationConfiguration = .default,
        onUnlocked: (() -> Void)? = nil,
    ) {
        self.state = state
        self.config = config
        self.badge = Image(systemName: systemIcon)
        self.onUnlocked = onUnlocked
    }
}

// MARK: - Progress Ring Only

/// Simplified progress ring without badge content
struct UnlockProgressRing: View {
    let progress: Double
    let size: CGFloat
    let ringWidth: CGFloat
    let primaryColor: Color
    let secondaryColor: Color

    @State private var animatedProgress: Double = 0

    init(
        progress: Double,
        size: CGFloat = 60,
        ringWidth: CGFloat = 4,
        primaryColor: Color = .DesignSystem.brandGreen,
        secondaryColor: Color = .DesignSystem.brandTeal,
    ) {
        self.progress = progress
        self.size = size
        self.ringWidth = ringWidth
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
    }

    var body: some View {
        ZStack {
            // Background
            Circle()
                .stroke(Color.DesignSystem.glassBorder, lineWidth: ringWidth)

            // Progress
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [primaryColor, secondaryColor, primaryColor],
                        center: .center,
                    ),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round),
                )
                .rotationEffect(.degrees(-90))

            // Percentage text
            Text("\(Int(animatedProgress * 100))%")
                .font(.LiquidGlass.caption)
                .fontWeight(.bold)
                .foregroundStyle(Color.DesignSystem.text)
        }
        .frame(width: size, height: size)
        .onChange(of: progress, initial: true) { _, newProgress in
            withAnimation(ProMotionAnimation.smooth) {
                animatedProgress = newProgress
            }
        }
    }
}

// MARK: - Badge Unlock Cell

/// Complete badge unlock cell for lists
struct BadgeUnlockCell: View {
    let title: String
    let description: String
    let iconName: String
    let state: UnlockAnimationState
    let config: UnlockAnimationConfiguration

    init(
        title: String,
        description: String,
        iconName: String,
        state: UnlockAnimationState,
        config: UnlockAnimationConfiguration = .compact,
    ) {
        self.title = title
        self.description = description
        self.iconName = iconName
        self.state = state
        self.config = config
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            UnlockAnimationView(
                state: state,
                systemIcon: iconName,
                config: config,
            )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.LiquidGlass.labelLarge)
                    .foregroundStyle(Color.DesignSystem.text)

                Text(description)
                    .font(.LiquidGlass.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)

                if case let .unlocking(progress) = state {
                    ProgressView(value: progress)
                        .tint(config.primaryColor)
                }
            }

            Spacer()

            if case .unlocked = state {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(config.primaryColor)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
    }
}

// MARK: - View Extension

extension View {
    /// Apply unlock celebration overlay when trigger fires
    func unlockCelebration(
        isPresented: Binding<Bool>,
        title: String,
        icon: String,
        config: UnlockAnimationConfiguration = .badge,
    ) -> some View {
        overlay {
            if isPresented.wrappedValue {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            isPresented.wrappedValue = false
                        }

                    VStack(spacing: Spacing.lg) {
                        UnlockAnimationView(
                            state: .unlocked,
                            systemIcon: icon,
                            config: config,
                        )

                        Text(title)
                            .font(.LiquidGlass.headlineLarge)
                            .foregroundStyle(Color.DesignSystem.text)
                            .multilineTextAlignment(.center)

                        Text("Tap to dismiss")
                            .font(.LiquidGlass.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                    .padding(Spacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.xxl)
                            #if !SKIP
                            .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                            #else
                            .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                            #endif
                    )
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(ProMotionAnimation.fluid, value: isPresented.wrappedValue)
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Unlock Animations") {
        struct PreviewContent: View {
            @State private var state1: UnlockAnimationState = .locked
            @State private var state2: UnlockAnimationState = .unlocking(progress: 0.65)
            @State private var state3: UnlockAnimationState = .unlocked
            @State private var progress = 0.3
            @State private var showCelebration = false

            var body: some View {
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        Text("Unlock Animations")
                            .font(.LiquidGlass.displayMedium)

                        // States demo
                        HStack(spacing: Spacing.xl) {
                            VStack {
                                UnlockAnimationView(
                                    state: state1,
                                    config: .badge,
                                ) {
                                    Image(systemName: "star.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .foregroundStyle(.yellow)
                                }

                                Text("Locked")
                                    .font(.LiquidGlass.caption)
                            }

                            VStack {
                                UnlockAnimationView(
                                    state: state2,
                                    config: .badge,
                                ) {
                                    Image(systemName: "flame.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .foregroundStyle(.orange)
                                }

                                Text("Progress")
                                    .font(.LiquidGlass.caption)
                            }

                            VStack {
                                UnlockAnimationView(
                                    state: state3,
                                    config: .badge,
                                ) {
                                    Image(systemName: "trophy.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .foregroundStyle(Color.DesignSystem.brandGreen)
                                }

                                Text("Unlocked")
                                    .font(.LiquidGlass.caption)
                            }
                        }
                        .foregroundStyle(Color.DesignSystem.textSecondary)

                        Divider()

                        // Interactive unlock
                        VStack(spacing: Spacing.md) {
                            Text("Tap to unlock")
                                .font(.LiquidGlass.headlineSmall)

                            UnlockAnimationView(
                                state: state1,
                                config: .achievement,
                            ) {
                                Image(systemName: "crown.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .foregroundStyle(.yellow)
                            } onUnlocked: {
                                print("Badge unlocked!")
                            }
                            .onTapGesture {
                                switch state1 {
                                case .locked:
                                    state1 = .unlocking(progress: 0.5)
                                case .unlocking:
                                    state1 = .unlocked
                                case .unlocked:
                                    state1 = .locked
                                }
                            }
                        }

                        Divider()

                        // Badge cell
                        BadgeUnlockCell(
                            title: "First Share",
                            description: "Share your first food item",
                            iconName: "gift.fill",
                            state: .unlocking(progress: 0.7),
                        )
                        .padding(.horizontal)

                        Divider()

                        // Celebration overlay trigger
                        Button("Show Celebration") {
                            showCelebration = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
                .background(Color.DesignSystem.background)
                .unlockCelebration(
                    isPresented: $showCelebration,
                    title: "Achievement Unlocked!",
                    icon: "star.circle.fill",
                )
            }
        }

        return PreviewContent()
            .preferredColorScheme(.dark)
    }
#endif
#endif

#endif
