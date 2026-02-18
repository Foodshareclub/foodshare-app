//
//  GlassCategoryBar.swift
//  Foodshare
//
//  Generic category bar with Liquid Glass design
//  Supports any type conforming to CategoryDisplayable
//


#if !SKIP
import SwiftUI

// MARK: - Generic Glass Category Bar

struct GlassCategoryBar<Category: Hashable & Identifiable>: View where Category: CategoryDisplayable {
    @Binding var selectedCategory: Category?
    let categories: [Category]
    let showAllOption: Bool
    let localizedTitleProvider: ((Category) -> String)?

    @State private var scrollOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool
    @Environment(\.translationService) private var t

    init(
        selectedCategory: Binding<Category?>,
        categories: [Category],
        showAllOption: Bool = true,
        localizedTitleProvider: ((Category) -> String)? = nil,
    ) {
        _selectedCategory = selectedCategory
        self.categories = categories
        self.showAllOption = showAllOption
        self.localizedTitleProvider = localizedTitleProvider
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                // "All" option
                if showAllOption {
                    GlassCategoryChip(
                        title: t.t("common.all"),
                        icon: "square.grid.2x2.fill",
                        isSelected: selectedCategory == nil,
                    ) {
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                            selectedCategory = nil
                        }
                    }
                }

                // Category chips
                ForEach(categories) { category in
                    GlassCategoryChip(
                        title: localizedTitleProvider?(category) ?? category.displayName,
                        icon: category.categoryIcon,
                        isSelected: selectedCategory?.id == category.id,
                        color: category.displayColor,
                    ) {
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.leading, Spacing.sm)
            .padding(.vertical, Spacing.sm)
            #if !SKIP
            .contentShape(Rectangle())
            #endif
        }
        #if !SKIP
        .scrollBounceBehavior(.basedOnSize)
        #endif
        #if !SKIP
        .fixedSize(horizontal: false, vertical: true)
        #endif
        .background(categoryBarBackground)
    }

    private var categoryBarBackground: some View {
        Color.DesignSystem.background
    }
}

// MARK: - Glass Category Chip Button Style

/// A scroll-friendly button style that uses `configuration.isPressed` instead of DragGesture
/// to avoid interfering with parent ScrollView gestures
struct GlassCategoryChipButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(
                reduceMotion ? Animation.default : Animation.interpolatingSpring(stiffness: 400, damping: 25),
                value: configuration.isPressed,
            )
    }
}

// MARK: - Glass Category Chip

struct GlassCategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var color: Color = .DesignSystem.brandGreen
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    var body: some View {
        Button(action: {
            action()
            HapticManager.selection()
        }) {
            VStack(spacing: Spacing.xs) {
                // Icon with background
                ZStack {
                    // Selection glow
                    if isSelected, !reduceMotion {
                        Circle()
                            .fill(color.opacity(0.3))
                            .frame(width: 52.0, height: 52)
                            .blur(radius: 8)
                    }

                    // Icon container
                    Circle()
                        .fill(isSelected ? color : Color.DesignSystem.surface)
                        .frame(width: 48.0, height: 48)
                        .overlay(
                            Circle()
                                .stroke(
                                    isSelected
                                        ? color.opacity(0.5)
                                        : Color.DesignSystem.glassBorder,
                                    lineWidth: 1,
                                ),
                        )

                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? .white : color)
                        #if !SKIP
                        .symbolEffect(.bounce, value: isSelected)
                        #endif
                }

                // Label
                Text(title)
                    .font(.LiquidGlass.captionSmall)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? color : Color.DesignSystem.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 64.0)
        }
        .buttonStyle(GlassCategoryChipButtonStyle())
        .accessibilityLabel("\(title) category")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

#endif
