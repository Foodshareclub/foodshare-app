//
//  Category.swift
//  Foodshare
//
//  Food category model - Maps to `categories` table in Supabase
//


import Foundation

/// Represents a food category for classification
/// Maps to `categories` table in Supabase
struct Category: Codable, Identifiable, Hashable {
    let id: Int // bigint in database
    let name: String // category name (unique)
    let description: String? // category description
    let iconUrl: String? // icon_url
    let color: String // hex color (default: #4CAF50)
    let sortOrder: Int // sort_order for display
    let isActive: Bool // is_active
    let createdAt: Date // created_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id, name, description, color
        case iconUrl = "icon_url"
        case sortOrder = "sort_order"
        case isActive = "is_active"
        case createdAt = "created_at"
    }

    // MARK: - Computed Properties

    /// SF Symbol icon based on category name
    var icon: String {
        switch name.lowercased() {
        case "produce", "fruits", "vegetables":
            return "leaf.fill"
        case "dairy":
            return "drop.fill"
        case "baked goods", "bakery", "bread":
            return "birthday.cake.fill"
        case "meat", "fish", "meat & fish":
            return "fish.fill"
        case "pantry", "pantry items", "canned":
            return "basket.fill"
        case "prepared food", "prepared meals", "cooked":
            return "fork.knife"
        case "beverages", "drinks":
            return "cup.and.saucer.fill"
        default:
            return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Test Fixtures

#if DEBUG

    extension Category {
        static func fixture(
            id: Int = 1,
            name: String = "Produce",
            description: String? = "Fresh fruits and vegetables",
            iconUrl: String? = nil,
            color: String = "#4CAF50",
            sortOrder: Int = 0,
            isActive: Bool = true,
            createdAt: Date = Date(),
        ) -> Category {
            Category(
                id: id,
                name: name,
                description: description,
                iconUrl: iconUrl,
                color: color,
                sortOrder: sortOrder,
                isActive: isActive,
                createdAt: createdAt,
            )
        }

        /// Default categories matching database
        static let defaultCategories: [Category] = [
            .fixture(id: 1, name: "Produce", color: "#2ECC71", sortOrder: 0),
            .fixture(id: 2, name: "Dairy", color: "#3498DB", sortOrder: 1),
            .fixture(id: 3, name: "Baked Goods", color: "#E67E22", sortOrder: 2),
            .fixture(id: 4, name: "Meat & Fish", color: "#E74C3C", sortOrder: 3),
            .fixture(id: 5, name: "Pantry", color: "#9B59B6", sortOrder: 4),
            .fixture(id: 6, name: "Prepared Food", color: "#F39C12", sortOrder: 5),
            .fixture(id: 7, name: "Beverages", color: "#1ABC9C", sortOrder: 6),
            .fixture(id: 8, name: "Other", color: "#95A5A6", sortOrder: 7)
        ]
    }

#endif
