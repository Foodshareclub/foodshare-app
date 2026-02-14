//
//  InputValidator.swift
//  FoodShare
//
//  Centralized input validation framework
//  Provides SQL injection, XSS, and general input sanitization
//

import Foundation

// MARK: - Validation Result

/// Result of input validation
public struct ValidationResult: Sendable {
    /// Whether the input passed validation
    public let isValid: Bool

    /// Validation error messages (empty if valid)
    public let errors: [String]

    /// The sanitized/cleaned input value
    public let sanitizedValue: String?

    /// First error message (convenience)
    public var firstError: String? {
        errors.first
    }

    public static func valid(_ sanitizedValue: String? = nil) -> ValidationResult {
        ValidationResult(isValid: true, errors: [], sanitizedValue: sanitizedValue)
    }

    public static func invalid(_ errors: [String]) -> ValidationResult {
        ValidationResult(isValid: false, errors: errors, sanitizedValue: nil)
    }

    public static func invalid(_ error: String) -> ValidationResult {
        invalid([error])
    }
}

// MARK: - Validation Rule Protocol

/// Protocol for validation rules
public protocol ValidationRule: Sendable {
    /// Validate the input
    func validate(_ input: String) -> ValidationResult
}

// MARK: - Input Validator

/// Centralized input validator with common security checks
public struct InputValidator: Sendable {
    /// Shared instance with default configuration
    public static let shared = InputValidator()

    // MARK: - Configuration

    /// Maximum length for various input types
    public struct MaxLengths: Sendable {
        public let name: Int
        public let email: Int
        public let bio: Int
        public let title: Int
        public let description: Int
        public let address: Int
        public let message: Int
        public let url: Int
        public let searchQuery: Int

        public static let `default` = MaxLengths(
            name: 100,
            email: 254,
            bio: 500,
            title: 200,
            description: 2000,
            address: 300,
            message: 5000,
            url: 2048,
            searchQuery: 200,
        )
    }

    public let maxLengths: MaxLengths

    public init(maxLengths: MaxLengths = .default) {
        self.maxLengths = maxLengths
    }

    // MARK: - General Validation

    /// Validate and sanitize a general text input
    public func validateText(
        _ input: String?,
        fieldName: String = "Field",
        minLength: Int = 0,
        maxLength: Int = 1000,
        allowEmpty: Bool = true,
        trim: Bool = true,
    ) -> ValidationResult {
        guard var text = input else {
            if allowEmpty {
                return .valid("")
            }
            return .invalid("\(fieldName) is required")
        }

        if trim {
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Check empty
        if text.isEmpty {
            if allowEmpty {
                return .valid("")
            }
            return .invalid("\(fieldName) is required")
        }

        // Check length
        if text.count < minLength {
            return .invalid("\(fieldName) must be at least \(minLength) characters")
        }

        if text.count > maxLength {
            return .invalid("\(fieldName) must be at most \(maxLength) characters")
        }

        // Sanitize
        let sanitized = sanitizeForDisplay(text)

        return .valid(sanitized)
    }

    /// Validate an email address
    public func validateEmail(_ email: String?) -> ValidationResult {
        guard let email = email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else {
            return .invalid("Email is required")
        }

        // Length check
        if email.count > maxLengths.email {
            return .invalid("Email is too long")
        }

        // Format check
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)

        if !emailPredicate.evaluate(with: email) {
            return .invalid("Invalid email format")
        }

        // Sanitize
        let sanitized = email.lowercased()

        return .valid(sanitized)
    }

    /// Validate a URL
    public func validateURL(_ urlString: String?, fieldName: String = "URL") -> ValidationResult {
        guard let urlString = urlString?.trimmingCharacters(in: .whitespacesAndNewlines), !urlString.isEmpty else {
            return .valid(nil) // URLs are often optional
        }

        // Length check
        if urlString.count > maxLengths.url {
            return .invalid("\(fieldName) is too long")
        }

        // Parse URL
        guard let url = URL(string: urlString) else {
            return .invalid("Invalid URL format")
        }

        // Scheme check (only allow http/https)
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return .invalid("\(fieldName) must use HTTP or HTTPS")
        }

        // Host check
        guard url.host != nil else {
            return .invalid("\(fieldName) is missing a domain")
        }

