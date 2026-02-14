//
//  ListingCategory.swift
//  Foodshare
//
//  Listing categories matching web app - Core shared model
//  Supports all 12 category types from the web platform
//

import FoodShareDesignSystem
import SwiftUI

/// All listing categories matching the web app
/// Order: Food basics → Community resources → Lifestyle → Engagement → Forum
/// Raw values use singular form to match database post_type column
enum ListingCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case food
    case thing // DB: "thing" (singular)
    case borrow
    case wanted
    case foodbank // DB: "foodbank" (singular)
    case fridge // DB: "fridge" (singular)
    case zerowaste
    case vegan
    case organisation // DB: "organisation" (singular)
    case volunteer // DB: "volunteer" (singular)
    case challenge // Separate table, but singular for consistency
    case forum

    var id: String {
        rawValue
    }

    // MARK: - Display Properties

    var displayName: String {
        switch self {
        case .food: "Food"
        case .thing: "Things"
        case .borrow: "Borrow"
        case .wanted: "Wanted"
        case .foodbank: "Food Banks"
        case .fridge: "Fridges"
        case .zerowaste: "Zero Waste"
        case .vegan: "Vegan"
        case .organisation: "Organisations"
        case .volunteer: "Volunteers"
        case .challenge: "Challenges"
        case .forum: "Forum"
        }
    }

    /// Localized display name using translation service
    /// Falls back to hardcoded displayName if translation returns the key itself
    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        let key = switch self {
        case .food: "categories.food"
        case .thing: "categories.things"
        case .borrow: "categories.borrow"
        case .wanted: "categories.wanted"
        case .foodbank: "categories.foodbanks"
        case .fridge: "categories.fridges"
        case .zerowaste: "categories.zerowaste"
        case .vegan: "categories.vegan"
        case .organisation: "categories.organisations"
        case .volunteer: "categories.volunteers"
        case .challenge: "categories.challenges"
        case .forum: "categories.forum"
        }
        let translated = t.t(key)
        // If translation returns the key itself, fall back to hardcoded displayName
        return translated != key ? translated : displayName
    }

    var icon: String {
        switch self {
        case .food: "fork.knife"
        case .thing: "lamp.desk"
        case .borrow: "hand.wave.fill"
        case .wanted: "magnifyingglass"
        case .foodbank: "building.2.fill"
        case .fridge: "refrigerator.fill"
        case .zerowaste: "arrow.3.trianglepath"
        case .vegan: "carrot.fill"
        case .organisation: "building.columns.fill"
        case .volunteer: "person.2.fill"
        case .challenge: "trophy.fill"
        case .forum: "bubble.left.and.bubble.right.fill"
        }
    }

    var emoji: String {
        switch self {
        case .food: "🍎"
        case .thing: "🎁"
        case .borrow: "🔧"
        case .wanted: "📦"
        case .foodbank: "🏠"
        case .fridge: "❄️"
        case .zerowaste: "♻️"
        case .vegan: "🌱"
        case .organisation: "🏛️"
        case .volunteer: "🙌🏻"
        case .challenge: "🏆"
        case .forum: "💬"
        }
    }

    var color: Color {
        switch self {
        case .food: .DesignSystem.brandGreen
        case .thing: .DesignSystem.brandOrange
        case .borrow: .DesignSystem.brandBlue
        case .wanted: .purple
        case .foodbank: .DesignSystem.blueDark
        case .fridge: .cyan
        case .zerowaste: .green
        case .vegan: .mint
        case .organisation: .indigo
        case .volunteer: .pink
        case .challenge: .yellow
        case .forum: .DesignSystem.blueLight
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        )
    }

    // MARK: - Category Groups

    /// Food-related categories
    static var foodCategories: [ListingCategory] {
        [.food, .foodbank, .fridge, .vegan]
    }

    /// Item sharing categories
    static var sharingCategories: [ListingCategory] {
        [.food, .thing, .borrow, .wanted]
    }

    /// Community resource categories
    static var communityCategories: [ListingCategory] {
        [.foodbank, .fridge, .organisation, .volunteer]
    }

    /// Engagement categories
    static var engagementCategories: [ListingCategory] {
        [.challenge, .forum, .zerowaste]
    }

    /// Categories shown in main feed filter (excludes challenge/forum which have their own tabs)
    static var feedCategories: [ListingCategory] {
        [.food, .thing, .borrow, .wanted, .foodbank, .fridge, .zerowaste, .vegan, .organisation, .volunteer]
    }

    /// Categories for creating new listings
    static var creatableCategories: [ListingCategory] {
        [.food, .thing, .borrow, .wanted, .zerowaste, .vegan]
    }
}

// MARK: - Category Filter Model

struct CategoryFilter: Identifiable, Hashable {
    let id: String
    let category: ListingCategory?
    let isAll: Bool

    var displayName: String {
        isAll ? "All" : (category?.displayName ?? "All")
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        isAll ? t.t("common.all") : (category?.localizedDisplayName(using: t) ?? t.t("common.all"))
    }

    var icon: String {
        isAll ? "square.grid.2x2.fill" : (category?.icon ?? "square.grid.2x2.fill")
    }

    var color: Color {
        isAll ? .DesignSystem.brandGreen : (category?.color ?? .DesignSystem.brandGreen)
    }

    static let all = CategoryFilter(id: "all", category: nil, isAll: true)

    static func from(_ category: ListingCategory) -> CategoryFilter {
        CategoryFilter(id: category.rawValue, category: category, isAll: false)
    }

    static var feedFilters: [CategoryFilter] {
        [.all] + ListingCategory.feedCategories.map { .from($0) }
    }
}
