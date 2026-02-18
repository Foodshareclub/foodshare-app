//
//  MilestoneOverlay.swift
//  FoodShare
//
//  Full-screen milestone celebration overlay.
//  Combines confetti, haptics, and animated content for big moments.
//
//  Features:
//  - Full-screen celebratory presentation
//  - Confetti + haptics integration
//  - Animated badge/icon reveal
//  - Progress ring completion animation
//  - XP counter animation
//


#if !SKIP
import SwiftUI

#if !SKIP

// MARK: - Milestone Type

/// Types of milestones that can be celebrated
enum MilestoneType {
    case levelUp(level: Int)
    case badgeUnlock(name: String, icon: String)
    case achievement(name: String, description: String, icon: String)
    case streakMilestone(days: Int)
    case impactMilestone(foodSaved: Int)
    case custom(title: String, subtitle: String, icon: String)

    var title: String {
        switch self {
        case let .levelUp(level):
            "Level \(level)!"
        case let .badgeUnlock(name, _):
            name
        case let .achievement(name, _, _):
            name
        case let .streakMilestone(days):
            "\(days) Day Streak!"
        case let .impactMilestone(food):
            "\(food)kg Saved!"
        case let .custom(title, _, _):
            title
        }
    }

    var subtitle: String {
        switch self {
        case .levelUp:
            "Congratulations! Keep up the great work."
        case .badgeUnlock:
            "Badge Unlocked"
        case let .achievement(_, description, _):
            description
        case .streakMilestone:
            "You're on fire! Keep the streak going."
        case .impactMilestone:
            "You're making a real difference!"
        case let .custom(_, subtitle, _):
            subtitle
        }
    }

    var icon: String {
        switch self {
        case .levelUp:
            "star.fill"
        case let .badgeUnlock(_, icon), let .achievement(_, _, icon), let .custom(_, _, icon):
            icon
        case .streakMilestone:
            "flame.fill"
        case .impactMilestone:
            "leaf.fill"
        }
    }

    var confettiConfig: ConfettiConfiguration {
        switch self {
        case .levelUp, .achievement:
            .celebration
        case .badgeUnlock:
            .gold
        case .streakMilestone:
            ConfettiConfiguration(
                particleCount: 120,
                duration: 3.5,
                colors: [.orange, .red, .yellow],
                velocityRange: 450 ... 850,
                gravity: 380,
                airResistance: 0.02,
                enableHaptics: true,
                spreadAngle: .pi / 2.5,
            )
        case .impactMilestone:
            ConfettiConfiguration(
                particleCount: 100,
                duration: 3.0,
                colors: [Color.DesignSystem.success, .green, .mint, .teal],
                velocityRange: 400 ... 750,
                gravity: 400,
                airResistance: 0.025,
                enableHaptics: true,
                spreadAngle: .pi / 3,
            )
        case .custom:
            .default
        }
    }
}

// MARK: - Milestone Overlay View

/// Full-screen celebration overlay for milestones
struct MilestoneOverlay: View {
    let milestone: MilestoneType
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var showConfetti = false
    @State private var iconScale: CGFloat = 0
    @State private var ringProgress: CGFloat = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Content
            VStack(spacing: Spacing.xl) {
                Spacer()

                // Animated icon with ring
                ZStack {
                    // Progress ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.primary,
                                    Color.DesignSystem.brandTeal
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round),
                        )
                        .frame(width: 140.0, height: 140)
                        .rotationEffect(.degrees(-90))
                        .opacity(0.3)

                    // Animated progress
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.primary,
                                    Color.DesignSystem.brandTeal
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round),
                        )
                        .frame(width: 140.0, height: 140)
                        .rotationEffect(.degrees(-90))

                    // Icon
                    Image(systemName: milestone.icon)
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.primary,
                                    Color.DesignSystem.brandTeal
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .scaleEffect(iconScale)
                }
                .padding(.bottom, Spacing.lg)

                // Title
                Text(milestone.title)
                    .font(Font.DesignSystem.displayLarge)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)

                // Subtitle
                Text(milestone.subtitle)
                    .font(Font.DesignSystem.bodyLarge)
                    .foregroundStyle(Color.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
                    .opacity(textOpacity)

                Spacer()

                // Dismiss button
                Button {
                    dismiss()
                } label: {
                    Text("Continue")
                        .font(Font.DesignSystem.headlineSmall)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.primary,
                                    Color.DesignSystem.brandTeal
                                ],
                                startPoint: .leading,
                                endPoint: .trailing,
                            ),
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xxl)
                .opacity(textOpacity)
            }

            // Confetti layer
            if showConfetti {
                ConfettiView(configuration: milestone.confettiConfig)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Play haptic
        AdvancedHapticEngine.shared.play(.milestone)

        // Start confetti
        withAnimation(.easeOut(duration: 0.1)) {
            showConfetti = true
        }

        // Animate icon
        withAnimation(ProMotionAnimation.celebration.delay(0.1)) {
            iconScale = 1.0
        }

        // Animate ring
        withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
            ringProgress = 1.0
        }

        // Animate text
        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
            textOpacity = 1.0
        }
    }

    private func dismiss() {
        withAnimation(ProMotionAnimation.quick) {
            textOpacity = 0
            iconScale = 0.5
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            onDismiss()
        }
    }
}

