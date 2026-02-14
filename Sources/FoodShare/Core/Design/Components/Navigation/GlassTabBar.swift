//
//  GlassTabBar.swift
//  Foodshare
//
//  Custom Liquid Glass tab bar with floating design
//  Premium glassmorphism navigation matching iOS 26 design language
//  120Hz ProMotion optimized animations
//

import FoodShareDesignSystem
import SwiftUI

struct GlassTabBar<Tab: Hashable>: View {
    @Binding var selectedTab: Tab
    let tabs: [GlassTabItem<Tab>]

    @Namespace private var animation
    @State private var breathingPhase: Double = 0
    @State private var previousTab: Tab?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(tabBarBackground)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.sm)
        .drawingGroup() // GPU rasterization for blur and shadow effects
        .onAppear {
            startBreathingAnimation()
        }
    }

    // MARK: - Tab Button

    private func tabButton(for tab: GlassTabItem<Tab>) -> some View {
        let isSelected = selectedTab == tab.tag
        let hasBadge = (tab.badge ?? 0) > 0

        return Button {
            previousTab = selectedTab
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
                selectedTab = tab.tag
            }
            HapticManager.selection()
        } label: {
            VStack(spacing: Spacing.xxs) {
                ZStack {
                    // Selection background with pulse effect
                    if isSelected {
                        // Outer glow pulse
                        Circle()
                            .fill(Color.DesignSystem.brandGreen.opacity(0.3))
                            .frame(width: 56, height: 56)
                            .scaleEffect(1.0 + 0.1 * sin(breathingPhase))
                            .blur(radius: 4)

                        // Main selection circle
                        Circle()
                            .fill(Color.DesignSystem.brandGreen)
                            .frame(width: 48, height: 48)
                            .matchedGeometryEffect(id: "tabBackground", in: animation)
                            .shadow(
                                color: .DesignSystem.brandGreen.opacity(0.4 + 0.2 * sin(breathingPhase)),
                                radius: 8 + 4 * sin(breathingPhase),
                                y: 4,
                            )
                    }

                    // Icon with scale animation on selection
                    Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .white : .DesignSystem.textSecondary)
                        .frame(width: 48, height: 48)
                        .scaleEffect(isSelected ? 1.0 : 0.95)
                        .animation(.interpolatingSpring(stiffness: 400, damping: 15), value: isSelected)

                    // Badge indicator
                    if hasBadge, let badgeCount = tab.badge {
                        badgeView(count: badgeCount)
                            .offset(x: 14, y: -14)
                    }
                }

                Text(tab.title)
                    .font(.DesignSystem.captionSmall)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .DesignSystem.brandGreen : .DesignSystem.textSecondary)
                    .opacity(isSelected ? 1.0 : 0.8 + 0.2 * sin(breathingPhase))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(TabButtonStyle())
    }

    // MARK: - Badge View

    private func badgeView(count: Int) -> some View {
        NotificationBadge(
            count: count,
            size: .regular,
            color: .DesignSystem.error,
        )
    }

    // MARK: - Background

    private var tabBarBackground: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.glassHighlight.opacity(0.6),
                                Color.DesignSystem.glassBorder,
                                Color.DesignSystem.glassBorder.opacity(0.5),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                        lineWidth: 1,
                    ),
            )
    }

    // MARK: - Breathing Animation

    private func startBreathingAnimation() {
        withAnimation(
            .easeInOut(duration: 2.5)
                .repeatForever(autoreverses: false),
        ) {
            breathingPhase = .pi * 2
        }
    }
}

// MARK: - Tab Button Style

private struct TabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.interpolatingSpring(stiffness: 400, damping: 15), value: configuration.isPressed)
    }
}

// MARK: - Tab Item Model

struct GlassTabItem<Tab: Hashable>: Identifiable {
    let id = UUID()
    let tag: Tab
    let title: String
    let icon: String
    let selectedIcon: String
    let badge: Int?

    init(
        tag: Tab,
        title: String,
        icon: String,
        selectedIcon: String? = nil,
        badge: Int? = nil,
    ) {
        self.tag = tag
        self.title = title
        self.icon = icon
        self.selectedIcon = selectedIcon ?? icon
        self.badge = badge
    }
}

// MARK: - Floating Tab Bar Modifier

struct FloatingTabBarModifier<Tab: Hashable>: ViewModifier {
    @Binding var selectedTab: Tab
    let tabs: [GlassTabItem<Tab>]

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
                .padding(.bottom, 90) // Space for tab bar

            GlassTabBar(selectedTab: $selectedTab, tabs: tabs)
        }
    }
}

extension View {
    func floatingTabBar<Tab: Hashable>(
        selectedTab: Binding<Tab>,
        tabs: [GlassTabItem<Tab>],
    ) -> some View {
        modifier(FloatingTabBarModifier(selectedTab: selectedTab, tabs: tabs))
    }
}

// MARK: - Mini Floating Action Bar

struct GlassActionBar: View {
    let actions: [GlassActionItem]

    var body: some View {
        HStack(spacing: Spacing.md) {
            ForEach(actions) { action in
                Button {
                    action.action()
                    HapticManager.medium()
                } label: {
                    VStack(spacing: Spacing.xxs) {
                        Image(systemName: action.icon)
                            .font(.system(size: 20, weight: .semibold))

                        if let title = action.title {
                            Text(title)
                                .font(.DesignSystem.captionSmall)
                        }
                    }
                    .foregroundColor(action.color)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(action.color.opacity(0.3), lineWidth: 1),
                            ),
                    )
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.9, haptic: .none))
            }
        }
        .padding(Spacing.sm)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
        .shadow(color: .black.opacity(0.1), radius: 16, y: 8)
    }
}

struct GlassActionItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String?
    let color: Color
    let action: () -> Void

    init(
        icon: String,
        title: String? = nil,
        color: Color = .DesignSystem.brandGreen,
        action: @escaping () -> Void,
    ) {
        self.icon = icon
        self.title = title
        self.color = color
        self.action = action
    }
}

// MARK: - Preview

#Preview("Glass Tab Bar") {
    struct PreviewContainer: View {
        @State private var selectedTab = 0

        var body: some View {
            ZStack {
                Color.DesignSystem.background
                    .ignoresSafeArea()

                VStack {
                    Text("Tab \(selectedTab)")
                        .font(.DesignSystem.displayLarge)

                    Spacer()
                }
                .padding(.top, 100)
            }
            .floatingTabBar(
                selectedTab: $selectedTab,
                tabs: [
                    GlassTabItem(tag: 0, title: "Explore", icon: "magnifyingglass", selectedIcon: "magnifyingglass"),
                    GlassTabItem(tag: 1, title: "Challenges", icon: "trophy", selectedIcon: "trophy.fill"),
                    GlassTabItem(tag: 2, title: "Chats", icon: "message", selectedIcon: "message.fill", badge: 3),
                    GlassTabItem(tag: 3, title: "Profile", icon: "person", selectedIcon: "person.fill"),
                ],
            )
        }
    }

    return PreviewContainer()
}

#Preview("Action Bar") {
    VStack {
        Spacer()

        GlassActionBar(actions: [
            GlassActionItem(icon: "map.fill", title: "Map", color: .DesignSystem.brandBlue) {},
            GlassActionItem(icon: "plus.circle.fill", title: "Add", color: .DesignSystem.brandGreen) {},
            GlassActionItem(icon: "slider.horizontal.3", title: "Filter", color: .DesignSystem.brandOrange) {},
        ])

        Spacer()
    }
    .background(Color.DesignSystem.background)
}
