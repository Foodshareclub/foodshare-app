//
//  GlassForm.swift
//  Foodshare
//
//  Liquid Glass v26 Form Container Component with grouped sections
//

import FoodShareDesignSystem
import SwiftUI

// MARK: - Glass Form

struct GlassForm<Content: View>: View {
    let title: String?
    let subtitle: String?
    @ViewBuilder let content: () -> Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    if let title {
                        Text(title)
                            .font(.DesignSystem.headlineSmall)
                            .foregroundStyle(Color.DesignSystem.text)
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(.DesignSystem.bodySmall)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                }
                .padding(.horizontal, Spacing.sm)
            }

            // Content
            VStack(spacing: Spacing.sm) {
                content()
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Color.white.opacity(0.05))
                    .background(.ultraThinMaterial),
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
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
        }
    }
}

// MARK: - Glass Form Section

struct GlassFormSection<Content: View>: View {
    let title: String?
    let icon: String?
    let iconColor: Color
    @ViewBuilder let content: () -> Content

    init(
        title: String? = nil,
        icon: String? = nil,
        iconColor: Color = .DesignSystem.brandGreen,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Section header
            if title != nil || icon != nil {
                HStack(spacing: Spacing.xs) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(iconColor)
                    }

                    if let title {
                        Text(title)
                            .font(.DesignSystem.labelLarge)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                }
            }

            // Section content
            VStack(spacing: Spacing.xs) {
                content()
            }
        }
    }
}

// MARK: - Glass Form Row

struct GlassFormRow<Content: View>: View {
    let label: String
    let icon: String?
    @ViewBuilder let content: () -> Content

    init(
        label: String,
        icon: String? = nil,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.label = label
        self.icon = icon
        self.content = content
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .frame(width: 24)
            }

            Text(label)
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.text)

            Spacer()

            content()
        }
        .padding(.vertical, Spacing.xxs)
    }
}

// MARK: - Glass Form Divider

struct GlassFormDivider: View {
    let style: DividerStyle

    enum DividerStyle {
        case solid
        case gradient
        case dotted
    }

    init(style: DividerStyle = .gradient) {
        self.style = style
    }

    var body: some View {
        switch style {
        case .solid:
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)

        case .gradient:
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.15),
                            Color.clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing,
                    ),
                )
                .frame(height: 1)

        case .dotted:
            GeometryReader { geometry in
                Path { path in
                    let dashWidth: CGFloat = 4
                    let gapWidth: CGFloat = 4
                    var x: CGFloat = 0
                    while x < geometry.size.width {
                        path.move(to: CGPoint(x: x, y: 0.5))
                        path.addLine(to: CGPoint(x: min(x + dashWidth, geometry.size.width), y: 0.5))
                        x += dashWidth + gapWidth
                    }
                }
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
            }
            .frame(height: 1)
        }
    }
}

// MARK: - Glass Info Row

struct GlassInfoRow: View {
    let label: String
    let value: String
    let icon: String?
    let valueColor: Color

    init(
        label: String,
        value: String,
        icon: String? = nil,
        valueColor: Color = .DesignSystem.text,
    ) {
        self.label = label
        self.value = value
        self.icon = icon
        self.valueColor = valueColor
    }

    var body: some View {
        HStack {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .frame(width: 24)
            }

            Text(label)
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.textSecondary)

            Spacer()

            Text(value)
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(valueColor)
        }
        .padding(.vertical, Spacing.xxs)
    }
}

// MARK: - Glass Action Row

struct GlassActionRow: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let iconColor: Color
    let showChevron: Bool
    let action: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color = .DesignSystem.brandGreen,
        showChevron: Bool = true,
        action: @escaping () -> Void,
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.showChevron = showChevron
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                // Icon
                if let icon {
                    ZStack {
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .fill(iconColor.opacity(0.15))
                            .frame(width: 36, height: 36)

                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(iconColor)
                    }
                }

                // Labels
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.DesignSystem.bodyLarge)
                        .foregroundStyle(Color.DesignSystem.text)

                    if let subtitle {
                        Text(subtitle)
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Chevron
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.DesignSystem.textTertiary)
                }
            }
            .padding(.vertical, Spacing.xxs)
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.98, haptic: .light))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Basic form
                GlassForm(title: "Personal Information", subtitle: "Update your profile details") {
                    GlassTextField("Full Name", text: .constant("John Doe"), icon: "person.fill")
                    GlassTextField("Email", text: .constant("john@example.com"), icon: "envelope.fill")
                    GlassTextField("Phone", text: .constant("+1 555 0123"), icon: "phone.fill")
                }

                // Form with sections
                GlassForm {
                    GlassFormSection(title: "ACCOUNT", icon: "person.circle.fill") {
                        GlassInfoRow(label: "Username", value: "@johndoe", icon: "at")
                        GlassFormDivider()
                        GlassInfoRow(label: "Member Since", value: "Jan 2024", icon: "calendar")
                    }

                    GlassFormDivider(style: .gradient)

                    GlassFormSection(title: "PREFERENCES", icon: "gearshape.fill") {
                        GlassActionRow(
                            title: "Notifications",
                            subtitle: "Manage your alerts",
                            icon: "bell.fill",
                            iconColor: .DesignSystem.brandOrange,
                        ) {}

                        GlassActionRow(
                            title: "Privacy",
                            subtitle: "Control your data",
                            icon: "lock.fill",
                            iconColor: .DesignSystem.brandBlue,
                        ) {}
                    }
                }

                // Settings-style form
                GlassForm(title: "Settings") {
                    GlassToggleRow(
                        isOn: .constant(true),
                        title: "Push Notifications",
                        icon: "bell.badge.fill",
                        iconColor: .DesignSystem.brandOrange,
                    )

                    GlassFormDivider()

                    GlassToggleRow(
                        isOn: .constant(false),
                        title: "Location Services",
                        subtitle: "Allow access to your location",
                        icon: "location.fill",
                        iconColor: .DesignSystem.brandBlue,
                    )
                }
            }
            .padding()
        }
    }
}
