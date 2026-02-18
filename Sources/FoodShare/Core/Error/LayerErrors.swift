//
//  LayerErrors.swift
//  Foodshare
//
//  Comprehensive typed error system for Clean Architecture layers.
//  Provides compile-time error type safety using Swift 6.2 typed throws.
//
//  Layer Hierarchy:
//  - RepositoryError: Data layer (network, database, storage)
//  - UseCaseError: Domain layer (business logic, validation)
//  - ViewModelError: Presentation layer (UI, state management)
//  - PersistenceError: Core Data operations
//
//  Usage:
//  ```swift
//  // Swift 6.2 typed throws syntax
//  func fetchProfile(userId: UUID) async throws(RepositoryError) -> UserProfile
//
//  // Error conversion between layers
//  func execute() async throws(UseCaseError) -> FoodListing {
//      do {
//          return try await repository.fetch(id: id)
//      } catch let error as RepositoryError {
//          throw error.toUseCaseError()
//      }
//  }
//  ```
//

#if !SKIP
import Foundation

// MARK: - Typed Throws Protocol

/// Protocol for errors that support typed throws
public protocol TypedError: Error, LocalizedError, Sendable {
    /// Error code for categorization and telemetry
    var code: String { get }

    /// Whether this error is recoverable through retry
    var isRetryable: Bool { get }

    /// User-friendly message for UI display
    var userFriendlyMessage: String { get }

    /// Suggested retry delay (if retryable)
    var suggestedRetryDelay: TimeInterval? { get }

    /// Tags for error categorization
    var tags: [ErrorTag] { get }
}

extension TypedError {
    public var suggestedRetryDelay: TimeInterval? { nil }
    public var tags: [ErrorTag] { [] }
}

// MARK: - Repository Error (Data Layer)

/// Errors from data layer operations (repositories)
public enum RepositoryError: TypedError {
    // Network errors
    case networkUnavailable
    case timeout(operation: String, duration: TimeInterval)
    case serverError(statusCode: Int, message: String?)
    case rateLimited(retryAfter: TimeInterval)

    // Authentication/Authorization
    case unauthorized
    case forbidden(resource: String)
    case sessionExpired

    // Data errors
    case notFound(resource: String, id: String?)
    case invalidData(reason: String)
    case decodingFailed(type: String, reason: String)
    case encodingFailed(type: String, reason: String)

    // Database errors
    case queryFailed(query: String, reason: String)
    case constraintViolation(field: String, reason: String)
    case transactionFailed(reason: String)

    // Storage errors
    case storageFull
    case storageUnavailable
    case fileNotFound(path: String)
    case fileCorrupted(path: String)

    // Generic
    case underlying(Error & Sendable)
    case unknown(reason: String)

    public var code: String {
        switch self {
        case .networkUnavailable: "REPO_NET_UNAVAILABLE"
        case .timeout: "REPO_TIMEOUT"
        case .serverError: "REPO_SERVER_ERROR"
        case .rateLimited: "REPO_RATE_LIMITED"
        case .unauthorized: "REPO_UNAUTHORIZED"
        case .forbidden: "REPO_FORBIDDEN"
        case .sessionExpired: "REPO_SESSION_EXPIRED"
        case .notFound: "REPO_NOT_FOUND"
        case .invalidData: "REPO_INVALID_DATA"
        case .decodingFailed: "REPO_DECODING_FAILED"
        case .encodingFailed: "REPO_ENCODING_FAILED"
        case .queryFailed: "REPO_QUERY_FAILED"
        case .constraintViolation: "REPO_CONSTRAINT"
        case .transactionFailed: "REPO_TX_FAILED"
        case .storageFull: "REPO_STORAGE_FULL"
        case .storageUnavailable: "REPO_STORAGE_UNAVAILABLE"
        case .fileNotFound: "REPO_FILE_NOT_FOUND"
        case .fileCorrupted: "REPO_FILE_CORRUPTED"
        case .underlying: "REPO_UNDERLYING"
        case .unknown: "REPO_UNKNOWN"
        }
    }

