//
//  GlassCard.swift
//  Foodshare
//
//  Glassmorphism card component - Core of Liquid Glass v26 design system
//

import SwiftUI
import FoodShareDesignSystem

/// Reusable glass card component with frosted glass effect
struct GlassCard<Content: View>: View {
    // MARK: - Properties

    private let content: Content
    private let cornerRadius: CGFloat
    private let shadow: GlassShadow

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    // MARK: - Initialization

    init(
        cornerRadius: CGFloat = 12,
        shadow: GlassShadow = .medium,
        @ViewBuilder content: () -> Content,
    ) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.shadow = shadow
    }

    // MARK: - Body

    var body: some View {
        content
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
            )
            .shadow(
                color: .black.opacity(shadow.opacity),
                radius: shadow.radius,
                x: 0,
                y: shadow.offset,
            )
            .drawingGroup() // GPU rasterization for 120Hz ProMotion
            .accessibilityElement(children: .contain)
    }

    // MARK: - Private Views

    @ViewBuilder
    private var cardBackground: some View {
        if reduceTransparency {
            // Solid background for accessibility
            Color(uiColor: .systemBackground)
                .opacity(0.95)
        } else {
            // Glass effect using native material
            Color.clear
                .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Shadow Definitions

enum GlassShadow {
    case subtle
    case medium
    case strong

    var opacity: Double {
        switch self {
        case .subtle: 0.1
        case .medium: 0.15
        case .strong: 0.2
        }
    }

    var radius: CGFloat {
        switch self {
        case .subtle: 10
        case .medium: 20
        case .strong: 30
        }
    }

    var offset: CGFloat {
        switch self {
        case .subtle: 4
        case .medium: 8
        case .strong: 12
        }
    }
}

// MARK: - View Extension

extension View {
    /// Apply glass card effect to any view
    func glassCard(
        cornerRadius: CGFloat = 12,
        shadow: GlassShadow = .medium,
    ) -> some View {
        GlassCard(cornerRadius: cornerRadius, shadow: shadow) {
            self
        }
    }
}

// MARK: - Previews

#Preview("Glass Card") {
    VStack(spacing: Spacing.lg) {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Glass Card")
                    .font(.DesignSystem.headlineMedium)
                Text("This is a glassmorphism card with frosted glass effect")
                    .font(.DesignSystem.bodyMedium)
            }
            .padding(Spacing.md)
        }

        GlassCard(shadow: .strong) {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color.DesignSystem.brandGreen)
                Text("Strong Shadow")
                    .font(.DesignSystem.caption)
            }
            .padding(Spacing.lg)
        }
    }
    .padding()
    .background(
        LinearGradient(
            colors: [Color.DesignSystem.brandGreen.opacity(0.3), Color.DesignSystem.brandBlue.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        ),
    )
}
