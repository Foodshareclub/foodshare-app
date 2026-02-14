//
//  GlassSectionHeader.swift
//  Foodshare
//
//  Liquid Glass v26 unified section header with gradient icon
//  Reusable across all detail views
//

import SwiftUI
import FoodShareDesignSystem

struct GlassSectionHeader: View {
    let title: String
    let icon: String
    let iconColors: [Color]
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil
    var actionIcon: String? = nil

    @State private var hasAppeared = false

    init(
        _ title: String,
        icon: String,
        iconColors: [Color],
        action: (() -> Void)? = nil,
        actionLabel: String? = nil,
        actionIcon: String? = nil
    ) {
        self.title = title
        self.icon = icon
        self.iconColors = iconColors
        self.action = action
        self.actionLabel = actionLabel
        self.actionIcon = actionIcon
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Icon with gradient
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: iconColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Title
            Text(title)
                .font(.DesignSystem.headlineMedium)
                .foregroundColor(.DesignSystem.text)

            Spacer()

            // Optional action button
            if let action, let label = actionLabel {
                Button {
                    action()
                    HapticManager.light()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        if let actionIcon {
                            Image(systemName: actionIcon)
                        }
                        Text(label)
                    }
                    .font(.DesignSystem.labelSmall)
                    .foregroundColor(iconColors.first ?? .DesignSystem.primary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        Capsule()
                            .fill((iconColors.first ?? .DesignSystem.primary).opacity(0.15))
                            .overlay(
                                Capsule()
                                    .stroke((iconColors.first ?? .DesignSystem.primary).opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 10)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.05)) {
                hasAppeared = true
            }
        }
    }
}

// MARK: - Convenience Initializers

extension GlassSectionHeader {
    /// Details section header (green-blue gradient)
    static func details(_ title: String, action: (() -> Void)? = nil, actionLabel: String? = nil, actionIcon: String? = nil) -> GlassSectionHeader {
        GlassSectionHeader(
            title,
            icon: "list.bullet.rectangle.portrait.fill",
            iconColors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
            action: action,
            actionLabel: actionLabel,
            actionIcon: actionIcon
        )
    }

    /// Location section header (red-orange gradient)
    static func location(_ title: String, action: (() -> Void)? = nil, actionLabel: String? = nil, actionIcon: String? = nil) -> GlassSectionHeader {
        GlassSectionHeader(
            title,
            icon: "mappin.and.ellipse",
            iconColors: [.DesignSystem.error, .orange],
            action: action,
            actionLabel: actionLabel,
            actionIcon: actionIcon
        )
    }

    /// Reviews section header (yellow-orange gradient)
    static func reviews(_ title: String, action: (() -> Void)? = nil, actionLabel: String? = nil, actionIcon: String? = nil) -> GlassSectionHeader {
        GlassSectionHeader(
            title,
            icon: "star.bubble.fill",
            iconColors: [.yellow, .orange],
            action: action,
            actionLabel: actionLabel,
            actionIcon: actionIcon
        )
    }

    /// Information section header (blue gradient)
    static func info(_ title: String, action: (() -> Void)? = nil, actionLabel: String? = nil, actionIcon: String? = nil) -> GlassSectionHeader {
        GlassSectionHeader(
            title,
            icon: "info.circle.fill",
            iconColors: [.DesignSystem.brandBlue, .DesignSystem.accentBlue],
            action: action,
            actionLabel: actionLabel,
            actionIcon: actionIcon
        )
    }

    /// Comments section header (purple gradient)
    static func comments(_ title: String, action: (() -> Void)? = nil, actionLabel: String? = nil, actionIcon: String? = nil) -> GlassSectionHeader {
        GlassSectionHeader(
            title,
            icon: "bubble.left.and.bubble.right.fill",
            iconColors: [.purple, .DesignSystem.accentBlue],
            action: action,
            actionLabel: actionLabel,
            actionIcon: actionIcon
        )
    }

