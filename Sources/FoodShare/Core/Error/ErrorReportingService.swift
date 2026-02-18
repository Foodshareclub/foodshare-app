//
//  ErrorReportingService.swift
//  Foodshare
//
//  Enterprise-grade centralized error reporting service.
//  Captures, logs, and reports all errors with full context.
//
//  Features:
//  - Centralized error capture with context
//  - Local logging to OSLog
//  - Optional remote telemetry
//  - Error aggregation and deduplication
//  - Minimum severity filtering
//  - Error rate tracking
//


#if !SKIP
import Foundation
import OSLog

// MARK: - Error Reporter Protocol

/// Protocol for error reporting implementations
public protocol ErrorReporter: Sendable {
    func report(_ capturedError: CapturedError) async
    func flush() async
}

// MARK: - Error Reporting Service

/// Centralized error reporting service
///
/// Usage:
/// ```swift
/// // Capture and report an error
/// await ErrorReportingService.shared.capture(error) {
///     ErrorContext.here(operation: "fetchProfile")
/// }
///
/// // Use the capture wrapper
/// let result = await ErrorReportingService.shared.capture(operation: "fetchProfile") {
///     try await repository.fetchProfile(userId: id)
/// }
/// ```
public actor ErrorReportingService {
    /// Shared instance
    public static let shared = ErrorReportingService()

    // MARK: - Configuration

    private let logger: Logger
    private var reporters: [ErrorReporter] = []
    private var minimumSeverity: ErrorSeverity = .warning

    // Error tracking
    private var errorCounts: [String: Int] = [:]
    private var recentErrors: [CapturedError] = []
    private let maxRecentErrors = 100

    // Rate limiting for error reporting
    private var lastReportTime: [String: Date] = [:]
    private let minReportInterval: TimeInterval = 1.0 // Dedupe window

    init(logger: Logger = Logger(subsystem: "com.flutterflow.foodshare", category: "errors")) {
        self.logger = logger
    }

    // MARK: - Configuration

    /// Set minimum severity for reporting
    public func setMinimumSeverity(_ severity: ErrorSeverity) {
        minimumSeverity = severity
    }

    /// Add an error reporter
    public func addReporter(_ reporter: ErrorReporter) {
        reporters.append(reporter)
    }

    // MARK: - Error Capture

    /// Capture and report an error with context
    public func capture(
        _ error: Error,
        context: ErrorContext,
        severity: ErrorSeverity = .error,
    ) async {
        let capturedError = CapturedError(
            error: error,
            context: context,
            severity: severity,
            captureStackTrace: severity >= .critical,
        )

        await process(capturedError)
    }

    /// Capture an error with a context builder
    public func capture(
        _ error: Error,
        severity: ErrorSeverity = .error,
        @ErrorContextBuilderBlock context: () -> ErrorContext,
    ) async {
        let capturedError = CapturedError(
            error: error,
            context: context(),
            severity: severity,
            captureStackTrace: severity >= .critical,
        )

        await process(capturedError)
    }

    /// Execute an operation and capture any errors
    public func capture<T: Sendable>(
        operation: String,
        severity: ErrorSeverity = .error,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        _ body: () async throws -> T,
    ) async -> Result<T, Error> {
        do {
            let result = try await body()
            return .success(result)
        } catch {
            let context = ErrorContext(
                file: file,
                function: function,
                line: line,
                operation: operation,
            )
            await capture(error, context: context, severity: severity)
            return .failure(error)
        }
    }

    /// Execute an operation and capture errors, returning the value or nil
    public func captureOrNil<T: Sendable>(
        operation: String,
        severity: ErrorSeverity = .error,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        _ body: () async throws -> T,
    ) async -> T? {
        let result = await capture(
            operation: operation,
            severity: severity,
            file: file,
            function: function,
            line: line,
            body,
        )

        switch result {
        case let .success(value):
            return value
        case .failure:
            return nil
        }
    }

    /// Execute an operation with automatic error capture and recovery
    public func captureWithRecovery<T: Sendable>(
        operation: String,
        severity: ErrorSeverity = .error,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        _ body: () async throws -> T,
        recover: (Error) async -> T?,
    ) async -> T? {
        do {
            return try await body()
        } catch {
            let context = ErrorContext(
                file: file,
                function: function,
                line: line,
                operation: operation,
            )

            var capturedError = CapturedError(
                error: error,
                context: context,
                severity: severity,
            )

            // Attempt recovery
            capturedError.recoveryAttempted = true
            if let recovered = await recover(error) {
                capturedError.recoverySucceeded = true
                await process(capturedError)
                return recovered
            } else {
                capturedError.recoverySucceeded = false
                await process(capturedError)
                return nil
            }
        }
    }

    // MARK: - Error Processing

    private func process(_ capturedError: CapturedError) async {
        // Skip if below minimum severity
        guard capturedError.severity >= minimumSeverity else { return }

        // Log locally
        logToOSLog(capturedError)

        // Track error counts
        trackError(capturedError)

        // Check rate limiting
        let errorKey = "\(capturedError.errorType):\(capturedError.context.operation)"
        if let lastReport = lastReportTime[errorKey],
           Date().timeIntervalSince(lastReport) < minReportInterval {
            // Skip duplicate report within window
            return
        }
        lastReportTime[errorKey] = Date()

        // Store in recent errors
        storeRecentError(capturedError)

        // Report to all reporters
        for reporter in reporters {
            await reporter.report(capturedError)
        }
    }

    private func logToOSLog(_ error: CapturedError) {
        let message = """
        [\(error.context.operation)] \(error.errorType): \(error.message)
        at \(error.context)
        """

        switch error.severity {
        case .debug:
            logger.debug("\(message)")
        case .info:
            logger.info("\(message)")
        case .warning:
            logger.warning("⚠️ \(message)")
        case .error:
            logger.error("❌ \(message)")
        case .critical:
            logger.critical("🚨 CRITICAL: \(message)")
        case .fatal:
            logger.fault("💀 FATAL: \(message)")
        }
    }

    private func trackError(_ error: CapturedError) {
        let key = error.errorType
        errorCounts[key, default: 0] += 1
    }

    private func storeRecentError(_ error: CapturedError) {
        recentErrors.append(error)
        if recentErrors.count > maxRecentErrors {
            recentErrors.removeFirst()
        }
    }

    // MARK: - Error Statistics

    /// Get error counts by type
    public func getErrorCounts() -> [String: Int] {
        errorCounts
    }

    /// Get recent errors
    public func getRecentErrors(limit: Int = 10) -> [CapturedError] {
        Array(recentErrors.suffix(limit))
    }

    /// Get errors by severity
    public func getRecentErrors(severity: ErrorSeverity) -> [CapturedError] {
        recentErrors.filter { $0.severity == severity }
    }

    /// Reset error tracking
    public func reset() {
        errorCounts.removeAll()
        recentErrors.removeAll()
        lastReportTime.removeAll()
    }

    /// Flush all reporters
    public func flush() async {
        for reporter in reporters {
            await reporter.flush()
        }
    }
}