    public var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            "Network is unavailable"
        case let .timeout(operation, duration):
            "Operation '\(operation)' timed out after \(Int(duration)) seconds"
        case let .serverError(statusCode, message):
            if let message { "Server error (\(statusCode)): \(message)" } else { "Server error with status code \(statusCode)" }
        case let .rateLimited(retryAfter):
            "Rate limited. Retry after \(Int(retryAfter)) seconds"
        case .unauthorized:
            "Authentication required"
        case let .forbidden(resource):
            "Access forbidden to \(resource)"
        case .sessionExpired:
            "Session has expired"
        case let .notFound(resource, id):
            if let id { "\(resource) with ID '\(id)' not found" } else { "\(resource) not found" }
        case let .invalidData(reason):
            "Invalid data: \(reason)"
        case let .decodingFailed(type, reason):
            "Failed to decode \(type): \(reason)"
        case let .encodingFailed(type, reason):
            "Failed to encode \(type): \(reason)"
        case let .queryFailed(query, reason):
            "Query '\(query)' failed: \(reason)"
        case let .constraintViolation(field, reason):
            "Constraint violation on '\(field)': \(reason)"
        case let .transactionFailed(reason):
            "Transaction failed: \(reason)"
        case .storageFull:
            "Storage is full"
        case .storageUnavailable:
            "Storage is unavailable"
        case let .fileNotFound(path):
            "File not found: \(path)"
        case let .fileCorrupted(path):
            "File corrupted: \(path)"
        case let .underlying(error):
            "Underlying error: \(error.localizedDescription)"
        case let .unknown(reason):
            "Unknown error: \(reason)"
        }
    }

    public var userFriendlyMessage: String {
        switch self {
        case .networkUnavailable:
            "No internet connection. Please check your network."
        case .timeout:
            "Request timed out. Please try again."
        case .serverError:
            "Our servers are having issues. Please try again later."
        case let .rateLimited(retryAfter):
            "Too many requests. Please wait \(Int(retryAfter)) seconds."
        case .unauthorized, .sessionExpired:
            "Please sign in to continue."
        case .forbidden:
            "You don't have permission to access this."
        case .notFound:
            "The item you're looking for doesn't exist."
        case .invalidData, .decodingFailed, .encodingFailed:
            "We received unexpected data. Please try again."
        case .queryFailed, .transactionFailed:
            "Something went wrong. Please try again."
        case .constraintViolation:
            "This action conflicts with existing data."
        case .storageFull:
            "Your device is running low on storage."
        case .storageUnavailable, .fileNotFound, .fileCorrupted:
            "Unable to access local storage."
        case .underlying, .unknown:
            "An unexpected error occurred. Please try again."
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .timeout, .rateLimited:
            true
        case let .serverError(statusCode, _):
            statusCode >= 500
        case .storageUnavailable:
            true
        default:
            false
        }
    }

    public var suggestedRetryDelay: TimeInterval? {
        switch self {
        case let .rateLimited(retryAfter):
            retryAfter
        case .timeout, .networkUnavailable:
            2.0
        case let .serverError(statusCode, _) where statusCode >= 500:
            5.0
        default:
            nil
        }
    }

    public var tags: [ErrorTag] {
        switch self {
        case .networkUnavailable, .timeout, .serverError, .rateLimited:
            [.network, .infrastructure]
        case .unauthorized, .forbidden, .sessionExpired:
            [.authentication, .authorization]
        case .notFound, .invalidData, .decodingFailed, .encodingFailed:
            [.data]
        case .queryFailed, .constraintViolation, .transactionFailed:
            [.persistence]
        case .storageFull, .storageUnavailable, .fileNotFound, .fileCorrupted:
            [.persistence]
        case .underlying, .unknown:
            [.infrastructure]
        }
    }

    // MARK: - Conversion to Use Case Error

    public func toUseCaseError() -> UseCaseError {
        switch self {
        case .networkUnavailable, .timeout, .serverError, .storageUnavailable:
            .serviceUnavailable(reason: userFriendlyMessage)
        case .rateLimited:
            .rateLimited
        case .unauthorized, .sessionExpired:
            .authenticationRequired
        case .forbidden:
            .unauthorized(action: "access this resource")
        case let .notFound(resource, _):
            .notFound(resource: resource)
        case .invalidData, .decodingFailed, .encodingFailed, .constraintViolation:
            .invalidInput(reason: userFriendlyMessage)
        case .queryFailed, .transactionFailed:
            .operationFailed(operation: "database operation", reason: userFriendlyMessage)
        case .storageFull, .fileNotFound, .fileCorrupted:
            .persistenceError(reason: userFriendlyMessage)
        case let .underlying(error):
            .underlying(error)
        case let .unknown(reason):
            .unknown(reason: reason)
        }
    }
}

