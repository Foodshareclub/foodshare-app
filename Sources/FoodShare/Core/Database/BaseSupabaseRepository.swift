//
//  BaseSupabaseRepository.swift
//  FoodShare
//
//  Base repository providing common Supabase operations.
//  Eliminates duplication across 14+ repository implementations.
//  iOS: Uses supabase-swift with OSLog and PostgrestError mapping
//  Android: Uses supabase-kt with print logging
//


#if !SKIP
import Foundation
import OSLog
import Supabase

/// Base repository providing common Supabase operations
@MainActor
open class BaseSupabaseRepository: @unchecked Sendable {
    // MARK: - Properties

    public let supabase: SupabaseClient
    public let decoder: JSONDecoder
    public let encoder: JSONEncoder
    public let logger: Logger

    // MARK: - Initialization

    public init(
        supabase: SupabaseClient,
        subsystem: String = "com.flutterflow.foodshare",
        category: String
    ) {
        self.supabase = supabase
        self.logger = Logger(subsystem: subsystem, category: category)

        // Configure decoder
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        // Configure encoder
        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    // MARK: - Common Operations

    /// Execute RPC with automatic error mapping
    @inline(__always)
    public func executeRPC<T: Decodable>(
        _ function: String,
        params: some Encodable & Sendable
    ) async throws -> T {
        do {
            let response = try await supabase
                .rpc(function, params: params)
                .execute()
            return try decoder.decode(T.self, from: response.data)
        } catch {
            throw mapError(error)
        }
    }

    /// Execute RPC without return value
    @inline(__always)
    public func executeRPC(
        _ function: String,
        params: some Encodable & Sendable
    ) async throws {
        do {
            _ = try await supabase
                .rpc(function, params: params)
                .execute()
        } catch {
            throw mapError(error)
        }
    }

    /// Fetch single record
    @inline(__always)
    public func fetchOne<T: Decodable>(
        from table: String,
        select: String = "*",
        id: Int
    ) async throws -> T {
        do {
            let response = try await supabase
                .from(table)
                .select(select)
                .eq("id", value: id)
                .single()
                .execute()
            return try decoder.decode(T.self, from: response.data)
        } catch {
            throw mapError(error)
        }
    }

    /// Fetch multiple records with simple filters
    @inline(__always)
    public func fetchMany<T: Decodable>(
        from table: String,
        select: String = "*",
        orderBy: String? = nil,
        ascending: Bool = true,
        limit: Int? = nil
    ) async throws -> [T] {
        do {
            var query: PostgrestTransformBuilder = supabase.from(table).select(select)

            if let orderBy {
                query = query.order(orderBy, ascending: ascending)
            }

            if let limit {
                query = query.limit(limit)
            }

            let response = try await query.execute()
            return try decoder.decode([T].self, from: response.data)
        } catch {
            throw mapError(error)
        }
    }

    /// Insert record
    @inline(__always)
    public func insert<T: Encodable & Decodable>(
        into table: String,
        value: T
    ) async throws -> T {
        do {
            let response = try await supabase
                .from(table)
                .insert(value)
                .select()
                .single()
                .execute()
            return try decoder.decode(T.self, from: response.data)
        } catch {
            throw mapError(error)
        }
    }

    /// Update record
    @inline(__always)
    public func update<T: Encodable & Decodable>(
        table: String,
        id: Int,
        value: T
    ) async throws -> T {
        do {
            let response = try await supabase
                .from(table)
                .update(value)
                .eq("id", value: id)
                .select()
                .single()
                .execute()
            return try decoder.decode(T.self, from: response.data)
        } catch {
            throw mapError(error)
        }
    }

    /// Delete record
    @inline(__always)
    public func delete(
        from table: String,
        id: Int
    ) async throws {
        do {
            _ = try await supabase
                .from(table)
                .delete()
                .eq("id", value: id)
                .execute()
        } catch {
            throw mapError(error)
        }
    }

    /// Execute transactional RPC with result validation
    @inline(__always)
    public func executeTransactionalRPC<T: Decodable & TransactionalResult>(
        _ function: String,
        params: some Encodable & Sendable
    ) async throws -> T {
        let result: T = try await executeRPC(function, params: params)

        guard result.success else {
            if let error = result.error {
                logger.error("\(function) failed: \(error.message)")
                throw mapTransactionalError(error)
            }
            throw AppError.databaseError("Operation failed")
        }

        return result
    }

    // MARK: - Error Mapping

    /// Unified error mapping for all repositories
    public func mapError(_ error: Error) -> Error {
        if let postgrestError = error as? PostgrestError {
            switch postgrestError.code {
            case "PGRST116":
                return AppError.notFound(resource: "Resource")
            case "42501":
                return AppError.unauthorized(action: "access this resource")
            case "23505":
                return AppError.databaseError("Duplicate entry")
            case "23503":
                return AppError.validationError("Referenced resource does not exist")
            default:
                return AppError.networkError("Server error: \(postgrestError.code ?? "unknown")")
            }
        }

        return error
    }

    /// Map transactional error from RPC
    public func mapTransactionalError(_ error: RPCTransactionalError) -> Error {
        switch error.code {
        case "VALIDATION_ERROR":
            return AppError.validationError(error.message)
        case "RESOURCE_NOT_FOUND":
            return AppError.notFound(resource: error.message)
        case "AUTH_FORBIDDEN":
            return AppError.unauthorized(action: error.message)
        case "DUPLICATE_ENTRY":
            return AppError.databaseError("Duplicate entry: \(error.message)")
        default:
            return AppError.databaseError(error.message)
        }
    }
}

#else

import Foundation

/// Base repository providing common Supabase operations (Android/Skip)
/// Subclasses implement actual supabase-kt operations directly.
/// This base provides error mapping shared across all repositories.
open class BaseSupabaseRepository {
    // MARK: - Properties

