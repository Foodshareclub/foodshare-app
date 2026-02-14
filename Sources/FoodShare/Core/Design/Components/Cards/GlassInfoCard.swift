//
//  GlassInfoCard.swift
//  Foodshare
//
//  Advanced Liquid Glass v26 Info Card with animations
//

import SwiftUI
import FoodShareDesignSystem

struct GlassInfoCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color
    let action: (() -> Void)?

    @State private var isPressed = false

    init(
        icon: String,
        title: String,
        subtitle: String,
        accentColor: Color = Color.DesignSystem.accentBlue,
        action: (() -> Void)? = nil,
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.accentColor = accentColor
        self.action = action
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
        .accessibilityLabel("\(title). \(subtitle)")
        .if(action != nil) { view in
            view.accessibilityHint("Double tap to open")
        }
    }

    private var cardContent: some View {
        HStack(spacing: Spacing.md) {
            // Icon with glow
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .blur(radius: 10)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor,
                                accentColor.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
            .shadow(color: accentColor.opacity(0.4), radius: 12, y: 6)

            // Content
            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(title)
                    .font(.DesignSystem.titleMedium)
                    .foregroundStyle(Color.DesignSystem.text)

                Text(subtitle)
                    .font(.DesignSystem.bodySmall)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }
        }
        .padding(Spacing.md)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Spacing.radiusLG)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: Spacing.radiusLG)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.glassHighlight,
                                Color.DesignSystem.glassBorder,
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                        lineWidth: 1,
                    )

                RoundedRectangle(cornerRadius: Spacing.radiusLG)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center,
                        ),
                    )
            },
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        GlassInfoCard(
            icon: "leaf.circle.fill",
            title: "24 Items Shared",
            subtitle: "You've helped reduce food waste",
            accentColor: Color.DesignSystem.success,
        ) {
            print("Tapped")
        }

        GlassInfoCard(
            icon: "star.fill",
            title: "4.8 Rating",
            subtitle: "Based on 15 reviews",
            accentColor: Color.DesignSystem.warning,
        )

        GlassInfoCard(
            icon: "heart.fill",
            title: "12 Favorites",
            subtitle: "Items you've saved",
            accentColor: Color.DesignSystem.error,
        )
    }
    .padding()
    .background(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
}
