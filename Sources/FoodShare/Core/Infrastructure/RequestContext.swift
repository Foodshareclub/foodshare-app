//
//  RequestContext.swift
//  Foodshare
//
//  TaskLocal-based request context for passing user ID, locale, and correlation ID
//  through async call stacks without explicit parameter passing
//

import Foundation

/// Request context that flows through async operations using TaskLocal
/// Eliminates the need to pass userId and locale through every function parameter
public struct RequestContext: Sendable {
    // MARK: - Properties
    
    /// Current user's ID (nil for guest users)
    public let userId: UUID?
    
    /// Current locale for translations
    public let locale: String
    
    /// Correlation ID for request tracing
    public let correlationId: UUID
    
    /// Request timestamp
    public let timestamp: Date
    
    /// Device information
    public let deviceInfo: DeviceInfo?
    
    // MARK: - TaskLocal Storage
    
    /// TaskLocal storage for request context
    @TaskLocal public static var current: RequestContext?
    
    // MARK: - Initialization
    
    public init(
        userId: UUID? = nil,
        locale: String = "en",
        correlationId: UUID = UUID(),
        timestamp: Date = Date(),
        deviceInfo: DeviceInfo? = nil
    ) {
        self.userId = userId
        self.locale = locale
        self.correlationId = correlationId
        self.timestamp = timestamp
        self.deviceInfo = deviceInfo
    }
    
    // MARK: - Convenience Accessors
    
    /// Get current user ID from context or return nil
    public static var userId: UUID? {
        current?.userId
    }
    
    /// Get current locale from context or return default
    public static var locale: String {
        current?.locale ?? "en"
    }
    
    /// Get current correlation ID from context or generate new one
    public static var correlationId: UUID {
        current?.correlationId ?? UUID()
    }
}

// MARK: - Device Info

public struct DeviceInfo: Sendable {
    public let model: String
    public let systemVersion: String
    public let appVersion: String
    public let buildNumber: String
    
    public init(
        model: String,
        systemVersion: String,
        appVersion: String,
        buildNumber: String
    ) {
        self.model = model
        self.systemVersion = systemVersion
        self.appVersion = appVersion
        self.buildNumber = buildNumber
    }
    
    /// Create device info from current device
    public static func current() -> DeviceInfo {
        #if !SKIP
        DeviceInfo(
            model: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        )
        #else
        DeviceInfo(
            model: "Android",
            systemVersion: "unknown",
            appVersion: "unknown",
            buildNumber: "unknown"
        )
        #endif
    }
}

// MARK: - Request Context Extensions

extension RequestContext {
    /// Create context from current app state
    @MainActor
    public static func fromAppState(_ appState: AppState) -> RequestContext {
        RequestContext(
            userId: appState.currentUser?.id,
            locale: EnhancedTranslationService.shared.currentLocale,
            deviceInfo: .current()
        )
    }
    
    /// Execute a task with this context
    public func withContext<T>(
        operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        try await RequestContext.$current.withValue(self) {
            try await operation()
        }
    }
}

// MARK: - Usage Examples

/*
 
 // Example 1: Set context at the top level
 let context = RequestContext(
     userId: currentUser.id,
     locale: "es"
 )
 
 await context.withContext {
     // All async operations in this scope have access to context
     await fetchUserData()
     await loadTranslations()
 }
 
 // Example 2: Access context in nested functions
 func fetchUserData() async {
     guard let userId = RequestContext.userId else {
         // Handle guest user
         return
     }
     
     let locale = RequestContext.locale
     let correlationId = RequestContext.correlationId
     
     // Use context values without passing them as parameters
     await repository.fetch(userId: userId, locale: locale)
 }
 
 // Example 3: Logging with correlation ID
 func logRequest() {
     logger.info("Request \(RequestContext.correlationId): Processing...")
 }
 
 */
