//
//  DesignSystemShowcase.swift
//  Foodshare
//
//  Liquid Glass v26 Design System Showcase
//  Use this view to preview all design components
//


#if !SKIP
import SwiftUI

struct DesignSystemShowcase: View {
    @Environment(\.translationService) private var t
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGlassBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        // Header
                        VStack(spacing: Spacing.xs) {
                            Text("Liquid Glass v26")
                                .font(.DesignSystem.displayMedium)
                                .gradientText()

                            Text(t.t("design.showcase_title"))
                                .font(.DesignSystem.bodyLarge)
                                .foregroundStyle(Color.DesignSystem.textSecondary)
                        }
                        .padding(.top, Spacing.xl)

                        // Colors Section
                        ShowcaseSection(title: "Colors") {
                            VStack(spacing: Spacing.sm) {
                                ColorRow(title: "Primary", color: Color.DesignSystem.primary)
                                ColorRow(title: "Brand Blue", color: Color.DesignSystem.brandBlue)
                                ColorRow(title: "Brand Orange", color: Color.DesignSystem.brandOrange)
                                ColorRow(title: "Success", color: Color.DesignSystem.success)
                                ColorRow(title: "Warning", color: Color.DesignSystem.warning)
                                ColorRow(title: "Error", color: Color.DesignSystem.error)
                                ColorRow(title: "Glass Background", color: Color.DesignSystem.glassBackground)
                                ColorRow(title: "Glass Border", color: Color.DesignSystem.glassBorder)
                            }
                        }

                        // Typography Section
                        ShowcaseSection(title: "Typography") {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text("Display Large")
                                    .font(.DesignSystem.displayLarge)
                                Text("Headline Large")
                                    .font(.DesignSystem.headlineLarge)
                                Text("Title Large")
                                    .font(.DesignSystem.titleLarge)
                                Text("Body Large - Regular text for content")
                                    .font(.DesignSystem.bodyLarge)
                                Text("Label Medium - For buttons and labels")
                                    .font(.DesignSystem.labelMedium)
                            }
                            .foregroundStyle(Color.DesignSystem.text)
                        }

                        // Buttons Section
                        ShowcaseSection(title: "Buttons") {
                            VStack(spacing: Spacing.sm) {
                                GlassButton("Primary Button", icon: "star.fill", style: .primary) {}
                                GlassButton("Secondary Button", icon: "heart.fill", style: .secondary) {}
                                GlassButton("Outline Button", icon: "bookmark", style: .outline) {}
                                GlassButton("Ghost Button", style: .ghost) {}
                            }
                        }

                        // Badges Section
                        ShowcaseSection(title: "Badges") {
                            HStack(spacing: Spacing.sm) {
                                GlassBadge("New", style: .primary)
                                GlassBadge("Available", style: .success)
                                GlassBadge("Expiring", style: .warning)
                                GlassBadge("Claimed", style: .error)
                            }
                        }

                        // Cards Section
                        ShowcaseSection(title: "Cards") {
                            VStack(spacing: Spacing.md) {
                                GlassInfoCard(
                                    icon: "leaf.circle.fill",
                                    title: "Info Card",
                                    subtitle: "With icon and description",
                                    accentColor: Color.DesignSystem.success,
                                )

                                // FoodItemCard(foodItem: .mock) {}
                            }
                        }

                        // Inputs Section
                        ShowcaseSection(title: "Text Fields") {
                            VStack(spacing: Spacing.sm) {
                                GlassTextField("Email", text: .constant(""), icon: "envelope.fill")
                                GlassTextField("Password", text: .constant(""), icon: "lock.fill", isSecure: true)
                            }
                        }

                        // Dividers Section
                        ShowcaseSection(title: "Dividers") {
                            VStack(spacing: Spacing.md) {
                                GlassDivider(style: .horizontal)
                                GlassDivider(style: .gradient)
                                GlassDivider(style: .dotted)
                            }
                        }

                        // Modifiers Section
                        ShowcaseSection(title: "Effects") {
                            VStack(spacing: Spacing.md) {
                                Text("Shimmer Effect")
                                    .font(.DesignSystem.headlineSmall)
                                    .foregroundStyle(Color.DesignSystem.primary)
                                    .shimmer()

                                Text("Glow Effect")
                                    .font(.DesignSystem.headlineSmall)
                                    .foregroundStyle(Color.DesignSystem.accentPurple)
                                    .glow()

                                Text("Floating Animation")
                                    .font(.DesignSystem.headlineSmall)
                                    .foregroundStyle(Color.DesignSystem.brandBlue)
                                    .floating()

                                Text("Pulse Animation")
                                    .font(.DesignSystem.headlineSmall)
                                    .foregroundStyle(Color.DesignSystem.success)
                                    .pulse()
                            }
                        }

                        Spacer()
                            .frame(height: 100.0)
                    }
                    .padding(.horizontal, Spacing.md)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Showcase Section

struct ShowcaseSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title)
                .font(.DesignSystem.headlineMedium)
                .foregroundStyle(Color.DesignSystem.text)

            content()
                .padding(Spacing.md)
                .glassEffect()
        }
    }
}

// MARK: - Color Row

struct ColorRow: View {
    let title: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 40.0, height: 40)
                .shadow(color: color.opacity(0.4), radius: 8, y: 4)

            Text(title)
                .font(.DesignSystem.bodyLarge)
                .foregroundStyle(Color.DesignSystem.text)

            Spacer()

            Text(title.uppercased())
                .font(.DesignSystem.labelSmall)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
    }
}

#Preview {
    DesignSystemShowcase()
}

#endif
