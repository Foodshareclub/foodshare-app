//
//  FeedCategoryExtensions.swift
//  Foodshare
//
//  Feed-specific category extensions
//  GlassCategoryBar and GlassCategoryChip are in Core/Design/Components/Navigation
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - ListingCategory Conformance

extension ListingCategory: CategoryDisplayable {
    var categoryIcon: String { icon }

    var displayColor: Color {
        switch self {
        case .food: .DesignSystem.brandGreen
        case .thing: .DesignSystem.brandBlue
        case .borrow: .DesignSystem.brandTeal
        case .wanted: .DesignSystem.brandPurple
        case .foodbank: .DesignSystem.brandOrange
        case .fridge: .DesignSystem.accentCyan
        case .zerowaste: .DesignSystem.success
        case .vegan: .DesignSystem.brandGreen
        case .organisation: .DesignSystem.brandBlue
        case .volunteer: .DesignSystem.brandPink
        case .challenge: .DesignSystem.accentYellow
        case .forum: .DesignSystem.brandPurple
        }
    }
}
