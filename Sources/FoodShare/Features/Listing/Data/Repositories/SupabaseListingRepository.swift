//
//  SupabaseListingRepository.swift
//  Foodshare
//
//  Supabase implementation of listing repository
//  Maps to `posts` table in Supabase
//



#if !SKIP
import Foundation
import OSLog
import Supabase

@MainActor
final class SupabaseListingRepository: BaseSupabaseRepository, ListingRepository {
    private let pushSender: PushNotificationSender
    private let productsAPI: ProductsAPIService

    init(
        supabase: Supabase.SupabaseClient,
        pushSender: PushNotificationSender = .shared,
        productsAPI: ProductsAPIService = .shared
    ) {
        self.pushSender = pushSender
        self.productsAPI = productsAPI
        super.init(supabase: supabase, subsystem: "com.flutterflow.foodshare", category: "ListingRepository")
    }

    // MARK: - Server-Side Validation

    func validateListing(_ request: CreateListingRequest, imageUrls: [String]) async throws -> ListingValidationResult {
        // Products API handles validation server-side during create, so return success
        ListingValidationResult(
            valid: true,
            errors: [],
            sanitized: SanitizedListing(
                title: request.title,
                description: request.description,
                images: imageUrls,
                postType: request.postType,
                latitude: request.pickupLocation.latitude,
                longitude: request.pickupLocation.longitude,
                pickupAddress: request.pickupAddress,
                pickupTime: request.pickupTime
            )
        )
    }

    // MARK: - Image Upload (Protocol Requirement)

    func uploadImages(_ imageData: [Data]) async throws -> [String] {
        try await uploadImages(imageData, bucket: "food-images")
    }

