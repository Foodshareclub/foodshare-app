//
//  AuditLogger.swift
//  Foodshare
//
//  Enterprise-grade audit logging service for sensitive operations.
//  Provides compliance-ready logging for security, GDPR, and operational monitoring.
//
//  Features:
//  - Comprehensive audit trail for sensitive operations
//  - Asynchronous logging with batching for performance
//  - Local persistence for offline support
//  - Automatic retry for failed log submissions
//  - Rich context capture (user, device, location)
//

import Foundation
import OSLog
import Supabase

// MARK: - Audit Operation Types

/// Categories of auditable operations
enum AuditCategory: String, Codable, Sendable {
    case authentication
    case authorization
    case dataAccess
    case dataModification
    case security
    case privacy
    case system
}

/// Specific auditable operations
enum AuditOperation: String, Codable, Sendable {
    // Authentication
    case login
    case logout
    case loginFailed
    case tokenRefresh
    case sessionExpired

    // Authorization
    case permissionGranted
    case permissionDenied
    case roleChanged

    // Data Access
    case profileViewed
    case listingViewed
    case messageAccessed
    case sensitiveDataAccessed

    // Data Modification
    case profileCreated
    case profileUpdated
    case profileDeleted
    case listingCreated
    case listingUpdated
    case listingDeleted
    case messageCreated
    case reservationCreated
    case reservationCancelled

    // Security
    case passwordChanged
    case mfaEnabled
    case mfaDisabled
    case biometricEnabled
    case biometricDisabled
    case suspiciousActivity

    // Privacy
    case dataExportRequested
    case dataDeleteRequested
    case consentUpdated

    // System
    case appLaunched
    case appBackgrounded
    case errorOccurred

    var category: AuditCategory {
        switch self {
        case .login, .logout, .loginFailed, .tokenRefresh, .sessionExpired:
            .authentication
        case .permissionGranted, .permissionDenied, .roleChanged:
            .authorization
        case .profileViewed, .listingViewed, .messageAccessed, .sensitiveDataAccessed:
            .dataAccess
        case .profileCreated, .profileUpdated, .profileDeleted,
             .listingCreated, .listingUpdated, .listingDeleted,
             .messageCreated, .reservationCreated, .reservationCancelled:
            .dataModification
        case .passwordChanged, .mfaEnabled, .mfaDisabled,
             .biometricEnabled, .biometricDisabled, .suspiciousActivity:
            .security
        case .dataExportRequested, .dataDeleteRequested, .consentUpdated:
            .privacy
        case .appLaunched, .appBackgrounded, .errorOccurred:
            .system
        }
    }

    var severity: AuditSeverity {
        switch self {
        case .loginFailed, .permissionDenied, .suspiciousActivity, .errorOccurred:
            .warning
        case .passwordChanged, .mfaEnabled, .mfaDisabled,
             .dataExportRequested, .dataDeleteRequested,
             .profileDeleted, .listingDeleted:
            .high
        case .login, .logout, .profileCreated, .listingCreated:
            .medium
        default:
            .low
        }
    }
}

/// Severity levels for audit events
enum AuditSeverity: String, Codable, Sendable, Comparable {
    case low
    case medium
    case high
    case warning
    case critical

