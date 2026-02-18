//
//  NotificationBadge.swift
//  Foodshare
//
//  Liquid Glass v27 - Atomic Notification Badge Counter
//  A numbered badge indicator for notification counts
//
//  Atomic Design: ATOM - Smallest reusable badge counter
//  Follows Liquid Glass design system with dynamic materials and spatial depth
//
//  Features:
//  - Count display with 99+ overflow handling
//  - Pulsing glow animation when count > 0
//  - @MainActor for Swift 6 concurrency safety
//  - @ScaledMetric for Dynamic Type support
//  - Respects accessibilityReduceMotion
//  - Size variants: compact (16pt), regular (20pt), large (24pt)
//  - Accessibility: announces count changes
//  - GPU-optimized with .drawingGroup()
//


#if !SKIP
import SwiftUI

/// A numbered notification badge following Liquid Glass design principles.
///
/// Usage:
/// ```swift
/// NotificationBadge(count: 5)
/// NotificationBadge(count: 150, size: .large, color: .DesignSystem.error)
/// ```
@MainActor
struct NotificationBadge: View {
    let count: Int
    var size: BadgeSize = .regular
    var color: Color = .DesignSystem.brandPink
    var showWhenZero = false

    @State private var glowScale: CGFloat = 1.0
    @State private var glowOpacity = 0.4
    @State private var animationTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    /// Dynamic Type support
    @ScaledMetric(relativeTo: .body) private var scaledSize: CGFloat = 20

    /// Badge size variants
    enum BadgeSize {
        case compact // 16pt
        case regular // 20pt
        case large // 24pt

        var diameter: CGFloat {
            switch self {
            case .compact: 16
            case .regular: 20
            case .large: 24
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .compact: 9
            case .regular: 11
            case .large: 13
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .compact: 3
            case .regular: 4
            case .large: 5
            }
        }
    }

    private var hasCount: Bool {
        count > 0
    }
    private var displayText: String {
        count > 99 ? "99+" : "\(count)"
    }

    var body: some View {
        Group {
            if hasCount || showWhenZero {
                ZStack {
                    // Pulsing glow (only when count > 0)
                    if hasCount, !reduceMotion {
                        Capsule()
                            .fill(color.opacity(glowOpacity))
                            .frame(minWidth: size.diameter, minHeight: size.diameter)
                            .scaleEffect(glowScale)
                            .blur(radius: 2)
                            .drawingGroup() // GPU rasterization
                    }

                    // Badge background with gradient
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    color,
                                    color.opacity(0.85),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .shadow(
                            color: color.opacity(0.4),
                            radius: 4,
                            y: 2,
                        )

                    // Badge count text
                    Text(displayText)
                        .font(.system(size: size.fontSize, weight: .bold))
                        .foregroundStyle(.white)
                        #if !SKIP
                        .monospacedDigit() // Prevents layout shifts when count changes
                        #endif
                }
                .frame(minWidth: size.diameter, minHeight: size.diameter)
                .padding(.horizontal, count > 9 ? size.horizontalPadding : 0)
                #if !SKIP
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityValue("\(count)")
                #endif
                .onAppear {
                    startGlowAnimation()
                }
                .onDisappear {
                    stopGlowAnimation()
                }
                .onChange(of: count) { oldValue, newValue in
                    // Announce count changes for VoiceOver
                    #if !SKIP
                    if newValue > 0, newValue != oldValue {
                        UIAccessibility.post(
                            notification: .announcement,
                            argument: "Notification count: \(displayText)",
                        )
                    }
                    #endif

                    if newValue > 0 {
                        startGlowAnimation()
                    } else {
                        stopGlowAnimation()
                    }
                }
            }
        }
    }

    // MARK: - Glow Animation

