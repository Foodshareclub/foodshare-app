//
//  SyncableEntities.swift
//  Foodshare
//
//  Syncable protocol implementations for domain models.
//  Enables conflict resolution between local cache and remote server.
//

import Foundation

// MARK: - Syncable Listing

/// Lightweight struct for listing sync operations
/// Contains only the fields needed for conflict detection and resolution
public struct SyncableListing: Syncable, Codable, Equatable {
    public let id: Int64
    public let name: String
    public let descriptionText: String?
    public let address: String?
    public let latitude: Double
    public let longitude: Double
    public let images: [String]
    public let category: String?
    public let profileId: UUID?
    public let isArranged: Bool
    public let createdAt: Date
    public let updatedAt: Date
    public let version: Int

    // MARK: - Syncable Protocol

    public var syncId: String { String(id) }
    public static var entityType: String { "Listing" }
    public var lastModifiedAt: Date { updatedAt }
    public var syncVersion: Int { version }

    public func conflictingFields(with other: SyncableListing) -> [String] {
        var conflicts: [String] = []

        if name != other.name { conflicts.append("name") }
        if descriptionText != other.descriptionText { conflicts.append("descriptionText") }
        if address != other.address { conflicts.append("address") }
        if abs(latitude - other.latitude) > 0.0001 { conflicts.append("latitude") }
        if abs(longitude - other.longitude) > 0.0001 { conflicts.append("longitude") }
        if images != other.images { conflicts.append("images") }
        if category != other.category { conflicts.append("category") }
        if isArranged != other.isArranged { conflicts.append("isArranged") }

        return conflicts
    }

    public func merge(
        with other: SyncableListing,
        preferring preference: ConflictWinner,
    ) -> (merged: SyncableListing, mergedFields: [String]) {
        let preferred = preference == .local ? self : other
        let secondary = preference == .local ? other : self

        var mergedFields: [String] = []

        // Merge strategy: use preferred for conflicting fields,
        // use most recent non-nil value for optional fields
        let mergedName = preferred.name
        if preferred.name != secondary.name { mergedFields.append("name") }

        let mergedDescription = preferred.descriptionText ?? secondary.descriptionText
        if preferred.descriptionText != secondary.descriptionText { mergedFields.append("descriptionText") }

        let mergedAddress = preferred.address ?? secondary.address
        if preferred.address != secondary.address { mergedFields.append("address") }

        let mergedCategory = preferred.category ?? secondary.category
        if preferred.category != secondary.category { mergedFields.append("category") }

        // Use newer images array
        let mergedImages = preferred.updatedAt > secondary.updatedAt ? preferred.images : secondary.images
        if preferred.images != secondary.images { mergedFields.append("images") }

        // isArranged - prefer true (more restrictive state)
        let mergedIsArranged = preferred.isArranged || secondary.isArranged
        if preferred.isArranged != secondary.isArranged { mergedFields.append("isArranged") }

        let merged = SyncableListing(
            id: id,
            name: mergedName,
            descriptionText: mergedDescription,
            address: mergedAddress,
            latitude: preferred.latitude,
            longitude: preferred.longitude,
            images: mergedImages,
            category: mergedCategory,
            profileId: profileId,
            isArranged: mergedIsArranged,
            createdAt: createdAt,
            updatedAt: max(preferred.updatedAt, secondary.updatedAt),
            version: max(preferred.version, secondary.version) + 1,
        )

        return (merged, mergedFields)
    }

    // MARK: - Factory Methods

    /// Create from CachedListing
    public static func from(_ cached: CachedListing) -> SyncableListing {
        SyncableListing(
            id: cached.id,
            name: cached.name,
            descriptionText: cached.descriptionText,
            address: cached.address,
            latitude: cached.latitude,
            longitude: cached.longitude,
            images: cached.images,
            category: cached.category,
            profileId: cached.profileId,
            isArranged: cached.isArranged,
            createdAt: cached.createdAt,
            updatedAt: cached.updatedAt,
            version: Int(cached.syncVersion),
        )
    }
}

// MARK: - Syncable Forum Post

/// Lightweight struct for forum post sync operations
public struct SyncableForumPost: Syncable, Codable, Equatable {
    public let id: Int64
    public let profileId: UUID
    public let title: String?
    public let descriptionText: String?
    public let imageUrl: String?
    public let categoryId: Int64
    public let postType: String
    public let commentsCount: Int64
    public let likesCount: Int64
    public let viewsCount: Int64
    public let isPinned: Bool
    public let createdAt: Date
    public let updatedAt: Date
    public let version: Int

    // MARK: - Syncable Protocol

    public var syncId: String { String(id) }
    public static var entityType: String { "ForumPost" }
    public var lastModifiedAt: Date { updatedAt }
    public var syncVersion: Int { version }

