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
// NOTE: UIApplication is provided by Skip UI framework (includes launch() method).
// Do NOT redefine it here — it would shadow Skip's implementation.

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
    public var batteryLevel: Double { 1.0 }
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

    public var size: CGSize { CGSize(width: 0.0, height: 0.0) }
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
    public var components: [CGFloat]? { [0.0, 0.0, 0.0, 1.0] }
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
    public var largeTitleTextAttributes: [NSAttributedStringKey: Any] = [:]
    public var titleTextAttributes: [NSAttributedStringKey: Any] = [:]
    public init() {}
    public func configureWithDefaultBackground() {}
}

public class UINavigationBar {
    public static func appearance() -> UINavigationBar { UINavigationBar() }
    public var standardAppearance: UINavigationBarAppearance?
    public var scrollEdgeAppearance: UINavigationBarAppearance?
}

// MARK: - NSAttributedStringKey (stub)

public struct NSAttributedStringKey: Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let foregroundColor = NSAttributedStringKey(rawValue: "NSColor")
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
