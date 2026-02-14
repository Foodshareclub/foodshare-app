//
//  FloatingActionButton.swift
//  Foodshare
//
//  Liquid Glass v26 Floating Action Button
//  Foodshare brand Pink gradient with premium glass effects
//

import SwiftUI
import FoodShareDesignSystem

struct FloatingActionButton: View {
    let icon: String
    let label: String?
    let style: FABStyle
    let primaryColor: Color
    let secondaryColor: Color
    let action: () -> Void

    @State private var isPressed = false
    @State private var pulsePhase: Double = 0

    enum FABStyle {
        case primary
        case secondary
        case mini

        var size: CGFloat {
            switch self {
            case .primary: 64
            case .secondary: 56
            case .mini: 48
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .primary: 28
            case .secondary: 24
            case .mini: 20
            }
        }
    }

    init(
        icon: String,
        label: String? = nil,
        style: FABStyle = .primary,
        color: Color = .DesignSystem.brandPink,
        secondaryColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.style = style
        self.primaryColor = color
        self.secondaryColor = secondaryColor ?? color.opacity(0.7)
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: label != nil ? Spacing.sm : 0) {
                Image(systemName: icon)
                    .font(.system(size: style.iconSize, weight: .semibold))
                    .foregroundStyle(Color.white)

                if let label {
                    Text(label)
                        .font(.DesignSystem.labelLarge)
                        .foregroundStyle(Color.white)
                }
            }
            .frame(
                minWidth: style.size,
                minHeight: style.size,
            )
            .padding(.horizontal, label != nil ? Spacing.md : 0)
            .background(
                ZStack {
                    // Outer pulse glow for primary style
                    if style == .primary {
                        Capsule()
                            .fill(primaryColor.opacity(0.3))
                            .scaleEffect(1.0 + 0.1 * sin(pulsePhase))
                            .blur(radius: 6)
                    }

                    // Main gradient fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    primaryColor,
                                    secondaryColor
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Highlight overlay
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.clear,
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: primaryColor.opacity(isPressed ? 0.3 : 0.5),
                radius: isPressed ? 8 : 16,
                y: isPressed ? 4 : 8
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(SpringAnimation.snappy) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(SpringAnimation.snappy) {
                        isPressed = false
                    }
                }
        )
        .onAppear {
            if style == .primary {
                withAnimation(
                    .easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: false)
                ) {
                    pulsePhase = .pi * 2
                }
            }
        }
    }
}

#Preview("Foodshare Brand FAB") {
    ZStack {
        Color.DesignSystem.background
            .ignoresSafeArea()

        VStack(spacing: Spacing.xl) {
            Text("Foodshare Brand (Pink)")
                .font(.caption)
                .foregroundColor(.gray)

            FloatingActionButton(
                icon: "plus",
                style: .primary
            ) {}

            FloatingActionButton(
                icon: "plus",
                label: "Share Food",
                style: .primary
            ) {}

            Text("Pink to Teal Gradient")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top)

            FloatingActionButton(
                icon: "heart.fill",
                style: .primary,
                color: .DesignSystem.brandPink,
                secondaryColor: .DesignSystem.brandTeal
            ) {}

            Text("Secondary & Mini")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top)

            FloatingActionButton(
                icon: "heart.fill",
                style: .secondary
            ) {}

            FloatingActionButton(
                icon: "bookmark",
                style: .mini
            ) {}

            Text("Green Eco Style")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top)

            FloatingActionButton(
                icon: "leaf.fill",
                label: "Eco Action",
                style: .primary,
                color: .DesignSystem.brandGreen,
                secondaryColor: .DesignSystem.brandCyan
            ) {}
        }
    }
}
