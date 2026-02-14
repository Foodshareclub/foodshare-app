import Foundation
import Supabase

/// Protocol for file storage operations
protocol StorageService: Sendable {
    /// Upload a file to storage
    func upload(
        bucket: String,
        path: String,
        file: Data,
        contentType: String,
    ) async throws -> URL

    /// Download a file from storage
    func download(bucket: String, path: String) async throws -> Data

    /// Delete a file from storage
    func delete(bucket: String, path: String) async throws

    /// Get public URL for a file
    func getPublicURL(bucket: String, path: String) throws -> URL

    /// List files in a bucket
    func list(bucket: String, path: String?) async throws -> [FileObject]
}

/// File object metadata
struct FileObject: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let createdAt: Date
    let updatedAt: Date
    let lastAccessedAt: Date?
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastAccessedAt = "last_accessed_at"
        case metadata
    }
}

/// Supabase implementation of StorageService
final class SupabaseStorageService: StorageService, @unchecked Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func upload(
        bucket: String,
        path: String,
        file: Data,
        contentType: String,
    ) async throws -> URL {
        do {
            _ = try await client.storage
                .from(bucket)
                .upload(path, data: file, options: FileOptions(contentType: contentType))

            return try getPublicURL(bucket: bucket, path: path)
        } catch {
            throw DatabaseError.unknown(error)
        }
    }

    func download(bucket: String, path: String) async throws -> Data {
        do {
            return try await client.storage
                .from(bucket)
                .download(path: path)
        } catch {
            throw DatabaseError.unknown(error)
        }
    }

    func delete(bucket: String, path: String) async throws {
        do {
            _ = try await client.storage
                .from(bucket)
                .remove(paths: [path])
        } catch {
            throw DatabaseError.deleteFailed
        }
    }

    func getPublicURL(bucket: String, path: String) throws -> URL {
        try client.storage
            .from(bucket)
            .getPublicURL(path: path)
    }

    func list(bucket: String, path: String?) async throws -> [FileObject] {
        do {
            let files = try await client.storage
                .from(bucket)
                .list(path: path)

            return files.map { file in
                FileObject(
                    id: file.id?.uuidString ?? UUID().uuidString,
                    name: file.name,
                    createdAt: file.createdAt ?? Date(),
                    updatedAt: file.updatedAt ?? Date(),
                    lastAccessedAt: file.lastAccessedAt,
                    metadata: file.metadata as? [String: String],
                )
            }
        } catch {
            throw DatabaseError.queryFailed("Failed to list files")
        }
    }
}
