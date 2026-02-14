//
//  GlassAlert.swift
//  Foodshare
//
//  Liquid Glass v27 Alert Component
//  Premium alerts with GPU-accelerated glass effects and ProMotion 120Hz animations
//

import SwiftUI
import FoodShareDesignSystem

struct GlassAlert: View {
    let type: AlertType
    let title: String
    let message: String
    let primaryAction: AlertAction?
    let secondaryAction: AlertAction?

    @State private var iconScale: CGFloat = 0.5
    @State private var contentOpacity: Double = 0
    @State private var isGlowing = false

    enum AlertType {
        case success
        case error
        case warning
        case info

        var icon: String {
            switch self {
            case .success: "checkmark.circle.fill"
            case .error: "xmark.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .info: "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: Color.DesignSystem.success
            case .error: Color.DesignSystem.error
            case .warning: Color.DesignSystem.warning
            case .info: Color.DesignSystem.info
            }
        }
    }

    struct AlertAction {
        let title: String
        let action: () -> Void
    }

    init(
        type: AlertType,
        title: String,
        message: String,
        primaryAction: AlertAction? = nil,
        secondaryAction: AlertAction? = nil,
    ) {
        self.type = type
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Icon with entrance animation
            ZStack {
                Circle()
                    .fill(type.color.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .blur(radius: 20)
                    .scaleEffect(isGlowing ? 1.2 : 1.0)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                type.color,
                                type.color.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: type.icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
            .scaleEffect(iconScale)
            .shadow(color: type.color.opacity(isGlowing ? 0.5 : 0.4), radius: isGlowing ? 20 : 16, y: 8)
            .drawingGroup() // GPU rasterization for blur and shadow

            // Content
            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.DesignSystem.headlineSmall)
                    .foregroundStyle(Color.DesignSystem.text)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.DesignSystem.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(contentOpacity)
            .offset(y: contentOpacity == 1 ? 0 : 10)

            // Actions
            if primaryAction != nil || secondaryAction != nil {
                VStack(spacing: Spacing.sm) {
                    if let primary = primaryAction {
                        GlassButton(
                            primary.title,
                            style: .primary,
                            action: {
                                HapticManager.medium()
                                primary.action()
                            },
                        )
                    }

                    if let secondary = secondaryAction {
                        GlassButton(
                            secondary.title,
                            style: .ghost,
                            action: {
                                HapticManager.light()
                                secondary.action()
                            },
                        )
                    }
                }
                .padding(.top, Spacing.sm)
                .opacity(contentOpacity)
            }
        }
        .onAppear {
            // ProMotion 120Hz optimized entrance animations
            withAnimation(.interpolatingSpring(stiffness: 250, damping: 18)) {
                iconScale = 1.0
            }
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 20).delay(0.1)) {
                contentOpacity = 1
            }
            // Subtle glow pulse
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.3)) {
                isGlowing = true
            }
            switch type {
            case .error: HapticManager.error()
            case .warning: HapticManager.warning()
            case .success, .info: HapticManager.success()
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: 320)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Spacing.radiusXL)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: Spacing.radiusXL)
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

                RoundedRectangle(cornerRadius: Spacing.radiusXL)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center,
                        ),
                    )
            },
        )
        .shadow(color: Color.black.opacity(0.2), radius: 30, y: 15)
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()

        VStack(spacing: Spacing.xl) {
            GlassAlert(
                type: .success,
                title: "Success!",
                message: "Your food item has been shared successfully.",
                primaryAction: .init(title: "Done", action: {}),
                secondaryAction: .init(title: "Share Another", action: {}),
            )

            GlassAlert(
                type: .error,
                title: "Error",
                message: "Failed to upload image. Please try again.",
                primaryAction: .init(title: "Retry", action: {}),
                secondaryAction: .init(title: "Cancel", action: {}),
            )
        }
    }
}
