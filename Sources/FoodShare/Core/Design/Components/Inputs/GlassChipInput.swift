//
//  GlassChipInput.swift
//  Foodshare
//
//  Liquid Glass v27 - Multi-Select Chip/Tag Input
//  ProMotion 120Hz optimized chip selection with fluid animations
//


#if !SKIP
import SwiftUI

// MARK: - Glass Chip Input

/// A multi-select chip/tag input component with fluid animations
///
/// Features:
/// - Single or multi-select modes
/// - Animated chip add/remove transitions
/// - Custom chip styling
/// - Horizontal scrolling or wrapping layout
/// - Search/filter integration
/// - Haptic feedback
///
/// Example usage:
/// ```swift
/// // Multi-select chips
/// GlassChipInput(
///     options: categories,
///     selectedIds: $selectedCategories
/// )
///
/// // Single select chips
/// GlassChipInput(
///     options: sortOptions,
///     selectedIds: $selectedSort,
///     allowsMultipleSelection: false
/// )
/// ```
struct GlassChipInput<ID: Hashable>: View {
    let options: [ChipOption<ID>]
    @Binding var selectedIds: Set<ID>
    let layout: ChipLayout
    let allowsMultipleSelection: Bool
    let chipStyle: ChipStyle
    let onSelectionChange: ((Set<ID>) -> Void)?

    #if !SKIP
    @Namespace private var chipNamespace
    #endif
    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    // MARK: - Initialization

    init(
        options: [ChipOption<ID>],
        selectedIds: Binding<Set<ID>>,
        layout: ChipLayout = .horizontal,
        allowsMultipleSelection: Bool = true,
        chipStyle: ChipStyle = .default,
        onSelectionChange: ((Set<ID>) -> Void)? = nil
    ) {
        self.options = options
        self._selectedIds = selectedIds
        self.layout = layout
        self.allowsMultipleSelection = allowsMultipleSelection
        self.chipStyle = chipStyle
        self.onSelectionChange = onSelectionChange
    }

    // MARK: - Body

    var body: some View {
        Group {
            switch layout {
            case .horizontal:
                horizontalLayout
            case .wrap:
                wrappingLayout
            case .vertical:
                verticalLayout
            }
        }
    }

    // MARK: - Layouts

    private var horizontalLayout: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: chipStyle.spacing) {
                ForEach(options) { option in
                    chipView(for: option)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private var wrappingLayout: some View {
        #if !SKIP
        ChipFlowLayout(spacing: chipStyle.spacing) {
            ForEach(options) { option in
                chipView(for: option)
            }
        }
        #else
        LazyVGrid(columns: [GridItem(GridItem.Size.adaptive(minimum: 100), spacing: chipStyle.spacing)], spacing: chipStyle.spacing) {
            ForEach(options) { option in
                chipView(for: option)
            }
        }
        #endif
    }

    private var verticalLayout: some View {
        VStack(spacing: chipStyle.spacing) {
            ForEach(options) { option in
                chipView(for: option)
            }
        }
    }

    // MARK: - Chip View

    @ViewBuilder
    private func chipView(for option: ChipOption<ID>) -> some View {
        let isSelected = selectedIds.contains(option.id)

        Button {
            toggleSelection(option.id)
        } label: {
            HStack(spacing: Spacing.xxs) {
                if let icon = option.icon {
                    Image(systemName: icon)
                        .font(.system(size: chipStyle.iconSize))
                }

                Text(option.label)
                    .font(chipStyle.font)

                if let count = option.count {
                    Text("\(count)")
                        .font(.DesignSystem.captionSmall)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.2) : Color.DesignSystem.glassBorder)
                        )
                }

                if isSelected && allowsMultipleSelection {
                    Image(systemName: "xmark")
                        .font(.system(size: chipStyle.iconSize * 0.8, weight: .medium))
                }
            }
            .foregroundStyle(isSelected ? chipStyle.selectedTextColor : chipStyle.textColor)
            .padding(.horizontal, chipStyle.horizontalPadding)
            .padding(.vertical, chipStyle.verticalPadding)
            .background(
                chipBackground(isSelected: isSelected, color: option.color ?? chipStyle.accentColor)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        isSelected
                            ? (option.color ?? chipStyle.accentColor)
                            : Color.DesignSystem.glassBorder,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isSelected ? (option.color ?? chipStyle.accentColor).opacity(0.3) : .clear,
                radius: 4,
                y: 2
            )
        }
        .buttonStyle(ChipButtonStyle())
        #if !SKIP
        .matchedGeometryEffect(id: option.id, in: chipNamespace)
        #endif
        .animation(
            reduceMotion ? nil : .interpolatingSpring(stiffness: 300, damping: 25),
            value: isSelected
        )
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "Double tap to deselect" : "Double tap to select")
    }

    @ViewBuilder
    private func chipBackground(isSelected: Bool, color: Color) -> some View {
        if isSelected {
            color.opacity(0.2)
        } else {
            Color.clear
                #if !SKIP
                .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .background(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
        }
    }

    // MARK: - Selection

    private func toggleSelection(_ id: ID) {
        // Haptic feedback
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif

        if allowsMultipleSelection {
            if selectedIds.contains(id) {
                selectedIds.remove(id)
            } else {
                selectedIds.insert(id)
            }
        } else {
            selectedIds = selectedIds.contains(id) ? [] : [id]
        }

        onSelectionChange?(selectedIds)
    }
}

