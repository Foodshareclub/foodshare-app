//
//  GlassContextMenu.swift
//  Foodshare
//
//  Liquid Glass v26 Context Menu with scale + blur transitions
//  Premium component with staggered item appearance and haptic feedback
//


#if !SKIP
import SwiftUI

// MARK: - Glass Context Menu Modifier

struct GlassContextMenuModifier: ViewModifier {
    let menuItems: [GlassMenuItem]

    func body(content: Content) -> some View {
        content
            #if !SKIP
            .contextMenu {
                ForEach(menuItems) { item in
                    if item.isDestructive {
                        Button(role: .destructive) {
                            item.action()
                        } label: {
                            Label(item.title, systemImage: item.icon)
                        }
                    } else {
                        Button {
                            item.action()
                        } label: {
                            Label(item.title, systemImage: item.icon)
                        }
                        .disabled(item.isDisabled)
                    }
                }
            }
            #endif
    }
}

// MARK: - Glass Menu Item

struct GlassMenuItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let isDestructive: Bool
    let isDisabled: Bool
    let action: () -> Void

    init(
        title: String,
        icon: String,
        isDestructive: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isDestructive = isDestructive
        self.isDisabled = isDisabled
        self.action = action
    }
}

// MARK: - View Extension

extension View {
    func glassContextMenu(_ items: [GlassMenuItem]) -> some View {
        modifier(GlassContextMenuModifier(menuItems: items))
    }
}

// MARK: - Custom Glass Action Menu (Popup Style)

struct GlassActionMenu: View {
    @Binding var isPresented: Bool
    let items: [GlassMenuItem]
    let anchor: UnitPoint

    @State private var itemsVisible: [Bool] = []

    var body: some View {
        GeometryReader { geometry in
            if isPresented {
                ZStack {
                    // Dimmed background
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            dismissMenu()
                        }

                    // Menu content
                    VStack(spacing: Spacing.xxs) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            menuButton(for: item, at: index)
                        }
                    }
                    .padding(Spacing.xs)
                    .background(menuBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 30, y: 15)
                    .scaleEffect(isPresented ? 1 : 0.8, anchor: anchor)
                    .position(menuPosition(in: geometry))
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: anchor)))
                .onAppear {
                    setupItemVisibility()
                    animateItemsIn()
                }
            }
        }
        .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: isPresented)
    }

    // MARK: - Menu Button

    private func menuButton(for item: GlassMenuItem, at index: Int) -> some View {
        Button {
            HapticFeedback.medium()
            item.action()
            dismissMenu()
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 24.0)

                Text(item.title)
                    .font(.DesignSystem.bodyMedium)

                Spacer()
            }
            .foregroundColor(
                item.isDestructive
                    ? Color.DesignSystem.error
                    : Color.DesignSystem.text
            )
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(Color.clear)
            )
            #if !SKIP
            .contentShape(Rectangle())
            #endif
        }
        .buttonStyle(MenuItemButtonStyle())
        .disabled(item.isDisabled)
        .opacity(item.isDisabled ? 0.5 : 1.0)
        .opacity(itemsVisible.indices.contains(index) && itemsVisible[index] ? 1 : 0)
        .offset(y: itemsVisible.indices.contains(index) && itemsVisible[index] ? 0 : 10)
    }

    // MARK: - Menu Background

    private var menuBackground: some View {
        ZStack {
            Rectangle()
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif

            LinearGradient(
                colors: [
                    Color.white.opacity(0.15),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
    }

    // MARK: - Helpers

    private func menuPosition(in geometry: GeometryProxy) -> CGPoint {
        CGPoint(
            x: geometry.size.width * anchor.x,
            y: geometry.size.height * anchor.y
        )
    }

    private func setupItemVisibility() {
        itemsVisible = Array(repeating: false, count: items.count)
    }

    private func animateItemsIn() {
        Task { @MainActor in
            for index in items.indices {
                #if SKIP
                try? await Task.sleep(nanoseconds: UInt64(50 * index * 1_000_000))
                #else
                try? await Task.sleep(for: .milliseconds(50 * UInt64(index)))
                #endif
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                    if itemsVisible.indices.contains(index) {
                        itemsVisible[index] = true
                    }
                }
            }
        }
    }

    private func dismissMenu() {
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
            isPresented = false
        }
    }
}

// MARK: - Menu Item Button Style

private struct MenuItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(configuration.isPressed ? Color.DesignSystem.glassBackground : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Animation.interpolatingSpring(stiffness: 400, damping: 25), value: configuration.isPressed)
    }
}

// MARK: - Quick Action Button with Menu

struct GlassQuickActionButton: View {
    let icon: String
    let menuItems: [GlassMenuItem]

    @State private var showMenu = false

    var body: some View {
        Button {
            HapticFeedback.light()
            showMenu = true
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.DesignSystem.text)
                .frame(width: 44.0, height: 44)
                .background(
                    Circle()
                        #if !SKIP
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                        #else
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                        #endif
                        .overlay(
                            Circle()
                                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                        )
                )
        }
        .glassContextMenu(menuItems)
    }
}

// MARK: - Previews

#Preview("Context Menu") {
    VStack(spacing: Spacing.xl) {
        GlassCard(cornerRadius: 16, shadow: .medium) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Long Press Me")
                    .font(.DesignSystem.headlineSmall)

                Text("This card has a context menu")
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.textSecondary)
            }
            .padding(Spacing.lg)
        }
        .glassContextMenu([
            GlassMenuItem(title: "Edit", icon: "pencil") { print("Edit") },
            GlassMenuItem(title: "Share", icon: "square.and.arrow.up") { print("Share") },
            GlassMenuItem(title: "Favorite", icon: "heart") { print("Favorite") },
            GlassMenuItem(title: "Delete", icon: "trash", isDestructive: true) { print("Delete") }
        ])
    }
    .padding()
    .background(
        LinearGradient(
            colors: [Color.DesignSystem.accentBlue.opacity(0.2), Color.DesignSystem.background],
            startPoint: .top,
            endPoint: .bottom
        )
    )
}

#Preview("Quick Action Button") {
    GlassQuickActionButton(
        icon: "ellipsis",
        menuItems: [
            GlassMenuItem(title: "Copy Link", icon: "link") { },
            GlassMenuItem(title: "Report", icon: "flag") { },
            GlassMenuItem(title: "Block", icon: "hand.raised", isDestructive: true) { }
        ]
    )
    .padding()
    .background(Color.DesignSystem.background)
}

#Preview("Action Menu Popup") {
    @Previewable @State var showMenu = true

    ZStack {
        Color.DesignSystem.background
            .ignoresSafeArea()

        Button("Show Menu") {
            showMenu = true
        }

        GlassActionMenu(
            isPresented: $showMenu,
            items: [
                GlassMenuItem(title: "Edit Listing", icon: "pencil") { },
                GlassMenuItem(title: "Share", icon: "square.and.arrow.up") { },
                GlassMenuItem(title: "Mark as Claimed", icon: "checkmark.circle") { },
                GlassMenuItem(title: "Delete", icon: "trash", isDestructive: true) { }
            ],
            anchor: .center
        )
    }
}

#endif
