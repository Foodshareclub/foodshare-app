//
//  SupabaseActor.swift
//  Foodshare
//
//  Actor-based wrapper for Supabase operations to prevent concurrent mutations
//  Provides thread-safe access to Supabase client with proper isolation
//

import Foundation
import Supabase

/// Actor-isolated Supabase client wrapper for thread-safe database operations
/// Prevents race conditions and concurrent mutations to the same resources
actor SupabaseActor {
    // MARK: - Properties
    
    private let client: SupabaseClient
    
    // MARK: - Initialization
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    // MARK: - Database Operations
    
    /// Execute a database query with actor isolation
    func query<T: Decodable>(
        _ table: String,
        select: String = "*",
        filters: [(column: String, value: Any)] = []
    ) async throws -> [T] {
        var query = client.database.from(table).select(select)
        
        for filter in filters {
            query = query.eq(filter.column, value: filter.value)
        }
        
        let response: [T] = try await query.execute().value
        return response
    }
    
    /// Insert a record with actor isolation
    func insert<T: Encodable & Decodable>(
        _ table: String,
        value: T
    ) async throws -> T {
        let response: T = try await client.database
            .from(table)
            .insert(value)
            .select()
            .single()
            .execute()
            .value
        return response
    }
    
    /// Update a record with actor isolation
    func update<T: Encodable & Decodable>(
        _ table: String,
        id: String,
        value: T
    ) async throws -> T {
        let response: T = try await client.database
            .from(table)
            .update(value)
            .eq("id", value: id)
            .select()
            .single()
            .execute()
            .value
        return response
    }
    
    /// Delete a record with actor isolation
    func delete(
        _ table: String,
        id: String
    ) async throws {
        try await client.database
            .from(table)
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    // MARK: - Auth Operations
    
    /// Get current session with actor isolation
    func currentSession() async throws -> Session? {
        try await client.auth.session
    }
    
    /// Sign in with actor isolation
    func signIn(email: String, password: String) async throws -> Session {
        try await client.auth.signIn(email: email, password: password)
    }
    
    /// Sign out with actor isolation
    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    // MARK: - Storage Operations
    
    /// Upload file with actor isolation
    func upload(
        bucket: String,
        path: String,
        data: Data,
        options: FileOptions? = nil
    ) async throws -> String {
        try await client.storage
            .from(bucket)
            .upload(path: path, file: data, options: options ?? FileOptions())
    }
    
    /// Download file with actor isolation
    func download(
        bucket: String,
        path: String
    ) async throws -> Data {
        try await client.storage
            .from(bucket)
            .download(path: path)
    }
    
    /// Delete file with actor isolation
    func deleteFile(
        bucket: String,
        paths: [String]
    ) async throws {
        try await client.storage
            .from(bucket)
            .remove(paths: paths)
    }
    
    // MARK: - Realtime Operations
    
    /// Subscribe to realtime changes with actor isolation
    nonisolated func subscribe(
        to table: String,
        event: String = "*",
        callback: @escaping @Sendable (RealtimeMessage) -> Void
    ) -> RealtimeChannel {
        client.realtime.channel("public:\(table)")
            .on(event, callback: callback)
    }
}

// MARK: - Convenience Extensions

extension SupabaseActor {
    /// Execute a raw SQL query with actor isolation
    func rpc<T: Decodable>(
        _ function: String,
        params: [String: Any] = [:]
    ) async throws -> T {
        try await client.database
            .rpc(function, params: params)
            .execute()
            .value
    }
    
    /// Execute a raw SQL query returning array with actor isolation
    func rpcArray<T: Decodable>(
        _ function: String,
        params: [String: Any] = [:]
    ) async throws -> [T] {
        try await client.database
            .rpc(function, params: params)
            .execute()
            .value
    }
}