// MARK: - Chip Option

struct ChipOption<ID: Hashable>: Identifiable {
    let id: ID
    let label: String
    let icon: String?
    let color: Color?
    let count: Int?

    init(
        id: ID,
        label: String,
        icon: String? = nil,
        color: Color? = nil,
        count: Int? = nil
    ) {
        self.id = id
        self.label = label
        self.icon = icon
        self.color = color
        self.count = count
    }
}

// MARK: - Chip Layout

extension GlassChipInput {
    enum ChipLayout {
        case horizontal
        case wrap
        case vertical
    }
}

// MARK: - Chip Style

/// Style configuration for GlassChipInput (standalone to avoid generic type static property limitation)
struct ChipStyle {
    let font: Font
    let iconSize: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let spacing: CGFloat
    let accentColor: Color
    let textColor: Color
    let selectedTextColor: Color

    static let `default` = ChipStyle(
        font: .DesignSystem.bodyMedium,
        iconSize: 14,
        horizontalPadding: Spacing.sm,
        verticalPadding: Spacing.xs,
        spacing: Spacing.xs,
        accentColor: .DesignSystem.brandGreen,
        textColor: .DesignSystem.textPrimary,
        selectedTextColor: .DesignSystem.textPrimary
    )

    static let small = ChipStyle(
        font: .DesignSystem.captionMedium,
        iconSize: 12,
        horizontalPadding: Spacing.xs,
        verticalPadding: Spacing.xxxs,
        spacing: Spacing.xxs,
        accentColor: .DesignSystem.brandGreen,
        textColor: .DesignSystem.textPrimary,
        selectedTextColor: .DesignSystem.textPrimary
    )

    static let large = ChipStyle(
        font: .DesignSystem.bodyLarge,
        iconSize: 18,
        horizontalPadding: Spacing.md,
        verticalPadding: Spacing.sm,
        spacing: Spacing.sm,
        accentColor: .DesignSystem.brandGreen,
        textColor: .DesignSystem.textPrimary,
        selectedTextColor: .DesignSystem.textPrimary
    )
}

// MARK: - Chip Button Style

private struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(Animation.interpolatingSpring(stiffness: 400, damping: 30), value: configuration.isPressed)
    }
}

// MARK: - Chip Flow Layout

/// A layout that wraps items horizontally (local to GlassChipInput to avoid conflicts)
#if !SKIP
private struct ChipFlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                // Move to next line
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))

            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        totalHeight = currentY + lineHeight

        return (CGSize(width: totalWidth, height: totalHeight), frames)
    }
}
#endif

// MARK: - Selected Chips View

/// A view showing only selected chips with remove buttons
struct GlassSelectedChips<ID: Hashable>: View {
    let options: [ChipOption<ID>]
    @Binding var selectedIds: Set<ID>
    let chipStyle: ChipStyle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    var body: some View {
        let selectedOptions = options.filter { selectedIds.contains($0.id) }

        if !selectedOptions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: chipStyle.spacing) {
                    ForEach(selectedOptions) { option in
                        selectedChipView(for: option)
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
        }
    }