    static func < (lhs: AuditSeverity, rhs: AuditSeverity) -> Bool {
        let order: [AuditSeverity] = [.low, .medium, .high, .warning, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

// MARK: - Audit Event

/// Represents a single audit event
struct AuditEvent: Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let userId: UUID?
    let operation: AuditOperation
    let category: AuditCategory
    let severity: AuditSeverity
    let resourceType: String?
    let resourceId: String?
    let metadata: [String: String]
    let deviceInfo: DeviceInfo
    let success: Bool
    let errorMessage: String?

    init(
        userId: UUID?,
        operation: AuditOperation,
        resourceType: String? = nil,
        resourceId: String? = nil,
        metadata: [String: String] = [:],
        success: Bool = true,
        errorMessage: String? = nil,
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.userId = userId
        self.operation = operation
        self.category = operation.category
        self.severity = operation.severity
        self.resourceType = resourceType
        self.resourceId = resourceId
        self.metadata = metadata
        self.deviceInfo = DeviceInfo.current
        self.success = success
        self.errorMessage = errorMessage
    }
}

/// Device information for audit context
struct DeviceInfo: Codable, Sendable {
    let deviceId: String
    let deviceModel: String
    let osVersion: String
    let appVersion: String
    let locale: String
    let timezone: String

    #if !SKIP
    static var current: DeviceInfo {
        DeviceInfo(
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            deviceModel: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier,
        )
    }
    #else
    static var current: DeviceInfo {
        DeviceInfo(
            deviceId: UUID().uuidString,
            deviceModel: "Android",
            osVersion: "unknown",
            appVersion: "unknown",
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier,
        )
    }
    #endif
}

#if !SKIP
import UIKit // Required for UIDevice
#endif

// MARK: - Audit Logger Protocol

/// Protocol for audit logging operations
protocol AuditLoggerProtocol: Sendable {
    func log(_ event: AuditEvent) async
    func log(
        operation: AuditOperation,
        userId: UUID?,
        resourceType: String?,
        resourceId: String?,
        metadata: [String: String],
        success: Bool,
        errorMessage: String?,
    ) async
    func flush() async
}

// MARK: - Audit Logger Implementation

/// Production-ready audit logger with batching and persistence
///
/// Features:
/// - Batches audit events for efficient transmission
/// - Persists events locally for offline support
/// - Automatically retries failed submissions
/// - Integrates with Supabase for centralized logging
///
/// Usage:
/// ```swift
/// let logger = AuditLogger(supabase: supabaseClient)
/// await logger.log(operation: .login, userId: user.id)
/// await logger.log(operation: .listingCreated, userId: user.id, resourceType: "listing", resourceId: listing.id)
/// ```
actor AuditLogger: AuditLoggerProtocol {
    private let supabase: SupabaseClient
    private let osLogger: Logger
    private let batchSize: Int
    private let flushInterval: TimeInterval

    // Event queue for batching
    private var eventQueue: [AuditEvent] = []
    private var flushTask: Task<Void, Never>?
    private var isFlushScheduled = false

    // Encrypted persistent storage for offline support (security-critical)
    private let secureStorage = SecureStorage.shared
    private let persistenceKey = "audit_events"

    init(
        supabase: Supabase.SupabaseClient,
        batchSize: Int = 10,
        flushInterval: TimeInterval = 30,
        logger: Logger = Logger(subsystem: "com.flutterflow.foodshare", category: "audit"),
    ) {
        self.supabase = supabase
        self.batchSize = batchSize
        self.flushInterval = flushInterval
        self.osLogger = logger

        // Load any persisted events from previous session asynchronously
        Task {
            await loadPersistedEvents()
        }

        osLogger.debug("AuditLogger initialized with encrypted storage")
    }

    deinit {
        flushTask?.cancel()
    }

    // MARK: - Public API

    /// Log an audit event
    func log(_ event: AuditEvent) async {
        eventQueue.append(event)

        // Log locally for immediate visibility
        osLogger
            .info(
                "AUDIT: \(event.operation.rawValue) by \(event.userId?.uuidString ?? "anonymous") - \(event.success ? "success" : "failed")",
            )

        // Check if we should flush
        if eventQueue.count >= batchSize {
            await flush()
        } else if !isFlushScheduled {
            scheduleFlush()
        }
    }

    /// Convenience method for logging operations
    func log(
        operation: AuditOperation,
        userId: UUID? = nil,
        resourceType: String? = nil,
        resourceId: String? = nil,
        metadata: [String: String] = [:],
        success: Bool = true,
        errorMessage: String? = nil,
    ) async {
        let event = AuditEvent(
            userId: userId,
            operation: operation,
            resourceType: resourceType,
            resourceId: resourceId,
            metadata: metadata,
            success: success,
            errorMessage: errorMessage,
        )
        await log(event)
    }

    /// Flush all pending events to the server
    func flush() async {
        flushTask?.cancel()
        isFlushScheduled = false

        guard !eventQueue.isEmpty else { return }

        let eventsToSend = eventQueue
        eventQueue.removeAll()

        do {
            try await sendEvents(eventsToSend)
            osLogger.debug("Flushed \(eventsToSend.count) audit events")
        } catch {
            osLogger.error("Failed to flush audit events: \(error.localizedDescription)")
            // Re-add events to queue for retry
            eventQueue.insert(contentsOf: eventsToSend, at: 0)
            // Persist for offline recovery
            persistEvents()
        }
    }

    // MARK: - Private Implementation

    private func scheduleFlush() {
        isFlushScheduled = true
        flushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(self?.flushInterval ?? 30 * 1_000_000_000))
            await self?.flush()
        }
    }

