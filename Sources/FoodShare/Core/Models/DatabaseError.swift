import Foundation

/// Database-related errors with Sendable conformance for safe concurrent usage
enum DatabaseError: LocalizedError, Sendable {
    case connectionFailed(String)
    case queryFailed(String)
    case notFound
    case unauthorized
    case invalidInput(String)
    case invalidData
    case deleteFailed
    case rateLimited(retryAfter: TimeInterval)
    case serverError(statusCode: Int, message: String)
    /// Unknown error - stores description string instead of Error for Sendable conformance
    case unknown(Error & Sendable)

    var errorDescription: String? {
        switch self {
        case let .connectionFailed(reason):
            "Failed to connect: \(reason)"
        case let .queryFailed(message):
            "Query failed: \(message)"
        case .notFound:
            "Resource not found"
        case .unauthorized:
            "Unauthorized access"
        case let .invalidInput(field):
            "Invalid input: \(field)"
        case .invalidData:
            "Invalid data format"
        case .deleteFailed:
            "Failed to delete resource"
        case let .rateLimited(retryAfter):
            "Rate limited. Try again in \(Int(retryAfter)) seconds"
        case let .serverError(statusCode, message):
            "Server error (\(statusCode)): \(message)"
        case let .unknown(error):
            "Database error: \(error.localizedDescription)"
        }
    }

    /// User-friendly error message for display in UI
    var userFriendlyMessage: String {
        switch self {
        case .connectionFailed:
            "Unable to connect. Please check your internet connection."
        case .queryFailed:
            "Something went wrong. Please try again."
        case .notFound:
            "The item you're looking for doesn't exist."
        case .unauthorized:
            "Please sign in to continue."
        case .invalidInput:
            "Please check your input and try again."
        case .invalidData:
            "We received unexpected data. Please try again."
        case .deleteFailed:
            "Couldn't delete this item. Please try again."
        case let .rateLimited(retryAfter):
            "Too many requests. Please wait \(Int(retryAfter)) seconds."
        case .serverError:
            "Our servers are having issues. Please try again later."
        case .unknown:
            "An unexpected error occurred. Please try again."
        }
    }

    /// Localized user-friendly error message for display in UI
    @MainActor
    func localizedUserFriendlyMessage(using t: EnhancedTranslationService) -> String {
        switch self {
        case .connectionFailed:
            t.t("errors.database.connection_failed")
        case .queryFailed:
            t.t("errors.database.query_failed")
        case .notFound:
            t.t("errors.database.not_found")
        case .unauthorized:
            t.t("errors.database.unauthorized")
        case .invalidInput:
            t.t("errors.database.invalid_input")
        case .invalidData:
            t.t("errors.database.invalid_data")
        case .deleteFailed:
            t.t("errors.database.delete_failed")
        case let .rateLimited(retryAfter):
            t.t("errors.database.rate_limited", args: ["seconds": String(Int(retryAfter))])
        case .serverError:
            t.t("errors.database.server_error")
        case .unknown:
            t.t("errors.database.unknown")
        }
    }

    /// Whether this error is recoverable by retrying
    var isRetryable: Bool {
        switch self {
        case .connectionFailed, .rateLimited, .serverError:
            true
        case .queryFailed, .notFound, .unauthorized, .invalidInput, .invalidData, .deleteFailed, .unknown:
            false
        }
    }
}
