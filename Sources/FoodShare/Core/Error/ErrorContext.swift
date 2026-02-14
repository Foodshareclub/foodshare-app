//
//  ErrorContext.swift
//  Foodshare
//
//  Rich error context capture for enterprise-grade error tracking.
//  Provides comprehensive metadata for debugging and telemetry.
//
//  Features:
//  - Automatic source location capture (file, function, line)
//  - Operation context and metadata
//  - Stack trace capture for critical errors
//  - User and session context
//  - Environment information
//

import Foundation
import OSLog

// MARK: - Error Context

/// Rich contextual information about where and why an error occurred
public struct ErrorContext: Sendable, CustomStringConvertible {
    /// Source file where error was captured
    public let file: String

    /// Function where error was captured
    public let function: String

    /// Line number where error was captured
    public let line: Int

    /// Column number where error was captured
    public let column: Int

    /// Name of the operation that failed
    public let operation: String

    /// Additional metadata about the error context
    public let metadata: [String: String]

    /// Timestamp when error was captured
    public let timestamp: Date

    /// User ID if available
    public let userId: UUID?

    /// Session ID for request correlation
    public let sessionId: String?

    /// Request/correlation ID for distributed tracing
    public let correlationId: String

    public var description: String {
        let fileShort = (file as NSString).lastPathComponent
        return "[\(fileShort):\(line)] \(function) - \(operation)"
    }

    public init(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        column: Int = #column,
        operation: String,
        metadata: [String: String] = [:],
        userId: UUID? = nil,
        sessionId: String? = nil,
    ) {
        self.file = file
        self.function = function
        self.line = line
        self.column = column
        self.operation = operation
        self.metadata = metadata
        self.timestamp = Date()
        self.userId = userId
        self.sessionId = sessionId
        self.correlationId = UUID().uuidString
    }

    /// Create context for the current location
    public static func here(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        column: Int = #column,
        operation: String,
        metadata: [String: String] = [:],
    ) -> ErrorContext {
        ErrorContext(
            file: file,
            function: function,
            line: line,
            column: column,
            operation: operation,
            metadata: metadata,
        )
    }

    /// Create context with user information
    public func withUser(_ userId: UUID?) -> ErrorContext {
        ErrorContext(
            file: file,
            function: function,
            line: line,
            column: column,
            operation: operation,
            metadata: metadata,
            userId: userId,
            sessionId: sessionId,
        )
    }

    /// Add metadata to context
    public func withMetadata(_ additionalMetadata: [String: String]) -> ErrorContext {
        var combined = metadata
        for (key, value) in additionalMetadata {
            combined[key] = value
        }
        return ErrorContext(
            file: file,
            function: function,
            line: line,
            column: column,
            operation: operation,
            metadata: combined,
            userId: userId,
            sessionId: sessionId,
        )
    }
}

// MARK: - Error Severity

/// Severity levels for error reporting
public enum ErrorSeverity: String, Codable, Sendable, Comparable {
    /// Debug-level errors (development only)
    case debug

    /// Informational - operation succeeded but with warnings
    case info

    /// Warning - potential issue, operation may have degraded
    case warning

    /// Error - operation failed, user may be affected
    case error

    /// Critical - system integrity may be compromised
    case critical

    /// Fatal - application cannot continue
    case fatal

    public static func < (lhs: ErrorSeverity, rhs: ErrorSeverity) -> Bool {
        let order: [ErrorSeverity] = [.debug, .info, .warning, .error, .critical, .fatal]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }

    /// OSLog level mapping
    public var osLogType: OSLogType {
        switch self {
        case .debug:
            .debug
        case .info:
            .info
        case .warning:
            .default
        case .error:
            .error
        case .critical, .fatal:
            .fault
        }
    }
}

// MARK: - Captured Error

/// An error with full context and metadata for reporting
public struct CapturedError: Sendable {
    /// The underlying error
    public let error: Error

    /// Error context with location and metadata
    public let context: ErrorContext

    /// Severity level
    public let severity: ErrorSeverity

    /// Stack trace if captured
    public let stackTrace: [String]?