    private func sendEvents(_ events: [AuditEvent]) async throws {
        // Convert to database format
        let records = events.map { event -> [String: Any] in
            var record: [String: Any] = [
                "id": event.id.uuidString,
                "timestamp": ISO8601DateFormatter().string(from: event.timestamp),
                "operation": event.operation.rawValue,
                "category": event.category.rawValue,
                "severity": event.severity.rawValue,
                "success": event.success,
                "device_info": [
                    "device_id": event.deviceInfo.deviceId,
                    "device_model": event.deviceInfo.deviceModel,
                    "os_version": event.deviceInfo.osVersion,
                    "app_version": event.deviceInfo.appVersion,
                    "locale": event.deviceInfo.locale,
                    "timezone": event.deviceInfo.timezone
                ]
            ]

            if let userId = event.userId {
                record["user_id"] = userId.uuidString
            }
            if let resourceType = event.resourceType {
                record["resource_type"] = resourceType
            }
            if let resourceId = event.resourceId {
                record["resource_id"] = resourceId
            }
            if !event.metadata.isEmpty {
                record["metadata"] = event.metadata
            }
            if let errorMessage = event.errorMessage {
                record["error_message"] = errorMessage
            }

            return record
        }

        // Insert via RPC for proper server-side handling
        try await supabase.rpc("log_audit_events", params: ["events": records]).execute()
    }

    private func persistEvents() {
        guard !eventQueue.isEmpty else { return }

        Task {
            do {
                // Use encrypted storage for sensitive audit events
                try await secureStorage.store(eventQueue, forKey: persistenceKey)
                osLogger.debug("Persisted \(eventQueue.count) audit events with encryption")
            } catch {
                osLogger.error("Failed to persist audit events: \(error.localizedDescription)")
                // Fallback: try to persist minimal info without sensitive data
                fallbackPersist()
            }
        }
    }

    private func loadPersistedEvents() async {
        do {
            // Load from encrypted storage
            if let events: [AuditEvent] = try await secureStorage.retrieve([AuditEvent].self, forKey: persistenceKey) {
                eventQueue.append(contentsOf: events)
                try await secureStorage.remove(forKey: persistenceKey)
                osLogger.debug("Loaded \(events.count) persisted audit events from encrypted storage")
            }

            // Also check legacy UserDefaults storage and migrate if found
            await migrateLegacyStorage()
        } catch {
            osLogger.error("Failed to load persisted audit events: \(error.localizedDescription)")
        }
    }

    /// Migrate from legacy UserDefaults storage to encrypted storage
    private func migrateLegacyStorage() async {
        let legacyKey = "com.foodshare.auditEvents"
        guard let data = UserDefaults.standard.data(forKey: legacyKey) else { return }

        do {
            let events = try JSONDecoder().decode([AuditEvent].self, from: data)
            eventQueue.append(contentsOf: events)
            UserDefaults.standard.removeObject(forKey: legacyKey)
            osLogger.info("Migrated \(events.count) audit events from legacy storage to encrypted storage")
        } catch {
            osLogger.error("Failed to migrate legacy audit events: \(error.localizedDescription)")
            // Clear corrupted legacy data
            UserDefaults.standard.removeObject(forKey: legacyKey)
        }
    }