// MARK: - Repository Error Factory

extension RepositoryError {
    /// Create from NetworkError
    static func from(_ error: NetworkError) -> RepositoryError {
        switch error {
        case .noInternetConnection:
            .networkUnavailable
        case let .timeout(endpoint, duration):
            .timeout(operation: endpoint, duration: duration)
        case let .serverError(statusCode, message, _):
            .serverError(statusCode: statusCode, message: message)
        case let .rateLimited(retryAfter):
            .rateLimited(retryAfter: retryAfter)
        case .unauthorized:
            .unauthorized
        case let .forbidden(endpoint):
            .forbidden(resource: endpoint)
        case let .notFound(endpoint):
            .notFound(resource: endpoint, id: nil)
        case let .decodingError(error, _):
            .decodingFailed(type: "response", reason: error.localizedDescription)
        case let .encodingError(error):
            .encodingFailed(type: "request", reason: error.localizedDescription)
        case .invalidURL, .noData:
            .invalidData(reason: error.localizedDescription)
        case let .unknown(underlyingError):
            if let sendable = underlyingError as? (Error & Sendable) {
                .underlying(sendable)
            } else {
                .unknown(reason: underlyingError.localizedDescription)
            }
        }
    }

    /// Create from DatabaseError
    static func from(_ error: DatabaseError) -> RepositoryError {
        switch error {
        case let .connectionFailed(reason):
            .networkUnavailable
        case let .queryFailed(message):
            .queryFailed(query: "unknown", reason: message)
        case .notFound:
            .notFound(resource: "record", id: nil)
        case .unauthorized:
            .unauthorized
        case let .invalidInput(field):
            .constraintViolation(field: field, reason: "Invalid input")
        case .invalidData:
            .invalidData(reason: "Invalid data format")
        case .deleteFailed:
            .transactionFailed(reason: "Delete operation failed")
        case let .rateLimited(retryAfter):
            .rateLimited(retryAfter: retryAfter)
        case let .serverError(statusCode, message):
            .serverError(statusCode: statusCode, message: message)
        case let .unknown(error):
            .underlying(error)
        }
    }
}

// MARK: - Use Case Error (Domain Layer)

/// Errors from domain layer operations (use cases)
public enum UseCaseError: TypedError {
    // Authentication/Authorization
    case authenticationRequired
    case unauthorized(action: String)
    case invalidCredentials

    // Validation
    case invalidInput(reason: String)
    case validationFailed(field: String, reason: String)
    case missingRequired(field: String)

    // Business logic
    case businessRuleViolation(rule: String)
    case preconditionFailed(condition: String)
    case operationNotAllowed(reason: String)

    // Resource errors
    case notFound(resource: String)
    case alreadyExists(resource: String)
    case conflictDetected(reason: String)

    // Service errors
    case serviceUnavailable(reason: String)
    case rateLimited
    case operationFailed(operation: String, reason: String)

    // Persistence
    case persistenceError(reason: String)
    case syncFailed(reason: String)

    // Generic
    case underlying(Error & Sendable)
    case unknown(reason: String)

