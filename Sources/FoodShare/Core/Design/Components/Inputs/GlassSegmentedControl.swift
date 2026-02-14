//
//  GlassSegmentedControl.swift
//  Foodshare
//
//  Liquid Glass v26 Segmented Control with animated sliding indicator
//  Premium component with 120Hz ProMotion optimization
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Glass Segmented Control

struct GlassSegmentedControl<T: Hashable>: View {
    @Binding var selection: T
    let options: [T]
    let label: (T) -> String

    @Namespace private var segmentNamespace
    @State private var segmentWidths: [T: CGFloat] = [:]
    @Environment(\.isEnabled) private var isEnabled

    init(
        selection: Binding<T>,
        options: [T],
        label: @escaping (T) -> String
    ) {
        self._selection = selection
        self.options = options
        self.label = label
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                segmentButton(for: option)
            }
        }
        .padding(Spacing.xxxs)
        .background(
            ZStack {
                // Glass background
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(.ultraThinMaterial)

                // Inner shadow for depth
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(Color.black.opacity(0.05))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
        .opacity(isEnabled ? 1.0 : 0.6)
    }

    // MARK: - Segment Button

    private func segmentButton(for option: T) -> some View {
        Button {
            HapticFeedback.light()
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                selection = option
            }
        } label: {
            Text(label(option))
                .font(.DesignSystem.labelMedium)
                .fontWeight(selection == option ? .semibold : .medium)
                .foregroundColor(
                    selection == option
                        ? Color.DesignSystem.text
                        : Color.DesignSystem.textSecondary
                )
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: SegmentWidthPreferenceKey.self,
                                value: [option: geo.size.width]
                            )
                    }
                )
                .background {
                    if selection == option {
                        selectedBackground
                            .matchedGeometryEffect(id: "selectedSegment", in: segmentNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .onPreferenceChange(SegmentWidthPreferenceKey.self) { prefs in
            for (key, value) in prefs {
                if let typedKey = key as? T {
                    segmentWidths[typedKey] = value
                }
            }
        }
    }

    // MARK: - Selected Background

    private var selectedBackground: some View {
        RoundedRectangle(cornerRadius: CornerRadius.small)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.95),
                        Color.white.opacity(0.85)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.glassHighlight,
                                Color.DesignSystem.glassBorder.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
    }
}

// MARK: - Preference Key for Segment Widths

private struct SegmentWidthPreferenceKey: PreferenceKey {
    static var defaultValue: [AnyHashable: CGFloat] = [:]

    static func reduce(value: inout [AnyHashable: CGFloat], nextValue: () -> [AnyHashable: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Glass Segmented Control (Raw Representable)

extension GlassSegmentedControl where T: CaseIterable & RawRepresentable, T.RawValue == String {
    /// Convenience initializer for enums with String raw values
    init(selection: Binding<T>) {
        self.init(
            selection: selection,
            options: Array(T.allCases),
            label: { $0.rawValue.capitalized }
        )
    }
}

// MARK: - Compact Variant

struct GlassSegmentedControlCompact<T: Hashable>: View {
    @Binding var selection: T
    let options: [T]
    let icon: (T) -> String

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(options, id: \.self) { option in
                Button {
                    HapticFeedback.light()
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                        selection = option
                    }
                } label: {
                    Image(systemName: icon(option))
                        .font(.system(size: 16, weight: selection == option ? .semibold : .medium))
                        .foregroundColor(
                            selection == option
                                ? Color.DesignSystem.accentBlue
                                : Color.DesignSystem.textSecondary
                        )
                        .frame(width: 40, height: 40)
                        .background {
                            if selection == option {
                                Circle()
                                    .fill(Color.DesignSystem.accentBlue.opacity(0.15))
                                    .matchedGeometryEffect(id: "compact", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.xxxs)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Previews

#Preview("Standard") {
    @Previewable @State var selection = "All"

    VStack(spacing: Spacing.xl) {
        GlassSegmentedControl(
            selection: $selection,
            options: ["All", "Nearby", "Favorites"],
            label: { $0 }
        )

        Text("Selected: \(selection)")
            .font(.DesignSystem.bodyMedium)
            .foregroundColor(.DesignSystem.textSecondary)
    }
    .padding()
    .background(
        LinearGradient(
            colors: [Color.DesignSystem.accentBlue.opacity(0.3), Color.DesignSystem.accentCyan.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}

#Preview("Compact Icons") {
    @Previewable @State var selection = "list"

    VStack(spacing: Spacing.xl) {
        GlassSegmentedControlCompact(
            selection: $selection,
            options: ["list", "grid", "map"],
            icon: {
                switch $0 {
                case "list": return "list.bullet"
                case "grid": return "square.grid.2x2"
                case "map": return "map"
                default: return "questionmark"
                }
            }
        )

        Text("View: \(selection)")
            .font(.DesignSystem.bodyMedium)
    }
    .padding()
    .background(Color.DesignSystem.background)
}

#Preview("Dark Mode") {
    @Previewable @State var selection = "Active"

    GlassSegmentedControl(
        selection: $selection,
        options: ["Active", "Pending", "Completed"],
        label: { $0 }
    )
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