    /// Whether recovery was attempted
    public var recoveryAttempted = false

    /// Recovery result if attempted
    public var recoverySucceeded: Bool?

    public init(
        error: Error,
        context: ErrorContext,
        severity: ErrorSeverity = .error,
        captureStackTrace: Bool = false,
    ) {
        self.error = error
        self.context = context
        self.severity = severity
        self.stackTrace = captureStackTrace ? Thread.callStackSymbols : nil
    }

    /// Error type name for categorization
    public var errorType: String {
        String(describing: type(of: error))
    }

    /// Localized error message
    public var message: String {
        error.localizedDescription
    }

    /// Create a dictionary representation for logging/telemetry
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "error_type": errorType,
            "message": message,
            "severity": severity.rawValue,
            "operation": context.operation,
            "file": (context.file as NSString).lastPathComponent,
            "function": context.function,
            "line": context.line,
            "timestamp": ISO8601DateFormatter().string(from: context.timestamp),
            "correlation_id": context.correlationId
        ]

        if let userId = context.userId {
            dict["user_id"] = userId.uuidString
        }

        if let sessionId = context.sessionId {
            dict["session_id"] = sessionId
        }

        if !context.metadata.isEmpty {
            dict["metadata"] = context.metadata
        }

        if let stackTrace, !stackTrace.isEmpty {
            dict["stack_trace"] = stackTrace.prefix(10).joined(separator: "\n")
        }

        if recoveryAttempted {
            dict["recovery_attempted"] = true
            dict["recovery_succeeded"] = recoverySucceeded ?? false
        }

        return dict
    }
}

// MARK: - Error Tags

/// Common tags for error categorization
public enum ErrorTag: String, Sendable {
    // Layer tags
    case presentation
    case domain
    case data
    case network
    case persistence

    // Feature tags
    case authentication
    case authorization
    case feed
    case listing
    case messaging
    case profile
    case search

    // Type tags
    case validation
    case business
    case infrastructure
    case external

    // Urgency tags
    case userBlocking
    case degraded
    case silent
}

// MARK: - Error Context Builder

/// Fluent builder for error context
public final class ErrorContextBuilder: @unchecked Sendable {
    private var operation: String
    private var metadata: [String: String] = [:]
    private var userId: UUID?
    private var sessionId: String?
    private var tags: Set<ErrorTag> = []

    private let file: String
    private let function: String
    private let line: Int
    private let column: Int

    public init(
        operation: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        column: Int = #column,
    ) {
        self.operation = operation
        self.file = file
        self.function = function
        self.line = line
        self.column = column
    }

    public func withMetadata(_ key: String, _ value: String) -> ErrorContextBuilder {
        metadata[key] = value
        return self
    }

    public func withUser(_ userId: UUID?) -> ErrorContextBuilder {
        self.userId = userId
        return self
    }

    public func withSession(_ sessionId: String?) -> ErrorContextBuilder {
        self.sessionId = sessionId
        return self
    }

    public func withTag(_ tag: ErrorTag) -> ErrorContextBuilder {
        tags.insert(tag)
        return self
    }

    public func withTags(_ tags: ErrorTag...) -> ErrorContextBuilder {
        for tag in tags {
            self.tags.insert(tag)
        }
        return self
    }

    public func build() -> ErrorContext {
        var enrichedMetadata = metadata
        if !tags.isEmpty {
            enrichedMetadata["tags"] = tags.map(\.rawValue).joined(separator: ",")
        }

        return ErrorContext(
            file: file,
            function: function,
            line: line,
            column: column,
            operation: operation,
            metadata: enrichedMetadata,
            userId: userId,
            sessionId: sessionId,
        )
    }
}

// MARK: - Convenience Extensions

extension Error {
    /// Capture this error with context
    public func captured(
        operation: String,
        severity: ErrorSeverity = .error,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        metadata: [String: String] = [:],
    ) -> CapturedError {
        let context = ErrorContext(
            file: file,
            function: function,
            line: line,
            operation: operation,
            metadata: metadata,
        )
        return CapturedError(error: self, context: context, severity: severity)
    }
}
