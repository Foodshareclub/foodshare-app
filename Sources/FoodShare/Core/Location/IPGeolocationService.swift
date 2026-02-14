//
//  IPGeolocationService.swift
//  Foodshare
//
//  Enterprise IP geolocation service with circuit breakers, parallel requests,
//  retry logic, metrics, and user override support.
//

import Foundation
import OSLog

// MARK: - Configuration

/// Configuration for the IP geolocation service
struct IPGeolocationConfiguration: Sendable {
    /// Enabled providers in priority order
    let enabledProviders: [IPGeolocationProvider]

    /// Whether to use parallel requests (race providers)
    let parallelRequests: Bool

    /// Maximum number of parallel providers
    let maxParallelProviders: Int

    /// Whether caching is enabled
    let cacheEnabled: Bool

    /// Default cache TTL (overridden by confidence-based TTL)
    let defaultCacheTTL: TimeInterval

    /// Retry policy for transient failures
    let retryPolicy: IPGeolocationRetryPolicy

    /// Request timeout in seconds
    let timeoutSeconds: TimeInterval

    /// Whether to collect metrics
    let enableMetrics: Bool

    /// Default configuration
    static let `default` = IPGeolocationConfiguration(
        enabledProviders: [.ipapi, .ipwhois, .ipinfo, .ipdata],
        parallelRequests: true,
        maxParallelProviders: 3,
        cacheEnabled: true,
        defaultCacheTTL: 3600,
        retryPolicy: .default,
        timeoutSeconds: 5.0,
        enableMetrics: true,
    )

    /// Conservative configuration for low-bandwidth scenarios
    static let conservative = IPGeolocationConfiguration(
        enabledProviders: [.ipapi, .ipwhois],
        parallelRequests: false,
        maxParallelProviders: 1,
        cacheEnabled: true,
        defaultCacheTTL: 7200,
        retryPolicy: .conservative,
        timeoutSeconds: 3.0,
        enableMetrics: false,
    )
}

// MARK: - IP Geolocation Service

