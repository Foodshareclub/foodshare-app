//
//  Logger.swift
//  Foodshare
//
//  Centralized logging utility with structured persistence
//


#if !SKIP
import Foundation
import OSLog

/// Application-wide logger with structured persistence
///
/// This logger delegates to `StructuredLogger` for persistent storage while
/// maintaining backward compatibility with existing call sites.
///
/// Usage:
/// ```swift
/// await AppLogger.shared.info("User logged in")
/// await AppLogger.shared.error("Failed to fetch data", error: someError)
/// ```
@globalActor
actor AppLogger {
    static let shared = AppLogger()

    /// Legacy OSLog logger for immediate console output
    private let osLogger = Logger(subsystem: Constants.bundleIdentifier, category: "app")

    /// Structured logger for persistence (lazily initialized)
    private var structuredLogger: StructuredLogger { StructuredLogger.shared }

    /// Whether the structured logger has been initialized
    private var isStructuredLoggingReady = false

    private init() {}

    // MARK: - Initialization

    /// Initialize structured logging with persistence
    /// Call this early in app lifecycle (e.g., in FoodShareApp.init)
    func initialize() async {
        await structuredLogger.initialize()
        isStructuredLoggingReady = true
        osLogger.info("AppLogger initialized with structured persistence")
    }

    // MARK: - Logging Methods

    /// Log a debug message (verbose, development only)
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard AppEnvironment.verboseLogging else { return }
        let fileName = (file as NSString).lastPathComponent
        osLogger.debug("[\(fileName):\(line)] \(function) - \(message)")

        // Also persist if structured logging is ready
        if isStructuredLoggingReady {
            Task {
                await structuredLogger.debug(message, file: file, function: function, line: line)
            }
        }
    }

    /// Log an informational message
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        osLogger.info("\(message)")

        if isStructuredLoggingReady {
            Task {
                await structuredLogger.info(message, file: file, function: function, line: line)
            }
        }
    }

    /// Log a notice (notable but not problematic)
    func notice(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        osLogger.notice("\(message)")

        if isStructuredLoggingReady {
            Task {
                await structuredLogger.notice(message, file: file, function: function, line: line)
            }
        }
    }

    /// Log a warning (potential issue)
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        osLogger.warning("[\(fileName):\(line)] \(function) - \(message)")

        if isStructuredLoggingReady {
            Task {
                await structuredLogger.warning(message, file: file, function: function, line: line)
            }
        }
    }

    /// Log an error (operation failed)
    func error(
        _ message: String,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
    ) {
        let fileName = (file as NSString).lastPathComponent
        if let error {
            osLogger.error("[\(fileName):\(line)] \(function) - \(message) | Error: \(error.localizedDescription)")
        } else {
            osLogger.error("[\(fileName):\(line)] \(function) - \(message)")
        }

        if isStructuredLoggingReady {
            Task {
                await structuredLogger.error(message, error: error, file: file, function: function, line: line)
            }
        }
    }

    /// Log a critical error (requires immediate attention)
    func critical(
        _ message: String,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
    ) {
        let fileName = (file as NSString).lastPathComponent
        if let error {
            osLogger.critical("[\(fileName):\(line)] \(function) - \(message) | Error: \(error.localizedDescription)")
        } else {
            osLogger.critical("[\(fileName):\(line)] \(function) - \(message)")
        }

        if isStructuredLoggingReady {
            Task {
                await structuredLogger.critical(message, error: error, file: file, function: function, line: line)
            }
        }
    }

    // MARK: - Extended Logging (Structured Only)

    /// Log a user action for analytics
    func userAction(_ action: String, details: [String: AnyCodable]? = nil) async {
        guard isStructuredLoggingReady else { return }
        await structuredLogger.userAction(action, details: details)
    }

    /// Log a network request
    func networkRequest(
        method: String,
        url: String,
        statusCode: Int? = nil,
        duration: TimeInterval? = nil,
        error: Error? = nil,
    ) async {
        guard isStructuredLoggingReady else { return }
        await structuredLogger.networkRequest(
            method: method,
            url: url,
            statusCode: statusCode,
            duration: duration,
            error: error,
        )
    }

    /// Log a performance metric
    func performance(operation: String, duration: TimeInterval, success: Bool = true) async {
        guard isStructuredLoggingReady else { return }
        await structuredLogger.performance(operation: operation, duration: duration, success: success)
    }

    // MARK: - Log Export & Maintenance

    /// Export logs as JSON data for debugging or crash reports
    func exportLogs(since: Date? = nil, limit: Int = 1000) async throws -> Data {
        try await structuredLogger.export(since: since, limit: limit)
    }

    /// Get storage statistics
    func logStatistics() async throws -> LogStorage.Statistics {
        try await structuredLogger.statistics()
    }

    /// Clear all stored logs
    func clearLogs() async throws {
        try await structuredLogger.clearLogs()
    }

    /// Shutdown the logger (call on app termination)
    func shutdown() async {
        await structuredLogger.shutdown()
        isStructuredLoggingReady = false
    }
}

// MARK: - Supabase Logger
// Custom logger implementation removed - using default Supabase logging

#endif
