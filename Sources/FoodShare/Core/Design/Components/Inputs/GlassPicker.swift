//
//  GlassPicker.swift
//  Foodshare
//
//  Liquid Glass v26 Picker Component with ProMotion-optimized animations
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Glass Picker

struct GlassPicker<SelectionValue: Hashable, Content: View>: View {
    let label: String?
    let icon: String?
    @Binding var selection: SelectionValue
    @ViewBuilder let content: () -> Content

    @State private var isExpanded = false

    init(
        _ label: String? = nil,
        icon: String? = nil,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.label = label
        self.icon = icon
        _selection = selection
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            if let label {
                Text(label)
                    .font(.DesignSystem.labelMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .padding(.leading, Spacing.xxs)
            }

            Menu {
                content()
            } label: {
                HStack(spacing: Spacing.sm) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.DesignSystem.brandGreen)
                    }

                    Text(String(describing: selection))
                        .font(.DesignSystem.bodyLarge)
                        .foregroundStyle(Color.DesignSystem.text)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(Color.white.opacity(0.08))
                        .background(.ultraThinMaterial),
                )
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.12), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                            lineWidth: 1,
                        ),
                )
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.98, haptic: .light))
        }
    }
}

// MARK: - Glass Segmented Picker

struct GlassSegmentedPicker<SelectionValue: Hashable & CaseIterable & CustomStringConvertible>: View
    where SelectionValue.AllCases: RandomAccessCollection {
    let label: String?
    @Binding var selection: SelectionValue
    let accentColor: Color

    @Namespace private var animation

    init(
        _ label: String? = nil,
        selection: Binding<SelectionValue>,
        accentColor: Color = .DesignSystem.brandGreen,
    ) {
        self.label = label
        _selection = selection
        self.accentColor = accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let label {
                Text(label)
                    .font(.DesignSystem.labelMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .padding(.leading, Spacing.xxs)
            }

            HStack(spacing: Spacing.xxxs) {
                ForEach(Array(SelectionValue.allCases), id: \.self) { option in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selection = option
                        }
                        HapticManager.selection()
                    } label: {
                        Text(option.description)
                            .font(.DesignSystem.labelLarge)
                            .foregroundStyle(
                                selection == option
                                    ? Color.white
                                    : Color.DesignSystem.textSecondary,
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .background {
                                if selection == option {
                                    Capsule()
                                        .fill(accentColor)
                                        .shadow(color: accentColor.opacity(0.3), radius: 8, y: 2)
                                        .matchedGeometryEffect(id: "selection", in: animation)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.xxxs)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.06))
                    .background(.ultraThinMaterial),
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1),
            )
        }
    }
}

// MARK: - Glass Option Picker (Inline Options)

struct GlassOptionPicker<T: Hashable & Identifiable>: View {
    let label: String?
    let options: [T]
    @Binding var selection: T
    let optionLabel: (T) -> String
    let optionIcon: ((T) -> String)?
    let columns: Int

    init(
        _ label: String? = nil,
        options: [T],
        selection: Binding<T>,
        columns: Int = 2,
        optionLabel: @escaping (T) -> String,
        optionIcon: ((T) -> String)? = nil,
    ) {
        self.label = label
        self.options = options
        _selection = selection
        self.columns = columns
        self.optionLabel = optionLabel
        self.optionIcon = optionIcon
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let label {
                Text(label)
                    .font(.DesignSystem.labelMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .padding(.leading, Spacing.xxs)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: columns),
                spacing: Spacing.xs,
            ) {
                ForEach(options) { option in
                    let isSelected = selection == option

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selection = option
                        }
                        HapticManager.selection()
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            if let optionIcon {
                                Image(systemName: optionIcon(option))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(
                                        isSelected
                                            ? Color.DesignSystem.brandGreen
                                            : Color.DesignSystem.textSecondary,
                                    )
                            }

                            Text(optionLabel(option))
                                .font(.DesignSystem.labelMedium)
                                .foregroundStyle(
                                    isSelected
                                        ? Color.DesignSystem.text
                                        : Color.DesignSystem.textSecondary,
                                )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .padding(.horizontal, Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(
                                    isSelected
                                        ? Color.DesignSystem.brandGreen.opacity(0.15)
                                        : Color.white.opacity(0.06),
                                )
                                .background(.ultraThinMaterial),
                        )
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .stroke(
                                    isSelected
                                        ? Color.DesignSystem.brandGreen.opacity(0.5)
                                        : Color.white.opacity(0.1),
                                    lineWidth: isSelected ? 1.5 : 1,
                                ),
                        )
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.97, haptic: .none))
                }
            }
        }
    }
}

