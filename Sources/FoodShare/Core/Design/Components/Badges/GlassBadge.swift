//
//  GlassBadge.swift
//  Foodshare
//
//  Liquid Glass v26 Badge Component
//


#if !SKIP
import SwiftUI

struct GlassBadge: View {
    let text: String
    let style: BadgeStyle

    enum BadgeStyle {
        case primary
        case success
        case warning
        case error
        case info
        case neutral

        var color: Color {
            switch self {
            case .primary: Color.DesignSystem.accentBlue
            case .success: Color.DesignSystem.success
            case .warning: Color.DesignSystem.warning
            case .error: Color.DesignSystem.error
            case .info: Color.DesignSystem.info
            case .neutral: Color.DesignSystem.textSecondary
            }
        }
    }

    init(_ text: String, style: BadgeStyle = .primary) {
        self.text = text
        self.style = style
    }

    var body: some View {
        Text(text)
            .font(.DesignSystem.labelSmall)
            .foregroundStyle(Color.white)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxxs)
            .background(
                ZStack {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    style.color,
                                    style.color.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom,
                            ),
                        )
                },
            )
            .shadow(color: style.color.opacity(0.3), radius: 6, y: 3)
            .accessibilityLabel(text)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        HStack(spacing: Spacing.sm) {
            GlassBadge("New", style: .primary)
            GlassBadge("Available", style: .success)
            GlassBadge("Expiring Soon", style: .warning)
        }

        HStack(spacing: Spacing.sm) {
            GlassBadge("Claimed", style: .error)
            GlassBadge("Info", style: .info)
            GlassBadge("Neutral", style: .neutral)
        }
    }
    .padding()
    .background(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
}

#endif
