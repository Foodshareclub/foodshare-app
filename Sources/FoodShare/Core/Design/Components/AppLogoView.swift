//
//  AppLogoView.swift
//  Foodshare
//
//  Reusable app logo component with Liquid Glass styling
//

import SwiftUI
import FoodShareDesignSystem

/// Reusable app logo view with configurable size and styling
struct AppLogoView: View {
    enum Size {
        case small // 40pt - for navigation bars, list items
        case medium // 60pt - for cards, headers
        case large // 100pt - for auth screens, splash
        case custom(CGFloat)

        var dimension: CGFloat {
            switch self {
            case .small: 40
            case .medium: 60
            case .large: 100
            case let .custom(size): size
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .small: 9
            case .medium: 13
            case .large: 22
            case let .custom(size): size * 0.22
            }
        }
    }

    let size: Size
    var showGlow = true
    var showShimmer = false
    var circular = false

    var body: some View {
        logoImage
            .frame(width: size.dimension, height: size.dimension)
            .clipShape(circular ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: size.cornerRadius)))
            .shadow(
                color: showGlow ? .DesignSystem.brandGreen.opacity(0.4) : .clear,
                radius: showGlow ? size.dimension * 0.24 : 0,
                y: showGlow ? size.dimension * 0.08 : 0,
            )
            .modifier(AppLogoShimmerModifier(isEnabled: showShimmer))
    }

    private var logoImage: some View {
        Image("AppLogo")
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}

// MARK: - Shimmer Modifier

private struct AppLogoShimmerModifier: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.shimmer(duration: 3.0, bounce: false)
        } else {
            content
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Spacing.xl) {
        AppLogoView(size: .small)
        AppLogoView(size: .medium)
        AppLogoView(size: .large, showShimmer: true)
        AppLogoView(size: .custom(150), showGlow: false)
    }
    .padding()
    .background(Color.backgroundGradient)
}
