//
//  GlassDetailSection.swift
//  Foodshare
//
//  Unified detail view section with built-in staggered animation
//  Consolidates detail section patterns across the app
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - GlassDetailSection

/// A detail view section container with staggered appearance animation and optional Metal glow
struct GlassDetailSection<Header: View, Content: View>: View {
    let index: Int
    @Binding var sectionsAppeared: Bool
    let useMetalGlow: Bool
    let glowColor: Color
    let cornerRadius: CGFloat
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Initialization

    /// Creates a new GlassDetailSection
    /// - Parameters:
    ///   - index: The section index for staggered animation timing
    ///   - sectionsAppeared: Binding to track when all sections should appear
    ///   - useMetalGlow: Whether to apply Metal glow effect
    ///   - glowColor: Color for the glow effect
    ///   - cornerRadius: Corner radius for the section container
    ///   - header: Header view builder
    ///   - content: Content view builder
    init(
        index: Int,
        sectionsAppeared: Binding<Bool>,
        useMetalGlow: Bool = false,
        glowColor: Color = Color.DesignSystem.brandGreen,
        cornerRadius: CGFloat = CornerRadius.large,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.index = index
        self._sectionsAppeared = sectionsAppeared
        self.useMetalGlow = useMetalGlow
        self.glowColor = glowColor
        self.cornerRadius = cornerRadius
        self.header = header
        self.content = content
    }

    private var animationDelay: Double {
        reduceMotion ? 0 : Double(index) * 0.08
    }

    private var shouldAnimate: Bool {
        !reduceMotion && sectionsAppeared
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header()

            content()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.white.opacity(0.05))
                .background(.ultraThinMaterial),
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.06),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                    lineWidth: 1,
                ),
        )
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .scaleEffect(hasAppeared ? 1 : 0.98)
        .modifier(ConditionalMetalGlow(enabled: useMetalGlow, color: glowColor))
        .onAppear {
            guard !hasAppeared else { return }
            withAnimation(
                .spring(response: 0.5, dampingFraction: 0.85)
                    .delay(animationDelay),
            ) {
                hasAppeared = true
            }
        }
        .onChange(of: sectionsAppeared) { _, newValue in
            if newValue, !hasAppeared {
                withAnimation(
                    .spring(response: 0.5, dampingFraction: 0.85)
                        .delay(animationDelay),
                ) {
                    hasAppeared = true
                }
            }
        }
    }
}

// MARK: - Conditional Metal Glow Modifier

private struct ConditionalMetalGlow: ViewModifier {
    let enabled: Bool
    let color: Color

    func body(content: Content) -> some View {
        if enabled {
            content.metalEffect(.glow(color: color, intensity: 0.3))
        } else {
            content
        }
    }
}

// MARK: - Convenience Initializers

extension GlassDetailSection where Header == EmptyView {
    /// Creates a section without a header
    init(
        index: Int,
        sectionsAppeared: Binding<Bool>,
        useMetalGlow: Bool = false,
        glowColor: Color = Color.DesignSystem.brandGreen,
        cornerRadius: CGFloat = CornerRadius.large,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.init(
            index: index,
            sectionsAppeared: sectionsAppeared,
            useMetalGlow: useMetalGlow,
            glowColor: glowColor,
            cornerRadius: cornerRadius,
            header: { EmptyView() },
            content: content,
        )
    }
}

// MARK: - GlassDetailSection with Title

extension GlassDetailSection {
    /// Creates a section with a GlassSectionHeader
    static func withTitle(
        _ title: String,
        icon: String,
        iconColors: [Color],
        index: Int,
        sectionsAppeared: Binding<Bool>,
        useMetalGlow: Bool = false,
        action: (() -> Void)? = nil,
        actionLabel: String? = nil,
        actionIcon: String? = nil,
        @ViewBuilder content: @escaping () -> Content,
    ) -> GlassDetailSection<GlassSectionHeader, Content> {
        GlassDetailSection<GlassSectionHeader, Content>(
            index: index,
            sectionsAppeared: sectionsAppeared,
            useMetalGlow: useMetalGlow,
            glowColor: iconColors.first ?? .DesignSystem.brandGreen,
            header: {
                GlassSectionHeader(
                    title,
                    icon: icon,
                    iconColors: iconColors,
                    action: action,
                    actionLabel: actionLabel,
                    actionIcon: actionIcon,
                )
            },
            content: content,
        )
    }
}

// MARK: - Preview

#Preview("GlassDetailSection") {
    @Previewable @State var sectionsAppeared = false

    ScrollView {
        VStack(spacing: Spacing.md) {
            GlassDetailSection(
                index: 0,
                sectionsAppeared: $sectionsAppeared,
                header: {
                    GlassSectionHeader.details("Item Details")
                },
                content: {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Image(systemName: "leaf.fill")
                                .foregroundColor(.DesignSystem.brandGreen)
                            Text("Category: Fresh Produce")
                                .font(.DesignSystem.bodyMedium)
                                .foregroundColor(.DesignSystem.text)
                        }
                        Divider()
                        HStack {
                            Image(systemName: "number")
                                .foregroundColor(.DesignSystem.brandBlue)
                            Text("Quantity: 5 items")
                                .font(.DesignSystem.bodyMedium)
                                .foregroundColor(.DesignSystem.text)
                        }
                        Divider()
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.orange)
                            Text("Expires: Tomorrow")
                                .font(.DesignSystem.bodyMedium)
                                .foregroundColor(.orange)
                        }
                    }
                },
            )

            GlassDetailSection(
                index: 1,
                sectionsAppeared: $sectionsAppeared,
                useMetalGlow: true,
                glowColor: .orange,
                header: {
                    GlassSectionHeader.location("Pickup Location")
                },
                content: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red, .orange],
                                    startPoint: .top,
                                    endPoint: .bottom,
                                ),
                            )

                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("123 Main Street")
                                .font(.DesignSystem.bodyLarge)
                                .foregroundColor(.DesignSystem.text)
                            Text("San Francisco, CA 94102")
                                .font(.DesignSystem.bodySmall)
                                .foregroundColor(.DesignSystem.textSecondary)
                        }
                    }
                },
            )

            GlassDetailSection(
                index: 2,
                sectionsAppeared: $sectionsAppeared,
                header: {
                    GlassSectionHeader.reviews(
                        "Reviews",
                        action: {},
                        actionLabel: "Write Review",
                        actionIcon: "star.fill",
                    )
                },
                content: {
                    VStack(spacing: Spacing.sm) {
                        HStack {
                            ForEach(0 ..< 5) { index in
                                Image(systemName: index < 4 ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                            }
                            Text("4.0")
                                .font(.DesignSystem.labelLarge)
                                .foregroundColor(.DesignSystem.text)
                            Text("(24 reviews)")
                                .font(.DesignSystem.caption)
                                .foregroundColor(.DesignSystem.textSecondary)
                        }
                    }
                },
            )

            // Section without header
            GlassDetailSection(
                index: 3,
                sectionsAppeared: $sectionsAppeared,
            ) {
                Text("This section has no header")
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.textSecondary)
            }
        }
        .padding(Spacing.md)
    }
    .background(Color.DesignSystem.background)
    .onAppear {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            sectionsAppeared = true
        }
    }
}