        return .valid(urlString)
    }

    /// Validate a phone number
    public func validatePhone(_ phone: String?) -> ValidationResult {
        guard let phone = phone?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty else {
            return .valid(nil) // Phone is often optional
        }

        // Remove common formatting
        let cleaned = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)

        // Length check
        if cleaned.count < 10 || cleaned.count > 15 {
            return .invalid("Invalid phone number")
        }

        return .valid(cleaned)
    }

    /// Validate a search query
    public func validateSearchQuery(_ query: String?) -> ValidationResult {
        guard var query = query?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty else {
            return .valid("")
        }

        // Length check
        if query.count > maxLengths.searchQuery {
            query = String(query.prefix(maxLengths.searchQuery))
        }

        // Sanitize for search
        let sanitized = sanitizeForSearch(query)

        return .valid(sanitized)
    }

    // MARK: - Security Sanitization

    /// Sanitize input for safe display (XSS prevention)
    public func sanitizeForDisplay(_ input: String) -> String {
        var sanitized = input

        // Encode HTML entities
        let htmlEntities: [(String, String)] = [
            ("&", "&amp;"),
            ("<", "&lt;"),
            (">", "&gt;"),
            ("\"", "&quot;"),
            ("'", "&#39;"),
        ]

        for (char, entity) in htmlEntities {
            sanitized = sanitized.replacingOccurrences(of: char, with: entity)
        }

        // Remove control characters
        sanitized = removeControlCharacters(sanitized)

        return sanitized
    }

    /// Sanitize input for database queries (SQL injection prevention)
    /// Note: Always use parameterized queries; this is a defense-in-depth measure
    public func sanitizeForDatabase(_ input: String) -> String {
        var sanitized = input

        // Escape single quotes
        sanitized = sanitized.replacingOccurrences(of: "'", with: "''")

        // Remove null bytes
        sanitized = sanitized.replacingOccurrences(of: "\0", with: "")

        // Remove control characters
        sanitized = removeControlCharacters(sanitized)

        return sanitized
    }

    /// Sanitize input for search queries
    public func sanitizeForSearch(_ input: String) -> String {
        var sanitized = input

        // Remove special regex/search operators
        let specialChars = ["\\", "[", "]", "(", ")", "{", "}", "^", "$", ".", "|", "?", "*", "+"]
        for char in specialChars {
            sanitized = sanitized.replacingOccurrences(of: char, with: " ")
        }

        // Normalize whitespace
        sanitized = sanitized.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return sanitized
    }

    /// Remove control characters from input
    public func removeControlCharacters(_ input: String) -> String {
        // Remove all control characters except newlines and tabs
        input.unicodeScalars.filter { scalar in
            if scalar == "\n" || scalar == "\r" || scalar == "\t" {
                return true
            }
            return !CharacterSet.controlCharacters.contains(scalar)
        }.map { String($0) }.joined()
    }

    // MARK: - Dangerous Pattern Detection

    /// Check if input contains potential SQL injection patterns
    public func containsSQLInjectionPatterns(_ input: String) -> Bool {
        let patterns = [
            #"(?i)(\b(SELECT|INSERT|UPDATE|DELETE|DROP|UNION|ALTER|CREATE|TRUNCATE)\b)"#,
            #"(?i)(--|\#|/\*|\*/)"#,
            #"(?i)(\bOR\b\s+\d+\s*=\s*\d+)"#,
            #"(?i)(\bAND\b\s+\d+\s*=\s*\d+)"#,
            #"(?i)(;\s*(SELECT|INSERT|UPDATE|DELETE|DROP))"#,
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) != nil
            {
                return true
            }
        }

        return false
    }

    /// Check if input contains potential XSS patterns
    public func containsXSSPatterns(_ input: String) -> Bool {
        let patterns = [
            #"<\s*script"#,
            #"javascript\s*:"#,
            #"on\w+\s*="#,
            #"<\s*iframe"#,
            #"<\s*object"#,
            #"<\s*embed"#,
            #"<\s*link"#,
            #"<\s*style"#,
            #"expression\s*\("#,
            #"url\s*\("#,
        ]

        let lowercased = input.lowercased()

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)) != nil
            {
                return true
            }
        }

        return false
    }

    /// Check if input contains any dangerous patterns
    public func containsDangerousPatterns(_ input: String) -> Bool {
        containsSQLInjectionPatterns(input) || containsXSSPatterns(input)
    }

    // MARK: - Composite Validation

    /// Validate a name (user name, listing name, etc.)
    public func validateName(_ name: String?, fieldName: String = "Name") -> ValidationResult {
        validateText(
            name,
            fieldName: fieldName,
            minLength: 1,
            maxLength: maxLengths.name,
            allowEmpty: false,
            trim: true,
        )
    }

    /// Validate a bio or description
    public func validateBio(_ bio: String?) -> ValidationResult {
        validateText(
            bio,
            fieldName: "Bio",
            minLength: 0,
            maxLength: maxLengths.bio,
            allowEmpty: true,
            trim: true,
        )
    }

    /// Validate a listing title
    public func validateListingTitle(_ title: String?) -> ValidationResult {
        let result = validateText(
            title,
            fieldName: "Title",
            minLength: 3,
            maxLength: maxLengths.title,
            allowEmpty: false,
            trim: true,
        )

        // Additional checks for listing titles
        if result.isValid, let sanitized = result.sanitizedValue {
            if containsDangerousPatterns(sanitized) {
                return .invalid("Title contains invalid characters")
            }
        }

        return result
    }

    /// Validate a listing description
    public func validateListingDescription(_ description: String?) -> ValidationResult {
        let result = validateText(
            description,
            fieldName: "Description",
            minLength: 10,
            maxLength: maxLengths.description,
            allowEmpty: false,
            trim: true,
        )

        if result.isValid, let sanitized = result.sanitizedValue {
            if containsDangerousPatterns(sanitized) {
                return .invalid("Description contains invalid characters")
            }
        }

        return result
    }

    /// Validate an address
    public func validateAddress(_ address: String?) -> ValidationResult {
        validateText(
            address,
            fieldName: "Address",
            minLength: 5,
            maxLength: maxLengths.address,
            allowEmpty: false,
            trim: true,
        )
    }

    /// Validate a message
    public func validateMessage(_ message: String?) -> ValidationResult {
        let result = validateText(
            message,
            fieldName: "Message",
            minLength: 1,
            maxLength: maxLengths.message,
            allowEmpty: false,
            trim: true,
        )

        if result.isValid, let sanitized = result.sanitizedValue {
            if containsDangerousPatterns(sanitized) {
                return .invalid("Message contains invalid content")
            }
        }

        return result
    }
}

