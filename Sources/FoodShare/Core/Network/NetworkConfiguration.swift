//
//  NetworkConfiguration.swift
//  Foodshare
//
//  Centralized network configuration for consistent behavior across all services
//  Enterprise-grade defaults optimized for reliability and performance
//

import Foundation

/// Centralized network configuration factory
/// Provides consistent URLSession configurations across all network services
enum NetworkConfiguration {
    // MARK: - Timeouts

    /// Request timeout in seconds (time to establish connection)
    static let requestTimeout: TimeInterval = 30

    /// Resource timeout in seconds (total time for request + response)
    static let resourceTimeout: TimeInterval = 60

    /// Long-running operation timeout (file uploads, large downloads)
    static let longOperationTimeout: TimeInterval = 300

    // MARK: - Session Configurations

    /// Default session configuration for API requests
    /// Optimized for reliability with Cloudflare-fronted endpoints
    static var defaultConfiguration: URLSessionConfiguration {
        let config = URLSessionConfiguration.default

        // Timeouts
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = resourceTimeout

        // Connectivity handling
        config.waitsForConnectivity = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true

        // Cache policy
        config.requestCachePolicy = .reloadRevalidatingCacheData

        // Connection limits
        config.httpMaximumConnectionsPerHost = 6

        // HTTP/2 multiplexing (helps with multiple concurrent requests)
        config.multipathServiceType = .handover

        return config
    }

    /// Background session configuration for uploads/downloads
    static func backgroundConfiguration(identifier: String) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.background(withIdentifier: identifier)

        config.timeoutIntervalForRequest = longOperationTimeout
        config.timeoutIntervalForResource = longOperationTimeout

        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.shouldUseExtendedBackgroundIdleMode = true

        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true

        return config
    }

    /// Ephemeral session configuration (no caching, no cookies stored)
    static var ephemeralConfiguration: URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral

        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = resourceTimeout

        config.waitsForConnectivity = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true

        return config
    }

    // MARK: - Pre-configured Sessions

    /// Default URLSession for API requests
    static var defaultSession: URLSession {
        URLSession(configuration: defaultConfiguration)
    }

    /// Ephemeral URLSession (no persistent storage)
    static var ephemeralSession: URLSession {
        URLSession(configuration: ephemeralConfiguration)
    }

    /// Creates a background session with the given identifier and delegate
    static func backgroundSession(
        identifier: String,
        delegate: URLSessionDelegate? = nil,
        delegateQueue: OperationQueue? = nil,
    ) -> URLSession {
        URLSession(
            configuration: backgroundConfiguration(identifier: identifier),
            delegate: delegate,
            delegateQueue: delegateQueue,
        )
    }

    // MARK: - Headers

    /// Default headers for API requests
    static var defaultHeaders: [String: String] {
        [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "X-Client-Version": Bundle.main.appVersion,
            "X-Platform": "iOS"
        ]
    }
}

// MARK: - Bundle Extension

extension Bundle {
    fileprivate var appVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }
}
