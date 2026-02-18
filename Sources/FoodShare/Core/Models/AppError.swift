//
//  AppError.swift
//  Foodshare
//
//  Application-wide error types with contextual information
//  Fully Sendable for safe concurrent error propagation
//


import Foundation

/// Application-wide error types with Sendable conformance for safe concurrent usage
enum AppError: LocalizedError, Equatable, Sendable {
    case networkError(String)
    case validationError(String)
    case validation(ValidationError)
    case unauthorized(action: String)
    case notFound(resource: String)
    case locationError(String)
    case databaseError(String)
    case configurationError(String)
    case rateLimitExceeded(retryAfter: TimeInterval)
    case permissionDenied(feature: String)
    case syncFailed(reason: String)
    case decodingError(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case let .networkError(message):
            "Network error: \(message)"
        case let .validationError(message):
            message
        case let .validation(validationError):
            validationError.localizedDescription
        case let .unauthorized(action):
            "You must be logged in to \(action)"
        case let .notFound(resource):
            "\(resource) not found"
        case let .locationError(message):
            "Location error: \(message)"
        case let .databaseError(message):
            "Database error: \(message)"
        case let .configurationError(message):
            "Configuration error: \(message)"
        case let .rateLimitExceeded(retryAfter):
            "Too many requests. Try again in \(Int(retryAfter)) seconds."
        case let .permissionDenied(feature):
            "Permission denied for \(feature)"
        case let .syncFailed(reason):
            "Sync failed: \(reason)"
        case let .decodingError(message):
            "Data parsing error: \(message)"
        case let .unknown(message):
            "Error: \(message)"
        }
    }

    /// User-friendly error message for display in UI
    var userFriendlyMessage: String {
        switch self {
        case .networkError:
            "Unable to connect. Please check your internet connection."
        case .validationError, .validation:
            errorDescription ?? "Please check your input and try again."
        case .unauthorized:
            "Please sign in to continue."
        case .notFound:
            "The item you're looking for doesn't exist."
        case .locationError:
            "Unable to access your location. Please check your settings."
        case .databaseError:
            "Something went wrong. Please try again."
        case .configurationError:
            "The app isn't configured correctly. Please restart."
        case let .rateLimitExceeded(retryAfter):
            "Too many requests. Please wait \(Int(retryAfter)) seconds."
        case .permissionDenied:
            "You don't have permission to access this feature."
        case .syncFailed:
            "Unable to sync your data. Will retry automatically."
        case .decodingError:
            "We had trouble reading the data. Please try again."
        case .unknown:
            "An unexpected error occurred. Please try again."
        }
    }

    #if !SKIP
    /// Localized user-friendly error message for display in UI
    @MainActor
    func localizedUserFriendlyMessage(using t: EnhancedTranslationService) -> String {
        switch self {
        case .networkError:
            t.t("errors.app.network")
        case .validationError, .validation:
            errorDescription ?? t.t("errors.app.validation")
        case .unauthorized:
            t.t("errors.app.unauthorized")
        case .notFound:
            t.t("errors.app.not_found")
        case .locationError:
            t.t("errors.app.location")
        case .databaseError:
            t.t("errors.app.database")
        case .configurationError:
            t.t("errors.app.configuration")
        case let .rateLimitExceeded(retryAfter):
            t.t("errors.app.rate_limited", args: ["seconds": String(Int(retryAfter))])
        case .permissionDenied:
            t.t("errors.app.permission_denied")
        case .syncFailed:
            t.t("errors.app.sync_failed")
        case .decodingError:
            t.t("errors.app.decoding")
        case .unknown:
            t.t("errors.app.unknown")
        }
    }
    #endif

    /// Whether this error is recoverable by retrying
    var isRetryable: Bool {
        switch self {
        case .networkError, .rateLimitExceeded, .syncFailed:
            true
        case .validationError, .validation, .unauthorized, .notFound,
             .locationError, .databaseError, .configurationError,
             .permissionDenied, .decodingError, .unknown:
            false
        }
    }

    /// Icon to display with this error in UI
    var iconName: String {
        switch self {
        case .networkError:
            "wifi.slash"
        case .validationError, .validation:
            "exclamationmark.triangle"
        case .unauthorized:
            "lock.fill"
        case .notFound:
            "magnifyingglass"
        case .locationError:
            "location.slash"
        case .databaseError, .syncFailed:
            "arrow.triangle.2.circlepath"
        case .decodingError:
            "doc.questionmark"
        case .configurationError:
            "gearshape.fill"
        case .rateLimitExceeded:
            "clock.fill"
        case .permissionDenied:
            "hand.raised.fill"
        case .unknown:
            "questionmark.circle"
        }
    }

    // MARK: - Factory Methods

    #if !SKIP
    /// Create from NetworkError
    static func from(_ error: NetworkError) -> AppError {
        switch error {
        case .noInternetConnection:
            .networkError("No internet connection")
        case .timeout:
            .networkError("Request timed out")
        case .unauthorized:
            .unauthorized(action: "access this resource")
        case .notFound:
            .notFound(resource: "Resource")
        case let .rateLimited(retryAfter):
            .rateLimitExceeded(retryAfter: retryAfter)
        default:
            .networkError(error.localizedDescription)
        }
    }

    /// Create from DatabaseError
    static func from(_ error: DatabaseError) -> AppError {
        switch error {
        case let .connectionFailed(reason):
            .networkError(reason)
        case .unauthorized:
            .unauthorized(action: "access the database")
        case .notFound:
            .notFound(resource: "Record")
        case let .rateLimited(retryAfter):
            .rateLimitExceeded(retryAfter: retryAfter)
        default:
            .databaseError(error.localizedDescription)
        }
    }
    #endif

    #if !SKIP
    /// Create from any Error type
    /// Attempts to convert known error types, falls back to unknown
    static func from(_ error: any Error) -> AppError {
        // Already an AppError
        if let appError = error as? AppError {
            return appError
        }

        // Known error types (iOS-only typed errors)
        if let networkError = error as? NetworkError {
            return from(networkError)
        }
        if let databaseError = error as? DatabaseError {
            return from(databaseError)
        }
        if let validationError = error as? ValidationError {
            return .validation(validationError)
        }

        // URLSession errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError("No internet connection")
            case .timedOut:
                return .networkError("Request timed out")
            case .cancelled:
                return .networkError("Request cancelled")
            default:
                return .networkError(urlError.localizedDescription)
            }
        }

        // Decoding errors
        if let decodingError = error as? DecodingError {
            switch decodingError {
            case let .keyNotFound(key, _):
                return .decodingError("Missing key: \(key.stringValue)")
            case let .typeMismatch(type, context):
                return .decodingError(
                    "Type mismatch for \(type): \(context.codingPath.map(\.stringValue).joined(separator: "."))"
                )
            case let .valueNotFound(type, context):
                return .decodingError(
                    "Missing value for \(type): \(context.codingPath.map(\.stringValue).joined(separator: "."))"
                )
            case let .dataCorrupted(context):
                return .decodingError("Data corrupted: \(context.debugDescription)")
            @unknown default:
                return .decodingError(decodingError.localizedDescription)
            }
        }

        // Fallback
        return .unknown(error.localizedDescription)
    }
    #else
    /// Create from Error (Android/Skip version)
    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        return .unknown(error.localizedDescription)
    }
    #endif
}

