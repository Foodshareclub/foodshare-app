//
//  StructuredLogger.swift
//  Foodshare
//
//  Enterprise-grade structured logging with persistence
//

import Foundation
import OSLog

/// Centralized structured logger with persistence and export capabilities
@globalActor
actor StructuredLogger {
    static let shared = StructuredLogger()

    private let osLogger: Logger
    private let storage: LogStorage
    private var isInitialized = false
    private var pendingEntries: [LogEntry] = []
    private let minimumLevel: LogLevel
    private let category: String

    /// Configuration for the structured logger
    struct Configuration: Sendable {
        let minimumLevel: LogLevel
        let enablePersistence: Bool
        let enableConsoleOutput: Bool
        let maxStoredEntries: Int
        let category: String

        static let `default` = Configuration(
            minimumLevel: AppEnvironment.verboseLogging ? .debug : .info,
            enablePersistence: true,
            enableConsoleOutput: true,
            maxStoredEntries: 10000,
            category: "app",
        )

        static let debug = Configuration(
            minimumLevel: .debug,
            enablePersistence: true,
            enableConsoleOutput: true,
            maxStoredEntries: 10000,
            category: "app",
        )
    }

    private let configuration: Configuration

    init(configuration: Configuration = .default) {
        self.configuration = configuration
        self.minimumLevel = configuration.minimumLevel
        self.category = configuration.category
        self.osLogger = Logger(subsystem: Constants.bundleIdentifier, category: configuration.category)
        self.storage = LogStorage(maxEntries: configuration.maxStoredEntries)
    }

    /// Initialize the logger and persistent storage
    func initialize() async {
        guard !isInitialized else { return }

        do {
            try await storage.initialize()
            isInitialized = true

            // Flush any pending entries
            for entry in pendingEntries {
                try? await storage.append(entry)
            }
            pendingEntries.removeAll()

            await info("Structured logger initialized", context: [
                "minimumLevel": AnyCodable(minimumLevel.rawValue),
                "persistenceEnabled": AnyCodable(configuration.enablePersistence)
            ])
        } catch {
            osLogger.error("Failed to initialize log storage: \(error.localizedDescription)")
        }
    }

    // MARK: - Logging Methods

    /// Log a debug message (verbose, development only)
    func debug(
        _ message: String,
        context: [String: AnyCodable]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
    ) async {
        await log(.debug, message, context: context, file: file, function: function, line: line)
    }

    /// Log an informational message
    func info(
        _ message: String,
        context: [String: AnyCodable]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
    ) async {
        await log(.info, message, context: context, file: file, function: function, line: line)
    }

    /// Log a notice (notable but not problematic)
    func notice(
        _ message: String,
        context: [String: AnyCodable]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
    ) async {
        await log(.notice, message, context: context, file: file, function: function, line: line)
    }

    /// Log a warning (potential issue)
    func warning(
        _ message: String,
        context: [String: AnyCodable]? = nil,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
    ) async {
        await log(.warning, message, context: context, error: error, file: file, function: function, line: line)
    }

    /// Log an error (operation failed)
    func error(
        _ message: String,
        context: [String: AnyCodable]? = nil,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
    ) async {
        await log(.error, message, context: context, error: error, file: file, function: function, line: line)
    }

    /// Log a critical error (requires immediate attention)
    func critical(
        _ message: String,
        context: [String: AnyCodable]? = nil,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
    ) async {
        await log(
            .critical,
            message,
            context: context,
            error: error,
            file: file,
            function: function,
            line: line,
            includeDeviceInfo: true,
        )
    }

    // MARK: - Core Logging

    private func log(
        _ level: LogLevel,
        _ message: String,
        context: [String: AnyCodable]? = nil,
        error: Error? = nil,
        file: String,
        function: String,
        line: Int,
        includeDeviceInfo: Bool = false,
    ) async {
        // Check minimum level
        guard level >= minimumLevel else { return }

        let fileName = (file as NSString).lastPathComponent

        // Create structured entry
        let entry = LogEntry(
            level: level,
            message: message,
            category: category,
            file: fileName,
            function: function,
            line: line,
            context: context,
            error: error,
            includeDeviceInfo: includeDeviceInfo || level >= .error,
        )

        // Output to console
        if configuration.enableConsoleOutput {
            outputToConsole(entry)
        }

        // Persist if enabled
        if configuration.enablePersistence {
            await persist(entry)
        }
    }

    private func outputToConsole(_ entry: LogEntry) {
        // Use OSLog for system integration
        switch entry.level {
        case .debug:
            osLogger.debug("[\(entry.file):\(entry.line)] \(entry.function) - \(entry.message)")
        case .info:
            osLogger.info("\(entry.message)")
        case .notice:
            osLogger.notice("\(entry.message)")
        case .warning:
            osLogger.warning("[\(entry.file):\(entry.line)] \(entry.function) - \(entry.message)")
        case .error:
            if let errorDesc = entry.errorDescription {
                osLogger
                    .error("[\(entry.file):\(entry.line)] \(entry.function) - \(entry.message) | Error: \(errorDesc)")
            } else {
                osLogger.error("[\(entry.file):\(entry.line)] \(entry.function) - \(entry.message)")
            }
        case .critical:
            if let errorDesc = entry.errorDescription {
                osLogger
                    .critical(
                        "[\(entry.file):\(entry.line)] \(entry.function) - \(entry.message) | Error: \(errorDesc)",
                    )
            } else {
                osLogger.critical("[\(entry.file):\(entry.line)] \(entry.function) - \(entry.message)")
            }
        }
    }

    private func persist(_ entry: LogEntry) async {
        if isInitialized {
            do {
                try await storage.append(entry)
            } catch {
                osLogger.error("Failed to persist log entry: \(error.localizedDescription)")
            }
        } else {
            // Queue for later if not initialized
            pendingEntries.append(entry)

            // Prevent unbounded growth
            if pendingEntries.count > 100 {
                pendingEntries.removeFirst(50)
            }
        }
    }

    // MARK: - Export & Maintenance

    /// Export logs as JSON data
    func export(
        since: Date? = nil,
        until: Date? = nil,
        levels: Set<LogLevel>? = nil,
        limit: Int = 1000,
    ) async throws -> Data {
        try await storage.export(since: since, until: until, levels: levels, limit: limit)
    }

    /// Get storage statistics
    func statistics() async throws -> LogStorage.Statistics {
        try await storage.statistics()
    }

    /// Clear all stored logs
    func clearLogs() async throws {
        try await storage.clear()
    }

    /// Flush and close the logger
    func shutdown() async {
        await storage.close()
        isInitialized = false
    }
}