// MARK: - Numeric Validation

extension InputValidator {
    /// Validate a numeric range value
    public func validateRange(
        _ value: Double,
        min: Double,
        max: Double,
        fieldName: String = "Value",
    ) -> ValidationResult {
        if value < min {
            return .invalid("\(fieldName) must be at least \(min)")
        }

        if value > max {
            return .invalid("\(fieldName) must be at most \(max)")
        }

        return .valid(String(value))
    }

    /// Validate a positive integer
    public func validatePositiveInteger(_ value: Int?, fieldName: String = "Value") -> ValidationResult {
        guard let value else {
            return .invalid("\(fieldName) is required")
        }

        if value <= 0 {
            return .invalid("\(fieldName) must be positive")
        }

        return .valid(String(value))
    }
}

// MARK: - Chainable Validation

/// Builder for chainable validation
public final class ValidationBuilder: @unchecked Sendable {
    private var results: [ValidationResult] = []
    private let validator = InputValidator.shared

    public init() {}

    @discardableResult
    public func validateEmail(_ email: String?) -> ValidationBuilder {
        results.append(validator.validateEmail(email))
        return self
    }

    @discardableResult
    public func validateName(_ name: String?, fieldName: String = "Name") -> ValidationBuilder {
        results.append(validator.validateName(name, fieldName: fieldName))
        return self
    }

    @discardableResult
    public func validateText(
        _ text: String?,
        fieldName: String,
        minLength: Int = 0,
        maxLength: Int = 1000,
    ) -> ValidationBuilder {
        results.append(validator.validateText(text, fieldName: fieldName, minLength: minLength, maxLength: maxLength))
        return self
    }

    public func build() -> ValidationResult {
        let errors = results.flatMap(\.errors)
        if errors.isEmpty {
            return .valid()
        }
        return .invalid(errors)
    }
}
