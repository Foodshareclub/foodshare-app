//
//  GlassStatPill.swift
//  Foodshare
//
//  Liquid Glass v26 stat pill with animated value display
//  Enhanced version of DetailStatPill with number counter animation
//


#if !SKIP
import SwiftUI

struct GlassStatPill: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String?
    var isHighlighted = false
    var animateValue = false

    @State private var hasAppeared = false
    @State private var displayValue = ""

    init(
        icon: String,
        iconColor: Color,
        value: String,
        label: String? = nil,
        isHighlighted: Bool = false,
        animateValue: Bool = false,
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.value = value
        self.label = label
        self.isHighlighted = isHighlighted
        self.animateValue = animateValue
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(iconColor)

            // Value with optional animation
            if animateValue {
                Text(displayValue)
                    .font(.DesignSystem.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(isHighlighted ? iconColor : .DesignSystem.text)
                    #if !SKIP
                    .contentTransition(.numericText())
                    #endif
            } else {
                Text(value)
                    .font(.DesignSystem.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(isHighlighted ? iconColor : .DesignSystem.text)
            }

            // Optional label
            if let label {
                Text(label)
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(.DesignSystem.textTertiary)
                    #if !SKIP
                    .fixedSize(horizontal: true, vertical: false)
                    #endif
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(isHighlighted ? iconColor.opacity(0.12) : Color.DesignSystem.glassBackground)
                .overlay(
                    Capsule()
                        .stroke(isHighlighted ? iconColor.opacity(0.25) : Color.clear, lineWidth: 1),
                ),
        )
        #if !SKIP
        .accessibilityElement(children: AccessibilityChildBehavior.ignore)
        .accessibilityLabel("\(value) \(label ?? icon)")
        #endif
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.9)
        .onAppear {
            if animateValue {
                displayValue = "0"
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                    hasAppeared = true
                }
                // Animate the number after appearing
                Task { @MainActor in
                    #if SKIP
                    try? await Task.sleep(nanoseconds: UInt64(200 * 1_000_000))
                    #else
                    try? await Task.sleep(for: .milliseconds(200))
                    #endif
                    withAnimation(.interpolatingSpring(stiffness: 100, damping: 15)) {
                        displayValue = value
                    }
                }
            } else {
                displayValue = value
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    hasAppeared = true
                }
            }
        }
        .onChange(of: value) { _, newValue in
            if animateValue {
                withAnimation(.interpolatingSpring(stiffness: 100, damping: 15)) {
                    displayValue = newValue
                }
            } else {
                displayValue = newValue
            }
        }
    }
}

// MARK: - Convenience Initializers

extension GlassStatPill {
    /// Views stat pill
    static func views(_ count: Int, animate: Bool = false) -> GlassStatPill {
        GlassStatPill(
            icon: "eye.fill",
            iconColor: .DesignSystem.textSecondary,
            value: "\(count)",
            label: nil,
            animateValue: animate,
        )
    }

    /// Likes stat pill
    static func likes(_ count: Int, isLiked: Bool = false, animate: Bool = false) -> GlassStatPill {
        GlassStatPill(
            icon: isLiked ? "heart.fill" : "heart",
            iconColor: isLiked ? .DesignSystem.error : .DesignSystem.textSecondary,
            value: "\(count)",
            label: nil,
            isHighlighted: isLiked,
            animateValue: animate,
        )
    }

    /// Distance stat pill
    static func distance(_ distance: String) -> GlassStatPill {
        GlassStatPill(
            icon: "location.fill",
            iconColor: .DesignSystem.brandBlue,
            value: distance,
            label: nil,
            isHighlighted: true,
        )
    }

    /// Comments stat pill
    static func comments(_ count: Int, animate: Bool = false) -> GlassStatPill {
        GlassStatPill(
            icon: "bubble.right.fill",
            iconColor: .DesignSystem.brandGreen,
            value: "\(count)",
            label: nil,
            animateValue: animate,
        )
    }

    /// Rating stat pill
    static func rating(_ rating: Double, reviewCount: Int? = nil) -> GlassStatPill {
        GlassStatPill(
            icon: "star.fill",
            iconColor: .yellow,
            value: String(format: "%.1f", rating),
            label: reviewCount.map { "(\($0))" },
            isHighlighted: true,
        )
    }
}

// MARK: - Stat Pill Row

struct GlassStatPillRow: View {
    let stats: [GlassStatPillData]
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        HStack(spacing: Spacing.md) {
            ForEach(stats) { stat in
                GlassStatPill(
                    icon: stat.icon,
                    iconColor: stat.iconColor,
                    value: stat.value,
                    label: stat.label,
                    isHighlighted: stat.isHighlighted,
                    animateValue: stat.animateValue,
                )
            }

            if alignment == .leading {
                Spacer()
            }
        }
    }
}

struct GlassStatPillData: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let value: String
    var label: String?
    var isHighlighted = false
    var animateValue = false
}

// MARK: - Preview

#Preview {
    VStack(spacing: Spacing.lg) {
        // Individual pills
        HStack(spacing: Spacing.md) {
            GlassStatPill.views(1234, animate: true)
            GlassStatPill.likes(56, isLiked: true)
            GlassStatPill.distance("2.3 km")
        }

        HStack(spacing: Spacing.md) {
            GlassStatPill.comments(42)
            GlassStatPill.rating(4.8, reviewCount: 15)
        }

        // Custom pill
        GlassStatPill(
            icon: "leaf.fill",
            iconColor: .DesignSystem.brandGreen,
            value: "12",
            label: "items shared",
            isHighlighted: true,
            animateValue: true,
        )
    }
    .padding()
    .background(Color.DesignSystem.background)
}

#endif
