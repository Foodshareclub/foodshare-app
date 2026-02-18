//
//  CrashReporter.swift
//  Foodshare
//
//  Enterprise crash reporting with Sentry integration
//



#if !SKIP
import Foundation
import OSLog

#if canImport(Sentry)
    import Sentry
#endif

// MARK: - Crash Reporter

@MainActor
final class CrashReporter {
    static let shared = CrashReporter()

    private let logger = Logger(subsystem: Constants.bundleIdentifier, category: "CrashReporter")
    private var isConfigured = false

    struct Configuration {
        let dsn: String
        let environment: String
        let enablePerformanceMonitoring: Bool
        let sampleRate: Double
        let tracesSampleRate: Double
        let attachStacktrace: Bool
        let sendDefaultPii: Bool
        let debug: Bool

        static let production = Configuration(
            dsn: "",
            environment: "production",
            enablePerformanceMonitoring: true,
            sampleRate: 1.0,
            tracesSampleRate: 0.2,
            attachStacktrace: true,
            sendDefaultPii: false,
            debug: false,
        )

        static let development = Configuration(
            dsn: "",
            environment: "development",
            enablePerformanceMonitoring: true,
            sampleRate: 1.0,
            tracesSampleRate: 1.0,
            attachStacktrace: true,
            sendDefaultPii: false,
            debug: true,
        )

        static var current: Configuration {
            #if DEBUG
                return .development
            #else
                return .production
            #endif
        }
    }

    private init() {}

    func configure(dsn: String? = nil) async {
        guard !isConfigured else {
            logger.debug("CrashReporter already configured")
            return
        }

        let config = Configuration.current
        let resolvedDSN = dsn ?? ProcessInfo.processInfo.environment["SENTRY_DSN"] ?? ""

        if resolvedDSN.isEmpty {
            logger.warning("Sentry DSN not configured - crash reporting disabled")
            return
        }

        #if canImport(Sentry)
            SentrySDK.start { options in
                options.dsn = resolvedDSN
                options.environment = config.environment
                options.enablePerformanceV2 = config.enablePerformanceMonitoring
                options.tracesSampleRate = NSNumber(value: config.tracesSampleRate)
                options.sampleRate = NSNumber(value: config.sampleRate)
                options.attachStacktrace = config.attachStacktrace
                options.sendDefaultPii = config.sendDefaultPii
                options.debug = config.debug
                options.releaseName = Bundle.main.releaseVersionNumber
                options.dist = Bundle.main.buildVersionNumber
                options.enableCaptureFailedRequests = true
                options.enableSwizzling = true
                options.enableAutoSessionTracking = true
                options.sessionTrackingIntervalMillis = 30000
                options.enableUIViewControllerTracing = true
                options.enableNetworkTracking = true
                options.enableFileIOTracing = true
                options.enableCoreDataTracing = true
                options.enableAutoBreadcrumbTracking = true
                options.maxBreadcrumbs = 100
            }
        #endif

        isConfigured = true
        logger.info("CrashReporter configured for \(config.environment)")
    }

    func setUser(id: UUID, email: String? = nil, username: String? = nil) async {
        guard isConfigured else { return }
        #if canImport(Sentry)
            let user = User()
            user.userId = id.uuidString
            user.email = email
            user.username = username
            SentrySDK.setUser(user)
        #endif
        logger.debug("User set: \(id.uuidString)")
    }

    func clearUser() async {
        guard isConfigured else { return }
        #if canImport(Sentry)
            SentrySDK.setUser(nil)
        #endif
        logger.debug("User cleared")
    }

    enum BreadcrumbLevel: String {
        case debug, info, warning, error, fatal
    }

    func addBreadcrumb(
        category: String,
        message: String,
        level: BreadcrumbLevel = .info,
        data: [String: Any]? = nil,
    ) async {
        guard isConfigured else { return }
        #if canImport(Sentry)
            let breadcrumb = Breadcrumb(level: sentryLevel(level), category: category)
            breadcrumb.message = message
            breadcrumb.data = data
            SentrySDK.addBreadcrumb(breadcrumb)
        #endif
        logger.debug("Breadcrumb: [\(category)] \(message)")
    }

    func trackNavigation(from: String?, to: String) async {
        await addBreadcrumb(
            category: "navigation",
            message: "Navigate to \(to)",
            level: .info,
            data: from.map { ["from": $0, "to": to] } ?? ["to": to],
        )
    }

    func trackUserAction(_ action: String, target: String? = nil) async {
        var data: [String: Any] = ["action": action]
        if let target { data["target"] = target }
        await addBreadcrumb(category: "user", message: action, level: .info, data: data)
    }

    func captureError(_ error: Error, context: [String: Any]? = nil, tags: [String: String]? = nil) async {
        guard isConfigured else {
            logger.error("CrashReporter not configured - error not captured: \(error.localizedDescription)")
            return
        }
        #if canImport(Sentry)
            SentrySDK.capture(error: error) { scope in
                if let context { scope.setContext(value: context, key: "custom") }
                if let tags { for (key, value) in tags {
                    scope.setTag(value: value, key: key)
                } }
            }
        #endif
        logger.error("Captured error: \(error.localizedDescription)")
    }

    func captureMessage(_ message: String, level: BreadcrumbLevel = .info, context: [String: Any]? = nil) async {
        guard isConfigured else { return }
        #if canImport(Sentry)
            SentrySDK.capture(message: message) { scope in
                scope.setLevel(sentryLevel(level))
                if let context { scope.setContext(value: context, key: "custom") }
            }
        #endif
        logger.info("Captured message: \(message)")
    }

    func startTransaction(name: String, operation: String) -> Any? {
        guard isConfigured else { return nil }
        #if canImport(Sentry)
            let transaction = SentrySDK.startTransaction(name: name, operation: operation)
            logger.debug("Transaction started: \(name) (\(operation))")
            return transaction
        #else
            return nil
        #endif
    }

    func finishTransaction(_ transaction: Any?) {
        guard isConfigured else { return }
        #if canImport(Sentry)
            (transaction as? Span)?.finish(status: .ok)
        #endif
        logger.debug("Transaction finished")
    }

    func setContext(_ key: String, value: [String: Any]) async {
        guard isConfigured else { return }
        #if canImport(Sentry)
            SentrySDK.configureScope { scope in scope.setContext(value: value, key: key) }
        #endif
        logger.debug("Context set: \(key)")
    }

    func setTag(_ key: String, value: String) async {
        guard isConfigured else { return }
        #if canImport(Sentry)
            SentrySDK.configureScope { scope in scope.setTag(value: value, key: key) }
        #endif
        logger.debug("Tag set: \(key)=\(value)")
    }

    #if canImport(Sentry)
        private func sentryLevel(_ level: BreadcrumbLevel) -> SentryLevel {
            switch level {
            case .debug: .debug
            case .info: .info
            case .warning: .warning
            case .error: .error
            case .fatal: .fatal
            }
        }
    #endif
}

extension Bundle {
    var releaseVersionNumber: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    var buildVersionNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}


#endif
