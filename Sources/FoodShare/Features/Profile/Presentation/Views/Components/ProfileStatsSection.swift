//
//  ProfileStatsSection.swift
//  FoodShare
//
//  Displays user statistics (shared, received, rating) with animated count-up effects.
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Profile Stats Section

struct ProfileStatsSection: View {
    @Environment(\.translationService) private var t
    let viewModel: ProfileViewModel

    @State private var hasAppeared = false

    var body: some View {
        HStack(spacing: 0) {
            ProfileStatItem(
                value: viewModel.sharedCount,
                label: t.t("profile.stats.shared"),
                icon: "arrow.up.heart.fill",
                color: .DesignSystem.brandOrange
            )
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .animation(.interpolatingSpring(stiffness: 300, damping: 22).delay(0.0), value: hasAppeared)

            Divider().frame(height: 50)

            ProfileStatItem(
                value: viewModel.receivedCount,
                label: t.t("profile.stats.received"),
                icon: "arrow.down.heart.fill",
                color: .DesignSystem.success
            )
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .animation(.interpolatingSpring(stiffness: 300, damping: 22).delay(0.08), value: hasAppeared)

            Divider().frame(height: 50)

            ProfileStatItem(
                value: viewModel.ratingText,
                label: t.t("profile.stats.rating"),
                icon: "star.fill",
                color: .DesignSystem.accentYellow
            )
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .animation(.interpolatingSpring(stiffness: 300, damping: 22).delay(0.16), value: hasAppeared)
        }
        .padding(Spacing.md)
        .glassEffect(cornerRadius: CornerRadius.large)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            t.t("profile.stats.accessibility", args: [
                "shared": viewModel.sharedCount,
                "received": viewModel.receivedCount,
                "rating": viewModel.ratingText
            ])
        )
        .onAppear {
            hasAppeared = true
        }
    }
}

// MARK: - Animated Profile Stat Item

struct ProfileStatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    @State private var displayValue = "0"
    @State private var isPulsing = false
    @State private var hasAnimated = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var numericValue: Int? {
        if let dotIndex = value.firstIndex(of: ".") {
            return Int(value[..<dotIndex])
        }
        return Int(value)
    }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .opacity(isPulsing ? 0 : 0.3)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
            }

            Text(displayValue)
                .font(.LiquidGlass.headlineLarge)
                .fontWeight(.bold)
                .foregroundStyle(Color.DesignSystem.text)
                .contentTransition(.numericText())

            Text(label)
                .font(.LiquidGlass.caption)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !hasAnimated else { return }
            hasAnimated = true

            if reduceMotion {
                displayValue = value
            } else {
                animateValue()
            }
        }
    }

    private func animateValue() {
        if value.contains(".") {
            animateDecimalValue()
        } else if let target = numericValue {
            animateIntegerValue(target: target)
        } else {
            displayValue = value
        }

        triggerPulseAtEnd()
    }

    private func animateDecimalValue() {
        let steps = 20
        let finalDouble = Double(value) ?? 0
        for i in 0...steps {
            let delay = Double(i) * 0.05
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let progress = Double(i) / Double(steps)
                let currentValue = finalDouble * progress
                withAnimation(.easeOut(duration: 0.05)) {
                    displayValue = String(format: "%.1f", currentValue)
                }
            }
        }
    }

    private func animateIntegerValue(target: Int) {
        let duration = 1.0
        let steps = min(target, 30)
        guard steps > 0 else {
            displayValue = value
            return
        }

        for i in 0...steps {
            let delay = (duration / Double(steps)) * Double(i)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let progress = Double(i) / Double(steps)
                let currentValue = Int(Double(target) * progress)
                withAnimation(.easeOut(duration: 0.03)) {
                    displayValue = "\(currentValue)"
                }
            }
        }
    }

    private func triggerPulseAtEnd() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeOut(duration: 0.4)) {
                isPulsing = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isPulsing = false
            }
            HapticManager.light()
        }
    }
}
