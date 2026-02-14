//
//  Color+Extensions.swift
//  Foodshare
//
//  Color utilities: hex initialization and interpolation
//

import SwiftUI
#if !SKIP
import UIKit
#endif

extension Color {
    // MARK: - Hex Initialization (String)

    /// Initialize Color from hex string
    /// - Parameter hex: Hex color string (supports 3, 6, or 8 character formats)
    ///
    /// Examples:
    /// - `Color(hex: "FFF")` - RGB (12-bit)
    /// - `Color(hex: "2ECC71")` - RGB (24-bit)
    /// - `Color(hex: "FF2ECC71")` - ARGB (32-bit)
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }

    // MARK: - Hex Initialization (UInt)

    /// Initialize Color from hex UInt value
    /// - Parameters:
    ///   - hex: Hex color as UInt (e.g., 0x2ECC71)
    ///   - alpha: Optional alpha value (0.0 - 1.0)
    init(_ hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, opacity: alpha)
    }

    // MARK: - Color Interpolation

    /// Interpolate between two colors for smooth animated transitions
    /// - Parameters:
    ///   - color: Target color to interpolate towards
    ///   - amount: Interpolation amount (0.0 = self, 1.0 = target color)
    /// - Returns: Interpolated color
    func interpolate(to color: Color, amount: Double) -> Color {
        let clampedAmount = min(max(0, amount), 1)

        #if !SKIP
        guard let c1 = UIColor(self).cgColor.components,
              let c2 = UIColor(color).cgColor.components
        else {
            return self
        }

        // Handle colors with different component counts (RGB vs grayscale)
        let r1 = c1.count >= 3 ? c1[0] : c1[0]
        let g1 = c1.count >= 3 ? c1[1] : c1[0]
        let b1 = c1.count >= 3 ? c1[2] : c1[0]
        let a1 = c1.count == 4 ? c1[3] : (c1.count == 2 ? c1[1] : 1.0)

        let r2 = c2.count >= 3 ? c2[0] : c2[0]
        let g2 = c2.count >= 3 ? c2[1] : c2[0]
        let b2 = c2.count >= 3 ? c2[2] : c2[0]
        let a2 = c2.count == 4 ? c2[3] : (c2.count == 2 ? c2[1] : 1.0)

        let r = r1 + (r2 - r1) * clampedAmount
        let g = g1 + (g2 - g1) * clampedAmount
        let b = b1 + (b2 - b1) * clampedAmount
        let a = a1 + (a2 - a1) * clampedAmount

        return Color(red: r, green: g, blue: b, opacity: a)
        #else
        // On Android, return a simple blend (no UIColor component extraction)
        return clampedAmount < 0.5 ? self : color
        #endif
    }
}
