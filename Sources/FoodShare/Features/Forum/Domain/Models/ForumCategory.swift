

#if !SKIP
import Foundation
import SwiftUI

// MARK: - Forum Category Model

/// Represents a forum category from the `forum_categories` table
struct ForumCategory: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let slug: String
    let description: String?
    let iconName: String?
    let color: String?
    let sortOrder: Int
    let isActive: Bool
    let postsCount: Int
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case slug
        case description
        case iconName = "icon_name"
        case color
        case sortOrder = "sort_order"
        case isActive = "is_active"
        case postsCount = "posts_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Custom Decoder (handles nullable database fields)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        slug = try container.decodeIfPresent(String.self, forKey: .slug) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description)
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        postsCount = try container.decodeIfPresent(Int.self, forKey: .postsCount) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    // MARK: - Memberwise Initializer (for fixtures)

    init(
        id: Int,
        name: String,
        slug: String,
        description: String?,
        iconName: String?,
        color: String?,
        sortOrder: Int,
        isActive: Bool,
        postsCount: Int,
        createdAt: Date?,
        updatedAt: Date?
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.description = description
        self.iconName = iconName
        self.color = color
        self.sortOrder = sortOrder
        self.isActive = isActive
        self.postsCount = postsCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Computed Properties

    var displayColor: Color {
        guard let hex = color else { return .blue }
        return Color(hex: hex) ?? .blue
    }

    var systemIconName: String {
        guard let iconName else { return "folder" }
        // Map Lucide/Feather icon names to SF Symbols
        // If the name already contains a dot, it's likely already an SF Symbol
        if iconName.contains(".") { return iconName }

        return switch iconName {
        // Lucide/Feather to SF Symbol mappings
        case "pencil": "pencil"
        case "edit-3": "square.and.pencil"
        case "book-open": "book.fill"
        case "message-circle": "bubble.left.fill"
        case "messages-square": "bubble.left.and.bubble.right.fill"
        case "users": "person.2.fill"
        case "lightbulb": "lightbulb.fill"
        case "sparkles": "sparkles"
        case "trophy": "trophy.fill"
        case "star": "star.fill"
        case "heart": "heart.fill"
        case "clock": "clock.fill"
        case "leaf": "leaf.fill"
        case "chef-hat": "fork.knife"
        case "help-circle": "questionmark.circle.fill"
        case "map-pin": "mappin.circle.fill"
        case "map": "map.fill"
        case "home": "house.fill"
        case "gift": "gift.fill"
        case "camera": "camera.fill"
        case "image": "photo.fill"
        case "share": "square.and.arrow.up.fill"
        case "bookmark": "bookmark.fill"
        case "flag": "flag.fill"
        case "bell": "bell.fill"
        case "settings": "gearshape.fill"
        case "search": "magnifyingglass"
        case "info": "info.circle.fill"
        case "utensils": "fork.knife"
        case "package": "shippingbox.fill"
        case "truck": "box.truck.fill"
        case "calendar": "calendar"
        case "user": "person.fill"
        case "folder": "folder.fill"
        case "file": "doc.fill"
        case "tag": "tag.fill"
        case "hash": "number"
        default: "folder"
        }
    }

    // MARK: - Default Categories

    /// Default categories for quick post creation (before loading from DB)
    static var defaultCategories: [ForumCategory] {
        [
            ForumCategory(
                id: 1,
                name: "General",
                slug: "general",
                description: "General discussions",
                iconName: "bubble.left.and.bubble.right",
                color: "#3498DB",
                sortOrder: 1,
                isActive: true,
                postsCount: 0,
                createdAt: nil,
                updatedAt: nil,
            ),
            ForumCategory(
                id: 2,
                name: "Tips & Tricks",
                slug: "tips-tricks",
                description: "Share your food saving tips",
                iconName: "lightbulb",
                color: "#F1C40F",
                sortOrder: 2,
                isActive: true,
                postsCount: 0,
                createdAt: nil,
                updatedAt: nil,
            ),
            ForumCategory(
                id: 3,
                name: "Recipes",
                slug: "recipes",
                description: "Share recipes and cooking ideas",
                iconName: "fork.knife",
                color: "#E74C3C",
                sortOrder: 3,
                isActive: true,
                postsCount: 0,
                createdAt: nil,
                updatedAt: nil,
            ),
            ForumCategory(
                id: 4,
                name: "Community",
                slug: "community",
                description: "Community discussions and events",
                iconName: "person.3",
                color: "#2ECC71",
                sortOrder: 4,
                isActive: true,
                postsCount: 0,
                createdAt: nil,
                updatedAt: nil,
            ),
        ]
    }
}

// MARK: - Forum Tag Model

/// Represents a forum tag from the `forum_tags` table
struct ForumTag: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let slug: String
    let description: String?
    let color: String?
    let usageCount: Int
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case slug
        case description
        case color
        case usageCount = "usage_count"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        slug = try container.decodeIfPresent(String.self, forKey: .slug) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        usageCount = try container.decodeIfPresent(Int.self, forKey: .usageCount) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    init(id: Int, name: String, slug: String, description: String?, color: String?, usageCount: Int, createdAt: Date?) {
        self.id = id
        self.name = name
        self.slug = slug
        self.description = description
        self.color = color
        self.usageCount = usageCount
        self.createdAt = createdAt
    }

    var displayColor: Color {
        guard let hex = color else { return .gray }
        return Color(hex: hex) ?? .gray
    }
}

// MARK: - Localization

extension ForumCategory {
    /// Returns the localized name for this category using the translation service.
    /// Falls back to the database name if no translation is found.
    @MainActor
    func localizedName(using t: EnhancedTranslationService) -> String {
        // Try translation key first: forum.category.{slug}
        let key = "forum.category.\(slug)"
        let translated = t.t(key)
        if translated != key {
            return translated
        }

        // Fallback: use local mapping for common categories
        // This ensures categories are translated even if backend keys are missing
        let localizedFallback = Self.localizedCategoryNames[slug]
        if let fallback = localizedFallback {
            let fallbackTranslated = t.t(fallback)
            if fallbackTranslated != fallback {
                return fallbackTranslated
            }
        }

        // Final fallback: database name
        return name
    }

    /// Mapping of category slugs to existing translation keys
    /// This provides fallback translations using existing keys in the system
    private static let localizedCategoryNames: [String: String] = [
        // Map slugs to existing translation keys
        "general": "forum.type.discussion", // "Обсуждение"
        "general-discussion": "forum.type.discussion",
        "announcements": "forum.type.announcement", // "Объявление"
        "tips-tricks": "tip", // "Совет"
        "tips": "tip",
        "recipes": "recipe", // "Рецепт"
        "community": "post_type.community", // "Сообщество"
        "questions": "forum.type.question", // "Вопрос"
        "guides": "forum.type.guide", // "Руководство"
        "help": "app.links.help", // "Помощь"
        "feedback": "feedback.title",
    ]
}

// MARK: - CategoryDisplayable Conformance

extension ForumCategory: CategoryDisplayable {
    var displayName: String { name }
    var categoryIcon: String { systemIconName }
    // displayColor is already implemented above
}


#endif