    public var code: String {
        switch self {
        case .authenticationRequired: "UC_AUTH_REQUIRED"
        case .unauthorized: "UC_UNAUTHORIZED"
        case .invalidCredentials: "UC_INVALID_CREDS"
        case .invalidInput: "UC_INVALID_INPUT"
        case .validationFailed: "UC_VALIDATION_FAILED"
        case .missingRequired: "UC_MISSING_REQUIRED"
        case .businessRuleViolation: "UC_BUSINESS_RULE"
        case .preconditionFailed: "UC_PRECONDITION"
        case .operationNotAllowed: "UC_NOT_ALLOWED"
        case .notFound: "UC_NOT_FOUND"
        case .alreadyExists: "UC_ALREADY_EXISTS"
        case .conflictDetected: "UC_CONFLICT"
        case .serviceUnavailable: "UC_SERVICE_UNAVAILABLE"
        case .rateLimited: "UC_RATE_LIMITED"
        case .operationFailed: "UC_OP_FAILED"
        case .persistenceError: "UC_PERSISTENCE"
        case .syncFailed: "UC_SYNC_FAILED"
        case .underlying: "UC_UNDERLYING"
        case .unknown: "UC_UNKNOWN"
        }
    }

    public var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            "Authentication is required"
        case let .unauthorized(action):
            "Not authorized to \(action)"
        case .invalidCredentials:
            "Invalid credentials"
        case let .invalidInput(reason):
            "Invalid input: \(reason)"
        case let .validationFailed(field, reason):
            "Validation failed for '\(field)': \(reason)"
        case let .missingRequired(field):
            "Required field '\(field)' is missing"
        case let .businessRuleViolation(rule):
            "Business rule violation: \(rule)"
        case let .preconditionFailed(condition):
            "Precondition failed: \(condition)"
        case let .operationNotAllowed(reason):
            "Operation not allowed: \(reason)"
        case let .notFound(resource):
            "\(resource) not found"
        case let .alreadyExists(resource):
            "\(resource) already exists"
        case let .conflictDetected(reason):
            "Conflict detected: \(reason)"
        case let .serviceUnavailable(reason):
            "Service unavailable: \(reason)"
        case .rateLimited:
            "Rate limit exceeded"
        case let .operationFailed(operation, reason):
            "Operation '\(operation)' failed: \(reason)"
        case let .persistenceError(reason):
            "Persistence error: \(reason)"
        case let .syncFailed(reason):
            "Sync failed: \(reason)"
        case let .underlying(error):
            "Underlying error: \(error.localizedDescription)"
        case let .unknown(reason):
            "Unknown error: \(reason)"
        }
    }

    public var userFriendlyMessage: String {
        switch self {
        case .authenticationRequired, .invalidCredentials:
            "Please sign in to continue."
        case .unauthorized:
            "You don't have permission for this action."
        case .invalidInput, .validationFailed, .missingRequired:
            "Please check your input and try again."
        case .businessRuleViolation, .preconditionFailed, .operationNotAllowed:
            "This action isn't allowed right now."
        case .notFound:
            "The item you're looking for doesn't exist."
        case .alreadyExists:
            "This item already exists."
        case .conflictDetected:
            "Someone else has modified this. Please refresh and try again."
        case .serviceUnavailable:
            "Service is temporarily unavailable. Please try again."
        case .rateLimited:
            "Too many requests. Please wait a moment."
        case .operationFailed:
            "Something went wrong. Please try again."
        case .persistenceError:
            "Unable to save your data. Please try again."
        case .syncFailed:
            "Unable to sync. Will retry automatically."
        case .underlying, .unknown:
            "An unexpected error occurred. Please try again."
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .serviceUnavailable, .rateLimited, .syncFailed:
            true
        default:
            false
        }
    }

    public var tags: [ErrorTag] {
        switch self {
        case .authenticationRequired, .unauthorized, .invalidCredentials:
            [.authentication, .authorization]
        case .invalidInput, .validationFailed, .missingRequired:
            [.validation]
        case .businessRuleViolation, .preconditionFailed, .operationNotAllowed:
            [.business]
        case .notFound, .alreadyExists, .conflictDetected:
            [.data]
        case .serviceUnavailable, .rateLimited, .operationFailed:
            [.infrastructure]
        case .persistenceError, .syncFailed:
            [.persistence]
        case .underlying, .unknown:
            [.infrastructure]
        }
    }

    // MARK: - Conversion to ViewModel Error

    public func toViewModelError() -> ViewModelError {
        switch self {
        case .authenticationRequired, .invalidCredentials:
            .authenticationRequired
        case .unauthorized:
            .permissionDenied
        case .invalidInput, .validationFailed, .missingRequired:
            .validationError(message: userFriendlyMessage)
        case .businessRuleViolation, .preconditionFailed, .operationNotAllowed:
            .businessError(message: userFriendlyMessage)
        case .notFound:
            .notFound
        case .alreadyExists, .conflictDetected:
            .conflict(message: userFriendlyMessage)
        case .serviceUnavailable:
            .serviceUnavailable
        case .rateLimited:
            .rateLimited
        case .operationFailed, .persistenceError, .syncFailed:
            .operationFailed(message: userFriendlyMessage)
        case let .underlying(error):
            .underlying(error)
        case let .unknown(reason):
            .unknown(message: reason)
        }
    }
}

