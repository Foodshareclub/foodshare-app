//
//  ProductsAPIService.swift
//  Foodshare
//
//  API service for product/listing operations via api-v1-products Edge Function.
//  Handles CRUD, nearby search, and feed operations.
//

import Foundation

// MARK: - Response DTOs

/// Product from the Edge Function (maps to FoodItem domain model)
struct ProductDTO: Decodable, Sendable {
    let id: Int
    let profileId: UUID?
    let postName: String?
    let postDescription: String?
    let postType: String?
    let pickupTime: String?
    let availableHours: String?
    let postAddress: String?
    let postStrippedAddress: String?
    let latitude: Double?
    let longitude: Double?
    let images: [String]?
    let isActive: Bool?
    let isArranged: Bool?
    let postArrangedTo: UUID?
    let postArrangedAt: Date?
    let postViews: Int?
    let postLikeCounter: Int?
    let hasPantry: Bool?
    let foodStatus: String?
    let network: String?
    let website: String?
    let donation: String?
    let donationRules: String?
    let fridgeId: String?
    let locationType: String?
    let categoryId: Int?
    let createdAt: Date?
    let updatedAt: Date?
    let distanceMeters: Double?
    let version: Int?

    /// Convert to domain model
    func toFoodItem() -> FoodItem {
        FoodItem(
            id: id,
            profileId: profileId,
            postName: postName ?? "Untitled",
            postDescription: postDescription,
            postType: postType ?? "food",
            pickupTime: pickupTime,
            availableHours: availableHours,
            postAddress: postAddress,
            postStrippedAddress: postStrippedAddress,
            latitude: latitude,
            longitude: longitude,
            images: images,
            isActive: isActive ?? true,
            isArranged: isArranged ?? false,
            postArrangedTo: postArrangedTo,
            postArrangedAt: postArrangedAt,
            postViews: postViews ?? 0,
            postLikeCounter: postLikeCounter,
            hasPantry: hasPantry,
            foodStatus: foodStatus,
            network: network,
            website: website,
            donation: donation,
            donationRules: donationRules,
            fridgeId: fridgeId,
            locationType: locationType,
            categoryId: categoryId,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date(),
            distanceMeters: distanceMeters
        )
    }
}

/// Feed response from mode=feed
struct FeedResponseDTO: Decodable, Sendable {
    let listings: [ProductDTO]
    let counts: FeedCountsDTO?
}

struct FeedCountsDTO: Decodable, Sendable {
    let total: Int?
    let food: Int?
    let fridge: Int?
    let urgent: Int?
}

// MARK: - Request Bodies

struct CreateProductRequest: Encodable, Sendable {
    let title: String
    let description: String?
    let images: [String]
    let postType: String
    let latitude: Double
    let longitude: Double
    let pickupAddress: String?
    let pickupTime: String?
    let categoryId: Int?
    let expiresAt: String?
}

struct UpdateProductRequest: Encodable, Sendable {
    let title: String?
    let description: String?
    let images: [String]?
    let pickupAddress: String?
    let pickupTime: String?
    let categoryId: Int?
    let expiresAt: String?
    let isActive: Bool?
    let version: Int
}

// MARK: - Products API Service

actor ProductsAPIService {
    nonisolated static let shared = ProductsAPIService()
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// Get nearby products with pagination
    func getNearbyProducts(
        lat: Double,
        lng: Double,
        radiusKm: Double? = nil,
        postType: String? = nil,
        categoryId: Int? = nil,
        limit: Int = 20,
        cursor: String? = nil,
        userId: String? = nil
    ) async throws -> [ProductDTO] {
        var params: [String: String] = [
            "lat": "\(lat)",
            "lng": "\(lng)",
            "limit": "\(limit)"
        ]
        if let radiusKm { params["radiusKm"] = "\(radiusKm)" }
        if let postType { params["postType"] = postType }
        if let categoryId { params["categoryId"] = "\(categoryId)" }
        if let cursor { params["cursor"] = cursor }
        if let userId { params["userId"] = userId }

        return try await client.get("api-v1-products", params: params)
    }

    /// Get feed data (mode=feed)
    func getFeed(
        lat: Double,
        lng: Double,
        radiusKm: Double? = nil,
        limit: Int = 20
    ) async throws -> FeedResponseDTO {
        var params: [String: String] = [
            "mode": "feed",
            "lat": "\(lat)",
            "lng": "\(lng)",
            "limit": "\(limit)"
        ]
        if let radiusKm { params["radiusKm"] = "\(radiusKm)" }

        return try await client.get("api-v1-products", params: params)
    }

    /// Get a single product by ID
    func getProduct(id: Int, include: String? = nil) async throws -> ProductDTO {
        var params: [String: String] = ["id": "\(id)"]
        if let include { params["include"] = include }

        return try await client.get("api-v1-products", params: params)
    }

    /// Create a new product
    func createProduct(_ request: CreateProductRequest) async throws -> ProductDTO {
        try await client.post("api-v1-products", body: request)
    }

    /// Update an existing product
    func updateProduct(id: Int, request: UpdateProductRequest) async throws -> ProductDTO {
        try await client.put(
            "api-v1-products",
            body: request,
            params: ["id": "\(id)"]
        )
    }

    /// Delete a product
    func deleteProduct(id: Int) async throws {
        try await client.deleteVoid("api-v1-products", params: ["id": "\(id)"])
    }
}
