//
//  LogLevel.swift
//  Foodshare
//
//  Structured logging level enumeration
//

import Foundation
import OSLog

/// Log severity levels for structured logging
enum LogLevel: String, Codable, Sendable, CaseIterable, Comparable {
    case debug = "DEBUG"
    case info = "INFO"
    case notice = "NOTICE"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"

    /// Numeric priority for comparison (higher = more severe)
    var priority: Int {
        switch self {
        case .debug: 0
        case .info: 1
        case .notice: 2
        case .warning: 3
        case .error: 4
        case .critical: 5
        }
    }

    /// Maps to OSLog type for system integration
    var osLogType: OSLogType {
        switch self {
        case .debug: .debug
        case .info: .info
        case .notice: .default
        case .warning: .error
        case .error: .error
        case .critical: .fault
        }
    }

    /// Color for console output (ANSI escape codes)
    var consoleColor: String {
        switch self {
        case .debug: "\u{001B}[36m" // Cyan
        case .info: "\u{001B}[32m" // Green
        case .notice: "\u{001B}[34m" // Blue
        case .warning: "\u{001B}[33m" // Yellow
        case .error: "\u{001B}[31m" // Red
        case .critical: "\u{001B}[35m" // Magenta
        }
    }

    /// Reset ANSI color
    static let colorReset = "\u{001B}[0m"

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.priority < rhs.priority
    }
}
