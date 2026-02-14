//
//  LiquidGlassSpacing.swift
//  Foodshare
//
//  Liquid Glass Spacing & Layout System v26
//

import SwiftUI
import FoodShareDesignSystem

enum Spacing {
    // MARK: - Base Unit (8pt grid)
    static let unit: CGFloat = 8

    // MARK: - Semantic Spacing
    static let xxxs: CGFloat = unit * 0.5 // 4
    static let xxs: CGFloat = unit // 8
    static let xs: CGFloat = unit * 1.5 // 12
    static let sm: CGFloat = unit * 2 // 16
    static let md: CGFloat = unit * 3 // 24
    static let lg: CGFloat = unit * 4 // 32
    static let xl: CGFloat = unit * 5 // 40
    static let xxl: CGFloat = unit * 6 // 48
    static let xxxl: CGFloat = unit * 8 // 64

    // MARK: - Corner Radius
    static let radiusXS: CGFloat = 4
    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 12
    static let radiusLG: CGFloat = 16
    static let radiusXL: CGFloat = 24
    static let radiusFull: CGFloat = 9999

    // MARK: - Shadows
    static let shadowSM: CGFloat = 2
    static let shadowMD: CGFloat = 4
    static let shadowLG: CGFloat = 8
    static let shadowXL: CGFloat = 16
}

// MARK: - LiquidGlassSpacing Alias
typealias LiquidGlassSpacing = Spacing

// MARK: - Corner Radius

enum CornerRadius {
    /// 8pt - small components (badges, chips)
    static let small: CGFloat = 8
    /// 12pt - medium components (cards, inputs)
    static let medium: CGFloat = 12
    /// 16pt - large components (modals, sheets)
    static let large: CGFloat = 16
    /// 24pt - extra large components (full-screen overlays)
    static let xl: CGFloat = 24
    /// 28pt - extra extra large (featured cards)
    static let xxl: CGFloat = 28
    /// Fully rounded (pills, avatars)
    static let full: CGFloat = 9999

    // MARK: - Deprecated Aliases

    @available(*, deprecated, renamed: "large")
    static let lg: CGFloat = 16
    @available(*, deprecated, renamed: "xl")
    static let extraLarge: CGFloat = 24
}