    @ViewBuilder
    private func selectedChipView(for option: ChipOption<ID>) -> some View {
        HStack(spacing: Spacing.xxs) {
            if let icon = option.icon {
                Image(systemName: icon)
                    .font(.system(size: chipStyle.iconSize))
            }

            Text(option.label)
                .font(chipStyle.font)

            Button {
                removeSelection(option.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: chipStyle.iconSize))
            }
        }
        .foregroundStyle(chipStyle.textColor)
        .padding(.horizontal, chipStyle.horizontalPadding)
        .padding(.vertical, chipStyle.verticalPadding)
        .background(
            Capsule()
                .fill((option.color ?? chipStyle.accentColor).opacity(0.2))
        )
        .overlay(
            Capsule()
                .stroke(option.color ?? chipStyle.accentColor, lineWidth: 1)
        )
        .transition(
            reduceMotion
                ? AnyTransition.opacity
                : AnyTransition.asymmetric(
                    insertion: AnyTransition.scale.combined(with: AnyTransition.opacity),
                    removal: AnyTransition.scale.combined(with: AnyTransition.opacity)
                )
        )
    }

    private func removeSelection(_ id: ID) {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif

        withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
            selectedIds.remove(id)
        }
    }
}

// MARK: - Preview

#Preview("Glass Chip Input") {
    struct PreviewWrapper: View {
        @State private var selectedCategories: Set<String> = ["produce"]
        @State private var selectedSort: Set<String> = []
        @State private var selectedFilters: Set<String> = ["nearby", "available"]

        let categories: [ChipOption<String>] = [
            ChipOption(id: "produce", label: "Produce", icon: "leaf.fill", color: .green, count: 24),
            ChipOption(id: "dairy", label: "Dairy", icon: "drop.fill", color: .blue, count: 12),
            ChipOption(id: "baked", label: "Baked Goods", icon: "birthday.cake.fill", color: .orange, count: 8),
            ChipOption(id: "prepared", label: "Prepared", icon: "fork.knife", color: .purple, count: 15),
            ChipOption(id: "pantry", label: "Pantry", icon: "cabinet.fill", color: .brown, count: 31)
        ]

        let sortOptions: [ChipOption<String>] = [
            ChipOption(id: "nearest", label: "Nearest", icon: "location.fill"),
            ChipOption(id: "newest", label: "Newest", icon: "clock.fill"),
            ChipOption(id: "expiring", label: "Expiring Soon", icon: "exclamationmark.circle.fill")
        ]

        let filters: [ChipOption<String>] = [
            ChipOption(id: "nearby", label: "Nearby"),
            ChipOption(id: "available", label: "Available Now"),
            ChipOption(id: "verified", label: "Verified"),
            ChipOption(id: "organic", label: "Organic"),
            ChipOption(id: "vegan", label: "Vegan"),
            ChipOption(id: "glutenfree", label: "Gluten-Free")
        ]

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    Text("Glass Chip Input")
                        .font(.DesignSystem.displayMedium)
                        .foregroundStyle(Color.DesignSystem.textPrimary)

                    // Horizontal multi-select
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Categories (Multi-Select)")
                            .font(.DesignSystem.headlineSmall)

                        GlassChipInput(
                            options: categories,
                            selectedIds: $selectedCategories,
                            layout: .horizontal
                        )
                    }

                    // Single select
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Sort By (Single Select)")
                            .font(.DesignSystem.headlineSmall)

                        GlassChipInput(
                            options: sortOptions,
                            selectedIds: $selectedSort,
                            layout: .horizontal,
                            allowsMultipleSelection: false
                        )
                    }

                    // Wrapping layout
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Filters (Wrap Layout)")
                            .font(.DesignSystem.headlineSmall)

                        GlassChipInput(
                            options: filters,
                            selectedIds: $selectedFilters,
                            layout: .wrap
                        )
                        .padding(.horizontal, Spacing.md)
                    }

                    // Selected chips
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Selected Filters")
                            .font(.DesignSystem.headlineSmall)

                        GlassSelectedChips(
                            options: filters,
                            selectedIds: $selectedFilters,
                            chipStyle: .default
                        )
                    }

                    // Small style
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Small Chips")
                            .font(.DesignSystem.headlineSmall)

                        GlassChipInput(
                            options: filters,
                            selectedIds: $selectedFilters,
                            layout: .horizontal,
                            chipStyle: .small
                        )
                    }
                }
                .padding()
            }
            .background(Color.DesignSystem.background)
        }
    }

    return PreviewWrapper()
}

#endif