// MARK: - ViewModel Error (Presentation Layer)

/// Errors for presentation layer (ViewModels)
public enum ViewModelError: TypedError {
    // User actions
    case authenticationRequired
    case permissionDenied
    case notFound
    case rateLimited
    case serviceUnavailable

    // Input/Validation
    case validationError(message: String)
    case businessError(message: String)
    case conflict(message: String)

    // State errors
    case invalidState(message: String)
    case operationFailed(message: String)
    case loadingFailed(message: String)

    // Generic
    case underlying(Error & Sendable)
    case unknown(message: String)

    public var code: String {
        switch self {
        case .authenticationRequired: "VM_AUTH_REQUIRED"
        case .permissionDenied: "VM_PERMISSION_DENIED"
        case .notFound: "VM_NOT_FOUND"
        case .rateLimited: "VM_RATE_LIMITED"
        case .serviceUnavailable: "VM_SERVICE_UNAVAILABLE"
        case .validationError: "VM_VALIDATION"
        case .businessError: "VM_BUSINESS"
        case .conflict: "VM_CONFLICT"
        case .invalidState: "VM_INVALID_STATE"
        case .operationFailed: "VM_OP_FAILED"
        case .loadingFailed: "VM_LOADING_FAILED"
        case .underlying: "VM_UNDERLYING"
        case .unknown: "VM_UNKNOWN"
        }
    }

    public var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            "Authentication required"
        case .permissionDenied:
            "Permission denied"
        case .notFound:
            "Resource not found"
        case .rateLimited:
            "Rate limit exceeded"
        case .serviceUnavailable:
            "Service unavailable"
        case let .validationError(message):
            message
        case let .businessError(message):
            message
        case let .conflict(message):
            message
        case let .invalidState(message):
            "Invalid state: \(message)"
        case let .operationFailed(message):
            message
        case let .loadingFailed(message):
            message
        case let .underlying(error):
            error.localizedDescription
        case let .unknown(message):
            message
        }
    }

    public var userFriendlyMessage: String {
        errorDescription ?? "An unexpected error occurred."
    }

    public var isRetryable: Bool {
        switch self {
        case .serviceUnavailable, .rateLimited, .loadingFailed:
            true
        default:
            false
        }
    }

    /// Icon to display in UI
    public var iconName: String {
        switch self {
        case .authenticationRequired:
            "person.crop.circle.badge.exclamationmark"
        case .permissionDenied:
            "lock.fill"
        case .notFound:
            "magnifyingglass"
        case .rateLimited:
            "clock.fill"
        case .serviceUnavailable:
            "wifi.slash"
        case .validationError, .businessError:
            "exclamationmark.triangle"
        case .conflict:
            "arrow.triangle.2.circlepath"
        case .invalidState, .operationFailed:
            "xmark.circle"
        case .loadingFailed:
            "arrow.clockwise"
        case .underlying, .unknown:
            "questionmark.circle"
        }
    }

    public var tags: [ErrorTag] { [] }
}