// MARK: - Glass Dropdown

struct GlassDropdown<T: Hashable & Identifiable>: View {
    let label: String?
    let placeholder: String
    let options: [T]
    @Binding var selection: T?
    let optionLabel: (T) -> String
    let icon: String?

    @State private var isExpanded = false

    init(
        _ label: String? = nil,
        placeholder: String = "Select an option",
        options: [T],
        selection: Binding<T?>,
        icon: String? = nil,
        optionLabel: @escaping (T) -> String,
    ) {
        self.label = label
        self.placeholder = placeholder
        self.options = options
        _selection = selection
        self.icon = icon
        self.optionLabel = optionLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            if let label {
                Text(label)
                    .font(.DesignSystem.labelMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .padding(.leading, Spacing.xxs)
            }

            VStack(spacing: 0) {
                // Header
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        isExpanded.toggle()
                    }
                    HapticManager.light()
                } label: {
                    HStack(spacing: Spacing.sm) {
                        if let icon {
                            Image(systemName: icon)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(
                                    selection != nil
                                        ? Color.DesignSystem.brandGreen
                                        : Color.DesignSystem.textSecondary,
                                )
                        }

                        Text(selection.map { optionLabel($0) } ?? placeholder)
                            .font(.DesignSystem.bodyLarge)
                            .foregroundStyle(
                                selection != nil
                                    ? Color.DesignSystem.text
                                    : Color.DesignSystem.textTertiary,
                            )
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .padding(Spacing.md)
                }
                .buttonStyle(.plain)

                // Options
                if isExpanded {
                    Divider()
                        .background(Color.white.opacity(0.1))

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(options) { option in
                                let isSelected = selection == option

                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                        selection = option
                                        isExpanded = false
                                    }
                                    HapticManager.selection()
                                } label: {
                                    HStack {
                                        Text(optionLabel(option))
                                            .font(.DesignSystem.bodyMedium)
                                            .foregroundStyle(
                                                isSelected
                                                    ? Color.DesignSystem.brandGreen
                                                    : Color.DesignSystem.text,
                                            )

                                        Spacer()

                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(Color.DesignSystem.brandGreen)
                                        }
                                    }
                                    .padding(.horizontal, Spacing.md)
                                    .padding(.vertical, Spacing.sm)
                                    .background(
                                        isSelected
                                            ? Color.DesignSystem.brandGreen.opacity(0.1)
                                            : Color.clear,
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Color.white.opacity(isExpanded ? 0.1 : 0.08))
                    .background(.ultraThinMaterial),
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(
                        isExpanded
                            ? LinearGradient(
                                colors: [
                                    Color.DesignSystem.brandGreen.opacity(0.5),
                                    Color.DesignSystem.brandBlue.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.12), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        lineWidth: isExpanded ? 1.5 : 1,
                    ),
            )
        }
    }
}

// MARK: - Preview Helpers

private enum SortOption: String, CaseIterable, CustomStringConvertible {
    case newest = "Newest"
    case nearest = "Nearest"
    case popular = "Popular"

    var description: String { rawValue }
}

private struct CategoryOption: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        ScrollView {
            VStack(spacing: Spacing.lg) {
                GlassSegmentedPicker(
                    "Sort By",
                    selection: .constant(SortOption.newest),
                )

                GlassDropdown(
                    "Category",
                    placeholder: "Select a category",
                    options: [
                        CategoryOption(id: "1", name: "Produce", icon: "leaf.fill"),
                        CategoryOption(id: "2", name: "Dairy", icon: "drop.fill"),
                        CategoryOption(id: "3", name: "Baked Goods", icon: "birthday.cake.fill"),
                        CategoryOption(id: "4", name: "Prepared Meals", icon: "fork.knife")
                    ],
                    selection: .constant(nil),
                    icon: "square.grid.2x2.fill",
                    optionLabel: { $0.name },
                )

                GlassOptionPicker(
                    "Transportation",
                    options: [
                        CategoryOption(id: "pickup", name: "Pickup", icon: "figure.walk"),
                        CategoryOption(id: "delivery", name: "Delivery", icon: "car.fill"),
                        CategoryOption(id: "both", name: "Both", icon: "arrow.left.arrow.right")
                    ],
                    selection: .constant(CategoryOption(id: "pickup", name: "Pickup", icon: "figure.walk")),
                    columns: 3,
                    optionLabel: { $0.name },
                    optionIcon: { $0.icon },
                )
            }
            .padding()
        }
    }
}
