//
//  HapticFeedback.swift
//  Foodshare
//
//  Haptic feedback utilities for tactile UI responses
//  Note: Uses HapticManager from Core/Utilities/HapticManager.swift
//


#if !SKIP
import SwiftUI
#if !SKIP
import UIKit
#endif

// MARK: - HapticFeedback Alias (for backward compatibility)

/// Alias for HapticManager to maintain compatibility with newer components
typealias HapticFeedback = HapticManager

// MARK: - Haptic Button Style

struct HapticButtonStyle: ButtonStyle {
    let hapticStyle: HapticStyle

    enum HapticStyle {
        case light, medium, heavy, selection, success
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(Animation.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    triggerHaptic()
                }
            }
    }

    private func triggerHaptic() {
        switch hapticStyle {
        case .light: HapticManager.light()
        case .medium: HapticManager.medium()
        case .heavy: HapticManager.heavy()
        case .selection: HapticManager.selection()
        case .success: HapticManager.success()
        }
    }
}

extension ButtonStyle where Self == HapticButtonStyle {
    static var hapticLight: HapticButtonStyle { HapticButtonStyle(hapticStyle: .light) }
    static var hapticMedium: HapticButtonStyle { HapticButtonStyle(hapticStyle: .medium) }
    static var hapticHeavy: HapticButtonStyle { HapticButtonStyle(hapticStyle: .heavy) }
    static var hapticSelection: HapticButtonStyle { HapticButtonStyle(hapticStyle: .selection) }
    static var hapticSuccess: HapticButtonStyle { HapticButtonStyle(hapticStyle: .success) }
}

// MARK: - Haptic View Modifier

struct HapticOnTapModifier: ViewModifier {
    let style: HapticButtonStyle.HapticStyle
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                switch style {
                case .light: HapticManager.light()
                case .medium: HapticManager.medium()
                case .heavy: HapticManager.heavy()
                case .selection: HapticManager.selection()
                case .success: HapticManager.success()
                }
                action()
            }
    }
}

extension View {
    func hapticOnTap(style: HapticButtonStyle.HapticStyle = .light, action: @escaping () -> Void) -> some View {
        modifier(HapticOnTapModifier(style: style, action: action))
    }
}

// MARK: - Haptic on Change

struct HapticOnChangeModifier<Value: Equatable>: ViewModifier {
    let value: Value
    let style: HapticButtonStyle.HapticStyle

    func body(content: Content) -> some View {
        content
            .onChange(of: value) { _, _ in
                switch style {
                case .light: HapticManager.light()
                case .medium: HapticManager.medium()
                case .heavy: HapticManager.heavy()
                case .selection: HapticManager.selection()
                case .success: HapticManager.success()
                }
            }
    }
}

extension View {
    func hapticOnChange(of value: some Equatable, style: HapticButtonStyle.HapticStyle = .selection) -> some View {
        modifier(HapticOnChangeModifier(value: value, style: style))
    }
}

#endif
