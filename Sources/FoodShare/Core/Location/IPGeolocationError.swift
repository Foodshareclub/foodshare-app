//
//  IPGeolocationError.swift
//  Foodshare
//
//  Enterprise error types for IP-based geolocation with detailed diagnostics.
//

import Foundation

// MARK: - IP Geolocation Provider

/// Available IP geolocation service providers
enum IPGeolocationProvider: String, CaseIterable, Sendable, Codable {
    case ipapi = "ip-api.com"
    case ipwhois = "ipwhois.app"
    case ipinfo = "ipinfo.io"
    case ipdata = "ipdata.co"
    case manual = "manual-override"

    /// Priority for provider selection (lower = higher priority)
    var priority: Int {
        switch self {
        case .ipapi: 1 // Most accurate for US, try first
        case .ipwhois: 2
        case .ipinfo: 3
        case .ipdata: 4
        case .manual: 0
        }
    }

    /// Rate limit per hour (approximate)
    var rateLimitPerHour: Int? {
        switch self {
        case .ipapi: 45 // 45 requests/minute on free tier
        case .ipwhois: 10000 / 30 / 24 // ~14/hour (10k/month)
        case .ipinfo: 50000 / 30 / 24 // ~70/hour (50k/month)
        case .ipdata: 1500 / 24 // ~62/hour (1500/day)
        case .manual: nil
        }
    }

    /// Base URL for the provider
    var baseURL: String {
        switch self {
        case .ipapi: "http://ip-api.com" // Note: HTTPS requires paid plan
        case .ipwhois: "https://ipwhois.app"
        case .ipinfo: "https://ipinfo.io"
        case .ipdata: "https://api.ipdata.co"
        case .manual: ""
        }
    }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .ipapi: "IP-API"
        case .ipwhois: "IP Whois"
        case .ipinfo: "IP Info"
        case .ipdata: "IP Data"
        case .manual: "Manual Location"
        }
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .ipapi: t.t("geolocation.provider.ipapi")
        case .ipwhois: t.t("geolocation.provider.ipwhois")
        case .ipinfo: t.t("geolocation.provider.ipinfo")
        case .ipdata: t.t("geolocation.provider.ipdata")
        case .manual: t.t("geolocation.provider.manual")
        }
    }
}

// MARK: - Provider Error

/// Error from a specific provider with context
struct IPGeolocationProviderError: Error, Sendable {
    let provider: IPGeolocationProvider
    let error: IPGeolocationError
    let attemptDuration: TimeInterval
    let timestamp: Date

    init(
        provider: IPGeolocationProvider,
        error: IPGeolocationError,
        attemptDuration: TimeInterval = 0,
        timestamp: Date = Date(),
    ) {
        self.provider = provider
        self.error = error
        self.attemptDuration = attemptDuration
        self.timestamp = timestamp
    }
}

// MARK: - IP Geolocation Error

/// Comprehensive error types for IP geolocation operations
enum IPGeolocationError: Error, LocalizedError, Sendable {
    // MARK: - Provider Errors

    /// All configured providers failed to return a valid location
    case allProvidersUnavailable([IPGeolocationProviderError])

    /// Circuit breaker is open for the specified provider
    case circuitOpen(provider: IPGeolocationProvider, retryAfter: TimeInterval)

    /// Provider rate limit exceeded
    case rateLimited(provider: IPGeolocationProvider, retryAfter: TimeInterval?)

    /// Request to provider timed out
    case timeout(provider: IPGeolocationProvider, duration: TimeInterval)

    // MARK: - Response Errors

    /// Provider returned invalid or unparseable response
    case invalidResponse(provider: IPGeolocationProvider, reason: String)

    /// Specific field in response was missing or invalid
    case parsingError(provider: IPGeolocationProvider, field: String)

    /// Returned coordinates are outside valid ranges
    case coordinatesInvalid(latitude: Double, longitude: Double)

    // MARK: - Network Errors

    /// Network connectivity issue
    case networkError(provider: IPGeolocationProvider, underlying: String)

    /// HTTP error response
    case httpError(provider: IPGeolocationProvider, statusCode: Int)

    // MARK: - Configuration Errors

    /// VPN detected, location may be inaccurate
    case vpnDetected(detectedLocation: String?)

