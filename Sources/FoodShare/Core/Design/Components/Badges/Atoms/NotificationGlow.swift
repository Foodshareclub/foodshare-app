//
//  NotificationGlow.swift
//  Foodshare
//
//  Liquid Glass v27 - Atomic Notification Glow Effect
//  A pulsing glow effect for notification indicators
//
//  Atomic Design: ATOM - Smallest reusable glow effect
//  Follows Liquid Glass design system with dynamic materials and spatial depth
//
//  Features:
//  - Configurable color and size
//  - Animation parameters (duration, scale range)
//  - GPU-optimized with .drawingGroup()
//  - Respects accessibilityReduceMotion
//  - Task-based animation with proper lifecycle management
//  - @MainActor for Swift 6 concurrency safety
//  - Blur radius control for depth effect
//

import FoodShareDesignSystem
import SwiftUI

/// A pulsing glow effect for notification indicators following Liquid Glass design principles.
///
/// Usage:
/// ```swift
/// NotificationGlow(isActive: true, color: .DesignSystem.brandPink, size: 48)
/// NotificationGlow(isActive: true, color: .DesignSystem.brandGreen, size: 56, duration: 2.0)
/// ```
@MainActor
struct NotificationGlow: View {
    let isActive: Bool
    var color: Color = .DesignSystem.brandGreen
    var size: CGFloat = 48
    var duration = 2.0
    var scaleRange: ClosedRange<CGFloat> = 1.0 ... 1.3
    var opacityRange: ClosedRange<Double> = 0.0 ... 0.4
    var blurRadius: CGFloat = 4

    @State private var scale: CGFloat = 1.0
    @State private var opacity = 0.4
    @State private var animationTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if isActive, !reduceMotion {
                Circle()
                    .fill(color.opacity(opacity))
                    .frame(width: size, height: size)
                    .scaleEffect(scale)
                    .blur(radius: blurRadius)
                    .drawingGroup() // GPU rasterization for performance
                    .onAppear {
                        startAnimation()
                    }
                    .onDisappear {
                        stopAnimation()
                    }
            }
        }
    }

    // MARK: - Animation

    private func startAnimation() {
        guard isActive, !reduceMotion else { return }

        // Cancel any existing animation
        animationTask?.cancel()

        // Task-based animation with cancellation support
        animationTask = Task { @MainActor in
            while !Task.isCancelled {
                // Expand phase
                withAnimation(.easeInOut(duration: duration / 2)) {
                    scale = scaleRange.upperBound
                    opacity = opacityRange.lowerBound
                }
                try? await Task.sleep(for: .seconds(duration / 2))

                guard !Task.isCancelled else { break }

                // Contract phase
                withAnimation(.easeInOut(duration: duration / 2)) {
                    scale = scaleRange.lowerBound
                    opacity = opacityRange.upperBound
                }
                try? await Task.sleep(for: .seconds(duration / 2))
            }
        }
    }

    private func stopAnimation() {
        // Cancel animation task safely
        let taskToCancel = animationTask
        animationTask = nil
        taskToCancel?.cancel()

        // Graceful cleanup
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.3)) {
                scale = scaleRange.lowerBound
                opacity = opacityRange.upperBound
            }
        }
    }
}

// MARK: - Preview

#Preview("Notification Glow") {
    struct PreviewWrapper: View {
        @State private var isActive = true

        var body: some View {
            VStack(spacing: Spacing.xxl) {
                Text("Notification Glow Atom")
                    .font(.DesignSystem.displayMedium)
                    .foregroundStyle(Color.DesignSystem.textPrimary)

                // Basic glow
                VStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.DesignSystem.brandGreen)
                            .frame(width: 48, height: 48)

                        NotificationGlow(
                            isActive: isActive,
                            color: .DesignSystem.brandGreen,
                            size: 56,
                        )
                    }

                    Text("Green Glow")
                        .font(.DesignSystem.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }

                Divider()
                    .padding(.horizontal, Spacing.xl)

                // Color variants
                HStack(spacing: Spacing.xxl) {
                    VStack(spacing: Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(Color.DesignSystem.brandPink)
                                .frame(width: 48, height: 48)

                            NotificationGlow(
                                isActive: true,
                                color: .DesignSystem.brandPink,
                                size: 56,
                            )
                        }
                        Text("Pink")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    VStack(spacing: Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(Color.DesignSystem.brandGreen)
                                .frame(width: 48, height: 48)

                            NotificationGlow(
                                isActive: true,
                                color: .DesignSystem.brandGreen,
                                size: 56,
                            )
                        }
                        Text("Green")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    VStack(spacing: Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(Color.DesignSystem.error)
                                .frame(width: 48, height: 48)

                            NotificationGlow(
                                isActive: true,
                                color: .DesignSystem.error,
                                size: 56,
                            )
                        }
                        Text("Error")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                }

                Divider()
                    .padding(.horizontal, Spacing.xl)

                // Size variants
                HStack(spacing: Spacing.xxl) {
                    VStack(spacing: Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(Color.DesignSystem.brandBlue)
                                .frame(width: 32, height: 32)

                            NotificationGlow(
                                isActive: true,
                                color: .DesignSystem.brandBlue,
                                size: 40,
                            )
                        }
                        Text("Small")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    VStack(spacing: Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(Color.DesignSystem.brandBlue)
                                .frame(width: 48, height: 48)

                            NotificationGlow(
                                isActive: true,
                                color: .DesignSystem.brandBlue,
                                size: 56,
                            )
                        }
                        Text("Regular")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    VStack(spacing: Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(Color.DesignSystem.brandBlue)
                                .frame(width: 64, height: 64)

                            NotificationGlow(
                                isActive: true,
                                color: .DesignSystem.brandBlue,
                                size: 72,
                            )
                        }
                        Text("Large")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                }

                Divider()
                    .padding(.horizontal, Spacing.xl)

                // Animation speed variants
                HStack(spacing: Spacing.xxl) {
                    VStack(spacing: Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(Color.DesignSystem.brandOrange)
                                .frame(width: 48, height: 48)

                            NotificationGlow(
                                isActive: true,
                                color: .DesignSystem.brandOrange,
                                size: 56,
                                duration: 1.0,
                            )
                        }
                        Text("Fast (1s)")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    VStack(spacing: Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(Color.DesignSystem.brandOrange)
                                .frame(width: 48, height: 48)

                            NotificationGlow(
                                isActive: true,
                                color: .DesignSystem.brandOrange,
                                size: 56,
                                duration: 2.0,
                            )
                        }
                        Text("Normal (2s)")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    VStack(spacing: Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(Color.DesignSystem.brandOrange)
                                .frame(width: 48, height: 48)

                            NotificationGlow(
                                isActive: true,
                                color: .DesignSystem.brandOrange,
                                size: 56,
                                duration: 3.0,
                            )
                        }
                        Text("Slow (3s)")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                }

                Divider()
                    .padding(.horizontal, Spacing.xl)

                // Interactive demo
                VStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.DesignSystem.brandGreen)
                            .frame(width: 48, height: 48)

                        NotificationGlow(
                            isActive: isActive,
                            color: .DesignSystem.brandGreen,
                            size: 56,
                        )
                    }

                    Button(isActive ? "Deactivate" : "Activate") {
                        withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                            isActive.toggle()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color.DesignSystem.background)
        }
    }

    return PreviewWrapper()
}