    private func uploadImages(_ imageData: [Data], bucket: String) async throws -> [String] {
        var urls: [String] = []
        for data in imageData {
            let fileName = "\(UUID().uuidString).jpg"
            let path = "listings/\(fileName)"
            try await supabase.storage.from(bucket).upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))
            let publicURL = try supabase.storage.from(bucket).getPublicURL(path: path)
            urls.append(publicURL.absoluteString)
        }
        return urls
    }

    // MARK: - CRUD Operations (via ProductsAPIService)

    func createListing(_ request: CreateListingRequest) async throws -> FoodItem {
        // Upload images using base class method
        let imageUrls = try await uploadImages(request.images, bucket: "food-images")

        // Create product via Edge Function (handles validation server-side)
        let createRequest = CreateProductRequest(
            title: request.title,
            description: request.description,
            images: imageUrls,
            postType: request.postType,
            latitude: request.pickupLocation.latitude,
            longitude: request.pickupLocation.longitude,
            pickupAddress: request.pickupAddress,
            pickupTime: request.pickupTime,
            categoryId: request.categoryId,
            expiresAt: nil
        )

        let product = try await productsAPI.createProduct(createRequest)
        return product.toFoodItem()
    }

    func updateListing(_ request: UpdateListingRequest) async throws -> FoodItem {
        let updateRequest = UpdateProductRequest(
            title: request.title,
            description: request.description,
            images: nil,
            pickupAddress: nil,
            pickupTime: nil,
            categoryId: request.categoryId,
            expiresAt: nil,
            isActive: request.isActive,
            version: 0
        )

        let product = try await productsAPI.updateProduct(id: request.listingId, request: updateRequest)
        return product.toFoodItem()
    }

    func deleteListing(_ id: Int) async throws {
        try await productsAPI.deleteProduct(id: id)
    }

    func fetchUserListings(userId: UUID) async throws -> [FoodItem] {
        let products = try await productsAPI.getNearbyProducts(
            lat: 0,
            lng: 0,
            userId: userId.uuidString
        )
        return products.map { $0.toFoodItem() }
    }

    func fetchListing(id: Int) async throws -> FoodItem {
        let product = try await productsAPI.getProduct(id: id)
        return product.toFoodItem()
    }

    // MARK: - Arrangement Operations (Transactional via RPC)

    func arrangePost(postId: Int, requesterId: UUID) async throws -> FoodItem {
        let params = ArrangePostParams(
            p_post_id: postId,
            p_requester_id: requesterId.uuidString
        )

        let result: ArrangementResult = try await executeTransactionalRPC("arrange_post", params: params)
        
        guard let post = result.post else {
            throw NSError(domain: "ListingRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "Arrangement operation failed"])
        }

        // Send push notification to sharer (post owner) - fire and forget
        if let ownerId = post.profileId {
            Task { [weak self] in
                await self?.sendArrangementPushNotification(
                    to: ownerId,
                    postId: postId,
                    postName: post.postName,
                    type: .arrangementRequest
                )
            }
        }

        return post
    }

    func cancelArrangement(postId: Int) async throws {
        // Fetch post first to get notification recipients
        let existingPost = try await fetchListing(id: postId)

        let params = CancelArrangementParams(p_post_id: postId)
        let _: ArrangementResult = try await executeTransactionalRPC("cancel_arrangement", params: params)

        // Notify both parties about cancellation - fire and forget
        Task {
            var recipients: [UUID] = []
            if let ownerId = existingPost.profileId {
                recipients.append(ownerId)
            }
            if let arrangedTo = existingPost.postArrangedTo {
                recipients.append(arrangedTo)
            }

            guard !recipients.isEmpty else { return }
            await sendArrangementPushNotification(
                to: recipients,
                postId: postId,
                postName: existingPost.postName,
                type: .arrangementCancelled
            )
        }
    }

    /// Send push notification for arrangement events
    private func sendArrangementPushNotification(
        to userId: UUID,
        postId: Int,
        postName: String,
        type: PushNotificationType,
    ) async {
        await sendArrangementPushNotification(to: [userId], postId: postId, postName: postName, type: type)
    }

    private func sendArrangementPushNotification(
        to userIds: [UUID],
        postId: Int,
        postName: String,
        type: PushNotificationType,
    ) async {
        let title: String
        let body: String

        switch type {
        case .arrangementRequest:
            title = "Pickup Requested"
            body = "Someone wants to pick up: \(postName)"
        case .arrangementConfirmed:
            title = "Pickup Confirmed"
            body = "Your pickup for \(postName) has been confirmed"
        case .arrangementCancelled:
            title = "Arrangement Cancelled"
            body = "The arrangement for \(postName) was cancelled"
        default:
            return
        }

        do {
            try await pushSender.sendNotification(
                to: userIds,
                title: title,
                body: body,
                type: type,
                data: ["postId": String(postId)],
            )
        } catch {
            logger.warning("Failed to send arrangement push: \(error.localizedDescription)")
        }
    }

    func deactivatePost(postId: Int) async throws {
        let params = DeactivatePostParams(p_post_id: postId)
        let _: ArrangementResult = try await executeTransactionalRPC("deactivate_post", params: params)
    }

    // MARK: - Arrangement History

    func fetchArrangementHistory(userId: UUID) async throws -> [ArrangementRecord] {
        try await executeRPC("get_arrangement_history", params: ["user_id": userId.uuidString])
    }

    // MARK: - Analytics

    func incrementViewCount(listingId: Int) async throws {
        await PostViewService.shared.recordView(postId: listingId)
    }
}

// MARK: - Arrangement DTOs

struct ArrangePostDTO: Encodable {
    let isArranged: Bool
    let postArrangedTo: UUID
    let postArrangedAt: String

    enum CodingKeys: String, CodingKey {
        case isArranged = "is_arranged"
        case postArrangedTo = "post_arranged_to"
        case postArrangedAt = "post_arranged_at"
    }
}

struct CancelArrangementDTO: Encodable {
    let isArranged = false
    let postArrangedTo: UUID? = nil
    let postArrangedAt: String? = nil

    enum CodingKeys: String, CodingKey {
        case isArranged = "is_arranged"
        case postArrangedTo = "post_arranged_to"
        case postArrangedAt = "post_arranged_at"
    }
}

struct DeactivatePostDTO: Encodable {
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case isActive = "is_active"
    }
}

/// Parameters for arrange_post RPC
struct ArrangePostParams: Encodable, Sendable {
    let p_post_id: Int
    let p_requester_id: String
}

/// Parameters for cancel_arrangement RPC
struct CancelArrangementParams: Encodable, Sendable {
    let p_post_id: Int
}

/// Parameters for deactivate_post RPC
struct DeactivatePostParams: Encodable, Sendable {
    let p_post_id: Int
}

/// Result from arrangement operations
struct ArrangementResult: Decodable, TransactionalResult {
    let success: Bool
    let post: FoodItem?
    let error: RPCTransactionalError?
}


#endif