/// Enterprise-grade IP geolocation service with reliability features.
///
/// Features:
/// - Per-provider circuit breakers for fault isolation
/// - Parallel provider requests for faster response
/// - Exponential backoff retry for transient failures
/// - Request deduplication to prevent redundant calls
/// - Confidence-based dynamic caching
/// - User location override support
/// - Comprehensive metrics collection
///
/// Usage:
/// ```swift
/// let service = IPGeolocationService.shared
///
/// // Get location with rich result
/// let result = try await service.getDetailedLocation()
/// print("Location: \(result.metadata.shortLocation)")
/// print("Confidence: \(result.confidence.displayName)")
///
/// // Legacy API (returns simple Location)
/// let location = try await service.getLocationFromIP()
/// ```
actor IPGeolocationService {
    static let shared = IPGeolocationService()

    private let logger = Logger(subsystem: Constants.bundleIdentifier, category: "IPGeolocationService")

    // MARK: - Configuration

    private let configuration: IPGeolocationConfiguration

    // MARK: - Circuit Breakers

    private let circuitBreakers: [IPGeolocationProvider: CircuitBreaker]

    // MARK: - Caching

    private var cachedResult: IPGeolocationResult?

    // MARK: - Request Deduplication

    private var inFlightRequest: Task<IPGeolocationResult, Error>?

    // MARK: - Initialization

    init(configuration: IPGeolocationConfiguration = .default) {
        self.configuration = configuration

        // Initialize circuit breakers for each enabled provider
        var breakers: [IPGeolocationProvider: CircuitBreaker] = [:]
        for provider in configuration.enabledProviders {
            let config = CircuitBreaker.Configuration(
                failureThreshold: 3,
                resetTimeout: 60,
                successThreshold: 2,
                failureWindow: 300,
                trackSlowCalls: true,
                slowCallThreshold: configuration.timeoutSeconds,
                slowCallRateThreshold: 0.5,
            )
            breakers[provider] = CircuitBreaker(
                name: "ip-geo-\(provider.rawValue)",
                config: config,
            )
        }
        self.circuitBreakers = breakers
    }

    // MARK: - Public API

    /// Get location from IP with rich result including confidence and metadata
    ///
    /// Priority:
    /// 1. User override (if set)
    /// 2. Valid cache
    /// 3. Fresh request (parallel or sequential based on config)
    func getDetailedLocation() async throws -> IPGeolocationResult {
        // Record service request
        if configuration.enableMetrics {
            await IPGeolocationMetrics.shared.recordServiceRequest()
        }

        // 1. Check for user override first
        if let override = await UserLocationOverrideManager.shared.asGeolocationResult() {
            logger.debug("Using user location override")
            return override
        }

        // 2. Check cache
        if configuration.cacheEnabled, let cached = cachedResult, cached.isValid {
            if configuration.enableMetrics {
                await IPGeolocationMetrics.shared.recordCacheHit()
            }
            logger.debug("Returning cached IP location")
            return cached.asCached()
        }

        if configuration.enableMetrics {
            await IPGeolocationMetrics.shared.recordCacheMiss()
        }

        // 3. Deduplicate concurrent requests
        if let existingRequest = inFlightRequest {
            logger.debug("Waiting for existing request")
            return try await existingRequest.value
        }

        // 4. Fetch fresh location
        let task = Task { () -> IPGeolocationResult in
            defer { inFlightRequest = nil }

            if configuration.parallelRequests {
                return try await fetchLocationParallel()
            } else {
                return try await fetchLocationSequential()
            }
        }

        inFlightRequest = task
        let result = try await task.value

        // Cache the result
        cachedResult = result

        return result
    }

    /// Legacy API: Get simple Location from IP
    ///
    /// For backward compatibility with existing code.
    func getLocationFromIP() async throws -> Location {
        let result = try await getDetailedLocation()
        return result.location
    }

    /// Clear the cached location
    func clearCache() {
        cachedResult = nil
        if configuration.enableMetrics {
            Task {
                await IPGeolocationMetrics.shared.recordCacheInvalidation()
            }
        }
        logger.debug("Cache cleared")
    }

    /// Get health status of the service
    func healthCheck() async -> IPGeolocationHealthStatus {
        var available: [IPGeolocationProvider] = []
        var unavailable: [IPGeolocationProvider] = []
        var states: [IPGeolocationProvider: String] = [:]

        for (provider, breaker) in circuitBreakers {
            let state = await breaker.currentState
            states[provider] = state.rawValue

            if await breaker.isAllowingRequests {
                available.append(provider)
            } else {
                unavailable.append(provider)
            }
        }

        let cacheStatus = IPGeolocationHealthStatus.CacheStatus(
            hasValidCache: cachedResult?.isValid ?? false,
            cacheAge: cachedResult.map { Date().timeIntervalSince($0.timestamp) },
            cacheConfidence: cachedResult?.confidence,
        )

        return await IPGeolocationHealthStatus(
            isHealthy: !available.isEmpty || cacheStatus.hasValidCache,
            availableProviders: available,
            unavailableProviders: unavailable,
            circuitBreakerStates: states,
            cacheStatus: cacheStatus,
            lastSuccessfulRequest: cachedResult?.timestamp,
            metrics: IPGeolocationMetrics.shared.serviceSummary(),
        )
    }

    // MARK: - Parallel Fetch Strategy

    /// Race multiple providers in parallel, take first success
    private func fetchLocationParallel() async throws -> IPGeolocationResult {
        // Get providers with open circuits
        var availableProviders: [IPGeolocationProvider] = []
        for provider in configuration.enabledProviders.sorted(by: { $0.priority < $1.priority }) {
            if let breaker = circuitBreakers[provider], await breaker.isAllowingRequests {
                availableProviders.append(provider)
            }
        }

        let providers = Array(availableProviders.prefix(configuration.maxParallelProviders))

        guard !providers.isEmpty else {
            // All circuits open - try to return stale cache or throw
            if let stale = cachedResult {
                logger.warning("All circuits open, returning stale cache")
                return stale.asCached()
            }
            throw IPGeolocationError.allProvidersUnavailable([])
        }

        if configuration.enableMetrics {
            await IPGeolocationMetrics.shared.recordParallelBatch(providerCount: providers.count)
        }

        logger.debug("Starting parallel fetch with \(providers.count) providers")

        return try await withThrowingTaskGroup(of: IPGeolocationResult?.self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        return try await self.fetchFromProvider(provider)
                    } catch {
                        return nil
                    }
                }
            }

            // Take first successful result
            for try await result in group {
                if let result {
                    group.cancelAll()
                    return result
                }
            }

            // All providers failed (we don't collect individual errors in parallel mode)
            throw IPGeolocationError.allProvidersUnavailable([])
        }
    }

    // MARK: - Sequential Fetch Strategy

    /// Try providers one by one until success
    private func fetchLocationSequential() async throws -> IPGeolocationResult {
        var providerErrors: [IPGeolocationProviderError] = []

        for provider in configuration.enabledProviders.sorted(by: { $0.priority < $1.priority }) {
            // Check circuit breaker
            guard let breaker = circuitBreakers[provider], await breaker.isAllowingRequests else {
                logger.debug("Skipping \(provider.rawValue) - circuit open")
                continue
            }

            do {
                return try await fetchFromProvider(provider)
            } catch {
                let providerError = IPGeolocationProviderError(
                    provider: provider,
                    error: error as? IPGeolocationError ?? .networkError(
                        provider: provider,
                        underlying: error.localizedDescription,
                    ),
                )
                providerErrors.append(providerError)
                logger.warning("Provider \(provider.rawValue) failed, trying next")
            }
        }

        throw IPGeolocationError.allProvidersUnavailable(providerErrors)
    }

    // MARK: - Provider Request

    /// Fetch from a single provider with circuit breaker and retry
    private func fetchFromProvider(_ provider: IPGeolocationProvider) async throws -> IPGeolocationResult {
        guard let breaker = circuitBreakers[provider] else {
            throw IPGeolocationError.serviceDisabled
        }

        let startTime = Date()
        let retryPolicy = configuration.retryPolicy
        let enableMetrics = configuration.enableMetrics

        do {
            // Execute with circuit breaker - handle retries inside
            let result = try await executeWithRetry(
                provider: provider,
                breaker: breaker,
                retryPolicy: retryPolicy,
            )

            let duration = Date().timeIntervalSince(startTime)

            if enableMetrics {
                await IPGeolocationMetrics.shared.recordRequest(
                    provider: provider,
                    duration: duration,
                    success: true,
                )
            }

            return result
        } catch {
            let duration = Date().timeIntervalSince(startTime)

            if enableMetrics {
                let geoError = error as? IPGeolocationError
                await IPGeolocationMetrics.shared.recordRequest(
                    provider: provider,
                    duration: duration,
                    success: false,
                    error: geoError,
                )

                if error is CircuitBreakerError {
                    await IPGeolocationMetrics.shared.recordCircuitOpen(provider: provider)
                }
            }

            throw error
        }
    }

    /// Execute provider request with retry logic, respecting circuit breaker
    private func executeWithRetry(
        provider: IPGeolocationProvider,
        breaker: CircuitBreaker,
        retryPolicy: IPGeolocationRetryPolicy,
    ) async throws -> IPGeolocationResult {
        var lastError: Error?
        var attempt = 0

        while attempt <= retryPolicy.maxRetries {
            // Check circuit breaker state before attempting
            guard await breaker.prepareRequest() else {
                throw CircuitBreakerError.circuitOpen(
                    name: provider.rawValue,
                    retryAfter: 30.0, // Default retry interval
                )
            }

            let startTime = Date()

            do {
                let result = try await performProviderRequest(provider)
                let duration = Date().timeIntervalSince(startTime)
                await breaker.reportSuccess(duration: duration)
                return result
            } catch let error as CircuitBreakerError {
                // Don't retry circuit breaker errors - they indicate the circuit is open
                throw error
            } catch {
                let duration = Date().timeIntervalSince(startTime)
                await breaker.reportFailure(error: error, duration: duration)

                lastError = error
                attempt += 1

                if retryPolicy.shouldRetry(attempt: attempt, error: error) {
                    let delay = retryPolicy.delay(for: attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    break
                }
            }
        }

        throw lastError ?? IPGeolocationError.networkError(provider: provider, underlying: "No attempts made")
    }

    /// Perform the actual HTTP request to a provider
    private func performProviderRequest(_ provider: IPGeolocationProvider) async throws -> IPGeolocationResult {
        let startTime = Date()

        switch provider {
        case .ipapi:
            return try await fetchFromIPAPI(startTime: startTime)
        case .ipwhois:
            return try await fetchFromIPWhoIs(startTime: startTime)
        case .ipinfo:
            return try await fetchFromIPInfo(startTime: startTime)
        case .ipdata:
            return try await fetchFromIPData(startTime: startTime)
        case .manual:
            throw IPGeolocationError.serviceDisabled
        }
    }

    // MARK: - Provider Implementations

    /// ip-api.com - Free, no API key, good US accuracy, returns accuracy radius
    /// Note: Free tier is HTTP only (HTTPS requires paid plan)
    private func fetchFromIPAPI(startTime: Date) async throws -> IPGeolocationResult {
        let provider = IPGeolocationProvider.ipapi
        guard let url =
            URL(
                string: "http://ip-api.com/json/?fields=status,message,lat,lon,city,regionName,country,countryCode,timezone,isp,mobile,proxy,hosting",
            ) else {
            throw IPGeolocationError.invalidResponse(provider: provider, reason: "Invalid URL")
        }

        let (data, _) = try await performRequest(url: url, provider: provider)

        struct IPAPIResponse: Decodable {
            let status: String
            let message: String?
            let lat: Double?
            let lon: Double?
            let city: String?
            let regionName: String?
            let country: String?
            let countryCode: String?
            let timezone: String?
            let isp: String?
            let mobile: Bool?
            let proxy: Bool?
            let hosting: Bool?
        }

        let decoded = try JSONDecoder().decode(IPAPIResponse.self, from: data)

        guard decoded.status == "success",
              let lat = decoded.lat,
              let lon = decoded.lon else {
            throw IPGeolocationError.invalidResponse(provider: provider, reason: decoded.message ?? "Request failed")
        }

        guard Location(latitude: lat, longitude: lon).isValid else {
            throw IPGeolocationError.coordinatesInvalid(latitude: lat, longitude: lon)
        }

        // ip-api is generally more accurate, especially for US
        let isVPN = decoded.proxy == true || decoded.hosting == true
        let confidence: LocationConfidence = decoded.city != nil ? .medium : .low
        let duration = Int(Date().timeIntervalSince(startTime) * 1000)

        return IPGeolocationResult(
            location: Location(latitude: lat, longitude: lon),
            provider: provider,
            confidence: confidence,
            timestamp: Date(),
            isFromCache: false,
            accuracyRadiusKm: 25.0, // ip-api is typically accurate to ~25km
            metadata: GeolocationMetadata(
                city: decoded.city,
                region: decoded.regionName,
                country: decoded.country,
                countryCode: decoded.countryCode,
                timezone: decoded.timezone,
                isp: decoded.isp,
                isVPN: isVPN,
            ),
            fetchDurationMs: duration,
        )
    }

    /// ipwhois.app - Free, no API key, HTTPS
    private func fetchFromIPWhoIs(startTime: Date) async throws -> IPGeolocationResult {
        let provider = IPGeolocationProvider.ipwhois
        guard let url =
            URL(
                string: "https://ipwhois.app/json/?objects=latitude,longitude,city,region,country,country_code,timezone,isp,success",
            ) else {
            throw IPGeolocationError.invalidResponse(provider: provider, reason: "Invalid URL")
        }

        let (data, _) = try await performRequest(url: url, provider: provider)

        struct IPWhoIsResponse: Decodable {
            let success: Bool
            let latitude: Double?
            let longitude: Double?
            let city: String?
            let region: String?
            let country: String?
            let country_code: String?
            let timezone: String?
            let isp: String?
        }

        let decoded = try JSONDecoder().decode(IPWhoIsResponse.self, from: data)

        guard decoded.success,
              let lat = decoded.latitude,
              let lon = decoded.longitude else {
            throw IPGeolocationError.invalidResponse(provider: provider, reason: "Missing coordinates")
        }

        guard Location(latitude: lat, longitude: lon).isValid else {
            throw IPGeolocationError.coordinatesInvalid(latitude: lat, longitude: lon)
        }

        let duration = Int(Date().timeIntervalSince(startTime) * 1000)

        return IPGeolocationResult(
            location: Location(latitude: lat, longitude: lon),
            provider: provider,
            confidence: decoded.city != nil ? .low : .veryLow,
            timestamp: Date(),
            isFromCache: false,
            accuracyRadiusKm: nil,
            metadata: GeolocationMetadata(
                city: decoded.city,
                region: decoded.region,
                country: decoded.country,
                countryCode: decoded.country_code,
                timezone: decoded.timezone,
                isp: decoded.isp,
                isVPN: nil,
            ),
            fetchDurationMs: duration,
        )
    }

    /// ipinfo.io - Free tier (50k/month), no API key needed for basic info, HTTPS
    private func fetchFromIPInfo(startTime: Date) async throws -> IPGeolocationResult {
        let provider = IPGeolocationProvider.ipinfo
        guard let url = URL(string: "https://ipinfo.io/json") else {
            throw IPGeolocationError.invalidResponse(provider: provider, reason: "Invalid URL")
        }

        let (data, _) = try await performRequest(url: url, provider: provider)

        struct IPInfoResponse: Decodable {
            let loc: String?
            let city: String?
            let region: String?
            let country: String?
            let timezone: String?
            let org: String?
        }

        let decoded = try JSONDecoder().decode(IPInfoResponse.self, from: data)

        guard let loc = decoded.loc else {
            throw IPGeolocationError.parsingError(provider: provider, field: "loc")
        }

        // Parse "lat,lon" format
        let components = loc.split(separator: ",")
        guard components.count == 2,
              let lat = Double(components[0]),
              let lon = Double(components[1]) else {
            throw IPGeolocationError.parsingError(provider: provider, field: "loc format")
        }

        guard Location(latitude: lat, longitude: lon).isValid else {
            throw IPGeolocationError.coordinatesInvalid(latitude: lat, longitude: lon)
        }

        let duration = Int(Date().timeIntervalSince(startTime) * 1000)

        return IPGeolocationResult(
            location: Location(latitude: lat, longitude: lon),
            provider: provider,
            confidence: decoded.city != nil ? .low : .veryLow,
            timestamp: Date(),
            isFromCache: false,
            accuracyRadiusKm: nil,
            metadata: GeolocationMetadata(
                city: decoded.city,
                region: decoded.region,
                country: decoded.country,
                countryCode: decoded.country,
                timezone: decoded.timezone,
                isp: decoded.org,
                isVPN: nil,
            ),
            fetchDurationMs: duration,
        )
    }

    /// ipdata.co - Free tier (1500/day), no API key needed for basic info, HTTPS
    private func fetchFromIPData(startTime: Date) async throws -> IPGeolocationResult {
        let provider = IPGeolocationProvider.ipdata
        guard let url =
            URL(
                string: "https://api.ipdata.co/?fields=latitude,longitude,city,region,country_name,country_code,time_zone,asn,threat",
            ) else {
            throw IPGeolocationError.invalidResponse(provider: provider, reason: "Invalid URL")
        }

        let (data, _) = try await performRequest(url: url, provider: provider)

        struct IPDataResponse: Decodable {
            let latitude: Double?
            let longitude: Double?
            let city: String?
            let region: String?
            let country_name: String?
            let country_code: String?
            let time_zone: TimeZone?
            let asn: ASN?
            let threat: Threat?

            struct TimeZone: Decodable {
                let name: String?
            }

            struct ASN: Decodable {
                let name: String?
            }

            struct Threat: Decodable {
                let is_vpn: Bool?
                let is_proxy: Bool?
            }
        }

        let decoded = try JSONDecoder().decode(IPDataResponse.self, from: data)

        guard let lat = decoded.latitude,
              let lon = decoded.longitude else {
            throw IPGeolocationError.parsingError(provider: provider, field: "coordinates")
        }

        guard Location(latitude: lat, longitude: lon).isValid else {
            throw IPGeolocationError.coordinatesInvalid(latitude: lat, longitude: lon)
        }

        let isVPN = decoded.threat?.is_vpn == true || decoded.threat?.is_proxy == true
        let duration = Int(Date().timeIntervalSince(startTime) * 1000)

        return IPGeolocationResult(
            location: Location(latitude: lat, longitude: lon),
            provider: provider,
            confidence: decoded.city != nil ? .low : .veryLow,
            timestamp: Date(),
            isFromCache: false,
            accuracyRadiusKm: nil,
            metadata: GeolocationMetadata(
                city: decoded.city,
                region: decoded.region,
                country: decoded.country_name,
                countryCode: decoded.country_code,
                timezone: decoded.time_zone?.name,
                isp: decoded.asn?.name,
                isVPN: isVPN,
            ),
            fetchDurationMs: duration,
        )
    }

    // MARK: - HTTP Request Helper

    private func performRequest(url: URL, provider: IPGeolocationProvider) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.timeoutInterval = configuration.timeoutSeconds

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw IPGeolocationError.invalidResponse(provider: provider, reason: "Not HTTP response")
            }

            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 429 {
                    throw IPGeolocationError.rateLimited(provider: provider, retryAfter: 60)
                }
                throw IPGeolocationError.httpError(provider: provider, statusCode: httpResponse.statusCode)
            }

            return (data, httpResponse)
        } catch let error as IPGeolocationError {
            throw error
        } catch let error as URLError {
            if error.code == .timedOut {
                throw IPGeolocationError.timeout(provider: provider, duration: configuration.timeoutSeconds)
            }
            throw IPGeolocationError.networkError(provider: provider, underlying: error.localizedDescription)
        } catch {
            throw IPGeolocationError.networkError(provider: provider, underlying: error.localizedDescription)
        }
    }
}

// MARK: - Testing Support

extension IPGeolocationService {
    /// Create a service for testing with custom configuration
    static func forTesting(configuration: IPGeolocationConfiguration) -> IPGeolocationService {
        IPGeolocationService(configuration: configuration)
    }
}
