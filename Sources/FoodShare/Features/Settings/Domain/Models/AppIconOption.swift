//
//  AppIconOption.swift
//  Foodshare
//
//  Model for alternate app icon options
//

import SwiftUI

/// Represents an app icon option that users can select
struct AppIconOption: Identifiable, Hashable, Sendable {
    /// Unique identifier for the icon
    let id: String

    /// Display name shown in the picker
    let displayName: String

    /// The icon name as configured in Info.plist (nil = primary icon)
    let iconName: String?

    /// Whether this icon requires premium subscription
    let isPremium: Bool

    /// Preview colors for displaying in the picker
    let previewColors: [Color]

    /// Description of the icon theme
    let description: String

    /// Check if this is the primary (default) app icon
    var isPrimary: Bool { iconName == nil }
}

// MARK: - Available Icons

extension AppIconOption {
    /// All available app icons
    /// Note: Alternate icons temporarily disabled - icon assets not yet created
    static let allIcons: [AppIconOption] = [
        // Primary icon (default)
        AppIconOption(
            id: "default",
            displayName: "Default",
            iconName: nil,
            isPremium: false,
            previewColors: [.DesignSystem.brandGreen, .DesignSystem.brandTeal],
            description: "The classic Foodshare icon",
        ),
        // TODO: Re-enable when alternate icon assets are added to the bundle
        // Requires: AppIcon-Dark, AppIcon-Minimal, AppIcon-Nature, AppIcon-Ocean, AppIcon-Pride
        // in both 60x60@2x (iPhone) and 76x76@2x (iPad) sizes
    ]

    /// Get the currently selected icon
    @MainActor
    static var currentIcon: AppIconOption {
        let currentIconName = UIApplication.shared.alternateIconName
        return allIcons.first { $0.iconName == currentIconName } ?? allIcons[0]
    }

    /// Free icons available to all users
    static var freeIcons: [AppIconOption] {
        allIcons.filter { !$0.isPremium }
    }

    /// Premium-only icons
    static var premiumIcons: [AppIconOption] {
        allIcons.filter(\.isPremium)
    }
}

// MARK: - App Icon Manager

/// Manager for changing the app icon
@MainActor
final class AppIconManager {
    static let shared = AppIconManager()

    private init() {}

    /// Whether alternate icons are supported on this device
    var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    /// The currently selected icon
    var currentIcon: AppIconOption {
        AppIconOption.currentIcon
    }

    /// Change the app icon
    /// - Parameter icon: The icon to switch to
    /// - Throws: Error if the icon change fails
    func setIcon(_ icon: AppIconOption) async throws {
        guard supportsAlternateIcons else {
            throw AppIconError.notSupported
        }

        try await UIApplication.shared.setAlternateIconName(icon.iconName)
    }

    /// Reset to the primary (default) icon
    func resetToDefault() async throws {
        try await UIApplication.shared.setAlternateIconName(nil)
    }
}

// MARK: - App Icon Error

enum AppIconError: LocalizedError, Sendable {
    case notSupported
    case changeFailed(String)

    var errorDescription: String? {
        switch self {
        case .notSupported:
            "Alternate app icons are not supported on this device"
        case let .changeFailed(reason):
            "Failed to change app icon: \(reason)"
        }
    }
}

// MARK: - Color Hex Helper

/// Helper for creating colors from hex strings (scoped to avoid redeclaration)
private func colorFromHex(_ hex: String) -> Color? {
    var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

    var rgb: UInt64 = 0

    guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
        return nil
    }

    let red = Double((rgb & 0xFF0000) >> 16) / 255.0
    let green = Double((rgb & 0x00FF00) >> 8) / 255.0
    let blue = Double(rgb & 0x0000FF) / 255.0

    return Color(red: red, green: green, blue: blue)
}