// MARK: - Result Builder

/// Builder block for error context
@resultBuilder
public struct ErrorContextBuilderBlock {
    public static func buildBlock(_ context: ErrorContext) -> ErrorContext {
        context
    }
}

// MARK: - Console Reporter

/// Simple console reporter for development
public final class ConsoleErrorReporter: ErrorReporter, @unchecked Sendable {
    private let includeStackTrace: Bool

    public init(includeStackTrace: Bool = false) {
        self.includeStackTrace = includeStackTrace
    }

    public func report(_ capturedError: CapturedError) async {
        var output = """
        ═══════════════════════════════════════
        ERROR: \(capturedError.errorType)
        ───────────────────────────────────────
        Message: \(capturedError.message)
        Severity: \(capturedError.severity.rawValue.uppercased())
        Operation: \(capturedError.context.operation)
        Location: \(capturedError.context)
        Time: \(capturedError.context.timestamp)
        Correlation ID: \(capturedError.context.correlationId)
        """

        if let userId = capturedError.context.userId {
            output += "\nUser ID: \(userId)"
        }

        if !capturedError.context.metadata.isEmpty {
            output += "\nMetadata: \(capturedError.context.metadata)"
        }

        if includeStackTrace, let stackTrace = capturedError.stackTrace {
            output += "\nStack Trace:\n\(stackTrace.prefix(5).joined(separator: "\n"))"
        }

        output += "\n═══════════════════════════════════════"

        print(output)
    }

    public func flush() async {
        // No-op for console
    }
}

// MARK: - Remote Reporter

/// Reporter that sends errors to a remote service
public actor RemoteErrorReporter: ErrorReporter {
    private let endpoint: URL
    private let batchSize: Int
    private let flushInterval: TimeInterval
    private var pendingErrors: [CapturedError] = []
    private var flushTask: Task<Void, Never>?

    public init(
        endpoint: URL,
        batchSize: Int = 10,
        flushInterval: TimeInterval = 30,
    ) {
        self.endpoint = endpoint
        self.batchSize = batchSize
        self.flushInterval = flushInterval
    }

    public func report(_ capturedError: CapturedError) async {
        pendingErrors.append(capturedError)

        if pendingErrors.count >= batchSize {
            await flush()
        } else {
            scheduleFlush()
        }
    }

    public func flush() async {
        flushTask?.cancel()
        guard !pendingErrors.isEmpty else { return }

        let errorsToSend = pendingErrors
        pendingErrors.removeAll()

        do {
            try await sendErrors(errorsToSend)
        } catch {
            // Re-queue failed errors
            pendingErrors.insert(contentsOf: errorsToSend, at: 0)
        }
    }

    private func scheduleFlush() {
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.flushInterval ?? 30) * 1_000_000_000))
            await self?.flush()
        }
    }

    private func sendErrors(_ errors: [CapturedError]) async throws {
        let payload = errors.map { $0.toDictionary() }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

// MARK: - Global Convenience Functions

/// Capture an error with context at the current location
public func captureError(
    _ error: Error,
    operation: String,
    severity: ErrorSeverity = .error,
    metadata: [String: String] = [:],
    file: String = #file,
    function: String = #function,
    line: Int = #line,
) async {
    let context = ErrorContext(
        file: file,
        function: function,
        line: line,
        operation: operation,
        metadata: metadata,
    )
    await ErrorReportingService.shared.capture(error, context: context, severity: severity)
}

/// Execute with error capture
public func withErrorCapture<T: Sendable>(
    operation: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line,
    _ body: () async throws -> T,
) async throws -> T {
    do {
        return try await body()
    } catch {
        await captureError(
            error,
            operation: operation,
            file: file,
            function: function,
            line: line,
        )
        throw error
    }
}

/// Execute with error capture, returning nil on failure
public func withErrorCaptureOrNil<T: Sendable>(
    operation: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line,
    _ body: @Sendable () async throws -> T,
) async -> T? {
    await ErrorReportingService.shared.captureOrNil(
        operation: operation,
        file: file,
        function: function,
        line: line,
        body,
    )
}

#endif
