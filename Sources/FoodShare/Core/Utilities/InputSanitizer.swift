//
//  InputSanitizer.swift
//  Foodshare
//
//  Input sanitization utilities for security
//

import Foundation

// MARK: - Input Sanitizer

enum InputSanitizer {
    // MARK: - Text Sanitization

    /// Sanitize text input by removing dangerous characters
    static func sanitizeText(_ input: String) -> String {
        var sanitized = input

        // Remove null bytes
        sanitized = sanitized.replacingOccurrences(of: "\0", with: "")

        // Remove control characters (except newlines and tabs)
        sanitized = sanitized.unicodeScalars
            .filter { scalar in
                scalar == "\n" || scalar == "\t" || scalar == "\r" ||
                    !CharacterSet.controlCharacters.contains(scalar)
            }
            .map { String($0) }
            .joined()

        return sanitized
    }

    /// Sanitize HTML by escaping special characters
    static func escapeHTML(_ input: String) -> String {
        input
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    /// Strip all HTML tags from input
    static func stripHTML(_ input: String) -> String {
        input.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression,
        )
    }

    /// Sanitize for SQL (basic protection - use parameterized queries)
    static func sanitizeForSQL(_ input: String) -> String {
        input
            .replacingOccurrences(of: "'", with: "''")
            .replacingOccurrences(of: "\\", with: "\\\\")
    }

    // MARK: - URL Sanitization

    /// Validate and sanitize URL string
    static func sanitizeURL(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for valid URL
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return nil
        }

        return url.absoluteString
    }

    // MARK: - Email Sanitization

    /// Sanitize email address
    static func sanitizeEmail(_ input: String) -> String {
        input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    // MARK: - Filename Sanitization

    /// Sanitize filename for safe storage
    static func sanitizeFilename(_ input: String) -> String {
        // Remove path separators and dangerous characters
        let dangerous = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let components = input.unicodeScalars.filter { !dangerous.contains($0) }
        var sanitized = String(String.UnicodeScalarView(components))

        // Remove leading dots (hidden files)
        while sanitized.hasPrefix(".") {
            sanitized.removeFirst()
        }

        // Limit length
        if sanitized.count > 255 {
            sanitized = String(sanitized.prefix(255))
        }

        // Ensure not empty
        if sanitized.isEmpty {
            sanitized = "unnamed"
        }

        return sanitized
    }

    // MARK: - Length Validation

    /// Truncate string to maximum length
    static func truncate(_ input: String, maxLength: Int) -> String {
        if input.count <= maxLength {
            return input
        }
        return String(input.prefix(maxLength))
    }

    /// Validate string length is within bounds
    static func validateLength(
        _ input: String,
        min: Int = 0,
        max: Int = Int.max,
    ) -> Bool {
        input.count >= min && input.count <= max
    }
}

// MARK: - String Extension

extension String {
    /// Sanitized version of the string
    var sanitized: String {
        InputSanitizer.sanitizeText(self)
    }

    /// HTML-escaped version of the string
    var htmlEscaped: String {
        InputSanitizer.escapeHTML(self)
    }

    /// HTML-stripped version of the string
    var htmlStripped: String {
        InputSanitizer.stripHTML(self)
    }

    /// Truncated to max length
    func truncated(to maxLength: Int) -> String {
        InputSanitizer.truncate(self, maxLength: maxLength)
    }

    /// Check if string is within length bounds
    func isWithinLength(min: Int = 0, max: Int = Int.max) -> Bool {
        InputSanitizer.validateLength(self, min: min, max: max)
    }
}

// MARK: - Validation Patterns

enum ValidationPattern {
    /// Email regex pattern
    static let email = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"

    /// Phone number pattern (basic)
    static let phone = "^[+]?[0-9]{10,15}$"

    /// Username pattern (alphanumeric + underscore)
    static let username = "^[a-zA-Z0-9_]{3,30}$"

    /// Strong password pattern
    static let strongPassword = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[@$!%*?&])[A-Za-z\\d@$!%*?&]{8,}$"

    /// Check if string matches pattern
    static func matches(_ input: String, pattern: String) -> Bool {
        input.range(of: pattern, options: .regularExpression) != nil
    }
}