    /// Service is disabled or misconfigured
    case serviceDisabled

    /// No providers configured
    case noProvidersConfigured

    // MARK: - Cache Errors

    /// Cached result expired and refresh failed
    case cacheExpiredRefreshFailed(originalError: String)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case let .allProvidersUnavailable(errors):
            let count = errors.count
            return "All \(count) location providers failed. Please check your internet connection."

        case let .circuitOpen(provider, retryAfter):
            return "Service '\(provider.displayName)' is temporarily unavailable. Retry in \(Int(retryAfter))s."

        case let .rateLimited(provider, retryAfter):
            let retryText = retryAfter.map { " Retry in \(Int($0))s." } ?? ""
            return "'\(provider.displayName)' rate limit exceeded.\(retryText)"

        case let .timeout(provider, duration):
            return "Request to '\(provider.displayName)' timed out after \(String(format: "%.1f", duration))s."

        case let .invalidResponse(provider, reason):
            return "Invalid response from '\(provider.displayName)': \(reason)"

        case let .parsingError(provider, field):
            return "Could not parse '\(field)' from '\(provider.displayName)' response."

        case let .coordinatesInvalid(lat, lon):
            return "Invalid coordinates returned: (\(lat), \(lon))"

        case let .networkError(_, underlying):
            return "Network error: \(underlying)"

        case let .httpError(provider, statusCode):
            return "HTTP \(statusCode) from '\(provider.displayName)'"

        case let .vpnDetected(location):
            let locationText = location.map { " (detected: \($0))" } ?? ""
            return "VPN detected\(locationText). Location may be inaccurate."

        case .serviceDisabled:
            return "IP geolocation service is disabled."

        case .noProvidersConfigured:
            return "No geolocation providers are configured."

        case let .cacheExpiredRefreshFailed(error):
            return "Cached location expired and refresh failed: \(error)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .allProvidersUnavailable:
            "Check your internet connection or try again later."

        case let .circuitOpen(_, retryAfter):
            "Wait \(Int(retryAfter)) seconds before retrying."

        case .rateLimited:
            "Wait a few minutes before retrying."

        case .timeout:
            "Check your connection speed and try again."

        case .vpnDetected:
            "Disable VPN for accurate location or set your location manually."

        case .serviceDisabled, .noProvidersConfigured:
            "Contact support if this persists."

        default:
            "Try again later."
        }
    }

    // MARK: - Error Classification

    /// Whether this error is transient and can be retried
    var isTransient: Bool {
        switch self {
        case .timeout, .networkError, .rateLimited:
            true
        case let .httpError(_, code) where code >= 500:
            true
        default:
            false
        }
    }

    /// Whether this error indicates the provider should be marked as failing
    var shouldCountAsFailure: Bool {
        switch self {
        case .timeout, .networkError, .httpError, .invalidResponse, .parsingError:
            true
        case .rateLimited, .circuitOpen, .vpnDetected:
            false
        default:
            false
        }
    }

    /// Suggested wait time before retry (if applicable)
    var suggestedRetryDelay: TimeInterval? {
        switch self {
        case let .circuitOpen(_, retryAfter):
            retryAfter
        case let .rateLimited(_, retryAfter):
            retryAfter ?? 60
        case .timeout:
            5
        case .networkError:
            3
        default:
            nil
        }
    }
}

// MARK: - Error Aggregation

extension IPGeolocationError {
    /// Create an aggregated error from multiple provider failures
    static func aggregate(_ errors: [IPGeolocationProviderError]) -> IPGeolocationError {
        guard !errors.isEmpty else {
            return .noProvidersConfigured
        }
        return .allProvidersUnavailable(errors)
    }

    /// Extract provider errors from an aggregated error
    var providerErrors: [IPGeolocationProviderError] {
        if case let .allProvidersUnavailable(errors) = self {
            return errors
        }
        return []
    }

    /// Get the fastest failing provider (for diagnostics)
    var fastestFailure: IPGeolocationProviderError? {
        providerErrors.min { $0.attemptDuration < $1.attemptDuration }
    }

    /// Total time spent across all provider attempts
    var totalAttemptDuration: TimeInterval {
        providerErrors.reduce(0) { $0 + $1.attemptDuration }
    }
}