// MARK: - Equatable for Associated Values

#if !SKIP
extension AppError {
    static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.networkError(let a), .networkError(let b)):
            a == b
        case (.validationError(let a), .validationError(let b)):
            a == b
        case (.validation(let a), .validation(let b)):
            a == b
        case (.unauthorized(let a), .unauthorized(let b)):
            a == b
        case (.notFound(let a), .notFound(let b)):
            a == b
        case (.locationError(let a), .locationError(let b)):
            a == b
        case (.databaseError(let a), .databaseError(let b)):
            a == b
        case (.configurationError(let a), .configurationError(let b)):
            a == b
        case (.rateLimitExceeded(let a), .rateLimitExceeded(let b)):
            a == b
        case (.permissionDenied(let a), .permissionDenied(let b)):
            a == b
        case (.syncFailed(let a), .syncFailed(let b)):
            a == b
        case (.decodingError(let a), .decodingError(let b)):
            a == b
        case (.unknown(let a), .unknown(let b)):
            a == b
        default:
            false
        }
    }
}
#endif

// MARK: - Validation Error

/// Validation errors with Sendable conformance for safe concurrent usage
enum ValidationError: LocalizedError, Equatable, Sendable {
    case outOfRange(field: String, min: Double, max: Double)
    case custom(String)
    case invalidInput(String)
    case missingRequiredField(String)
    case invalidFormat(field: String, expected: String)
    case tooLong(field: String, maxLength: Int)
    case tooShort(field: String, minLength: Int)

    var errorDescription: String? {
        switch self {
        case let .outOfRange(field, min, max):
            "\(field) must be between \(Int(min)) and \(Int(max))"
        case let .custom(message):
            message
        case let .invalidInput(field):
            "Invalid input for \(field)"
        case let .missingRequiredField(field):
            "\(field) is required"
        case let .invalidFormat(field, expected):
            "\(field) must be in \(expected) format"
        case let .tooLong(field, maxLength):
            "\(field) must be \(maxLength) characters or less"
        case let .tooShort(field, minLength):
            "\(field) must be at least \(minLength) characters"
        }
    }

    /// User-friendly error message for display in UI
    var userFriendlyMessage: String {
        errorDescription ?? "Please check your input."
    }

    #if !SKIP
    /// Localized user-friendly error message for display in UI
    @MainActor
    func localizedUserFriendlyMessage(using t: EnhancedTranslationService) -> String {
        errorDescription ?? t.t("errors.validation.check_input")
    }
    #endif
}
