import Foundation

/// Network-specific errors with contextual information
enum NetworkError: LocalizedError, Sendable {
    case invalidURL(String)
    case noData(endpoint: String)
    case decodingError(Error, endpoint: String)
    case encodingError(Error)
    case serverError(statusCode: Int, message: String?, endpoint: String)
    case unauthorized(endpoint: String)
    case forbidden(endpoint: String)
    case notFound(endpoint: String)
    case timeout(endpoint: String, duration: TimeInterval)
    case noInternetConnection
    case rateLimited(retryAfter: TimeInterval)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case let .invalidURL(url):
            return "Invalid URL: \(url)"
        case let .noData(endpoint):
            return "No data received from \(endpoint)"
        case let .decodingError(error, endpoint):
            return "Failed to decode response from \(endpoint): \(error.localizedDescription)"
        case let .encodingError(error):
            return "Failed to encode request: \(error.localizedDescription)"
        case let .serverError(statusCode, message, endpoint):
            if let message {
                return "Server error (\(statusCode)) at \(endpoint): \(message)"
            }
            return "Server error \(statusCode) at \(endpoint)"
        case let .unauthorized(endpoint):
            return "Unauthorized access to \(endpoint)"
        case let .forbidden(endpoint):
            return "Forbidden access to \(endpoint)"
        case let .notFound(endpoint):
            return "Resource not found: \(endpoint)"
        case let .timeout(endpoint, duration):
            return "Request to \(endpoint) timed out after \(Int(duration))s"
        case .noInternetConnection:
            return "No internet connection"
        case let .rateLimited(retryAfter):
            return "Rate limited. Retry after \(Int(retryAfter)) seconds"
        case let .unknown(error):
            return "Network error: \(error.localizedDescription)"
        }
    }

    /// User-friendly error message for display in UI
    var userFriendlyMessage: String {
        switch self {
        case .invalidURL:
            return "Something went wrong. Please try again."
        case .noData:
            return "No data received. Please try again."
        case .decodingError:
            return "We received unexpected data. Please try again."
        case .encodingError:
            return "Failed to send your request. Please try again."
        case let .serverError(statusCode, _, _):
            if statusCode >= 500 {
                return "Our servers are having issues. Please try again later."
            }
            return "Something went wrong. Please try again."
        case .unauthorized:
            return "Please sign in to continue."
        case .forbidden:
            return "You don't have permission to access this."
        case .notFound:
            return "The item you're looking for doesn't exist."
        case .timeout:
            return "Request timed out. Please check your connection and try again."
        case .noInternetConnection:
            return "No internet connection. Please check your connection."
        case let .rateLimited(retryAfter):
            return "Too many requests. Please wait \(Int(retryAfter)) seconds."
        case .unknown:
            return "An unexpected error occurred. Please try again."
        }
    }

    /// Localized user-friendly error message for display in UI
    @MainActor
    func localizedUserFriendlyMessage(using t: EnhancedTranslationService) -> String {
        switch self {
        case .invalidURL:
            return t.t("errors.network.invalid_url")
        case .noData:
            return t.t("errors.network.no_data")
        case .decodingError:
            return t.t("errors.network.decoding")
        case .encodingError:
            return t.t("errors.network.encoding")
        case let .serverError(statusCode, _, _):
            if statusCode >= 500 {
                return t.t("errors.network.server_error")
            }
            return t.t("errors.network.something_wrong")
        case .unauthorized:
            return t.t("errors.network.unauthorized")
        case .forbidden:
            return t.t("errors.network.forbidden")
        case .notFound:
            return t.t("errors.network.not_found")
        case .timeout:
            return t.t("errors.network.timeout")
        case .noInternetConnection:
            return t.t("errors.network.no_internet")
        case let .rateLimited(retryAfter):
            return t.t("errors.network.rate_limited", args: ["seconds": String(Int(retryAfter))])
        case .unknown:
            return t.t("errors.network.unknown")
        }
    }

    /// Whether this error is recoverable by retrying
    var isRetryable: Bool {
        switch self {
        case .noInternetConnection, .timeout, .rateLimited:
            true
        case let .serverError(statusCode, _, _):
            // 5xx errors are typically transient
            statusCode >= 500
        case .invalidURL, .noData, .decodingError, .encodingError,
             .unauthorized, .forbidden, .notFound, .unknown:
            false
        }
    }

    /// Suggested retry delay in seconds (nil if not retryable)
    var suggestedRetryDelay: TimeInterval? {
        switch self {
        case let .rateLimited(retryAfter):
            retryAfter
        case .timeout, .noInternetConnection:
            2.0
        case let .serverError(statusCode, _, _) where statusCode >= 500:
            5.0
        default:
            nil
        }
    }
}