// MARK: - Persistence Error (Core Data)

/// Errors from Core Data persistence operations
public enum PersistenceError: TypedError {
    // Context errors
    case contextNotFound
    case saveFailed(reason: String)
    case fetchFailed(entity: String, reason: String)

    // Entity errors
    case entityNotFound(entity: String, id: String)
    case duplicateEntity(entity: String, id: String)
    case invalidEntity(entity: String, reason: String)

    // Relationship errors
    case relationshipNotFound(entity: String, relationship: String)
    case orphanedEntity(entity: String, id: String)

    // Migration errors
    case migrationFailed(from: String, to: String, reason: String)
    case incompatibleModel(reason: String)

    // Storage errors
    case storeNotFound
    case storeCorrupted(reason: String)
    case storeFull

    // Sync errors
    case syncConflict(entity: String, localVersion: Int, remoteVersion: Int)
    case mergeConflict(entity: String, reason: String)

    // Generic
    case underlying(Error & Sendable)
    case unknown(reason: String)

    public var code: String {
        switch self {
        case .contextNotFound: "PERS_CONTEXT_NOT_FOUND"
        case .saveFailed: "PERS_SAVE_FAILED"
        case .fetchFailed: "PERS_FETCH_FAILED"
        case .entityNotFound: "PERS_ENTITY_NOT_FOUND"
        case .duplicateEntity: "PERS_DUPLICATE"
        case .invalidEntity: "PERS_INVALID_ENTITY"
        case .relationshipNotFound: "PERS_REL_NOT_FOUND"
        case .orphanedEntity: "PERS_ORPHANED"
        case .migrationFailed: "PERS_MIGRATION_FAILED"
        case .incompatibleModel: "PERS_INCOMPATIBLE"
        case .storeNotFound: "PERS_STORE_NOT_FOUND"
        case .storeCorrupted: "PERS_STORE_CORRUPTED"
        case .storeFull: "PERS_STORE_FULL"
        case .syncConflict: "PERS_SYNC_CONFLICT"
        case .mergeConflict: "PERS_MERGE_CONFLICT"
        case .underlying: "PERS_UNDERLYING"
        case .unknown: "PERS_UNKNOWN"
        }
    }

    public var errorDescription: String? {
        switch self {
        case .contextNotFound:
            "Core Data context not found"
        case let .saveFailed(reason):
            "Save failed: \(reason)"
        case let .fetchFailed(entity, reason):
            "Failed to fetch \(entity): \(reason)"
        case let .entityNotFound(entity, id):
            "\(entity) with ID '\(id)' not found"
        case let .duplicateEntity(entity, id):
            "Duplicate \(entity) with ID '\(id)'"
        case let .invalidEntity(entity, reason):
            "Invalid \(entity): \(reason)"
        case let .relationshipNotFound(entity, relationship):
            "Relationship '\(relationship)' not found on \(entity)"
        case let .orphanedEntity(entity, id):
            "Orphaned \(entity) with ID '\(id)'"
        case let .migrationFailed(from, to, reason):
            "Migration from \(from) to \(to) failed: \(reason)"
        case let .incompatibleModel(reason):
            "Incompatible model: \(reason)"
        case .storeNotFound:
            "Persistent store not found"
        case let .storeCorrupted(reason):
            "Store corrupted: \(reason)"
        case .storeFull:
            "Storage is full"
        case let .syncConflict(entity, localVersion, remoteVersion):
            "Sync conflict for \(entity): local v\(localVersion) vs remote v\(remoteVersion)"
        case let .mergeConflict(entity, reason):
            "Merge conflict for \(entity): \(reason)"
        case let .underlying(error):
            "Underlying error: \(error.localizedDescription)"
        case let .unknown(reason):
            "Unknown error: \(reason)"
        }
    }

