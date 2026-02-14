//
//  GlassNavigationBar.swift
//  Foodshare
//
//  Premium Liquid Glass navigation bar with proper material effects
//  Fixes grey rectangle issue with proper glass morphism
//  Optimized for ProMotion 120Hz
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Glass Navigation Bar

struct GlassNavigationBar<Leading: View, Center: View, Trailing: View>: View {
    let leading: Leading
    let center: Center
    let trailing: Trailing
    let showDivider: Bool
    let blurStyle: UIBlurEffect.Style

    @Environment(\.colorScheme) private var colorScheme

    init(
        showDivider: Bool = true,
        blurStyle: UIBlurEffect.Style = .systemUltraThinMaterial,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder center: () -> Center,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.showDivider = showDivider
        self.blurStyle = blurStyle
        self.leading = leading()
        self.center = center()
        self.trailing = trailing()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.md) {
                // Leading content
                leading
                    .frame(minWidth: 44)

                Spacer()

                // Center content
                center

                Spacer()

                // Trailing content
                trailing
                    .frame(minWidth: 44)
            }
            .padding(.horizontal, Spacing.md)
            .frame(height: 56)
            .background(navBarBackground)

            // Divider
            if showDivider {
                Rectangle()
                    .fill(Color.DesignSystem.glassBorder.opacity(0.3))
                    .frame(height: 0.5)
            }
        }
        .drawingGroup() // GPU rasterization for 120Hz ProMotion
    }

    @ViewBuilder
    private var navBarBackground: some View {
        ZStack {
            // Glass material
            VisualEffectBlur(blurStyle: blurStyle)

            // Top highlight
            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.05 : 0.1),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
    }
}

// MARK: - Convenience Initializers

extension GlassNavigationBar where Leading == EmptyView {
    init(
        showDivider: Bool = true,
        @ViewBuilder center: () -> Center,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            showDivider: showDivider,
            leading: { EmptyView() },
            center: center,
            trailing: trailing
        )
    }
}

extension GlassNavigationBar where Trailing == EmptyView {
    init(
        showDivider: Bool = true,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder center: () -> Center
    ) {
        self.init(
            showDivider: showDivider,
            leading: leading,
            center: center,
            trailing: { EmptyView() }
        )
    }
}

extension GlassNavigationBar where Leading == EmptyView, Trailing == EmptyView {
    init(
        showDivider: Bool = true,
        @ViewBuilder center: () -> Center
    ) {
        self.init(
            showDivider: showDivider,
            leading: { EmptyView() },
            center: center,
            trailing: { EmptyView() }
        )
    }
}

// MARK: - Visual Effect Blur (UIKit Bridge)

struct VisualEffectBlur: UIViewRepresentable {
    let blurStyle: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

// MARK: - Foodshare Brand Navigation Bar

struct FoodshareNavigationBar: View {
    let showLogo: Bool
    let title: String?
    let trailing: AnyView?

    @Environment(\.colorScheme) private var colorScheme

    init(
        showLogo: Bool = true,
        title: String? = nil,
        trailing: AnyView? = nil
    ) {
        self.showLogo = showLogo
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        GlassNavigationBar(
            leading: {
                if showLogo {
                    brandLogo
                } else {
                    EmptyView()
                }
            },
            center: {
                if let title {
                    Text(title)
                        .font(.LiquidGlass.headlineSmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.DesignSystem.text)
                }
            },
            trailing: {
                if let trailing {
                    trailing
                }
            }
        )
    }

    private var brandLogo: some View {
        HStack(spacing: Spacing.sm) {
            // Circular logo
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            // App name
            Text("Foodshare")
                .font(.LiquidGlass.headlineSmall)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandTeal],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
}

// MARK: - Glass Tab Bar

struct GlassTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [TabItem]

    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var tabAnimation

    struct TabItem: Identifiable {
        let id: Int
        let icon: String
        let selectedIcon: String
        let title: String
        var badge: Int?
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top divider
            Rectangle()
                .fill(Color.DesignSystem.glassBorder.opacity(0.3))
                .frame(height: 0.5)

            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.md)
            .background(tabBarBackground)
        }
    }

    private func tabButton(for tab: TabItem) -> some View {
        Button {
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                selectedTab = tab.id
            }
            HapticManager.selection()
        } label: {
            VStack(spacing: Spacing.xxs) {
                ZStack {
                    // Selection background
                    if selectedTab == tab.id {
                        Capsule()
                            .fill(Color.DesignSystem.brandGreen.opacity(0.15))
                            .frame(width: 56, height: 32)
                            .matchedGeometryEffect(id: "tabSelection", in: tabAnimation)
                    }

                    // Icon
                    Image(systemName: selectedTab == tab.id ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 20, weight: selectedTab == tab.id ? .semibold : .regular))
                        .foregroundStyle(
                            selectedTab == tab.id
                                ? Color.DesignSystem.brandGreen
                                : Color.DesignSystem.textSecondary
                        )
                        .frame(width: 56, height: 32)

                    // Badge
                    if let badge = tab.badge, badge > 0 {
                        Text(badge > 99 ? "99+" : "\(badge)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.DesignSystem.brandPink)
                            )
                            .offset(x: 14, y: -10)
                    }
                }

                // Title
                Text(tab.title)
                    .font(.system(size: 10, weight: selectedTab == tab.id ? .semibold : .regular))
                    .foregroundStyle(
                        selectedTab == tab.id
                            ? Color.DesignSystem.brandGreen
                            : Color.DesignSystem.textSecondary
                    )
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var tabBarBackground: some View {
        ZStack {
            VisualEffectBlur(blurStyle: .systemUltraThinMaterial)

            // Bottom highlight
            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.03 : 0.05),
                    Color.clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        }
    }
}

