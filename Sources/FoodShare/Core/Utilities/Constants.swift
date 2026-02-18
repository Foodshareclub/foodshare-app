
import Foundation

/// Static constants for values that don't change based on configuration.
/// For configurable values, use `AppConfiguration.shared` instead.
enum Constants {
    // MARK: - App Identity

    #if !SKIP
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.flutterflow.foodshare"
    static let appName = "Foodshare"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "246"
    #else
    static let bundleIdentifier = "com.flutterflow.foodshare"
    static let appName = "Foodshare"
    static let appVersion = "3.0"
    static let buildNumber = "246"
    #endif

    // MARK: - Unit Conversions (immutable)

    static let metersPerKilometer = 1000.0

    // MARK: - Time Intervals (immutable)

    static let secondsPerHour = 3600.0
    static let secondsPerDay = 86400.0
    static let locationRequestTimeout = 10.0 // seconds

    // MARK: - Authentication

    static let minimumPasswordLength = 8

    // MARK: - Default Values

    static let defaultExpiryDays = 1

    // MARK: - Component Sizes (Design System)

    enum ComponentSize {
        // Button heights
        static let buttonHeight: CGFloat = 56
        static let buttonHeightCompact: CGFloat = 44

        // Card images
        static let cardImageHeight: CGFloat = 200
        static let detailImageHeight: CGFloat = 300

        // Avatars and icons
        static let avatarSmall: CGFloat = 32
        static let avatarMedium: CGFloat = 40
        static let avatarLarge: CGFloat = 64

        // List items
        static let listItemHeight: CGFloat = 60
        static let leaderboardItemHeight: CGFloat = 60

        // Touch targets (minimum)
        static let minTouchTarget: CGFloat = 44 // Apple HIG
    }
}
