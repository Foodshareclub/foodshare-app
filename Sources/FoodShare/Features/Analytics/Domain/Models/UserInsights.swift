//
//  UserInsights.swift
//  Foodshare
//
//  User analytics and insights models
//

import Foundation

/// User activity insights and statistics
struct UserInsights: Codable, Sendable {
    let userId: UUID
    let period: InsightsPeriod

    // MARK: - Sharing Stats

    let itemsShared: Int
    let itemsReceived: Int
    let totalViews: Int
    let totalLikes: Int

    // MARK: - Environmental Impact

    let foodSavedKg: Double
    let co2SavedKg: Double
    let waterSavedLiters: Double
    let moneySavedEstimate: Double

    // MARK: - Engagement

    let messagesExchanged: Int
    let successfulArrangements: Int
    let averageResponseTimeMinutes: Int
    let reviewsGiven: Int
    let reviewsReceived: Int

    // MARK: - Streaks

    let currentStreak: Int
    let longestStreak: Int
    let lastActiveDate: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case period
        case itemsShared = "items_shared"
        case itemsReceived = "items_received"
        case totalViews = "total_views"
        case totalLikes = "total_likes"
        case foodSavedKg = "food_saved_kg"
        case co2SavedKg = "co2_saved_kg"
        case waterSavedLiters = "water_saved_liters"
        case moneySavedEstimate = "money_saved_estimate"
        case messagesExchanged = "messages_exchanged"
        case successfulArrangements = "successful_arrangements"
        case averageResponseTimeMinutes = "average_response_time_minutes"
        case reviewsGiven = "reviews_given"
        case reviewsReceived = "reviews_received"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case lastActiveDate = "last_active_date"
    }

    // MARK: - Computed Properties

    /// Total items exchanged
    var totalExchanges: Int {
        itemsShared + itemsReceived
    }

    /// Arrangement success rate
    var successRate: Double {
        guard totalExchanges > 0 else { return 0 }
        return Double(successfulArrangements) / Double(totalExchanges) * 100
    }

    /// Environmental impact score (0-100)
    var impactScore: Int {
        // Simple scoring based on food saved
        min(100, Int(foodSavedKg * 10))
    }
}

// MARK: - Insights Period

enum InsightsPeriod: String, Codable, Sendable, CaseIterable {
    case week
    case month
    case year
    case allTime = "all_time"

    @MainActor
    func displayName(_ t: TranslationService) -> String {
        t.t("insights.period.\(rawValue)")
    }
}

// MARK: - Activity Timeline

struct ActivityTimelineItem: Codable, Identifiable, Sendable {
    let id: Int
    let type: ActivityType
    let title: String
    let description: String?
    let timestamp: Date
    let relatedPostId: Int?
    let relatedUserId: UUID?

    enum ActivityType: String, Codable, Sendable {
        case shared
        case received
        case reviewed
        case joined
        case completed
        case badge

        var icon: String {
            switch self {
            case .shared: "arrow.up.heart.fill"
            case .received: "arrow.down.heart.fill"
            case .reviewed: "star.fill"
            case .joined: "person.badge.plus"
            case .completed: "checkmark.circle.fill"
            case .badge: "medal.fill"
            }
        }

        var color: String {
            switch self {
            case .shared: "#F39C12"
            case .received: "#2ECC71"
            case .reviewed: "#F1C40F"
            case .joined: "#3498DB"
            case .completed: "#27AE60"
            case .badge: "#9B59B6"
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, type, title, description, timestamp
        case relatedPostId = "related_post_id"
        case relatedUserId = "related_user_id"
    }
}

// MARK: - Impact Metrics

struct ImpactMetrics: Sendable {
    let foodSavedKg: Double
    let co2SavedKg: Double
    let waterSavedLiters: Double
    let moneySaved: Double

    /// Calculate impact from number of items shared
    @MainActor
    static func calculate(itemsShared: Int) -> ImpactMetrics {
        let config = AppConfiguration.shared
        return ImpactMetrics(
            foodSavedKg: Double(itemsShared) * config.foodKgPerItem,
            co2SavedKg: Double(itemsShared) * config.co2KgPerItem,
            waterSavedLiters: Double(itemsShared) * config.waterLitersPerItem,
            moneySaved: Double(itemsShared) * config.moneyUsdPerItem,
        )
    }

    var formattedFoodSaved: String {
        if foodSavedKg >= 1000 {
            return String(format: "%.1f tonnes", foodSavedKg / 1000)
        }
        return String(format: "%.1f kg", foodSavedKg)
    }

    var formattedCo2Saved: String {
        if co2SavedKg >= 1000 {
            return String(format: "%.1f tonnes", co2SavedKg / 1000)
        }
        return String(format: "%.1f kg", co2SavedKg)
    }

    var formattedWaterSaved: String {
        if waterSavedLiters >= 1000 {
            return String(format: "%.0f m³", waterSavedLiters / 1000)
        }
        return String(format: "%.0f L", waterSavedLiters)
    }

    var formattedMoneySaved: String {
        String(format: "$%.0f", moneySaved)
    }
}

// MARK: - Test Fixtures

#if DEBUG

    extension UserInsights {
        static func fixture(
            userId: UUID = UUID(),
            period: InsightsPeriod = .month,
            itemsShared: Int = 25,
            itemsReceived: Int = 15,
            totalViews: Int = 500,
            totalLikes: Int = 120,
            foodSavedKg: Double = 12.5,
            co2SavedKg: Double = 62.5,
            waterSavedLiters: Double = 2500,
            moneySavedEstimate: Double = 125,
            messagesExchanged: Int = 85,
            successfulArrangements: Int = 38,
            averageResponseTimeMinutes: Int = 15,
            reviewsGiven: Int = 12,
            reviewsReceived: Int = 18,
            currentStreak: Int = 5,
            longestStreak: Int = 14,
            lastActiveDate: Date = Date(),
        ) -> UserInsights {
            UserInsights(
                userId: userId,
                period: period,
                itemsShared: itemsShared,
                itemsReceived: itemsReceived,
                totalViews: totalViews,
                totalLikes: totalLikes,
                foodSavedKg: foodSavedKg,
                co2SavedKg: co2SavedKg,
                waterSavedLiters: waterSavedLiters,
                moneySavedEstimate: moneySavedEstimate,
                messagesExchanged: messagesExchanged,
                successfulArrangements: successfulArrangements,
                averageResponseTimeMinutes: averageResponseTimeMinutes,
                reviewsGiven: reviewsGiven,
                reviewsReceived: reviewsReceived,
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                lastActiveDate: lastActiveDate,
            )
        }
    }

    extension ActivityTimelineItem {
        static func fixture(
            id: Int = 1,
            type: ActivityType = .shared,
            title: String = "Shared Fresh Apples",
            description: String? = "with Jane Doe",
            timestamp: Date = Date(),
            relatedPostId: Int? = 1,
            relatedUserId: UUID? = nil,
        ) -> ActivityTimelineItem {
            ActivityTimelineItem(
                id: id,
                type: type,
                title: title,
                description: description,
                timestamp: timestamp,
                relatedPostId: relatedPostId,
                relatedUserId: relatedUserId,
            )
        }
    }

#endif