    /// Fallback persistence without encryption (for critical failures only)
    private func fallbackPersist() {
        // Only store non-sensitive event metadata as a last resort
        let minimalEvents = eventQueue.map { event -> [String: String] in
            [
                "id": event.id.uuidString,
                "operation": event.operation.rawValue,
                "timestamp": ISO8601DateFormatter().string(from: event.timestamp)
            ]
        }

        if let data = try? JSONEncoder().encode(minimalEvents) {
            UserDefaults.standard.set(data, forKey: "audit_events_minimal_backup")
            osLogger.warning("Used fallback persistence for audit events (minimal data only)")
        }
    }
}

// MARK: - Audit Logger Extensions

extension AuditLogger {
    /// Log authentication events
    func logLogin(userId: UUID, method: String, success: Bool = true, errorMessage: String? = nil) async {
        await log(
            operation: success ? .login : .loginFailed,
            userId: userId,
            metadata: ["method": method],
            success: success,
            errorMessage: errorMessage,
        )
    }

    func logLogout(userId: UUID) async {
        await log(operation: .logout, userId: userId)
    }

    /// Log data access events
    func logProfileViewed(userId: UUID, viewedProfileId: UUID) async {
        await log(
            operation: .profileViewed,
            userId: userId,
            resourceType: "profile",
            resourceId: viewedProfileId.uuidString,
        )
    }

    func logListingViewed(userId: UUID?, listingId: UUID) async {
        await log(
            operation: .listingViewed,
            userId: userId,
            resourceType: "listing",
            resourceId: listingId.uuidString,
        )
    }

    /// Log data modification events
    func logListingCreated(userId: UUID, listingId: UUID) async {
        await log(
            operation: .listingCreated,
            userId: userId,
            resourceType: "listing",
            resourceId: listingId.uuidString,
        )
    }

    func logListingDeleted(userId: UUID, listingId: UUID) async {
        await log(
            operation: .listingDeleted,
            userId: userId,
            resourceType: "listing",
            resourceId: listingId.uuidString,
        )
    }

    /// Log security events
    func logPasswordChanged(userId: UUID) async {
        await log(operation: .passwordChanged, userId: userId)
    }

    func logMFAEnabled(userId: UUID, method: String) async {
        await log(
            operation: .mfaEnabled,
            userId: userId,
            metadata: ["method": method],
        )
    }

    func logSuspiciousActivity(userId: UUID?, reason: String, metadata: [String: String] = [:]) async {
        var enrichedMetadata = metadata
        enrichedMetadata["reason"] = reason
        await log(
            operation: .suspiciousActivity,
            userId: userId,
            metadata: enrichedMetadata,
            success: false,
        )
    }

    /// Log error events
    func logError(userId: UUID?, operation: String, error: Error) async {
        await log(
            operation: .errorOccurred,
            userId: userId,
            metadata: [
                "operation": operation,
                "error_type": String(describing: type(of: error))
            ],
            success: false,
            errorMessage: error.localizedDescription,
        )
    }
}

// MARK: - Mock Implementation for Testing

#if DEBUG
    actor MockAuditLogger: AuditLoggerProtocol {
        private(set) var loggedEvents: [AuditEvent] = []

        func log(_ event: AuditEvent) async {
            loggedEvents.append(event)
        }

        func log(
            operation: AuditOperation,
            userId: UUID?,
            resourceType: String?,
            resourceId: String?,
            metadata: [String: String],
            success: Bool,
            errorMessage: String?,
        ) async {
            let event = AuditEvent(
                userId: userId,
                operation: operation,
                resourceType: resourceType,
                resourceId: resourceId,
                metadata: metadata,
                success: success,
                errorMessage: errorMessage,
            )
            await log(event)
        }

        func flush() async {
            // No-op for mock
        }

        func reset() {
            loggedEvents.removeAll()
        }

        func events(for operation: AuditOperation) -> [AuditEvent] {
            loggedEvents.filter { $0.operation == operation }
        }

        func events(for userId: UUID) -> [AuditEvent] {
            loggedEvents.filter { $0.userId == userId }
        }
    }
#endif
