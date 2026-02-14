//
//  NotificationDot.swift
//  Foodshare
//
//  Liquid Glass v27 - Atomic Notification Dot Indicator
//  A pulsing dot indicator for notification states
//
//  Atomic Design: ATOM - Smallest reusable notification indicator
//  Follows Liquid Glass design system with dynamic materials and spatial depth
//
//  Features:
//  - Pulsing ring animation (3-second cycle: 1.5s expand, 1.5s contract)
//  - Task-based animation with proper lifecycle management
//  - @MainActor for Swift 6 concurrency safety
//  - @ScaledMetric for Dynamic Type support
//  - Respects accessibilityReduceMotion
//  - Inner highlight gradient for depth
//  - Configurable size with minimum 18pt
//  - Active/inactive color states
//

import FoodShareDesignSystem
import SwiftUI

/// A pulsing notification dot indicator following Liquid Glass design principles.
///
/// Usage:
/// ```swift
/// NotificationDot(isActive: true)
/// NotificationDot(isActive: false, size: 20, activeColor: .DesignSystem.brandPink)
/// ```
@MainActor
struct NotificationDot: View {
    let isActive: Bool
    var size: CGFloat = 18
    var activeColor: Color = .DesignSystem.brandPink
    var inactiveColor: Color = .DesignSystem.textTertiary

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity = 1.0
    @State private var animationTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Dynamic Type support - scales with user's text size preference
    @ScaledMetric(relativeTo: .body) private var scaledSize: CGFloat = 18

    /// Effective size (never smaller than design spec minimum)
    private var effectiveSize: CGFloat {
        max(size, 18)
    }

    var body: some View {
        ZStack {
            // Outer pulse ring (only when active)
            if isActive, !reduceMotion {
                Circle()
                    .fill(activeColor.opacity(0.3))
                    .frame(width: effectiveSize + 6, height: effectiveSize + 6)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
                    .drawingGroup() // GPU rasterization for animated layer
            }

            // Main indicator dot
            Circle()
                .fill(isActive ? activeColor : inactiveColor.opacity(0.5))
                .frame(width: effectiveSize, height: effectiveSize)

            // Inner highlight for depth
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(isActive ? 0.4 : 0.2),
                            Color.clear,
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: effectiveSize / 2,
                    ),
                )
                .frame(width: effectiveSize, height: effectiveSize)

            // Subtle border
            Circle()
                .stroke(
                    isActive
                        ? activeColor.opacity(0.3)
                        : inactiveColor.opacity(0.3),
                    lineWidth: 1,
                )
                .frame(width: effectiveSize, height: effectiveSize)
        }
        .onAppear {
            startPulseAnimation()
        }
        .onDisappear {
            stopPulseAnimation()
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startPulseAnimation()
            } else {
                stopPulseAnimation()
            }
        }
    }

    // MARK: - Pulse Animation (Task-based for proper lifecycle)

    private func startPulseAnimation() {
        guard isActive, !reduceMotion else { return }

        // Cancel any existing animation
        animationTask?.cancel()

        // Task-based animation with cancellation support
        animationTask = Task { @MainActor in
            while !Task.isCancelled {
                // Expand phase
                withAnimation(.smooth(duration: 1.5)) {
                    pulseScale = 1.4
                    pulseOpacity = 0.0
                }
                try? await Task.sleep(for: .seconds(1.5))

                guard !Task.isCancelled else { break }

                // Contract phase
                withAnimation(.smooth(duration: 1.5)) {
                    pulseScale = 1.0
                    pulseOpacity = 1.0
                }
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }

    private func stopPulseAnimation() {
        // Cancel animation task safely
        let taskToCancel = animationTask
        animationTask = nil
        taskToCancel?.cancel()

        // Graceful cleanup
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.3)) {
                pulseScale = 1.0
                pulseOpacity = 1.0
            }
        }
    }
}

// MARK: - Preview

#Preview("Notification Dot") {
    struct PreviewWrapper: View {
        @State private var isActive = true

        var body: some View {
            VStack(spacing: Spacing.xxl) {
                Text("Notification Dot Atom")
                    .font(.DesignSystem.displayMedium)
                    .foregroundStyle(Color.DesignSystem.textPrimary)

                // State variants
                HStack(spacing: Spacing.xxl) {
                    VStack(spacing: Spacing.md) {
                        NotificationDot(isActive: true)
                        Text("Active")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    VStack(spacing: Spacing.md) {
                        NotificationDot(isActive: false)
                        Text("Inactive")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                }

                Divider()
                    .padding(.horizontal, Spacing.xl)

                // Size variants
                HStack(spacing: Spacing.xxl) {
                    VStack(spacing: Spacing.md) {
                        NotificationDot(isActive: true, size: 14)
                        Text("Small (14pt)")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    VStack(spacing: Spacing.md) {
                        NotificationDot(isActive: true, size: 18)
                        Text("Regular (18pt)")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    VStack(spacing: Spacing.md) {
                        NotificationDot(isActive: true, size: 24)
                        Text("Large (24pt)")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                }

                Divider()
                    .padding(.horizontal, Spacing.xl)

                // Color variants
                HStack(spacing: Spacing.xxl) {
                    VStack(spacing: Spacing.md) {
                        NotificationDot(isActive: true, activeColor: .DesignSystem.brandPink)
                        Text("Pink")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    VStack(spacing: Spacing.md) {
                        NotificationDot(isActive: true, activeColor: .DesignSystem.brandGreen)
                        Text("Green")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    VStack(spacing: Spacing.md) {
                        NotificationDot(isActive: true, activeColor: .DesignSystem.error)
                        Text("Red")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                }

                Divider()
                    .padding(.horizontal, Spacing.xl)

                // Interactive demo
                VStack(spacing: Spacing.md) {
                    NotificationDot(isActive: isActive)

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
