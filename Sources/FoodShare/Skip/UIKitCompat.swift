//
//  UIKitCompat.swift
//  FoodShare
//
//  Skip-compatible stubs for UIKit types used across the codebase.
//  Only compiled when transpiling for Android via Skip.
//  On iOS, the real UIKit framework is used instead.
//
//  These stubs provide API compatibility for transpilation.
//  Android-native implementations should be added where needed.
//

#if SKIP

import Foundation

// MARK: - UIApplication

public class UIApplication: @unchecked Sendable {
    public nonisolated static let shared = UIApplication()

    // Notification names (used by .onReceive / NotificationCenter observers)
    public static let willEnterForegroundNotification = Notification.Name("UIApplicationWillEnterForegroundNotification")
    public static let didBecomeActiveNotification = Notification.Name("UIApplicationDidBecomeActiveNotification")
    public static let willResignActiveNotification = Notification.Name("UIApplicationWillResignActiveNotification")
    public static let didEnterBackgroundNotification = Notification.Name("UIApplicationDidEnterBackgroundNotification")
    public static let didReceiveMemoryWarningNotification = Notification.Name("UIApplicationDidReceiveMemoryWarningNotification")

    /// Settings URL — on Android, maps to system Settings intent
    public static let openSettingsURLString = "app-settings:"

    /// Open a URL — on Android, should map to an Intent
    public func open(_ url: URL) {
        // TODO: Implement via Android Intent
    }

    /// Check if a URL can be opened
    public func canOpenURL(_ url: URL) -> Bool {
        false // TODO: Implement via Android PackageManager
    }

    /// Connected scenes — no equivalent on Android
    public var connectedScenes: [AnyObject] { [] }

    /// Alternate icon support (iOS-only)
    public var alternateIconName: String? { nil }
    public var supportsAlternateIcons: Bool { false }
    public func setAlternateIconName(_ iconName: String?) async throws {}
}

// MARK: - UIWindowScene (stub for type casting)

public class UIWindowScene {
    public var windows: [UIWindow] { [] }
}

// MARK: - UIWindow (stub)

public class UIWindow {
    public var rootViewController: AnyObject?
    public init(frame: CGRect = .zero) {}
}

// MARK: - UIScreen

public class UIScreen: @unchecked Sendable {
    public nonisolated static let main = UIScreen()
    public var bounds: CGRect { CGRect(x: 0, y: 0, width: 393, height: 852) }
    public var maximumFramesPerSecond: Int { 60 }
    public var isCaptured: Bool { false }
    public static let capturedDidChangeNotification = Notification.Name("UIScreenCapturedDidChangeNotification")
}

// MARK: - UIDevice

public class UIDevice: @unchecked Sendable {
    public nonisolated static let current = UIDevice()
    public var model: String { "Android" }
    public var systemVersion: String { "14" }
    public var name: String { "Android Device" }
    public var identifierForVendor: UUID? { nil }
    public var isBatteryMonitoringEnabled = false
    public var batteryLevel: Float { 1.0 }
    public var userInterfaceIdiom: UIUserInterfaceIdiom { .phone }
    public static let batteryLevelDidChangeNotification = Notification.Name("UIDeviceBatteryLevelDidChangeNotification")
}

public enum UIUserInterfaceIdiom: Int, Sendable {
    case phone
    case pad
}

// MARK: - UIImage (minimal stub for basic usage)

public class UIImage: @unchecked Sendable {
    public let cgImage: CGImage?
    private let imageData: Data?

    public init?(data: Data) {
        self.imageData = data
        self.cgImage = nil
    }

    public init(cgImage: CGImage) {
        self.cgImage = cgImage
        self.imageData = nil
    }

    public init?(systemName: String) {
        self.imageData = nil
        self.cgImage = nil
    }

    public init?(named: String) {
        self.imageData = nil
        self.cgImage = nil
    }

    public init() {
        self.imageData = nil
        self.cgImage = nil
    }

    /// JPEG representation
    public func jpegData(compressionQuality: CGFloat) -> Data? {
        imageData
    }

    /// PNG representation
    public func pngData() -> Data? {
        imageData
    }

    public var size: CGSize { CGSize(width: 0, height: 0) }
}

// MARK: - CGImage (minimal stub)

public class CGImage {}

// MARK: - UIColor (minimal stub for common patterns)

public class UIColor: @unchecked Sendable {
    public var cgColor: CGColor { CGColor() }

    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {}

    /// Dynamic color provider (trait-based)
    public convenience init(_ dynamicProvider: @escaping (Any) -> UIColor) {
        self.init(red: 0, green: 0, blue: 0, alpha: 1)
    }

    /// Initialize from SwiftUI Color (no-op stub)
    public convenience init(_ color: Any) {
        self.init(red: 0, green: 0, blue: 0, alpha: 1)
    }

    /// Get RGBA components
    public func getRed(
        _ red: inout CGFloat,
        green: inout CGFloat,
        blue: inout CGFloat,
        alpha: inout CGFloat
    ) -> Bool {
        red = 0; green = 0; blue = 0; alpha = 1
        return true
    }

    // System colors
    public static let secondarySystemBackground = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
}

// MARK: - CGColor (minimal stub)

public class CGColor {
    public var components: [CGFloat]? { [0, 0, 0, 1] }
}

// MARK: - UITabBar / UINavigationBarAppearance (stubs for appearance setup)

public class UITabBar {
    public static func appearance() -> UITabBar { UITabBar() }
    public var unselectedItemTintColor: UIColor?
}

public class UITabBarAppearance {
    public var backgroundColor: UIColor?
    public init() {}
    public func configureWithDefaultBackground() {}
}

public class UINavigationBarAppearance {
    public var backgroundColor: UIColor?
    public var largeTitleTextAttributes: [NSAttributedString.Key: Any] = [:]
    public var titleTextAttributes: [NSAttributedString.Key: Any] = [:]
    public init() {}
    public func configureWithDefaultBackground() {}
}

public class UINavigationBar {
    public static func appearance() -> UINavigationBar { UINavigationBar() }
    public var standardAppearance: UINavigationBarAppearance?
    public var scrollEdgeAppearance: UINavigationBarAppearance?
}

// MARK: - NSAttributedString.Key (stub)

extension NSAttributedString {
    public struct Key: Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let foregroundColor = Key(rawValue: "NSColor")
    }
}

// MARK: - UIImagePickerController (stub for camera picker)

public class UIImagePickerController {
    public enum SourceType {
        case camera
        case photoLibrary
    }

    public struct InfoKey: Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let originalImage = InfoKey(rawValue: "UIImagePickerControllerOriginalImage")
    }

    public var sourceType: SourceType = .camera
    public var delegate: AnyObject?
}

#endif
