//
//  GlassToggle.swift
//  Foodshare
//
//  Liquid Glass v26 Toggle Component with ProMotion-optimized animations
//


#if !SKIP
import SwiftUI

// MARK: - Glass Toggle

struct GlassToggle: View {
    @Binding var isOn: Bool
    let label: String?
    let subtitle: String?
    let icon: String?
    let accentColor: Color

    init(
        isOn: Binding<Bool>,
        label: String? = nil,
        subtitle: String? = nil,
        icon: String? = nil,
        accentColor: Color = .DesignSystem.brandGreen,
    ) {
        _isOn = isOn
        self.label = label
        self.subtitle = subtitle
        self.icon = icon
        self.accentColor = accentColor
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
            HapticManager.selection()
        } label: {
            HStack(spacing: Spacing.sm) {
                // Icon
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isOn ? accentColor : Color.DesignSystem.textSecondary)
                        .frame(width: 32.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
                }

                // Labels
                if label != nil || subtitle != nil {
                    VStack(alignment: .leading, spacing: Spacing.xxxs) {
                        if let label {
                            Text(label)
                                .font(.DesignSystem.labelLarge)
                                .foregroundStyle(Color.DesignSystem.text)
                        }

                        if let subtitle {
                            Text(subtitle)
                                .font(.DesignSystem.caption)
                                .foregroundStyle(Color.DesignSystem.textSecondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()
                }

                // Toggle switch
                GlassToggleSwitch(isOn: $isOn, accentColor: accentColor)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Color.white.opacity(isOn ? 0.08 : 0.05))
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
                        isOn
                            ? accentColor.opacity(0.3)
                            : Color.white.opacity(0.1),
                        lineWidth: 1,
                    ),
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Toggle Switch (Standalone)

struct GlassToggleSwitch: View {
    @Binding var isOn: Bool
    let accentColor: Color

    @State private var isPressed = false

    init(isOn: Binding<Bool>, accentColor: Color = .DesignSystem.brandGreen) {
        _isOn = isOn
        self.accentColor = accentColor
    }

    private let width: CGFloat = 52
    private let height: CGFloat = 32
    private let thumbSize: CGFloat = 26

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            // Track
            Capsule()
                .fill(
                    isOn
                        ? LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing,
                        )
                        : LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.08)],
                            startPoint: .leading,
                            endPoint: .trailing,
                        ),
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isOn
                                ? accentColor.opacity(0.5)
                                : Color.white.opacity(0.15),
                            lineWidth: 1,
                        ),
                )
                .shadow(
                    color: isOn ? accentColor.opacity(0.4) : Color.clear,
                    radius: 8,
                    y: 0,
                )

            // Thumb
            Circle()
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom,
                            ),
                        ),
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1),
                )
                .frame(width: thumbSize, height: thumbSize)
                .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .padding(3)
        }
        .frame(width: width, height: height)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
            HapticManager.selection()
        }
        #if !SKIP
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isPressed = false
                    }
                },
        )
        #endif
    }
}

// MARK: - Glass Toggle Row (For Settings)

struct GlassToggleRow: View {
    @Binding var isOn: Bool
    let title: String
    let subtitle: String?
    let icon: String?
    let iconColor: Color

    init(
        isOn: Binding<Bool>,
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color = .DesignSystem.brandGreen,
    ) {
        _isOn = isOn
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Icon
            if let icon {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.small)
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
                    .font(.DesignSystem.bodyLarge)
                    .foregroundStyle(Color.DesignSystem.text)

                if let subtitle {
                    Text(subtitle)
                        .font(.DesignSystem.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
            }

            Spacer()

            // Toggle
            GlassToggleSwitch(isOn: $isOn, accentColor: iconColor)
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.white.opacity(0.04)),
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Standalone switches
                HStack(spacing: Spacing.lg) {
                    GlassToggleSwitch(isOn: .constant(true))
                    GlassToggleSwitch(isOn: .constant(false))
                    GlassToggleSwitch(isOn: .constant(true), accentColor: .DesignSystem.brandBlue)
                }

                // Full toggle with label
                GlassToggle(
                    isOn: .constant(true),
                    label: "Push Notifications",
                    subtitle: "Receive alerts for new listings nearby",
                    icon: "bell.fill",
                )

                GlassToggle(
                    isOn: .constant(false),
                    label: "Dark Mode",
                    icon: "moon.fill",
                    accentColor: .DesignSystem.brandPurple,
                )

                // Toggle rows for settings
                VStack(spacing: Spacing.xxs) {
                    GlassToggleRow(
                        isOn: .constant(true),
                        title: "New Messages",
                        subtitle: "Get notified when you receive messages",
                        icon: "message.fill",
                        iconColor: .DesignSystem.brandBlue,
                    )

                    GlassToggleRow(
                        isOn: .constant(true),
                        title: "Nearby Listings",
                        icon: "location.fill",
                        iconColor: .DesignSystem.brandOrange,
                    )

                    GlassToggleRow(
                        isOn: .constant(false),
                        title: "Email Digest",
                        subtitle: "Weekly summary of activity",
                        icon: "envelope.fill",
                        iconColor: .DesignSystem.brandGreen,
                    )
                }
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(Color.white.opacity(0.04))
                        #if !SKIP
                        .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                        #else
                        .background(Color.DesignSystem.glassSurface.opacity(0.15))
                        #endif
                )
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1),
                )
            }
            .padding()
        }
    }
}

#endif