    private func startGlowAnimation() {
        guard hasCount, !reduceMotion else { return }

        // Cancel any existing animation
        animationTask?.cancel()

        // Task-based animation with cancellation support
        animationTask = Task { @MainActor in
            while !Task.isCancelled {
                // Expand phase
                withAnimation(.easeInOut(duration: 1.0)) {
                    glowScale = 1.2
                    glowOpacity = 0.2
                }
                #if SKIP
                try? await Task.sleep(nanoseconds: UInt64(1.0 * 1_000_000_000))
                #else
                try? await Task.sleep(for: .seconds(1.0))
                #endif

                guard !Task.isCancelled else { break }

                // Contract phase
                withAnimation(.easeInOut(duration: 1.0)) {
                    glowScale = 1.0
                    glowOpacity = 0.4
                }
                #if SKIP
                try? await Task.sleep(nanoseconds: UInt64(1.0 * 1_000_000_000))
                #else
                try? await Task.sleep(for: .seconds(1.0))
                #endif
            }
        }
    }

    private func stopGlowAnimation() {
        // Cancel animation task safely
        let taskToCancel = animationTask
        animationTask = nil
        taskToCancel?.cancel()

        // Graceful cleanup
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.3)) {
                glowScale = 1.0
                glowOpacity = 0.4
            }
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        switch count {
        case 0:
            "No notifications"
        case 1:
            "1 notification"
        case ...99:
            "\(count) notifications"
        default:
            "99 plus notifications"
        }
    }
}

// MARK: - Preview

#Preview("Notification Badge") {
    struct PreviewWrapper: View {
        @State private var count = 5

        var body: some View {
            VStack(spacing: Spacing.xxl) {
                Text("Notification Badge Atom")
                    .font(.DesignSystem.displayMedium)
                    .foregroundStyle(Color.DesignSystem.textPrimary)

                // Count variants
                HStack(spacing: Spacing.xxl) {
                    VStack(spacing: Spacing.md) {
                        NotificationBadge(count: 0)
                        Text("Zero (hidden)")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    VStack(spacing: Spacing.md) {
                        NotificationBadge(count: 1)
                        Text("One")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    VStack(spacing: Spacing.md) {
                        NotificationBadge(count: 9)
                        Text("Nine")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    VStack(spacing: Spacing.md) {
                        NotificationBadge(count: 42)
                        Text("Double")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    VStack(spacing: Spacing.md) {
                        NotificationBadge(count: 150)
                        Text("99+")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                }

                Divider()
                    .padding(.horizontal, Spacing.xl)

                // Size variants
                HStack(spacing: Spacing.xxl) {
                    VStack(spacing: Spacing.md) {
                        NotificationBadge(count: 12, size: .compact)
                        Text("Compact")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    VStack(spacing: Spacing.md) {
                        NotificationBadge(count: 12, size: .regular)
                        Text("Regular")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    VStack(spacing: Spacing.md) {
                        NotificationBadge(count: 12, size: .large)
                        Text("Large")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                }

                Divider()
                    .padding(.horizontal, Spacing.xl)

                // Color variants
                HStack(spacing: Spacing.xxl) {
                    VStack(spacing: Spacing.md) {
                        NotificationBadge(count: 3, color: .DesignSystem.brandPink)
                        Text("Pink")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    VStack(spacing: Spacing.md) {
                        NotificationBadge(count: 3, color: .DesignSystem.brandGreen)
                        Text("Green")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    VStack(spacing: Spacing.md) {
                        NotificationBadge(count: 3, color: .DesignSystem.error)
                        Text("Red")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    VStack(spacing: Spacing.md) {
                        NotificationBadge(count: 3, color: .DesignSystem.brandBlue)
                        Text("Blue")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                }

                Divider()
                    .padding(.horizontal, Spacing.xl)

                // Interactive demo
                VStack(spacing: Spacing.md) {
                    NotificationBadge(count: count)

                    HStack(spacing: Spacing.md) {
                        Button("Add") {
                            count += 1
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Reset") {
                            count = 0
                        }
                        .buttonStyle(.bordered)

                        Button("99+") {
                            count = 150
                        }
                        .buttonStyle(.bordered)
                    }

                    Text("Count: \(count)")
                        .font(.DesignSystem.bodySmall)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
            }
            .padding()
            .background(Color.DesignSystem.background)
        }
    }

    return PreviewWrapper()
}

#endif