    public func conflictingFields(with other: SyncableForumPost) -> [String] {
        var conflicts: [String] = []

        if title != other.title { conflicts.append("title") }
        if descriptionText != other.descriptionText { conflicts.append("descriptionText") }
        if imageUrl != other.imageUrl { conflicts.append("imageUrl") }
        if categoryId != other.categoryId { conflicts.append("categoryId") }
        if postType != other.postType { conflicts.append("postType") }
        if isPinned != other.isPinned { conflicts.append("isPinned") }
        // Counters are typically server-authoritative, so we don't consider them conflicts
        // unless explicitly needed

        return conflicts
    }

    public func merge(
        with other: SyncableForumPost,
        preferring preference: ConflictWinner,
    ) -> (merged: SyncableForumPost, mergedFields: [String]) {
        let preferred = preference == .local ? self : other
        let secondary = preference == .local ? other : self

        var mergedFields: [String] = []

        let mergedTitle = preferred.title ?? secondary.title
        if preferred.title != secondary.title { mergedFields.append("title") }

        let mergedDescription = preferred.descriptionText ?? secondary.descriptionText
        if preferred.descriptionText != secondary.descriptionText { mergedFields.append("descriptionText") }

        let mergedImageUrl = preferred.imageUrl ?? secondary.imageUrl
        if preferred.imageUrl != secondary.imageUrl { mergedFields.append("imageUrl") }

        // Use server's counters (they're authoritative)
        let mergedCommentsCount = max(preferred.commentsCount, secondary.commentsCount)
        let mergedLikesCount = max(preferred.likesCount, secondary.likesCount)
        let mergedViewsCount = max(preferred.viewsCount, secondary.viewsCount)

        // isPinned - prefer true (admin action)
        let mergedIsPinned = preferred.isPinned || secondary.isPinned
        if preferred.isPinned != secondary.isPinned { mergedFields.append("isPinned") }

        let merged = SyncableForumPost(
            id: id,
            profileId: profileId,
            title: mergedTitle,
            descriptionText: mergedDescription,
            imageUrl: mergedImageUrl,
            categoryId: preferred.categoryId,
            postType: preferred.postType,
            commentsCount: mergedCommentsCount,
            likesCount: mergedLikesCount,
            viewsCount: mergedViewsCount,
            isPinned: mergedIsPinned,
            createdAt: createdAt,
            updatedAt: max(preferred.updatedAt, secondary.updatedAt),
            version: max(preferred.version, secondary.version) + 1,
        )

        return (merged, mergedFields)
    }

    // MARK: - Factory Methods

    /// Create from CachedForumPost
    public static func from(_ cached: CachedForumPost) -> SyncableForumPost {
        SyncableForumPost(
            id: cached.id,
            profileId: cached.profileId,
            title: cached.title,
            descriptionText: cached.descriptionText,
            imageUrl: cached.imageUrl,
            categoryId: cached.categoryId,
            postType: cached.postType,
            commentsCount: cached.commentsCount,
            likesCount: cached.likesCount,
            viewsCount: cached.viewsCount,
            isPinned: cached.isPinned,
            createdAt: cached.createdAt,
            updatedAt: cached.cachedAt, // Use cachedAt as proxy for updatedAt
            version: Int(cached.syncVersion),
        )
    }
}

// MARK: - Sync Statistics

/// Statistics about a sync operation
public struct SyncStatistics: Sendable {
    public let entityType: String
    public let totalProcessed: Int
    public let created: Int
    public let updated: Int
    public let conflictsDetected: Int
    public let conflictsResolved: Int
    public let errors: Int
    public let duration: TimeInterval
    public let startedAt: Date
    public let completedAt: Date

    public init(
        entityType: String,
        totalProcessed: Int,
        created: Int,
        updated: Int,
        conflictsDetected: Int,
        conflictsResolved: Int,
        errors: Int,
        duration: TimeInterval,
        startedAt: Date = Date(),
        completedAt: Date = Date(),
    ) {
        self.entityType = entityType
        self.totalProcessed = totalProcessed
        self.created = created
        self.updated = updated
        self.conflictsDetected = conflictsDetected
        self.conflictsResolved = conflictsResolved
        self.errors = errors
        self.duration = duration
        self.startedAt = startedAt
        self.completedAt = completedAt
    }

    /// Convenience initializer for empty statistics
    public static func empty(entityType: String) -> SyncStatistics {
        SyncStatistics(
            entityType: entityType,
            totalProcessed: 0,
            created: 0,
            updated: 0,
            conflictsDetected: 0,
            conflictsResolved: 0,
            errors: 0,
            duration: 0,
        )
    }
}

// MARK: - Sync Result

/// Result of a sync operation
public enum SyncResult<T: Sendable>: Sendable {
    case success(T, SyncStatistics)
    case partialSuccess(T, SyncStatistics, [Error])
    case failure(Error)

    public var isSuccess: Bool {
        switch self {
        case .success, .partialSuccess: true
        case .failure: false
        }
    }

    public var statistics: SyncStatistics? {
        switch self {
        case let .success(_, stats), let .partialSuccess(_, stats, _):
            stats
        case .failure:
            nil
        }
    }
}
