//
//  FeedLoadingComponents.swift
//  Foodshare
//
//  Loading skeleton and shimmer effects for the feed
//  Extracted from FeedView for better organization
//


#if !SKIP
import SwiftUI

// MARK: - Feed Skeleton Card

struct FeedSkeletonCard: View {
    @State private var shimmerPhase: CGFloat = -200
    @Environment(\.accessibilityManager) private var accessibilityManager: AccessibilityManager
    @Environment(\.translationService) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image placeholder
            Rectangle()
                .fill(skeletonGradient)
                .frame(height: 160.0)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Title skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(height: 20.0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 80)

                // Subtitle skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(width: 150.0, height: 14)

                HStack {
                    // Badge skeleton
                    Capsule()
                        .fill(skeletonGradient)
                        .frame(width: 60.0, height: 24)

                    Spacer()

                    // Distance skeleton
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(width: 40.0, height: 12)
                }
            }
            .padding(Spacing.md)
        }
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(accessibilityManager.shouldReduceAnimations ? nil : shimmerOverlay)
        // Accessibility: Label for VoiceOver, hide decorative shimmer
        .accessibilityElement(children: AccessibilityChildBehavior.ignore)
        .accessibilityLabel(t.t("accessibility.loading_item"))
        .accessibilityHint(t.t("accessibility.loading_hint"))
    }

    @ViewBuilder
    private var backgroundView: some View {
        if accessibilityManager.isReduceTransparencyEnabled {
            // Solid background for reduced transparency
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(Color.DesignSystem.background)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: CornerRadius.large)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder.opacity(0.5), lineWidth: 1)
                )
        }
    }

    private var skeletonGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.DesignSystem.textTertiary.opacity(0.3),
                Color.DesignSystem.textTertiary.opacity(0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        )
    }

    private var shimmerOverlay: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.15),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing,
            )
            .frame(width: 150.0)
            .offset(x: shimmerPhase)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                ) {
                    shimmerPhase = geometry.size.width + 150
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
}

// MARK: - Rotating Modifier for Loading

struct RotatingModifier: ViewModifier {
    @State private var isRotating = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(
                .linear(duration: 1)
                    .repeatForever(autoreverses: false),
                value: isRotating,
            )
            .onAppear {
                isRotating = true
            }
    }
}

extension View {
    /// Applies continuous rotation animation
    func rotating() -> some View {
        modifier(RotatingModifier())
    }
}

// MARK: - Search Pill Press Style

struct SearchPillPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(Animation.interpolatingSpring(stiffness: 400, damping: 20), value: configuration.isPressed)
    }
}

// MARK: - Loading More Indicator

struct FeedLoadingMoreIndicator: View {
    @Environment(\.translationService) private var t

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView()
                .tint(Color.DesignSystem.brandGreen)

            Text(t.t("common.loading_more"))
                .font(.DesignSystem.caption)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .padding(Spacing.md)
        .background(
            Capsule()
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    Capsule()
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
    }
}

#endif
