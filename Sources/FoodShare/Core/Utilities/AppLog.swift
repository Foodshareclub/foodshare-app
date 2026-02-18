//
//  AppLog.swift
//  FoodShare
//
//  Cross-platform logging utility.
//  Uses OSLog on iOS, print() on Android (Skip).
//

import Foundation
#if !SKIP
import OSLog
#endif

/// Cross-platform logger for use in shared code.
/// On iOS, wraps OSLog.Logger. On Android, uses print().
public struct AppLog: Sendable {
    let category: String

    #if !SKIP
    private let logger: Logger

    init(category: String) {
        self.category = category
        self.logger = Logger(subsystem: "com.flutterflow.foodshare", category: category)
    }

    func debug(_ message: String) { logger.debug("\(message)") }
    func info(_ message: String) { logger.info("\(message)") }
    func warning(_ message: String) { logger.warning("\(message)") }
    func error(_ message: String) { logger.error("\(message)") }
    #else
    init(category: String) {
        self.category = category
    }

    func debug(_ message: String) { print("[\(category)] DEBUG: \(message)") }
    func info(_ message: String) { print("[\(category)] INFO: \(message)") }
    func warning(_ message: String) { print("[\(category)] WARN: \(message)") }
    func error(_ message: String) { print("[\(category)] ERROR: \(message)") }
    #endif
}
