//
//  GlassExpander.swift
//  Foodshare
//
//  Liquid Glass v26 Expander/Accordion Component with smooth animations
//


#if !SKIP
import SwiftUI

// MARK: - Glass Expander

struct GlassExpander<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let iconColor: Color
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    @State private var contentHeight: CGFloat = 0

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color = .DesignSystem.brandGreen,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        _isExpanded = isExpanded
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
                HapticManager.light()
            } label: {
                HStack(spacing: Spacing.sm) {
                    // Icon
                    if let icon {
                        ZStack {
                            Circle()
                                .fill(iconColor.opacity(0.15))
                                .frame(width: 36.0, height: 36)

                            Image(systemName: icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(iconColor)
                        }
                    }

                    // Labels
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.DesignSystem.labelLarge)
                            .foregroundStyle(Color.DesignSystem.text)

                        if let subtitle {
                            Text(subtitle)
                                .font(.DesignSystem.caption)
                                .foregroundStyle(Color.DesignSystem.textSecondary)
                                .lineLimit(isExpanded ? nil : 1)
                        }
                    }

                    Spacer()

                    // Chevron
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(Spacing.md)
            }
            .buttonStyle(.plain)

            // Expandable content
            if isExpanded {
                VStack(spacing: 0) {
                    // Divider
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing,
                            ),
                        )
                        .frame(height: 1.0)

                    // Content
                    content()
                        .padding(Spacing.md)
                }
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top)),
                    ),
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(Color.white.opacity(isExpanded ? 0.08 : 0.05))
                #if !SKIP
                .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .background(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(
                    isExpanded
                        ? iconColor.opacity(0.2)
                        : Color.white.opacity(0.1),
                    lineWidth: 1,
                ),
        )
        .shadow(
            color: isExpanded ? iconColor.opacity(0.1) : Color.clear,
            radius: 10,
            y: 4,
        )
    }
}

// MARK: - Glass Accordion

#if !SKIP
struct GlassAccordion<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let titleKeyPath: KeyPath<Item, String>
    let subtitleKeyPath: KeyPath<Item, String?>?
    let iconKeyPath: KeyPath<Item, String?>?
    let allowMultipleExpanded: Bool
    @ViewBuilder let content: (Item) -> Content

    @State private var expandedItems: Set<Item.ID> = []

    init(
        items: [Item],
        title: KeyPath<Item, String>,
        subtitle: KeyPath<Item, String?>? = nil,
        icon: KeyPath<Item, String?>? = nil,
        allowMultipleExpanded: Bool = false,
        @ViewBuilder content: @escaping (Item) -> Content,
    ) {
        self.items = items
        titleKeyPath = title
        subtitleKeyPath = subtitle
        iconKeyPath = icon
        self.allowMultipleExpanded = allowMultipleExpanded
        self.content = content
    }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ForEach(items) { item in
                let isExpanded = expandedItems.contains(item.id)

                GlassExpander(
                    title: item[keyPath: titleKeyPath],
                    subtitle: subtitleKeyPath.flatMap { item[keyPath: $0] },
                    icon: iconKeyPath.flatMap { item[keyPath: $0] },
                    isExpanded: Binding(
                        get: { isExpanded },
                        set: { newValue in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if newValue {
                                    if !allowMultipleExpanded {
                                        expandedItems.removeAll()
                                    }
                                    expandedItems.insert(item.id)
                                } else {
                                    expandedItems.remove(item.id)
                                }
                            }
                        },
                    ),
                ) {
                    content(item)
                }
            }
        }
    }
}
#endif

// MARK: - Glass FAQ Item

struct GlassFAQItem: View {
    let question: String
    let answer: String
    @Binding var isExpanded: Bool

    var body: some View {
        GlassExpander(
            title: question,
            icon: "questionmark.circle.fill",
            iconColor: .DesignSystem.brandBlue,
            isExpanded: $isExpanded,
        ) {
            Text(answer)
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.textSecondary)
                #if !SKIP
                .fixedSize(horizontal: false, vertical: true)
                #endif
        }
    }
}

// MARK: - Glass Collapsible Section

struct GlassCollapsibleSection<Header: View, Content: View>: View {
    @Binding var isExpanded: Bool
    let accentColor: Color
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    init(
        isExpanded: Binding<Bool>,
        accentColor: Color = .DesignSystem.brandGreen,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        _isExpanded = isExpanded
        self.accentColor = accentColor
        self.header = header
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom header with toggle
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
                HapticManager.light()
            } label: {
                HStack {
                    header()

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .frame(width: 24.0, height: 24)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08)),
                        )
                }
                .padding(Spacing.md)
            }
            .buttonStyle(.plain)

            // Content
            if isExpanded {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1.0)

                    content()
                        .padding(Spacing.md)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(Color.white.opacity(0.05))
                #if !SKIP
                .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .background(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(
                    isExpanded ? accentColor.opacity(0.2) : Color.white.opacity(0.1),
                    lineWidth: 1,
                ),
        )
    }
}

// MARK: - Preview Helpers

private struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
    let icon: String?
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Single expander
                GlassExpander(
                    title: "What is Foodshare?",
                    subtitle: "Learn about our mission",
                    icon: "leaf.fill",
                    iconColor: .DesignSystem.brandGreen,
                    isExpanded: .constant(true),
                ) {
                    Text(
                        "Foodshare is a community-driven platform that connects people with surplus food to those who need it, reducing waste and building stronger communities.",
                    )
                    .font(.DesignSystem.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                }

                // Collapsed expander
                GlassExpander(
                    title: "How does it work?",
                    icon: "gearshape.fill",
                    iconColor: .DesignSystem.brandBlue,
                    isExpanded: .constant(false),
                ) {
                    Text("Placeholder content")
                }

                // FAQ items
                VStack(spacing: Spacing.xs) {
                    Text("Frequently Asked Questions")
                        .font(.DesignSystem.headlineSmall)
                        .foregroundStyle(Color.DesignSystem.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.xxs)

                    GlassFAQItem(
                        question: "Is Foodshare free to use?",
                        answer: "Yes! Foodshare is completely free for all users. Our mission is to reduce food waste and help communities.",
                        isExpanded: .constant(false),
                    )

                    GlassFAQItem(
                        question: "How do I post food?",
                        answer: "Simply tap the + button, take a photo, add details about your food item, and post. Nearby users will be able to see and request it.",
                        isExpanded: .constant(false),
                    )
                }

                // Collapsible section with custom header
                GlassCollapsibleSection(isExpanded: .constant(true)) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "shield.fill")
                            .foregroundStyle(Color.DesignSystem.brandOrange)
                        Text("Safety Guidelines")
                            .font(.DesignSystem.labelLarge)
                            .foregroundStyle(Color.DesignSystem.text)
                    }
                } content: {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Label("Always meet in public places", systemImage: "location.fill")
                        Label("Check food for freshness", systemImage: "checkmark.circle.fill")
                        Label("Trust your instincts", systemImage: "heart.fill")
                    }
                    .font(.DesignSystem.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                }
            }
            .padding()
        }
    }
}

#endif
