//
//  PrimaryButton.swift
//  Foodshare
//
//  Primary action button component with Foodshare brand Pink gradient
//

import SwiftUI
import FoodShareDesignSystem

/// Primary button with Foodshare brand gradient and optional loading state
struct PrimaryButton: View {
    // MARK: - Properties

    private let title: String
    private let icon: String?
    private let action: () -> Void
    private let isLoading: Bool
    private let isEnabled: Bool

    @Environment(\.isEnabled) private var environmentIsEnabled

    // MARK: - Initialization

    init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
        self.isLoading = isLoading
        self.isEnabled = isEnabled
    }

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.headline)
                }

                Text(title)
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(
                color: Color.DesignSystem.brandPink.opacity(buttonEnabled ? 0.4 : 0),
                radius: 12,
                y: 6
            )
        }
        .disabled(!isEnabled || isLoading)
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Private Properties

    private var buttonEnabled: Bool {
        isEnabled && environmentIsEnabled && !isLoading
    }

    @ViewBuilder
    private var backgroundView: some View {
        ZStack {
            // Gradient fill
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.DesignSystem.brandPink.opacity(buttonEnabled ? 0.95 : 0.5),
                            Color.DesignSystem.brandTeal.opacity(buttonEnabled ? 0.85 : 0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Highlight overlay
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Secondary Button

/// Secondary button with glass effect and Foodshare brand border
struct SecondaryButton: View {
    private let title: String
    private let icon: String?
    private let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.headline)
                }

                Text(title)
                    .font(.headline)
            }
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.DesignSystem.brandPink, Color.DesignSystem.brandTeal],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [Color.DesignSystem.brandPink, Color.DesignSystem.brandTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Ghost Button

/// Ghost button with no background and Foodshare brand text
struct GhostButton: View {
    private let title: String
    private let icon: String?
    private let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.callout)
                }

                Text(title)
                    .font(.callout)
            }
            .foregroundColor(Color.DesignSystem.brandPink)
        }
        .buttonStyle(PrimaryScaleButtonStyle())
    }
}

// MARK: - Button Style

private struct PrimaryScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.interpolatingSpring(stiffness: 400, damping: 20), value: configuration.isPressed)
    }
}

// MARK: - Previews

#Preview("Buttons") {
    VStack(spacing: Spacing.md) {
        PrimaryButton("Create Listing", icon: "plus.circle.fill") {
            print("Primary tapped")
        }

        PrimaryButton("Loading...", isLoading: true) {
            print("Loading")
        }

        PrimaryButton("Disabled", isEnabled: false) {
            print("Disabled")
        }

        SecondaryButton("Cancel", icon: "xmark") {
            print("Secondary tapped")
        }

        GhostButton("Learn More", icon: "info.circle") {
            print("Ghost tapped")
        }
    }
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