    public let log: AppLog

    // MARK: - Initialization

    public init(category: String) {
        self.log = AppLog(category: category)
    }

    // MARK: - Error Mapping

    /// Unified error mapping for all repositories
    public func mapError(_ error: Error) -> Error {
        let message = error.localizedDescription.lowercased()
        if message.contains("not found") || message.contains("pgrst116") {
            return AppError.notFound(resource: "Resource")
        }
        if message.contains("permission denied") || message.contains("42501") {
            return AppError.unauthorized(action: "access this resource")
        }
        if message.contains("duplicate") || message.contains("23505") {
            return AppError.databaseError("Duplicate entry")
        }
        return error
    }

    /// Map transactional error from RPC
    public func mapTransactionalError(_ error: RPCTransactionalError) -> Error {
        switch error.code {
        case "VALIDATION_ERROR":
            return AppError.validationError(error.message)
        case "RESOURCE_NOT_FOUND":
            return AppError.notFound(resource: error.message)
        case "AUTH_FORBIDDEN":
            return AppError.unauthorized(action: error.message)
        case "DUPLICATE_ENTRY":
            return AppError.databaseError("Duplicate entry: \(error.message)")
        default:
            return AppError.databaseError(error.message)
        }
    }
}

#endif

// MARK: - Shared Types (both platforms)

/// Protocol for transactional RPC results
public protocol TransactionalResult: Decodable {
    var success: Bool { get }
    var error: RPCTransactionalError? { get }
}

/// Standard error structure from transactional RPCs
public struct RPCTransactionalError: Decodable, Sendable {
    public let code: String
    public let message: String
    public let details: [String: String]?

    public init(code: String, message: String, details: [String: String]? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }
}

/// Empty parameters for RPCs that don't need params
public struct EmptyParams: Encodable, Sendable {
    public init() {}
}

/// Empty response for RPCs that don't return data
public struct EmptyResponse: Decodable, Sendable {}
