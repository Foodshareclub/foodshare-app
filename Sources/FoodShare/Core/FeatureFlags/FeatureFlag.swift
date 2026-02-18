//
//  FeatureFlag.swift
//  Foodshare
//
//  Enterprise feature flag definitions for controlled rollouts
//


#if !SKIP
import Foundation

// MARK: - Feature Flag

/// All feature flags available in the application
///
/// Feature flags enable:
/// - Gradual rollouts to percentage of users
/// - A/B testing for new features
/// - Kill switches for problematic features
/// - Regional or user-segment targeting
///
/// Usage:
/// ```swift
/// if await FeatureFlagManager.shared.isEnabled(.newFeedAlgorithm) {
///     showNewFeed()
/// } else {
///     showLegacyFeed()
/// }
/// ```
enum FeatureFlag: String, CaseIterable, Sendable, Codable {
    // MARK: - Core Features

    /// New algorithm for feed ranking
    case newFeedAlgorithm = "new_feed_algorithm"

    /// Real-time messaging updates
    case realtimeMessaging = "realtime_messaging"

    /// AI-powered food categorization
    case aiCategories = "ai_categories"

    /// Enhanced search with filters
    case advancedSearch = "advanced_search"

    // MARK: - UI/UX Features

    /// New onboarding flow
    case newOnboarding = "new_onboarding"

    /// Liquid Glass design system v2
    case liquidGlassV2 = "liquid_glass_v2"

    /// Bottom sheet navigation
    case bottomSheetNav = "bottom_sheet_nav"

    /// Haptic feedback for all interactions
    case richHaptics = "rich_haptics"

    // MARK: - Social Features

    /// Community challenges
    case challenges

    /// User achievements and badges
    case achievements

    /// Food sharing streaks
    case streaks

    /// Social sharing to external platforms
    case socialSharing = "social_sharing"

    // MARK: - Premium Features

    /// Premium subscription tier
    case premiumSubscription = "premium_subscription"

    /// Priority listing placement
    case priorityListing = "priority_listing"

    /// Analytics dashboard for power users
    case userAnalytics = "user_analytics"

    /// Free premium trial - bypasses premium gates for map and challenges
    /// Toggle this in Supabase feature_flags table to enable/disable
    case freePremiumTrial = "free_premium_trial"

    // MARK: - Experimental

    /// AR food scanning
    case arFoodScanner = "ar_food_scanner"

    /// Voice-based listing creation
    case voiceListings = "voice_listings"

    /// Machine learning recommendations
    case mlRecommendations = "ml_recommendations"

    // MARK: - Debug/Dev

    /// Developer tools and debug menu
    case developerTools = "developer_tools"

    /// Network request logging
    case networkLogging = "network_logging"

    /// Performance overlay
    case performanceOverlay = "performance_overlay"

    // MARK: - Properties

    /// Human-readable name for the flag
    var displayName: String {
        switch self {
        case .newFeedAlgorithm: "New Feed Algorithm"
        case .realtimeMessaging: "Real-time Messaging"
        case .aiCategories: "AI Categories"
        case .advancedSearch: "Advanced Search"
        case .newOnboarding: "New Onboarding"
        case .liquidGlassV2: "Liquid Glass v2"
        case .bottomSheetNav: "Bottom Sheet Navigation"
        case .richHaptics: "Rich Haptics"
        case .challenges: "Challenges"
        case .achievements: "Achievements"
        case .streaks: "Streaks"
        case .socialSharing: "Social Sharing"
        case .premiumSubscription: "Premium Subscription"
        case .priorityListing: "Priority Listing"
        case .userAnalytics: "User Analytics"
        case .freePremiumTrial: "Free Premium Trial"
        case .arFoodScanner: "AR Food Scanner"
        case .voiceListings: "Voice Listings"
        case .mlRecommendations: "ML Recommendations"
        case .developerTools: "Developer Tools"
        case .networkLogging: "Network Logging"
        case .performanceOverlay: "Performance Overlay"
        }
    }

