//
//  EdgeFunctionError.swift
//  Foodshare
//
//  Typed errors mapping Edge Function error codes to app-level errors.
//  Error codes from foodshare-backend/_shared/errors.ts
//



#if !SKIP
import Foundation

enum EdgeFunctionError: LocalizedError, Sendable {
    case validation(String)
    case authenticationRequired
    case forbidden(String)
    case notFound(String)
    case conflict(String)
    case rateLimited(retryAfterMs: Int?)
    case payloadTooLarge(String)
    case serverError(String)
    case serviceUnavailable(String)
    case timeout(String)
    case networkError(String)
    case decodingError(String)
    case unknownError(code: String, message: String)

    var errorDescription: String? {
        switch self {
        case .validation(let msg): msg
        case .authenticationRequired: "Authentication required"
        case .forbidden(let msg): msg
        case .notFound(let msg): msg
        case .conflict(let msg): msg
        case .rateLimited: "Too many requests. Please try again later."
        case .payloadTooLarge(let msg): msg
        case .serverError(let msg): msg
        case .serviceUnavailable(let msg): msg
        case .timeout(let msg): msg
        case .networkError(let msg): msg
        case .decodingError(let msg): "Failed to decode response: \(msg)"
        case .unknownError(_, let msg): msg
        }
    }

    var isRetryable: Bool {
        switch self {
        case .rateLimited, .serviceUnavailable, .timeout, .networkError:
            true
        case .serverError:
            true
        default:
            false
        }
    }

    /// Maps an Edge Function error code + message to a typed error
    static func from(code: String, message: String) -> EdgeFunctionError {
        switch code {
        case "VALIDATION_ERROR", "UNPROCESSABLE_ENTITY":
            .validation(message)
        case "AUTHENTICATION_ERROR":
            .authenticationRequired
        case "AUTHORIZATION_ERROR", "FORBIDDEN":
            .forbidden(message)
        case "NOT_FOUND":
            .notFound(message)
        case "CONFLICT":
            .conflict(message)
        case "RATE_LIMIT_EXCEEDED":
            .rateLimited(retryAfterMs: nil)
        case "PAYLOAD_TOO_LARGE":
            .payloadTooLarge(message)
        case "DATABASE_ERROR", "SERVER_ERROR", "CONFIGURATION_ERROR":
            .serverError(message)
        case "SERVICE_UNAVAILABLE", "CIRCUIT_OPEN":
            .serviceUnavailable(message)
        case "TIMEOUT":
            .timeout(message)
        case "EXTERNAL_SERVICE_ERROR", "BAD_GATEWAY":
            .serviceUnavailable(message)
        default:
            .unknownError(code: code, message: message)
        }
    }

    /// Maps an HTTP status code (when response body isn't parseable) to an error
    static func fromHTTPStatus(_ statusCode: Int, body: String? = nil) -> EdgeFunctionError {
        let message = body ?? "HTTP \(statusCode)"
        switch statusCode {
        case 400: return .validation(message)
        case 401: return .authenticationRequired
        case 403: return .forbidden(message)
        case 404: return .notFound(message)
        case 409: return .conflict(message)
        case 413: return .payloadTooLarge(message)
        case 429: return .rateLimited(retryAfterMs: nil)
        case 500: return .serverError(message)
        case 502, 503: return .serviceUnavailable(message)
        case 504: return .timeout(message)
        default: return .unknownError(code: "HTTP_\(statusCode)", message: message)
        }
    }
}


#endif