// MARK: - Milestone Overlay Modifier

/// View modifier to show milestone overlay
struct MilestoneOverlayModifier: ViewModifier {
    @Binding var milestone: MilestoneType?

    func body(content: Content) -> some View {
        ZStack {
            content

            if let milestone {
                MilestoneOverlay(milestone: milestone) {
                    self.milestone = nil
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .zIndex(100)
            }
        }
        .animation(ProMotionAnimation.smooth, value: milestone != nil)
    }
}

extension View {
    /// Show milestone celebration overlay
    func milestoneOverlay(_ milestone: Binding<MilestoneType?>) -> some View {
        modifier(MilestoneOverlayModifier(milestone: milestone))
    }
}

// MARK: - Level Up Specific View

/// Specialized level up celebration
struct LevelUpOverlay: View {
    let level: Int
    let xpEarned: Int?
    let onDismiss: () -> Void

    @State private var showLevel = false
    @State private var countedXP = 0

    var body: some View {
        MilestoneOverlay(
            milestone: .levelUp(level: level),
            onDismiss: onDismiss,
        )
        .overlay(alignment: .center) {
            if let xp = xpEarned {
                VStack {
                    Spacer()
                    Spacer()

                    // XP counter
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.yellow)
                        Text("+\(countedXP) XP")
                            .font(Font.DesignSystem.headlineLarge)
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    #if !SKIP
                    .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                    #else
                    .background(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .clipShape(Capsule())

                    Spacer()
                }
                .onAppear {
                    animateXPCounter(to: xp)
                }
            }
        }
    }

    private func animateXPCounter(to target: Int) {
        let duration = 1.0
        let steps = 20
        let stepDelay = duration / Double(steps)
        let stepValue = target / steps

        for i in 1 ... steps {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(stepDelay * Double(i)))
                withAnimation(ProMotionAnimation.counter) {
                    countedXP = min(i * stepValue, target)
                }
            }
        }
    }
}

// MARK: - Badge Unlock View

/// Specialized badge unlock celebration
struct BadgeUnlockOverlay: View {
    let badgeName: String
    let badgeIcon: String
    let badgeDescription: String
    let onDismiss: () -> Void

    @State private var showBadge = false
    @State private var glowOpacity: Double = 0

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: Spacing.xl) {
                Spacer()

                // Badge with glow
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.DesignSystem.warning.opacity(glowOpacity),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 40,
                                endRadius: 120,
                            ),
                        )
                        .frame(width: 240.0, height: 240)

                    // Badge container
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.84, blue: 0),
                                        Color(red: 0.85, green: 0.65, blue: 0.13)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                            )
                            .frame(width: 120.0, height: 120)
                            .shadow(color: .orange.opacity(0.5), radius: 20)

                        Image(systemName: badgeIcon)
                            .font(.system(size: 50, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(showBadge ? 1.0 : 0)
                }

                // Text
                VStack(spacing: Spacing.sm) {
                    Text("Badge Unlocked!")
                        .font(Font.DesignSystem.bodyLarge)
                        .foregroundStyle(Color.DesignSystem.warning)

                    Text(badgeName)
                        .font(Font.DesignSystem.displayMedium)
                        .foregroundStyle(.white)

                    Text(badgeDescription)
                        .font(Font.DesignSystem.bodyMedium)
                        .foregroundStyle(Color.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)
                }
                .opacity(showBadge ? 1 : 0)

                Spacer()

                // Continue button
                Button {
                    onDismiss()
                } label: {
                    Text("Awesome!")
                        .font(Font.DesignSystem.headlineSmall)
                        .foregroundStyle(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(Color.DesignSystem.warning)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xxl)
                .opacity(showBadge ? 1 : 0)
            }

            // Confetti
            if showBadge {
                ConfettiView(configuration: .gold)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Play haptic
        AdvancedHapticEngine.shared.play(.unlock)

        // Animate badge
        withAnimation(ProMotionAnimation.celebration.delay(0.2)) {
            showBadge = true
        }

        // Animate glow
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            glowOpacity = 0.6
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Milestone Overlay") {
        struct MilestonePreview: View {
            @State private var milestone: MilestoneType?

            var body: some View {
                ZStack {
                    Color.DesignSystem.background.ignoresSafeArea()

                    VStack(spacing: Spacing.lg) {
                        Button("Level Up") {
                            milestone = .levelUp(level: 10)
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Badge Unlock") {
                            milestone = .badgeUnlock(name: "Food Hero", icon: "heart.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)

                        Button("Streak") {
                            milestone = .streakMilestone(days: 30)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)

                        Button("Impact") {
                            milestone = .impactMilestone(foodSaved: 100)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
                .milestoneOverlay($milestone)
            }
        }

        return MilestonePreview()
    }
#endif
#endif

#endif