    public var userFriendlyMessage: String {
        switch self {
        case .contextNotFound, .storeNotFound:
            "Unable to access local storage. Please restart the app."
        case .saveFailed:
            "Unable to save your changes. Please try again."
        case .fetchFailed:
            "Unable to load your data. Please try again."
        case .entityNotFound:
            "The item you're looking for no longer exists."
        case .duplicateEntity, .invalidEntity:
            "There was a problem with your data. Please try again."
        case .relationshipNotFound, .orphanedEntity:
            "Data integrity issue detected. Please sync your data."
        case .migrationFailed, .incompatibleModel:
            "App update required. Please update to the latest version."
        case .storeCorrupted:
            "Local storage is corrupted. Your data will be re-synced."
        case .storeFull:
            "Your device is running low on storage."
        case .syncConflict, .mergeConflict:
            "There's a sync conflict. Please refresh to see the latest data."
        case .underlying, .unknown:
            "An unexpected error occurred. Please try again."
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .saveFailed, .fetchFailed, .syncConflict, .mergeConflict:
            true
        default:
            false
        }
    }

    public var tags: [ErrorTag] {
        [.persistence]
    }

    // MARK: - Conversion

    public func toRepositoryError() -> RepositoryError {
        switch self {
        case .contextNotFound, .storeNotFound:
            .storageUnavailable
        case let .saveFailed(reason):
            .transactionFailed(reason: reason)
        case let .fetchFailed(entity, reason):
            .queryFailed(query: "fetch \(entity)", reason: reason)
        case let .entityNotFound(entity, id):
            .notFound(resource: entity, id: id)
        case let .duplicateEntity(entity, _):
            .constraintViolation(field: entity, reason: "Duplicate entity")
        case let .invalidEntity(entity, reason):
            .invalidData(reason: "\(entity): \(reason)")
        case .relationshipNotFound, .orphanedEntity:
            .invalidData(reason: userFriendlyMessage)
        case .migrationFailed, .incompatibleModel:
            .storageUnavailable
        case .storeCorrupted:
            .fileCorrupted(path: "persistent store")
        case .storeFull:
            .storageFull
        case .syncConflict, .mergeConflict:
            .transactionFailed(reason: userFriendlyMessage)
        case let .underlying(error):
            .underlying(error)
        case let .unknown(reason):
            .unknown(reason: reason)
        }
    }
}

// MARK: - Error Conversion Extensions

extension Error {
    /// Convert any error to RepositoryError
    public func toRepositoryError() -> RepositoryError {
        if let repoError = self as? RepositoryError {
            return repoError
        }
        if let networkError = self as? NetworkError {
            return .from(networkError)
        }
        if let databaseError = self as? DatabaseError {
            return .from(databaseError)
        }
        if let persistenceError = self as? PersistenceError {
            return persistenceError.toRepositoryError()
        }
        if let sendable = self as? (Error & Sendable) {
            return .underlying(sendable)
        }
        return .unknown(reason: localizedDescription)
    }

    /// Convert any error to UseCaseError
    public func toUseCaseError() -> UseCaseError {
        if let useCaseError = self as? UseCaseError {
            return useCaseError
        }
        if let repoError = self as? RepositoryError {
            return repoError.toUseCaseError()
        }
        return toRepositoryError().toUseCaseError()
    }

    /// Convert any error to ViewModelError
    public func toViewModelError() -> ViewModelError {
        if let vmError = self as? ViewModelError {
            return vmError
        }
        if let useCaseError = self as? UseCaseError {
            return useCaseError.toViewModelError()
        }
        return toUseCaseError().toViewModelError()
    }
}

// MARK: - RetryableError Conformance

extension RepositoryError: RetryableError {}
extension UseCaseError: RetryableError {}
extension ViewModelError: RetryableError {}
extension PersistenceError: RetryableError {}
#endif