    /// Localized display name using translation service
    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .newFeedAlgorithm: t.t("feature_flag.new_feed_algorithm")
        case .realtimeMessaging: t.t("feature_flag.realtime_messaging")
        case .aiCategories: t.t("feature_flag.ai_categories")
        case .advancedSearch: t.t("feature_flag.advanced_search")
        case .newOnboarding: t.t("feature_flag.new_onboarding")
        case .liquidGlassV2: t.t("feature_flag.liquid_glass_v2")
        case .bottomSheetNav: t.t("feature_flag.bottom_sheet_nav")
        case .richHaptics: t.t("feature_flag.rich_haptics")
        case .challenges: t.t("feature_flag.challenges")
        case .achievements: t.t("feature_flag.achievements")
        case .streaks: t.t("feature_flag.streaks")
        case .socialSharing: t.t("feature_flag.social_sharing")
        case .premiumSubscription: t.t("feature_flag.premium_subscription")
        case .priorityListing: t.t("feature_flag.priority_listing")
        case .userAnalytics: t.t("feature_flag.user_analytics")
        case .freePremiumTrial: t.t("feature_flag.free_premium_trial")
        case .arFoodScanner: t.t("feature_flag.ar_food_scanner")
        case .voiceListings: t.t("feature_flag.voice_listings")
        case .mlRecommendations: t.t("feature_flag.ml_recommendations")
        case .developerTools: t.t("feature_flag.developer_tools")
        case .networkLogging: t.t("feature_flag.network_logging")
        case .performanceOverlay: t.t("feature_flag.performance_overlay")
        }
    }

    /// Description of what the flag controls
    var description: String {
        switch self {
        case .newFeedAlgorithm: "Personalized feed based on user preferences and location"
        case .realtimeMessaging: "Instant message delivery with typing indicators"
        case .aiCategories: "Automatic food categorization using ML"
        case .advancedSearch: "Filters for dietary restrictions, distance, and more"
        case .newOnboarding: "Streamlined onboarding with personalization"
        case .liquidGlassV2: "Enhanced glass morphism with improved animations"
        case .bottomSheetNav: "iOS 16+ style bottom sheet navigation"
        case .richHaptics: "Subtle haptic feedback for all interactions"
        case .challenges: "Community food sharing challenges"
        case .achievements: "Badges and achievements for milestones"
        case .streaks: "Track consecutive days of sharing"
        case .socialSharing: "Share listings to Instagram, Twitter, etc."
        case .premiumSubscription: "Premium tier with enhanced features"
        case .priorityListing: "Boost visibility of listings"
        case .userAnalytics: "Detailed stats on sharing activity"
        case .freePremiumTrial: "Temporarily unlock map and challenges for all users"
        case .arFoodScanner: "Scan food with camera for quick listing"
        case .voiceListings: "Create listings by voice description"
        case .mlRecommendations: "AI-powered food recommendations"
        case .developerTools: "Debug menu and developer options"
        case .networkLogging: "Log all network requests"
        case .performanceOverlay: "FPS and memory usage overlay"
        }
    }

    /// Default value when flag is not configured remotely
    var defaultValue: Bool {
        switch self {
        // Enabled by default
        case .realtimeMessaging, .advancedSearch, .richHaptics, .challenges, .achievements:
            return true

        // Debug flags and free trial enabled only in DEBUG builds
        case .developerTools, .networkLogging, .performanceOverlay, .freePremiumTrial:
            #if DEBUG
                return true
            #else
                return false
            #endif

        // Everything else disabled by default
        default:
            return false
        }
    }

    /// Category for organizing flags in admin UI
    var category: Category {
        switch self {
        case .newFeedAlgorithm, .realtimeMessaging, .aiCategories, .advancedSearch:
            .core
        case .newOnboarding, .liquidGlassV2, .bottomSheetNav, .richHaptics:
            .uiux
        case .challenges, .achievements, .streaks, .socialSharing:
            .social
        case .premiumSubscription, .priorityListing, .userAnalytics, .freePremiumTrial:
            .premium
        case .arFoodScanner, .voiceListings, .mlRecommendations:
            .experimental
        case .developerTools, .networkLogging, .performanceOverlay:
            .debug
        }
    }

    enum Category: String, CaseIterable, Sendable {
        case core = "Core Features"
        case uiux = "UI/UX"
        case social = "Social"
        case premium = "Premium"
        case experimental = "Experimental"
        case debug = "Debug"

        /// Localized display name for the category
        @MainActor
        func localizedDisplayName(using t: EnhancedTranslationService) -> String {
            switch self {
            case .core: t.t("feature_flag.category.core")
            case .uiux: t.t("feature_flag.category.uiux")
            case .social: t.t("feature_flag.category.social")
            case .premium: t.t("feature_flag.category.premium")
            case .experimental: t.t("feature_flag.category.experimental")
            case .debug: t.t("feature_flag.category.debug")
            }
        }
    }
}

// MARK: - Feature Flag Value

/// A feature flag value with metadata
struct FeatureFlagValue: Sendable, Codable {
    let flag: FeatureFlag
    let enabled: Bool
    let rolloutPercentage: Int // 0-100
    let targetSegments: [String]? // User segments this flag applies to
    let expiresAt: Date?
    let updatedAt: Date

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() > expiresAt
    }
}

// MARK: - Feature Flag Override

/// Local override for feature flags (for testing)
struct FeatureFlagOverride: Sendable, Codable {
    let flag: FeatureFlag
    let enabled: Bool
    let reason: String
    let createdAt: Date

    init(flag: FeatureFlag, enabled: Bool, reason: String = "Manual override") {
        self.flag = flag
        self.enabled = enabled
        self.reason = reason
        self.createdAt = Date()
    }
}

#endif