// MARK: - Convenience Extensions

extension StructuredLogger {
    /// Log user action for analytics
    func userAction(
        _ action: String,
        details: [String: AnyCodable]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
    ) async {
        var context = details ?? [:]
        context["action_type"] = AnyCodable("user_action")
        await info("User: \(action)", context: context, file: file, function: function, line: line)
    }

    /// Log network request
    func networkRequest(
        method: String,
        url: String,
        statusCode: Int? = nil,
        duration: TimeInterval? = nil,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
    ) async {
        var context: [String: AnyCodable] = [
            "method": AnyCodable(method),
            "url": AnyCodable(url)
        ]
        if let statusCode {
            context["status_code"] = AnyCodable(statusCode)
        }
        if let duration {
            context["duration_ms"] = AnyCodable(Int(duration * 1000))
        }

        let level: LogLevel = if let statusCode, statusCode >= 400 {
            .warning
        } else if error != nil {
            .error
        } else {
            .debug
        }

        await log(
            level,
            "Network: \(method) \(url)",
            context: context,
            error: error,
            file: file,
            function: function,
            line: line,
        )
    }

    /// Log performance metric
    func performance(
        operation: String,
        duration: TimeInterval,
        success: Bool = true,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
    ) async {
        let context: [String: AnyCodable] = [
            "operation": AnyCodable(operation),
            "duration_ms": AnyCodable(Int(duration * 1000)),
            "success": AnyCodable(success)
        ]
        let level: LogLevel = duration > 3.0 ? .warning : .debug
        await log(
            level,
            "Perf: \(operation) took \(Int(duration * 1000))ms",
            context: context,
            file: file,
            function: function,
            line: line,
        )
    }
}
