//
//  PasswordStrength.swift
//  Foodshare
//
//  Password strength evaluation utility
//  Extracted from AuthenticationService for reusability
//


#if !SKIP
import SwiftUI

/// Password strength levels with visual feedback
enum PasswordStrength: Sendable, Equatable {
    case none
    case weak
    case medium
    case strong
    case veryStrong

    /// Evaluate password strength based on complexity criteria
    /// - Parameter password: The password to evaluate
    /// - Returns: Strength level based on length and character variety
    static func evaluate(_ password: String) -> PasswordStrength {
        if password.isEmpty { return .none }
        if password.count < 8 { return .weak }

        let hasUppercase = password.range(of: "[A-Z]", options: String.CompareOptions.regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: String.CompareOptions.regularExpression) != nil
        let hasNumber = password.range(of: "[0-9]", options: String.CompareOptions.regularExpression) != nil
        let hasSpecial = password.range(of: "[^A-Za-z0-9]", options: String.CompareOptions.regularExpression) != nil

        let strength = [hasUppercase, hasLowercase, hasNumber, hasSpecial].count(where: { $0 })

        switch strength {
        case 0 ... 1: return .weak
        case 2: return .medium
        case 3: return .strong
        default: return .veryStrong
        }
    }

    /// Color for visual strength indicator
    var color: Color {
        switch self {
        case .none: .gray
        case .weak: .red
        case .medium: .orange
        case .strong: .yellow
        case .veryStrong: .green
        }
    }

    /// Human-readable strength label
    var text: String {
        switch self {
        case .none: ""
        case .weak: "Weak"
        case .medium: "Medium"
        case .strong: "Strong"
        case .veryStrong: "Very Strong"
        }
    }
}

#endif
