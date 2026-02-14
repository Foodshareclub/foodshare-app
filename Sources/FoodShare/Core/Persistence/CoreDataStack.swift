//
//  CoreDataStack.swift
//  Foodshare
//
//  Core Data stack for offline caching
//

#if !SKIP
import CoreData
#endif
import Foundation
import OSLog

// MARK: - Core Data Stack

@MainActor
final class CoreDataStack {
    static let shared = CoreDataStack()

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "CoreData")

    /// Tracks whether the persistent store loaded successfully
    private(set) var isStoreHealthy = false

    /// Error encountered during store initialization (if any)
    private(set) var storeError: Error?

    /// Continuation for waiting on store initialization
    private var storeLoadContinuation: CheckedContinuation<Void, Never>?

    // MARK: - Persistent Container

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "FoodshareCache", managedObjectModel: Self.managedObjectModel)

        guard let storeDescription = container.persistentStoreDescriptions.first else {
            logger.critical("No persistent store description found — Core Data will not function")
            assertionFailure("No persistent store description found")
            self.isStoreHealthy = false
            self.storeError = NSError(
                domain: "CoreDataStack",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No persistent store description found"]
            )
            return container
        }

        // MARK: Security - Enable file protection for data at rest
        // This ensures the database is encrypted when the device is locked
        storeDescription.setOption(
            FileProtectionType.complete as NSObject,
            forKey: NSPersistentStoreFileProtectionKey,
        )

        // Configure for background access with history tracking
        storeDescription.setOption(
            true as NSNumber,
            forKey: NSPersistentHistoryTrackingKey,
        )

        // Enable lightweight migration for schema changes
        storeDescription.setOption(
            true as NSNumber,
            forKey: NSMigratePersistentStoresAutomaticallyOption,
        )
        storeDescription.setOption(
            true as NSNumber,
            forKey: NSInferMappingModelAutomaticallyOption,
        )

        loadStore(container: container, retryOnCorruption: true)

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)

        return container
    }()

    /// Wait for the store to be ready before performing operations
    /// Call this early in the app lifecycle to ensure store is loaded
    func waitForStoreReady() async {
        // If already healthy, return immediately
        if isStoreHealthy { return }

        // If there's already an error, don't wait
        if storeError != nil { return }

        // Wait for store to load (with timeout)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // Check again in case it became ready while setting up continuation
            if self.isStoreHealthy || self.storeError != nil {
                continuation.resume()
                return
            }

            self.storeLoadContinuation = continuation

            // Timeout after 5 seconds to prevent indefinite waiting
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(5))
                if let cont = self?.storeLoadContinuation {
                    self?.storeLoadContinuation = nil
                    self?.logger.warning("⚠️ [CoreData] Store load timed out after 5 seconds")
                    cont.resume()
                }
            }
        }
    }

    /// Load the persistent store with optional corruption recovery
    private func loadStore(container: NSPersistentContainer, retryOnCorruption: Bool) {
        container.loadPersistentStores { [weak self] description, error in
            guard let self else { return }

            let storeURL = description.url

            if let error {
                Task { @MainActor in
                    self.logger.error("❌ [CoreData] Failed to load store: \(error.localizedDescription)")

                    // Check if this is a corruption error and we should retry
                    if retryOnCorruption, let storeURL {
                        self.logger.warning("⚠️ [CoreData] Attempting to recover from corrupted database...")
                        self.recoverFromCorruption(container: container, storeURL: storeURL)
                    } else {
                        self.storeError = error
                        self.isStoreHealthy = false
                    }
                }
            } else {
                Task { @MainActor in
                    self.logger.info("✅ [CoreData] Store loaded: \(storeURL?.absoluteString ?? "unknown")")
                    self.isStoreHealthy = true
                    self.storeError = nil

                    // Resume any waiting continuation
                    if let continuation = self.storeLoadContinuation {
                        self.storeLoadContinuation = nil
                        continuation.resume()
                    }
                }
            }
        }
    }

    /// Recover from database corruption by deleting and recreating the store
    private func recoverFromCorruption(container: NSPersistentContainer, storeURL: URL) {
        do {
            // Remove the corrupted store files
            let fileManager = FileManager.default
            let storeDirectory = storeURL.deletingLastPathComponent()
            let storeName = storeURL.deletingPathExtension().lastPathComponent

            // Delete all related SQLite files
            let filesToDelete = [
                storeURL,
                storeDirectory.appendingPathComponent("\(storeName).sqlite-shm"),
                storeDirectory.appendingPathComponent("\(storeName).sqlite-wal")
            ]

            for fileURL in filesToDelete {
                if fileManager.fileExists(atPath: fileURL.path) {
                    try fileManager.removeItem(at: fileURL)
                    logger.info("🗑️ [CoreData] Deleted corrupted file: \(fileURL.lastPathComponent)")
                }
            }

            // Retry loading the store (this will create a fresh database)
            loadStore(container: container, retryOnCorruption: false)

            logger.info("✅ [CoreData] Database recovered - created fresh store")

        } catch {
            logger.error("❌ [CoreData] Failed to recover from corruption: \(error.localizedDescription)")
            storeError = error
            isStoreHealthy = false
        }
    }

    /// Check if the store is ready for operations, log warning if not
    private func guardStoreHealth(operation: String) -> Bool {
        guard isStoreHealthy else {
            logger.warning("⚠️ [CoreData] Skipping \(operation) - store not healthy")
            return false
        }
        return true
    }

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    // MARK: - Background Context

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        return context
    }

    // MARK: - Save

    func save() {
        let context = viewContext
        guard context.hasChanges else { return }

        do {
            try context.save()
            logger.debug("✅ [CoreData] Context saved successfully")
        } catch {
            logger.error("❌ [CoreData] Failed to save context: \(error.localizedDescription)")
        }
    }

    func saveBackground(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }

        context.perform {
            do {
                try context.save()
            } catch {
                Task { @MainActor in
                    self.logger.error("❌ [CoreData] Failed to save background context: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Programmatic Model Definition

    static let managedObjectModel: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        // MARK: CachedListing Entity
        let listingEntity = NSEntityDescription()
        listingEntity.name = "CachedListing"
        listingEntity.managedObjectClassName = "CachedListing"

        let listingIdAttr = NSAttributeDescription()
        listingIdAttr.name = "id"
        listingIdAttr.attributeType = .integer64AttributeType

        let listingNameAttr = NSAttributeDescription()
        listingNameAttr.name = "name"
        listingNameAttr.attributeType = .stringAttributeType

        let listingDescAttr = NSAttributeDescription()
        listingDescAttr.name = "descriptionText"
        listingDescAttr.attributeType = .stringAttributeType
        listingDescAttr.isOptional = true

        let listingAddressAttr = NSAttributeDescription()
        listingAddressAttr.name = "address"
        listingAddressAttr.attributeType = .stringAttributeType
        listingAddressAttr.isOptional = true

        let listingLatAttr = NSAttributeDescription()
        listingLatAttr.name = "latitude"
        listingLatAttr.attributeType = .doubleAttributeType
        listingLatAttr.isOptional = true

        let listingLngAttr = NSAttributeDescription()
        listingLngAttr.name = "longitude"
        listingLngAttr.attributeType = .doubleAttributeType
        listingLngAttr.isOptional = true

        let listingImagesAttr = NSAttributeDescription()
        listingImagesAttr.name = "imagesData"
        listingImagesAttr.attributeType = .binaryDataAttributeType
        listingImagesAttr.isOptional = true

        let listingCategoryAttr = NSAttributeDescription()
        listingCategoryAttr.name = "category"
        listingCategoryAttr.attributeType = .stringAttributeType
        listingCategoryAttr.isOptional = true

        let listingProfileIdAttr = NSAttributeDescription()
        listingProfileIdAttr.name = "profileId"
        listingProfileIdAttr.attributeType = .UUIDAttributeType

        let listingIsArrangedAttr = NSAttributeDescription()
        listingIsArrangedAttr.name = "isArranged"
        listingIsArrangedAttr.attributeType = .booleanAttributeType
        listingIsArrangedAttr.defaultValue = false

        let listingCreatedAttr = NSAttributeDescription()
        listingCreatedAttr.name = "createdAt"
        listingCreatedAttr.attributeType = .dateAttributeType

        let listingUpdatedAttr = NSAttributeDescription()
        listingUpdatedAttr.name = "updatedAt"
        listingUpdatedAttr.attributeType = .dateAttributeType

        let listingCachedAtAttr = NSAttributeDescription()
        listingCachedAtAttr.name = "cachedAt"
        listingCachedAtAttr.attributeType = .dateAttributeType

        // MARK: Sync Support Attributes for Conflict Resolution
        let listingSyncVersionAttr = NSAttributeDescription()
        listingSyncVersionAttr.name = "syncVersion"
        listingSyncVersionAttr.attributeType = .integer64AttributeType
        listingSyncVersionAttr.defaultValue = 0

        let listingLocallyModifiedAttr = NSAttributeDescription()
        listingLocallyModifiedAttr.name = "locallyModified"
        listingLocallyModifiedAttr.attributeType = .booleanAttributeType
        listingLocallyModifiedAttr.defaultValue = false

        let listingPendingSyncAttr = NSAttributeDescription()
        listingPendingSyncAttr.name = "pendingSync"
        listingPendingSyncAttr.attributeType = .booleanAttributeType
        listingPendingSyncAttr.defaultValue = false

        listingEntity.properties = [
            listingIdAttr, listingNameAttr, listingDescAttr, listingAddressAttr,
            listingLatAttr, listingLngAttr, listingImagesAttr, listingCategoryAttr,
            listingProfileIdAttr, listingIsArrangedAttr, listingCreatedAttr,
            listingUpdatedAttr, listingCachedAtAttr, listingSyncVersionAttr,
            listingLocallyModifiedAttr, listingPendingSyncAttr
        ]

        // MARK: CachedProfile Entity
        let profileEntity = NSEntityDescription()
        profileEntity.name = "CachedProfile"
        profileEntity.managedObjectClassName = "CachedProfile"

        let profileIdAttr = NSAttributeDescription()
        profileIdAttr.name = "id"
        profileIdAttr.attributeType = .UUIDAttributeType

        let profileNicknameAttr = NSAttributeDescription()
        profileNicknameAttr.name = "nickname"
        profileNicknameAttr.attributeType = .stringAttributeType
        profileNicknameAttr.isOptional = true

        let profileAvatarAttr = NSAttributeDescription()
        profileAvatarAttr.name = "avatarUrl"
        profileAvatarAttr.attributeType = .stringAttributeType
        profileAvatarAttr.isOptional = true

        let profileBioAttr = NSAttributeDescription()
        profileBioAttr.name = "bio"
        profileBioAttr.attributeType = .stringAttributeType
        profileBioAttr.isOptional = true

        let profileAboutMeAttr = NSAttributeDescription()
        profileAboutMeAttr.name = "aboutMe"
        profileAboutMeAttr.attributeType = .stringAttributeType
        profileAboutMeAttr.isOptional = true

        let profileRatingAvgAttr = NSAttributeDescription()
        profileRatingAvgAttr.name = "ratingAverage"
        profileRatingAvgAttr.attributeType = .doubleAttributeType
        profileRatingAvgAttr.defaultValue = 0.0

        let profileItemsSharedAttr = NSAttributeDescription()
        profileItemsSharedAttr.name = "itemsShared"
        profileItemsSharedAttr.attributeType = .integer64AttributeType
        profileItemsSharedAttr.defaultValue = 0

        let profileItemsReceivedAttr = NSAttributeDescription()
        profileItemsReceivedAttr.name = "itemsReceived"
        profileItemsReceivedAttr.attributeType = .integer64AttributeType
        profileItemsReceivedAttr.defaultValue = 0

        let profileRatingCountAttr = NSAttributeDescription()
        profileRatingCountAttr.name = "ratingCount"
        profileRatingCountAttr.attributeType = .integer64AttributeType
        profileRatingCountAttr.defaultValue = 0

        let profileCreatedTimeAttr = NSAttributeDescription()
        profileCreatedTimeAttr.name = "createdTime"
        profileCreatedTimeAttr.attributeType = .dateAttributeType
        profileCreatedTimeAttr.isOptional = true

        let profileVerifiedAttr = NSAttributeDescription()
        profileVerifiedAttr.name = "isVerified"
        profileVerifiedAttr.attributeType = .booleanAttributeType
        profileVerifiedAttr.defaultValue = false

        let profileCachedAtAttr = NSAttributeDescription()
        profileCachedAtAttr.name = "cachedAt"
        profileCachedAtAttr.attributeType = .dateAttributeType

        let profileSearchRadiusAttr = NSAttributeDescription()
        profileSearchRadiusAttr.name = "searchRadiusKm"
        profileSearchRadiusAttr.attributeType = .integer64AttributeType
        profileSearchRadiusAttr.defaultValue = 5

        let profilePreferredLocaleAttr = NSAttributeDescription()
        profilePreferredLocaleAttr.name = "preferredLocale"
        profilePreferredLocaleAttr.attributeType = .stringAttributeType
        profilePreferredLocaleAttr.isOptional = true

        profileEntity.properties = [
            profileIdAttr, profileNicknameAttr, profileAvatarAttr,
            profileBioAttr, profileAboutMeAttr, profileRatingAvgAttr,
            profileItemsSharedAttr, profileItemsReceivedAttr, profileRatingCountAttr,
            profileCreatedTimeAttr, profileVerifiedAttr, profileCachedAtAttr,
            profileSearchRadiusAttr, profilePreferredLocaleAttr
        ]

        // MARK: CachedMessage Entity
        let messageEntity = NSEntityDescription()
        messageEntity.name = "CachedMessage"
        messageEntity.managedObjectClassName = "CachedMessage"

        let messageIdAttr = NSAttributeDescription()
        messageIdAttr.name = "id"
        messageIdAttr.attributeType = .UUIDAttributeType

        let messageRoomIdAttr = NSAttributeDescription()
        messageRoomIdAttr.name = "roomId"
        messageRoomIdAttr.attributeType = .UUIDAttributeType

        let messageSenderIdAttr = NSAttributeDescription()
        messageSenderIdAttr.name = "senderId"
        messageSenderIdAttr.attributeType = .UUIDAttributeType

        let messageContentAttr = NSAttributeDescription()
        messageContentAttr.name = "content"
        messageContentAttr.attributeType = .stringAttributeType

        let messageCreatedAttr = NSAttributeDescription()
        messageCreatedAttr.name = "createdAt"
        messageCreatedAttr.attributeType = .dateAttributeType

        let messageCachedAtAttr = NSAttributeDescription()
        messageCachedAtAttr.name = "cachedAt"
        messageCachedAtAttr.attributeType = .dateAttributeType

        let messageIsSentAttr = NSAttributeDescription()
        messageIsSentAttr.name = "isSent"
        messageIsSentAttr.attributeType = .booleanAttributeType
        messageIsSentAttr.defaultValue = true

        messageEntity.properties = [
            messageIdAttr, messageRoomIdAttr, messageSenderIdAttr,
            messageContentAttr, messageCreatedAttr, messageCachedAtAttr, messageIsSentAttr
        ]

        // MARK: CachedForumPost Entity
        let forumPostEntity = NSEntityDescription()
        forumPostEntity.name = "CachedForumPost"
        forumPostEntity.managedObjectClassName = "CachedForumPost"

        let forumPostIdAttr = NSAttributeDescription()
        forumPostIdAttr.name = "id"
        forumPostIdAttr.attributeType = .integer64AttributeType

        let forumPostProfileIdAttr = NSAttributeDescription()
        forumPostProfileIdAttr.name = "profileId"
        forumPostProfileIdAttr.attributeType = .UUIDAttributeType

        let forumPostTitleAttr = NSAttributeDescription()
        forumPostTitleAttr.name = "title"
        forumPostTitleAttr.attributeType = .stringAttributeType
        forumPostTitleAttr.isOptional = true

        let forumPostDescAttr = NSAttributeDescription()
        forumPostDescAttr.name = "descriptionText"
        forumPostDescAttr.attributeType = .stringAttributeType
        forumPostDescAttr.isOptional = true

        let forumPostImageAttr = NSAttributeDescription()
        forumPostImageAttr.name = "imageUrl"
        forumPostImageAttr.attributeType = .stringAttributeType
        forumPostImageAttr.isOptional = true

        let forumPostCategoryIdAttr = NSAttributeDescription()
        forumPostCategoryIdAttr.name = "categoryId"
        forumPostCategoryIdAttr.attributeType = .integer64AttributeType
        forumPostCategoryIdAttr.isOptional = true

        let forumPostTypeAttr = NSAttributeDescription()
        forumPostTypeAttr.name = "postType"
        forumPostTypeAttr.attributeType = .stringAttributeType

        let forumPostCommentsAttr = NSAttributeDescription()
        forumPostCommentsAttr.name = "commentsCount"
        forumPostCommentsAttr.attributeType = .integer64AttributeType
        forumPostCommentsAttr.defaultValue = 0

        let forumPostLikesAttr = NSAttributeDescription()
        forumPostLikesAttr.name = "likesCount"
        forumPostLikesAttr.attributeType = .integer64AttributeType
        forumPostLikesAttr.defaultValue = 0

        let forumPostViewsAttr = NSAttributeDescription()
        forumPostViewsAttr.name = "viewsCount"
        forumPostViewsAttr.attributeType = .integer64AttributeType
        forumPostViewsAttr.defaultValue = 0

        let forumPostPinnedAttr = NSAttributeDescription()
        forumPostPinnedAttr.name = "isPinned"
        forumPostPinnedAttr.attributeType = .booleanAttributeType
        forumPostPinnedAttr.defaultValue = false

        let forumPostAuthorDataAttr = NSAttributeDescription()
        forumPostAuthorDataAttr.name = "authorData"
        forumPostAuthorDataAttr.attributeType = .binaryDataAttributeType
        forumPostAuthorDataAttr.isOptional = true

        let forumPostCreatedAttr = NSAttributeDescription()
        forumPostCreatedAttr.name = "createdAt"
        forumPostCreatedAttr.attributeType = .dateAttributeType

        let forumPostCachedAtAttr = NSAttributeDescription()
        forumPostCachedAtAttr.name = "cachedAt"
        forumPostCachedAtAttr.attributeType = .dateAttributeType

        // MARK: Sync Support Attributes for Conflict Resolution
        let forumPostSyncVersionAttr = NSAttributeDescription()
        forumPostSyncVersionAttr.name = "syncVersion"
        forumPostSyncVersionAttr.attributeType = .integer64AttributeType
        forumPostSyncVersionAttr.defaultValue = 0

        let forumPostLocallyModifiedAttr = NSAttributeDescription()
        forumPostLocallyModifiedAttr.name = "locallyModified"
        forumPostLocallyModifiedAttr.attributeType = .booleanAttributeType
        forumPostLocallyModifiedAttr.defaultValue = false

        let forumPostPendingSyncAttr = NSAttributeDescription()
        forumPostPendingSyncAttr.name = "pendingSync"
        forumPostPendingSyncAttr.attributeType = .booleanAttributeType
        forumPostPendingSyncAttr.defaultValue = false

        forumPostEntity.properties = [
            forumPostIdAttr, forumPostProfileIdAttr, forumPostTitleAttr, forumPostDescAttr,
            forumPostImageAttr, forumPostCategoryIdAttr, forumPostTypeAttr, forumPostCommentsAttr,
            forumPostLikesAttr, forumPostViewsAttr, forumPostPinnedAttr, forumPostAuthorDataAttr,
            forumPostCreatedAttr, forumPostCachedAtAttr, forumPostSyncVersionAttr,
            forumPostLocallyModifiedAttr, forumPostPendingSyncAttr
        ]

        // MARK: CachedRoom Entity
        let roomEntity = NSEntityDescription()
        roomEntity.name = "CachedRoom"
        roomEntity.managedObjectClassName = "CachedRoom"

        let roomIdAttr = NSAttributeDescription()
        roomIdAttr.name = "id"
        roomIdAttr.attributeType = .UUIDAttributeType

        let roomPostIdAttr = NSAttributeDescription()
        roomPostIdAttr.name = "postId"
        roomPostIdAttr.attributeType = .integer64AttributeType

        let roomSharerIdAttr = NSAttributeDescription()
        roomSharerIdAttr.name = "sharerId"
        roomSharerIdAttr.attributeType = .UUIDAttributeType

        let roomRequesterIdAttr = NSAttributeDescription()
        roomRequesterIdAttr.name = "requesterId"
        roomRequesterIdAttr.attributeType = .UUIDAttributeType

        let roomLastMessageAttr = NSAttributeDescription()
        roomLastMessageAttr.name = "lastMessage"
        roomLastMessageAttr.attributeType = .stringAttributeType
        roomLastMessageAttr.isOptional = true

        let roomLastMessageAtAttr = NSAttributeDescription()
        roomLastMessageAtAttr.name = "lastMessageAt"
        roomLastMessageAtAttr.attributeType = .dateAttributeType
        roomLastMessageAtAttr.isOptional = true

        let roomUnreadCountAttr = NSAttributeDescription()
        roomUnreadCountAttr.name = "unreadCount"
        roomUnreadCountAttr.attributeType = .integer64AttributeType
        roomUnreadCountAttr.defaultValue = 0

        let roomCachedAtAttr = NSAttributeDescription()
        roomCachedAtAttr.name = "cachedAt"
        roomCachedAtAttr.attributeType = .dateAttributeType

        roomEntity.properties = [
            roomIdAttr, roomPostIdAttr, roomSharerIdAttr, roomRequesterIdAttr,
            roomLastMessageAttr, roomLastMessageAtAttr, roomUnreadCountAttr, roomCachedAtAttr
        ]

        // MARK: SyncMetadata Entity (tracks sync state)
        let syncEntity = NSEntityDescription()
        syncEntity.name = "SyncMetadata"
        syncEntity.managedObjectClassName = "SyncMetadata"

        let syncEntityTypeAttr = NSAttributeDescription()
        syncEntityTypeAttr.name = "entityType"
        syncEntityTypeAttr.attributeType = .stringAttributeType

        let syncLastSyncAttr = NSAttributeDescription()
        syncLastSyncAttr.name = "lastSyncedAt"
        syncLastSyncAttr.attributeType = .dateAttributeType

        let syncLastIdAttr = NSAttributeDescription()
        syncLastIdAttr.name = "lastSyncedId"
        syncLastIdAttr.attributeType = .stringAttributeType
        syncLastIdAttr.isOptional = true

        syncEntity.properties = [syncEntityTypeAttr, syncLastSyncAttr, syncLastIdAttr]

        model.entities = [listingEntity, profileEntity, messageEntity, forumPostEntity, roomEntity, syncEntity]

        return model
    }()

    // MARK: - Room Cache Operations

    /// Fetch cached rooms for a user
    func fetchCachedRooms(for userId: UUID) async throws -> [Room] {
        guard guardStoreHealth(operation: "fetchCachedRooms") else { return [] }

        let context = newBackgroundContext()

        return try await context.perform {
            let request = NSFetchRequest<CachedRoom>(entityName: "CachedRoom")
            request.predicate = NSPredicate(
                format: "sharerId == %@ OR requesterId == %@",
                userId as CVarArg, userId as CVarArg,
            )
            request.sortDescriptors = [NSSortDescriptor(key: "lastMessageAt", ascending: false)]

            let cachedRooms = try context.fetch(request)
            return cachedRooms.map { cached in
                Room(
                    id: cached.id,
                    postId: Int(cached.postId),
                    sharer: cached.sharerId,
                    requester: cached.requesterId,
                    lastMessage: cached.lastMessage,
                    lastMessageTime: cached.lastMessageAt,
                    lastMessageSentBy: nil,
                    lastMessageSeenBy: nil,
                    postArrangedTo: nil,
                    emailTo: nil,
                )
            }
        }
    }

    /// Cache rooms for a user
    func cacheRooms(_ rooms: [Room], for userId: UUID) async throws {
        guard guardStoreHealth(operation: "cacheRooms") else { return }

        let context = newBackgroundContext()

        await context.perform {
            // Delete existing cached rooms for this user
            let deleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CachedRoom")
            deleteRequest.predicate = NSPredicate(
                format: "sharerId == %@ OR requesterId == %@",
                userId as CVarArg, userId as CVarArg,
            )
            let batchDelete = NSBatchDeleteRequest(fetchRequest: deleteRequest)
            do {
                try context.execute(batchDelete)
            } catch {
                let logger = self.logger
                Task { @MainActor in logger.warning("⚠️ [CoreData] Failed to delete existing rooms: \(error.localizedDescription)") }
            }

            // Insert new rooms
            for room in rooms {
                let cached = CachedRoom(context: context)
                cached.id = room.id
                cached.postId = Int64(room.postId)
                cached.sharerId = room.sharer
                cached.requesterId = room.requester
                cached.lastMessage = room.lastMessage
                cached.lastMessageAt = room.lastMessageTime
                cached.unreadCount = 0
                cached.cachedAt = Date()
            }

            do {
                try context.save()
            } catch {
                let logger = self.logger
                Task { @MainActor in logger.error("❌ [CoreData] Failed to save cached rooms: \(error.localizedDescription)") }
            }
        }

        logger.debug("✅ [CoreData] Cached \(rooms.count) rooms for user \(userId.uuidString)")
    }

    // MARK: - Message Cache Operations

    /// Fetch cached messages for a room
    func fetchCachedMessages(for roomId: UUID, limit: Int = 50, offset: Int = 0) async throws -> [Message] {
        guard guardStoreHealth(operation: "fetchCachedMessages") else { return [] }

        let context = newBackgroundContext()

        return try await context.perform {
            let request = NSFetchRequest<CachedMessage>(entityName: "CachedMessage")
            request.predicate = NSPredicate(format: "roomId == %@", roomId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            request.fetchLimit = limit
            request.fetchOffset = offset

            let cachedMessages = try context.fetch(request)
            return cachedMessages.map { cached in
                Message(
                    id: cached.id,
                    roomId: cached.roomId, // UUID? - optional in Message model
                    profileId: cached.senderId,
                    text: cached.content,
                    image: nil,
                    timestamp: cached.createdAt,
                )
            }
        }
    }

    /// Cache messages for a room
    func cacheMessages(_ messages: [Message], for roomId: UUID) async throws {
        guard guardStoreHealth(operation: "cacheMessages") else { return }

        let context = newBackgroundContext()

        await context.perform {
            for message in messages {
                // Check if message already exists
                let existingRequest = NSFetchRequest<CachedMessage>(entityName: "CachedMessage")
                existingRequest.predicate = NSPredicate(format: "id == %@", message.id as CVarArg)
                existingRequest.fetchLimit = 1

                if let existing = try? context.fetch(existingRequest).first {
                    // Update existing message
                    existing.content = message.text
                    existing.createdAt = message.timestamp
                    existing.cachedAt = Date()
                } else {
                    // Insert new message
                    let cached = CachedMessage(context: context)
                    cached.id = message.id
                    cached.roomId = message.roomId ?? roomId // Use provided roomId as fallback
                    cached.senderId = message.profileId
                    cached.content = message.text
                    cached.createdAt = message.timestamp
                    cached.cachedAt = Date()
                    cached.isSent = true
                }
            }

            do {
                try context.save()
            } catch {
                let logger = self.logger
                Task { @MainActor in logger.error("❌ [CoreData] Failed to save cached messages: \(error.localizedDescription)") }
            }
        }

        logger.debug("✅ [CoreData] Cached \(messages.count) messages for room \(roomId.uuidString)")
    }

    /// Cache a single message (for realtime updates)
    func cacheMessage(_ message: Message) async throws {
        guard let roomId = message.roomId else {
            logger.warning("Cannot cache message without roomId")
            return
        }
        try await cacheMessages([message], for: roomId)
    }

    // MARK: - Forum Post Cache Operations

    /// Fetch cached forum posts with optional filtering
    func fetchCachedForumPosts(
        categoryId: Int?,
        postType: ForumPostType?,
        limit: Int = 50,
        offset: Int = 0,
    ) async throws -> [ForumPost] {
        guard guardStoreHealth(operation: "fetchCachedForumPosts") else { return [] }

        let context = newBackgroundContext()

        return try await context.perform {
            let request = NSFetchRequest<CachedForumPost>(entityName: "CachedForumPost")

            // Build predicates for filtering
            var predicates: [NSPredicate] = []

            if let categoryId {
                predicates.append(NSPredicate(format: "categoryId == %d", categoryId))
            }

            if let postType {
                predicates.append(NSPredicate(format: "postType == %@", postType.rawValue))
            }

            if !predicates.isEmpty {
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            }

            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            request.fetchLimit = limit
            request.fetchOffset = offset

            let cachedPosts = try context.fetch(request)
            return cachedPosts.map { cached in
                ForumPost(
                    id: Int(cached.id),
                    profileId: cached.profileId,
                    forumPostName: cached.title,
                    forumPostDescription: cached.descriptionText,
                    forumPostImage: cached.imageUrl,
                    forumCommentsCounter: Int(cached.commentsCount),
                    forumLikesCounter: Int(cached.likesCount),
                    forumPublished: true,
                    categoryId: cached.categoryId > 0 ? Int(cached.categoryId) : nil,
                    slug: nil,
                    viewsCount: Int(cached.viewsCount),
                    isPinned: cached.isPinned,
                    isLocked: false,
                    isEdited: false,
                    lastActivityAt: nil,
                    postType: ForumPostType(rawValue: cached.postType) ?? .discussion,
                    bestAnswerId: nil,
                    hotScore: nil,
                    isFeatured: false,
                    featuredAt: nil,
                    forumPostCreatedAt: cached.createdAt,
                    forumPostUpdatedAt: cached.createdAt,
                    author: cached.author,
                    category: nil,
                    tags: nil,
                    commentsPreview: nil,
                )
            }
        }
    }

    /// Cache forum posts
    func cacheForumPosts(_ posts: [ForumPost]) async throws {
        guard guardStoreHealth(operation: "cacheForumPosts") else { return }

        let context = newBackgroundContext()

        await context.perform {
            for post in posts {
                // Check if post already exists
                let existingRequest = NSFetchRequest<CachedForumPost>(entityName: "CachedForumPost")
                existingRequest.predicate = NSPredicate(format: "id == %d", post.id)
                existingRequest.fetchLimit = 1

                if let existing = try? context.fetch(existingRequest).first {
                    // Update existing post
                    existing.title = post.forumPostName
                    existing.descriptionText = post.forumPostDescription
                    existing.imageUrl = post.forumPostImage
                    existing.categoryId = Int64(post.categoryId ?? 0)
                    existing.postType = post.postType.rawValue
                    existing.commentsCount = Int64(post.forumCommentsCounter ?? 0)
                    existing.likesCount = Int64(post.forumLikesCounter)
                    existing.viewsCount = Int64(post.viewsCount)
                    existing.isPinned = post.isPinned
                    existing.author = post.author
                    existing.cachedAt = Date()
                } else {
                    // Insert new post
                    let cached = CachedForumPost(context: context)
                    cached.id = Int64(post.id)
                    cached.profileId = post.profileId
                    cached.title = post.forumPostName
                    cached.descriptionText = post.forumPostDescription
                    cached.imageUrl = post.forumPostImage
                    cached.categoryId = Int64(post.categoryId ?? 0)
                    cached.postType = post.postType.rawValue
                    cached.commentsCount = Int64(post.forumCommentsCounter ?? 0)
                    cached.likesCount = Int64(post.forumLikesCounter)
                    cached.viewsCount = Int64(post.viewsCount)
                    cached.isPinned = post.isPinned
                    cached.author = post.author
                    cached.createdAt = post.forumPostCreatedAt
                    cached.cachedAt = Date()
                }
            }

            do {
                try context.save()
            } catch {
                let logger = self.logger
                Task { @MainActor in logger.error("❌ [CoreData] Failed to save cached forum posts: \(error.localizedDescription)") }
            }
        }

        logger.debug("✅ [CoreData] Cached \(posts.count) forum posts")
    }

    // MARK: - Profile Cache Operations

    /// Fetch a cached profile for a user
    func fetchCachedProfile(for userId: UUID) async throws -> UserProfile {
        guard guardStoreHealth(operation: "fetchCachedProfile") else {
            throw DatabaseError.notFound
        }

        let context = newBackgroundContext()

        return try await context.perform {
            let request = NSFetchRequest<CachedProfile>(entityName: "CachedProfile")
            request.predicate = NSPredicate(format: "id == %@", userId as CVarArg)
            request.fetchLimit = 1

            guard let cached = try context.fetch(request).first else {
                throw DatabaseError.notFound
            }

            return UserProfile(
                id: cached.id,
                nickname: cached.nickname ?? "Unknown",
                avatarUrl: cached.avatarUrl,
                bio: cached.bio,
                aboutMe: cached.aboutMe,
                ratingAverage: cached.ratingAverage,
                itemsShared: Int(cached.itemsShared),
                itemsReceived: Int(cached.itemsReceived),
                ratingCount: Int(cached.ratingCount),
                createdTime: cached.createdTime ?? Date(),
                searchRadiusKm: Int(cached.searchRadiusKm),
                preferredLocale: cached.preferredLocale
            )
        }
    }

    /// Cache a user profile
    func cacheProfile(_ profile: UserProfile) async throws {
        guard guardStoreHealth(operation: "cacheProfile") else { return }

        let context = newBackgroundContext()

        await context.perform {
            // Check if profile already exists
            let existingRequest = NSFetchRequest<CachedProfile>(entityName: "CachedProfile")
            existingRequest.predicate = NSPredicate(format: "id == %@", profile.id as CVarArg)
            existingRequest.fetchLimit = 1

            if let existing = try? context.fetch(existingRequest).first {
                // Update existing profile
                existing.nickname = profile.nickname
                existing.avatarUrl = profile.avatarUrl
                existing.bio = profile.bio
                existing.aboutMe = profile.aboutMe
                existing.ratingAverage = profile.ratingAverage
                existing.itemsShared = Int64(profile.itemsShared)
                existing.itemsReceived = Int64(profile.itemsReceived)
                existing.ratingCount = Int64(profile.ratingCount)
                existing.createdTime = profile.createdTime
                existing.searchRadiusKm = Int64(profile.searchRadiusKm ?? 5)
                existing.preferredLocale = profile.preferredLocale
                existing.cachedAt = Date()
            } else {
                // Insert new profile
                let cached = CachedProfile(context: context)
                cached.id = profile.id
                cached.nickname = profile.nickname
                cached.avatarUrl = profile.avatarUrl
                cached.bio = profile.bio
                cached.aboutMe = profile.aboutMe
                cached.ratingAverage = profile.ratingAverage
                cached.itemsShared = Int64(profile.itemsShared)
                cached.itemsReceived = Int64(profile.itemsReceived)
                cached.ratingCount = Int64(profile.ratingCount)
                cached.createdTime = profile.createdTime
                cached.searchRadiusKm = Int64(profile.searchRadiusKm ?? 5)
                cached.preferredLocale = profile.preferredLocale
                cached.cachedAt = Date()
            }

            do {
                try context.save()
            } catch {
                let logger = self.logger
                Task { @MainActor in logger.error("❌ [CoreData] Failed to save cached profile: \(error.localizedDescription)") }
            }
        }

        logger.debug("✅ [CoreData] Cached profile for user \(profile.id.uuidString)")
    }

    // MARK: - Clear All Cache

    func clearAllCache() async {
        guard guardStoreHealth(operation: "clearAllCache") else { return }

        let context = newBackgroundContext()

        await context.perform {
            for entityName in [
                "CachedListing",
                "CachedProfile",
                "CachedMessage",
                "CachedForumPost",
                "CachedRoom",
                "SyncMetadata"
            ] {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

                do {
                    try context.execute(deleteRequest)
                } catch {
                    Task { @MainActor in
                        self.logger.error("❌ [CoreData] Failed to clear \(entityName): \(error.localizedDescription)")
                    }
                }
            }

            do {
                try context.save()
            } catch {
                let logger = self.logger
                Task { @MainActor in logger.error("❌ [CoreData] Failed to save after clearing cache: \(error.localizedDescription)") }
            }
        }

        logger.info("✅ [CoreData] All cache cleared")
    }
}

// MARK: - Managed Object Subclasses

@objc(CachedListing)
public class CachedListing: NSManagedObject {
    @NSManaged public var id: Int64
    @NSManaged public var name: String
    @NSManaged public var descriptionText: String?
    @NSManaged public var address: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var imagesData: Data?
    @NSManaged public var category: String?
    @NSManaged public var profileId: UUID?
    @NSManaged public var isArranged: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var cachedAt: Date

    // MARK: Sync Support Properties
    @NSManaged public var syncVersion: Int64
    @NSManaged public var locallyModified: Bool
    @NSManaged public var pendingSync: Bool

    var images: [String] {
        get {
            guard let data = imagesData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            imagesData = try? JSONEncoder().encode(newValue)
        }
    }
}

@objc(CachedProfile)
public class CachedProfile: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var nickname: String?
    @NSManaged public var avatarUrl: String?
    @NSManaged public var bio: String?
    @NSManaged public var aboutMe: String?
    @NSManaged public var ratingAverage: Double
    @NSManaged public var itemsShared: Int64
    @NSManaged public var itemsReceived: Int64
    @NSManaged public var ratingCount: Int64
    @NSManaged public var createdTime: Date?
    @NSManaged public var isVerified: Bool
    @NSManaged public var cachedAt: Date
    @NSManaged public var searchRadiusKm: Int64
    @NSManaged public var preferredLocale: String?
}

@objc(CachedMessage)
public class CachedMessage: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var roomId: UUID
    @NSManaged public var senderId: UUID
    @NSManaged public var content: String
    @NSManaged public var createdAt: Date
    @NSManaged public var cachedAt: Date
    @NSManaged public var isSent: Bool
}

@objc(CachedForumPost)
public class CachedForumPost: NSManagedObject {
    @NSManaged public var id: Int64
    @NSManaged public var profileId: UUID
    @NSManaged public var title: String?
    @NSManaged public var descriptionText: String?
    @NSManaged public var imageUrl: String?
    @NSManaged public var categoryId: Int64
    @NSManaged public var postType: String
    @NSManaged public var commentsCount: Int64
    @NSManaged public var likesCount: Int64
    @NSManaged public var viewsCount: Int64
    @NSManaged public var isPinned: Bool
    @NSManaged public var authorData: Data?
    @NSManaged public var createdAt: Date
    @NSManaged public var cachedAt: Date

    // MARK: Sync Support Properties
    @NSManaged public var syncVersion: Int64
    @NSManaged public var locallyModified: Bool
    @NSManaged public var pendingSync: Bool

    var author: ForumAuthor? {
        get {
            guard let data = authorData else { return nil }
            return try? JSONDecoder().decode(ForumAuthor.self, from: data)
        }
        set {
            authorData = try? JSONEncoder().encode(newValue)
        }
    }
}

@objc(CachedRoom)
public class CachedRoom: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var postId: Int64
    @NSManaged public var sharerId: UUID
    @NSManaged public var requesterId: UUID
    @NSManaged public var lastMessage: String?
    @NSManaged public var lastMessageAt: Date?
    @NSManaged public var unreadCount: Int64
    @NSManaged public var cachedAt: Date
}

@objc(SyncMetadata)
public class SyncMetadata: NSManagedObject {
    @NSManaged public var entityType: String
    @NSManaged public var lastSyncedAt: Date
    @NSManaged public var lastSyncedId: String?
}
