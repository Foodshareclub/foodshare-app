//
//  SpringAnimations.swift
//  Foodshare
//
//  Liquid Glass v26 Spring Animation Presets
//


#if !SKIP
import SwiftUI

enum SpringAnimation {
    /// Quick, snappy animation for buttons and toggles
    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.7)

    /// Smooth, fluid animation for transitions
    static let smooth = Animation.spring(response: 0.4, dampingFraction: 0.8)

    /// Bouncy animation for playful interactions
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)

    /// Gentle animation for subtle changes
    static let gentle = Animation.spring(response: 0.6, dampingFraction: 0.9)

    /// Elastic animation for dramatic effects
    static let elastic = Animation.spring(response: 0.7, dampingFraction: 0.5)
}

// MARK: - Transition Presets

extension AnyTransition {
    /// Scale and fade transition
    static var scaleAndFade: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.8).combined(with: AnyTransition.opacity),
            removal: .scale(scale: 0.8).combined(with: AnyTransition.opacity),
        )
    }

    /// Slide from bottom with fade
    static var slideUp: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: AnyTransition.opacity),
            removal: .move(edge: .bottom).combined(with: AnyTransition.opacity),
        )
    }

    /// Slide from top with fade
    static var slideDown: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .top).combined(with: AnyTransition.opacity),
            removal: .move(edge: .top).combined(with: AnyTransition.opacity),
        )
    }

    /// Slide from right with fade
    static var slideRight: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: AnyTransition.opacity),
            removal: .move(edge: .trailing).combined(with: AnyTransition.opacity),
        )
    }

    /// Scale with blur effect
    static var scaleAndBlur: AnyTransition {
        #if !SKIP
        .modifier(
            active: ScaleAndBlurModifier(scale: 0.8, blur: 10),
            identity: ScaleAndBlurModifier(scale: 1.0, blur: 0),
        )
        #else
        .opacity
        #endif
    }
}

// MARK: - Scale and Blur Modifier

struct ScaleAndBlurModifier: ViewModifier {
    let scale: CGFloat
    let blur: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .blur(radius: blur)
    }
}

#endif
