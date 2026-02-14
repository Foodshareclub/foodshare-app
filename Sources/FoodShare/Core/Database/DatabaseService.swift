import Foundation
import OSLog
import Supabase

/// Protocol defining database operations
protocol DatabaseService: Sendable {
    /// Execute a query and return results
    func query<T: Decodable & Sendable>(_ query: PostgrestQueryBuilder) async throws -> [T]

    /// Execute a query and return a single result
    func querySingle<T: Decodable & Sendable>(_ query: PostgrestQueryBuilder) async throws -> T

    /// Insert a record
    func insert(_ table: String, values: some Encodable & Sendable) async throws

    /// Update a record
    func update(_ table: String, values: some Encodable & Sendable) async throws

    /// Delete a record
    func delete(_ table: String, id: UUID) async throws
}

// MARK: - Retry Configuration

/// Configuration for retry behavior with exponential backoff
struct RetryConfiguration: Sendable {
    let maxAttempts: Int
    let initialDelay: TimeInterval
    let maxDelay: TimeInterval
    let multiplier: Double
    let jitter: Bool

    static let `default` = RetryConfiguration(
        maxAttempts: 3,
        initialDelay: 0.5,
        maxDelay: 10.0,
        multiplier: 2.0,
        jitter: true,
    )

    static let aggressive = RetryConfiguration(
        maxAttempts: 5,
        initialDelay: 0.25,
        maxDelay: 30.0,
        multiplier: 2.0,
        jitter: true,
    )

    /// Calculate delay for a given attempt (0-indexed)
    func delay(for attempt: Int) -> TimeInterval {
        let exponentialDelay = initialDelay * pow(multiplier, Double(attempt))
        let cappedDelay = min(exponentialDelay, maxDelay)

        if jitter {
            // Add random jitter (±25%) to prevent thundering herd
            let jitterFactor = Double.random(in: 0.75 ... 1.25)
            return cappedDelay * jitterFactor
        }
        return cappedDelay
    }
}

/// Supabase implementation of DatabaseService with retry support
actor SupabaseDatabaseService: DatabaseService {
    private let client: SupabaseClient
    private let retryConfig: RetryConfiguration
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "DatabaseService")

    init(
        client: SupabaseClient,
        retryConfig: RetryConfiguration = .default,
    ) {
        self.client = client
        self.retryConfig = retryConfig
    }

    func query<T: Decodable & Sendable>(_ query: PostgrestQueryBuilder) async throws -> [T] {
        try await withRetry(operation: "query") {
            let response: [T] = try await query.execute().value
            return response
        }
    }

    func querySingle<T: Decodable & Sendable>(_ query: PostgrestQueryBuilder) async throws -> T {
        try await withRetry(operation: "querySingle") {
            let response: T = try await query.execute().value
            return response
        }
    }

    func insert(_ table: String, values: some Encodable & Sendable) async throws {
        try await withRetry(operation: "insert:\(table)") {
            try await client.from(table).insert(values).execute()
        }
    }

    func update(_ table: String, values: some Encodable & Sendable) async throws {
        try await withRetry(operation: "update:\(table)") {
            try await client.from(table).update(values).execute()
        }
    }

    func delete(_ table: String, id: UUID) async throws {
        try await withRetry(operation: "delete:\(table)") {
            try await client.from(table).delete().eq("id", value: id.uuidString).execute()
        }
    }

    // MARK: - Retry Logic

    /// Execute an operation with exponential backoff retry
    private func withRetry<T>(
        operation: String,
        _ work: @Sendable () async throws -> T,
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0 ..< retryConfig.maxAttempts {
            do {
                return try await work()
            } catch {
                lastError = error

                // Check if error is retryable
                guard isRetryableError(error) else {
                    logger.warning("Non-retryable error in \(operation): \(error.localizedDescription)")
                    throw mapSupabaseError(error)
                }

                // Don't delay on the last attempt
                if attempt < retryConfig.maxAttempts - 1 {
                    let delay = retryConfig.delay(for: attempt)
                    logger
                        .info(
                            "Retry \(attempt + 1)/\(self.retryConfig.maxAttempts) for \(operation) after \(delay, format: .fixed(precision: 2))s",
                        )
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        logger.error("All \(self.retryConfig.maxAttempts) attempts failed for \(operation)")
        guard let error = lastError else {
            throw DatabaseError.unknown(NSError(domain: "DatabaseService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "All retry attempts failed with no captured error"
            ]))
        }
        throw mapSupabaseError(error)
    }

    /// Determine if an error is retryable (transient)
    private func isRetryableError(_ error: Error) -> Bool {
        // Network errors are typically retryable
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .dnsLookupFailed,
                 .notConnectedToInternet,
                 .secureConnectionFailed:
                return true
            default:
                return false
            }
        }

        // Supabase/Postgrest errors - retry on server errors (5xx)
        if let postgrestError = error as? PostgrestError {
            // Check if it's a server error (500-599)
            let errorMessage = postgrestError.localizedDescription.lowercased()
            if errorMessage.contains("500") ||
                errorMessage.contains("502") ||
                errorMessage.contains("503") ||
                errorMessage.contains("504") ||
                errorMessage.contains("timeout") ||
                errorMessage.contains("connection") {
                return true
            }
        }

        return false
    }

    // MARK: - Error Mapping

    private func mapSupabaseError(_ error: Error) -> DatabaseError {
        // Network connectivity errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return .connectionFailed("No internet connection")
            case .timedOut:
                return .connectionFailed("Request timed out")
            case .cannotConnectToHost:
                return .connectionFailed("Cannot connect to server")
            default:
                return .connectionFailed(urlError.localizedDescription)
            }
        }

        // Supabase/Postgrest errors
        if let postgrestError = error as? PostgrestError {
            return .queryFailed(postgrestError.localizedDescription)
        }

        return .unknown(error)
    }
}

// MARK: - Convenience Retry Function

/// Standalone retry function for use outside DatabaseService
func withRetry<T>(
    maxAttempts: Int = 3,
    initialDelay: TimeInterval = 0.5,
    maxDelay: TimeInterval = 10.0,
    operation: @escaping @Sendable () async throws -> T,
) async throws -> T {
    let config = RetryConfiguration(
        maxAttempts: maxAttempts,
        initialDelay: initialDelay,
        maxDelay: maxDelay,
        multiplier: 2.0,
        jitter: true,
    )

    var lastError: Error?

    for attempt in 0 ..< config.maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error

            // Don't delay on the last attempt
            if attempt < config.maxAttempts - 1 {
                let delay = config.delay(for: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    guard let error = lastError else {
        throw DatabaseError.unknown(NSError(domain: "DatabaseService", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "All retry attempts failed with no captured error"
        ]))
    }
    throw error
}
