//
//  LogStorage.swift
//  Foodshare
//
//  SQLite-based persistent log storage with automatic rotation
//

import Foundation
import OSLog
import SQLite3

/// Persistent log storage using SQLite for crash resilience
actor LogStorage {
    private var db: OpaquePointer?
    private let dbPath: String
    private let maxEntries: Int
    private let systemLogger = Logger(subsystem: Constants.bundleIdentifier, category: "LogStorage")

    /// Statistics about log storage
    struct Statistics: Sendable {
        let totalEntries: Int
        let oldestEntry: Date?
        let newestEntry: Date?
        let sizeInBytes: Int64
        let entriesByLevel: [LogLevel: Int]
    }

    init(maxEntries: Int = 10000) {
        self.maxEntries = maxEntries

        // Store in Application Support for persistence
        let fileManager = FileManager.default
        let appSupport: URL
        if let dir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            appSupport = dir
        } else {
            // Fallback to temp directory — logging will still work but won't survive app reinstall
            assertionFailure("Unable to access application support directory")
            appSupport = fileManager.temporaryDirectory
        }
        let logsDir = appSupport.appendingPathComponent("Logs", isDirectory: true)

        // Create logs directory if needed
        try? fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true)

        self.dbPath = logsDir.appendingPathComponent("structured_logs.sqlite").path
    }

    /// Open database connection and create schema
    func initialize() async throws {
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))
            throw LogStorageError.databaseOpenFailed(error)
        }

        // Create logs table with indexes
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS logs (
            id TEXT PRIMARY KEY,
            timestamp REAL NOT NULL,
            level TEXT NOT NULL,
            message TEXT NOT NULL,
            category TEXT NOT NULL,
            file TEXT NOT NULL,
            function TEXT NOT NULL,
            line INTEGER NOT NULL,
            context TEXT,
            error_description TEXT,
            error_type TEXT,
            device_info TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_logs_timestamp ON logs(timestamp);
        CREATE INDEX IF NOT EXISTS idx_logs_level ON logs(level);
        CREATE INDEX IF NOT EXISTS idx_logs_category ON logs(category);
        """

        var errMsg: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, createTableSQL, nil, nil, &errMsg) == SQLITE_OK else {
            let error = errMsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errMsg)
            throw LogStorageError.schemaCreationFailed(error)
        }

        // Enable WAL mode for better concurrent access
        _ = sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        _ = sqlite3_exec(db, "PRAGMA synchronous=NORMAL;", nil, nil, nil)

        systemLogger.info("Log storage initialized at \(self.dbPath)")
    }

    /// Append a log entry to storage
    func append(_ entry: LogEntry) async throws {
        guard let db else {
            throw LogStorageError.notInitialized
        }

        let insertSQL = """
        INSERT INTO logs (id, timestamp, level, message, category, file, function, line, context, error_description, error_type, device_info)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK else {
            throw LogStorageError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, entry.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_double(stmt, 2, entry.timestamp.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 3, entry.level.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 4, entry.message, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 5, entry.category, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 6, entry.file, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 7, entry.function, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int(stmt, 8, Int32(entry.line))

        if let context = entry.context {
            let contextData = try? JSONEncoder().encode(context)
            let contextString = contextData.flatMap { String(data: $0, encoding: .utf8) }
            sqlite3_bind_text(stmt, 9, contextString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(stmt, 9)
        }

        if let errorDesc = entry.errorDescription {
            sqlite3_bind_text(stmt, 10, errorDesc, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(stmt, 10)
        }

        if let errorType = entry.errorType {
            sqlite3_bind_text(stmt, 11, errorType, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(stmt, 11)
        }

        if let deviceInfo = entry.deviceInfo {
            let deviceData = try? JSONEncoder().encode(deviceInfo)
            let deviceString = deviceData.flatMap { String(data: $0, encoding: .utf8) }
            sqlite3_bind_text(stmt, 12, deviceString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(stmt, 12)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw LogStorageError.insertFailed(String(cString: sqlite3_errmsg(db)))
        }

        // Rotate logs if needed
        await rotateIfNeeded()
    }

    /// Rotate logs to maintain max entry limit
    private func rotateIfNeeded() async {
        guard let db else { return }

        // Count current entries
        let countSQL = "SELECT COUNT(*) FROM logs"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, countSQL, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW else { return }
        let count = Int(sqlite3_column_int(stmt, 0))

        if count > maxEntries {
            let deleteCount = count - maxEntries + (maxEntries / 10) // Delete 10% extra for buffer
            let deleteSQL = """
            DELETE FROM logs WHERE id IN (
                SELECT id FROM logs ORDER BY timestamp ASC LIMIT \(deleteCount)
            )
            """
            sqlite3_exec(db, deleteSQL, nil, nil, nil)
            systemLogger.debug("Rotated \(deleteCount) old log entries")
        }
    }

    /// Export logs as JSON array
    func export(
        since: Date? = nil,
        until: Date? = nil,
        levels: Set<LogLevel>? = nil,
        category: String? = nil,
        limit: Int = 1000,
    ) async throws -> Data {
        guard let db else {
            throw LogStorageError.notInitialized
        }

        var conditions: [String] = []
        var params: [Any] = []

        if let since {
            conditions.append("timestamp >= ?")
            params.append(since.timeIntervalSince1970)
        }

        if let until {
            conditions.append("timestamp <= ?")
            params.append(until.timeIntervalSince1970)
        }

        if let levels, !levels.isEmpty {
            let levelPlaceholders = levels.map { _ in "?" }.joined(separator: ", ")
            conditions.append("level IN (\(levelPlaceholders))")
            levels.forEach { params.append($0.rawValue) }
        }

        if let category {
            conditions.append("category = ?")
            params.append(category)
        }

        let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")
        let selectSQL = """
        SELECT id, timestamp, level, message, category, file, function, line, context, error_description, error_type, device_info
        FROM logs \(whereClause) ORDER BY timestamp DESC LIMIT \(limit)
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, selectSQL, -1, &stmt, nil) == SQLITE_OK else {
            throw LogStorageError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        // Bind parameters
        for (index, param) in params.enumerated() {
            let sqlIndex = Int32(index + 1)
            if let doubleVal = param as? Double {
                sqlite3_bind_double(stmt, sqlIndex, doubleVal)
            } else if let stringVal = param as? String {
                sqlite3_bind_text(stmt, sqlIndex, stringVal, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
        }

        var entries: [[String: Any]] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            var entry: [String: Any] = [:]

            if let id = sqlite3_column_text(stmt, 0) {
                entry["id"] = String(cString: id)
            }
            entry["timestamp"] = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)).ISO8601Format()
            if let level = sqlite3_column_text(stmt, 2) {
                entry["level"] = String(cString: level)
            }
            if let message = sqlite3_column_text(stmt, 3) {
                entry["message"] = String(cString: message)
            }
            if let category = sqlite3_column_text(stmt, 4) {
                entry["category"] = String(cString: category)
            }
            if let file = sqlite3_column_text(stmt, 5) {
                entry["file"] = String(cString: file)
            }
            if let function = sqlite3_column_text(stmt, 6) {
                entry["function"] = String(cString: function)
            }
            entry["line"] = Int(sqlite3_column_int(stmt, 7))

            if let context = sqlite3_column_text(stmt, 8) {
                entry["context"] = String(cString: context)
            }
            if let errorDesc = sqlite3_column_text(stmt, 9) {
                entry["error_description"] = String(cString: errorDesc)
            }
            if let errorType = sqlite3_column_text(stmt, 10) {
                entry["error_type"] = String(cString: errorType)
            }
            if let deviceInfo = sqlite3_column_text(stmt, 11) {
                entry["device_info"] = String(cString: deviceInfo)
            }

            entries.append(entry)
        }

        return try JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys])
    }

    /// Get storage statistics
    func statistics() async throws -> Statistics {
        guard let db else {
            throw LogStorageError.notInitialized
        }

        // Get file size
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: dbPath)[.size] as? Int64) ?? 0

        // Get entry counts by level
        let statsSQL = """
        SELECT
            COUNT(*) as total,
            MIN(timestamp) as oldest,
            MAX(timestamp) as newest,
            level,
            COUNT(*) as level_count
        FROM logs
        GROUP BY level
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, statsSQL, -1, &stmt, nil) == SQLITE_OK else {
            throw LogStorageError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        var totalEntries = 0
        var oldestEntry: Date?
        var newestEntry: Date?
        var entriesByLevel: [LogLevel: Int] = [:]

        while sqlite3_step(stmt) == SQLITE_ROW {
            let count = Int(sqlite3_column_int(stmt, 0))
            totalEntries = max(totalEntries, count)

            let oldest = sqlite3_column_double(stmt, 1)
            if oldest > 0 {
                let date = Date(timeIntervalSince1970: oldest)
                if oldestEntry.map({ date < $0 }) ?? true {
                    oldestEntry = date
                }
            }

            let newest = sqlite3_column_double(stmt, 2)
            if newest > 0 {
                let date = Date(timeIntervalSince1970: newest)
                if newestEntry.map({ date > $0 }) ?? true {
                    newestEntry = date
                }
            }

            if let levelStr = sqlite3_column_text(stmt, 3),
               let level = LogLevel(rawValue: String(cString: levelStr))
            {
                entriesByLevel[level] = Int(sqlite3_column_int(stmt, 4))
            }
        }

        return Statistics(
            totalEntries: totalEntries,
            oldestEntry: oldestEntry,
            newestEntry: newestEntry,
            sizeInBytes: fileSize,
            entriesByLevel: entriesByLevel,
        )
    }

    /// Clear all logs
    func clear() async throws {
        guard let db else {
            throw LogStorageError.notInitialized
        }

        guard sqlite3_exec(db, "DELETE FROM logs", nil, nil, nil) == SQLITE_OK else {
            throw LogStorageError.deleteFailed(String(cString: sqlite3_errmsg(db)))
        }

        // Reclaim space
        sqlite3_exec(db, "VACUUM", nil, nil, nil)
        systemLogger.info("Log storage cleared")
    }

    /// Close database connection
    func close() {
        if let db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    // Note: deinit removed for Swift 6 actor safety
    // Call close() explicitly before discarding the actor
}

// MARK: - Errors

enum LogStorageError: Error, LocalizedError {
    case notInitialized
    case databaseOpenFailed(String)
    case schemaCreationFailed(String)
    case prepareFailed(String)
    case insertFailed(String)
    case queryFailed(String)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            "Log storage not initialized"
        case let .databaseOpenFailed(msg):
            "Failed to open log database: \(msg)"
        case let .schemaCreationFailed(msg):
            "Failed to create log schema: \(msg)"
        case let .prepareFailed(msg):
            "Failed to prepare statement: \(msg)"
        case let .insertFailed(msg):
            "Failed to insert log entry: \(msg)"
        case let .queryFailed(msg):
            "Failed to query logs: \(msg)"
        case let .deleteFailed(msg):
            "Failed to delete logs: \(msg)"
        }
    }
}
