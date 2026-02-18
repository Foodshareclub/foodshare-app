//
//  Protocols.swift
//  Foodshare
//
//  Shared protocols for the Liquid Glass design system
//


#if !SKIP
import SwiftUI

// MARK: - Category Displayable Protocol

/// Protocol for types that can be displayed in category bars and chips
/// Used by GlassCategoryBar, GlassCategoryPills, and similar components
protocol CategoryDisplayable {
    var displayName: String { get }
    var categoryIcon: String { get }
    var displayColor: Color { get }
}

#endif