    /// Stats section header (purple gradient)
    static func stats(_ title: String, action: (() -> Void)? = nil, actionLabel: String? = nil, actionIcon: String? = nil) -> GlassSectionHeader {
        GlassSectionHeader(
            title,
            icon: "chart.bar.fill",
            iconColors: [.purple, .pink],
            action: action,
            actionLabel: actionLabel,
            actionIcon: actionIcon
        )
    }

    /// Activity section header (green gradient)
    static func activity(_ title: String, action: (() -> Void)? = nil, actionLabel: String? = nil, actionIcon: String? = nil) -> GlassSectionHeader {
        GlassSectionHeader(
            title,
            icon: "bolt.fill",
            iconColors: [.DesignSystem.brandGreen, .DesignSystem.success],
            action: action,
            actionLabel: actionLabel,
            actionIcon: actionIcon
        )
    }

    /// Settings section header (gray gradient)
    static func settings(_ title: String, action: (() -> Void)? = nil, actionLabel: String? = nil, actionIcon: String? = nil) -> GlassSectionHeader {
        GlassSectionHeader(
            title,
            icon: "gearshape.fill",
            iconColors: [.DesignSystem.textSecondary, .DesignSystem.textTertiary],
            action: action,
            actionLabel: actionLabel,
            actionIcon: actionIcon
        )
    }

    /// Challenges section header (orange gradient)
    static func challenges(_ title: String, action: (() -> Void)? = nil, actionLabel: String? = nil, actionIcon: String? = nil) -> GlassSectionHeader {
        GlassSectionHeader(
            title,
            icon: "trophy.fill",
            iconColors: [.orange, .yellow],
            action: action,
            actionLabel: actionLabel,
            actionIcon: actionIcon
        )
    }

    /// Badges section header (gold gradient)
    static func badges(_ title: String, action: (() -> Void)? = nil, actionLabel: String? = nil, actionIcon: String? = nil) -> GlassSectionHeader {
        GlassSectionHeader(
            title,
            icon: "medal.fill",
            iconColors: [.yellow, .orange],
            action: action,
            actionLabel: actionLabel,
            actionIcon: actionIcon
        )
    }

    /// Impact section header (green-blue gradient)
    static func impact(_ title: String, action: (() -> Void)? = nil, actionLabel: String? = nil, actionIcon: String? = nil) -> GlassSectionHeader {
        GlassSectionHeader(
            title,
            icon: "leaf.fill",
            iconColors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
            action: action,
            actionLabel: actionLabel,
            actionIcon: actionIcon
        )
    }

    /// Messages section header (blue gradient)
    static func messages(_ title: String, action: (() -> Void)? = nil, actionLabel: String? = nil, actionIcon: String? = nil) -> GlassSectionHeader {
        GlassSectionHeader(
            title,
            icon: "envelope.fill",
            iconColors: [.DesignSystem.brandBlue, .DesignSystem.accentBlue],
            action: action,
            actionLabel: actionLabel,
            actionIcon: actionIcon
        )
    }

    /// Trending section header (flame gradient)
    static func trending(_ title: String, action: (() -> Void)? = nil, actionLabel: String? = nil, actionIcon: String? = nil) -> GlassSectionHeader {
        GlassSectionHeader(
            title,
            icon: "flame.fill",
            iconColors: [.orange, .red],
            action: action,
            actionLabel: actionLabel,
            actionIcon: actionIcon
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Spacing.lg) {
        GlassSectionHeader.details("Details")

        GlassSectionHeader.location("Pickup Location")

        GlassSectionHeader.reviews("Reviews", action: {}, actionLabel: "Leave Review", actionIcon: "star.fill")

        GlassSectionHeader(
            "Custom Section",
            icon: "sparkles",
            iconColors: [.pink, .purple],
            action: {},
            actionLabel: "Action"
        )
    }
    .padding()
    .background(Color.DesignSystem.background)
}