// MARK: - Glass Search Bar

struct GlassSearchBar: View {
    @Binding var text: String
    let placeholder: String
    var onSubmit: (() -> Void)?
    var onClear: (() -> Void)?

    @FocusState private var isFocused: Bool
    @State private var isPressed = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(
                    isFocused
                        ? Color.DesignSystem.brandGreen
                        : Color.DesignSystem.textSecondary
                )

            // Text field
            TextField(placeholder, text: $text)
                .font(.LiquidGlass.bodyMedium)
                .foregroundStyle(Color.DesignSystem.text)
                .focused($isFocused)
                .onSubmit {
                    onSubmit?()
                }

            // Clear button
            if !text.isEmpty {
                Button {
                    HapticManager.light()
                    text = ""
                    onClear?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(searchBarBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(searchBarBorder)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.interpolatingSpring(stiffness: 400, damping: 25), value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: text.isEmpty)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    @ViewBuilder
    private var searchBarBackground: some View {
        if isFocused {
            Color.DesignSystem.brandGreen.opacity(0.05)
        } else {
            Color.DesignSystem.glassBackground
        }
    }

    private var searchBarBorder: some View {
        RoundedRectangle(cornerRadius: CornerRadius.large)
            .stroke(
                isFocused
                    ? Color.DesignSystem.brandGreen.opacity(0.5)
                    : Color.DesignSystem.glassBorder,
                lineWidth: isFocused ? 1.5 : 1
            )
    }
}

// MARK: - Glass Segmented Control

struct GlassSegmentedControl<T: Hashable & CaseIterable & CustomStringConvertible>: View where T.AllCases: RandomAccessCollection {
    @Binding var selection: T
    let options: T.AllCases

    @Namespace private var segmentAnimation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options), id: \.self) { option in
                segmentButton(for: option)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                )
        )
    }

    private func segmentButton(for option: T) -> some View {
        Button {
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                selection = option
            }
            HapticManager.selection()
        } label: {
            Text(option.description)
                .font(.LiquidGlass.labelMedium)
                .fontWeight(selection == option ? .semibold : .medium)
                .foregroundStyle(
                    selection == option
                        ? Color.DesignSystem.text
                        : Color.DesignSystem.textSecondary
                )
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity)
                .background(
                    Group {
                        if selection == option {
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(Color.DesignSystem.glassBackground)
                                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                                .matchedGeometryEffect(id: "segment", in: segmentAnimation)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Navigation Bar Modifier

struct GlassNavigationBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

extension View {
    /// Apply glass navigation bar styling
    func glassNavigationBar() -> some View {
        modifier(GlassNavigationBarModifier())
    }
}

// MARK: - Preview

#Preview("Glass Navigation Components") {
    NavigationStack {
        ZStack {
            Color.DesignSystem.background
                .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Text("Navigation Components")
                    .font(.DesignSystem.headlineLarge)

                // Brand navigation bar
                FoodshareNavigationBar(
                    showLogo: true,
                    title: nil,
                    trailing: AnyView(
                        Button {
                        } label: {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.DesignSystem.text)
                        }
                    )
                )

                // Search bar
                GlassSearchBar(
                    text: .constant(""),
                    placeholder: "Search food near you..."
                )
                .padding(.horizontal, Spacing.md)

                // Search bar with text
                GlassSearchBar(
                    text: .constant("Apples"),
                    placeholder: "Search food near you..."
                )
                .padding(.horizontal, Spacing.md)

                Spacer()
            }
        }
        .glassNavigationBar()
    }
    .preferredColorScheme(.dark)
}

#Preview("Glass Tab Bar") {
    struct TabBarPreview: View {
        @State private var selectedTab = 0

        var body: some View {
            VStack {
                Spacer()

                GlassTabBar(
                    selectedTab: $selectedTab,
                    tabs: [
                        .init(id: 0, icon: "house", selectedIcon: "house.fill", title: "Home"),
                        .init(id: 1, icon: "magnifyingglass", selectedIcon: "magnifyingglass", title: "Explore"),
                        .init(id: 2, icon: "plus.circle", selectedIcon: "plus.circle.fill", title: "Share"),
                        .init(id: 3, icon: "bubble.left.and.bubble.right", selectedIcon: "bubble.left.and.bubble.right.fill", title: "Chats", badge: 3),
                        .init(id: 4, icon: "person", selectedIcon: "person.fill", title: "Profile"),
                    ]
                )
            }
            .background(Color.DesignSystem.background)
        }
    }

    return TabBarPreview()
        .preferredColorScheme(.dark)
}
