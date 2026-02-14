//
//  ProfileAPIService.swift
//  Foodshare
//
//  Centralized API service for profile Edge Function (api-v1-profile).
//  Replaces direct Supabase queries with Edge Function calls.
//
//  Endpoints:
//  - GET    /api-v1-profile                 → getProfile()
//  - GET    /api-v1-profile?action=address   → getAddress()
//  - GET    /api-v1-profile?action=dashboard → getDashboard()
//  - PUT    /api-v1-profile                 → updateProfile()
//  - PUT    /api-v1-profile?action=address   → updateAddress()
//  - POST   /api-v1-profile?action=avatar   → uploadAvatar()
//  - DELETE /api-v1-profile?action=avatar   → deleteAvatar()
//  - DELETE /api-v1-profile?action=account  → deleteAccount()
//

import Foundation

// MARK: - DTOs

/// Profile data returned by GET /api-v1-profile
/// Maps to the `transformProfile` output in the Edge Function
struct ProfileDTO: Codable, Sendable {
    let id: UUID
    let name: String?
    let firstName: String?
    let lastName: String?
    let bio: String?
    let phone: String?
    let location: String?
    let avatarUrl: String?
    let isVolunteer: Bool?
    let ratingCount: Int?
    let ratingAverage: Double?
    let createdAt: Date?
    let updatedAt: Date?
}

/// Dashboard data returned by GET /api-v1-profile?action=dashboard
struct ProfileDashboardDTO: Codable, Sendable {
    let user: ProfileDashboardUserDTO?
    let stats: ProfileDashboardStatsDTO?
    let impact: ProfileDashboardImpactDTO?
    let counts: ProfileDashboardCountsDTO?
    let recentListings: [ProfileDashboardListingDTO]?
}

struct ProfileDashboardUserDTO: Codable, Sendable {
    let id: String?
    let firstName: String?
    let secondName: String?
    let displayName: String?
    let bio: String?
    let avatarUrl: String?
    let ratingAverage: Double?
    let ratingCount: Int?
    let createdAt: String?
}

struct ProfileDashboardStatsDTO: Codable, Sendable {
    let itemsShared: Int?
    let itemsReceived: Int?
    let activeListings: Int?
    let rating: Double?
    let ratingCount: Int?
}

struct ProfileDashboardImpactDTO: Codable, Sendable {
    let foodSavedKg: Double?
    let co2SavedKg: Double?
    let mealsProvided: Int?
}

struct ProfileDashboardCountsDTO: Codable, Sendable {
    let notifications: Int?
    let messages: Int?
    let requests: Int?
}

struct ProfileDashboardListingDTO: Codable, Sendable {
    let id: Int?
    let title: String?
    let images: [String]?
    let status: String?
    let createdAt: Date?
}

/// Address data returned by GET/PUT /api-v1-profile?action=address
/// Maps to the `transformAddress` output in the Edge Function
struct AddressDTO: Codable, Sendable {
    let profileId: UUID?
    let addressLine1: String?
    let addressLine2: String?
    let addressLine3: String?
    let city: String?
    let stateProvince: String?
    let postalCode: String?
    let country: String?
    let lat: Double?
    let lng: Double?
    let fullAddress: String?
    let radiusMeters: Int?
}

/// Avatar upload response from POST /api-v1-profile?action=avatar
struct AvatarDTO: Codable, Sendable {
    let url: String
}

/// Request body for PUT /api-v1-profile
struct UpdateProfileAPIRequest: Encodable, Sendable {
    let name: String?
    let bio: String?
    let phone: String?
    let location: String?
    let isVolunteer: Bool?

    init(name: String? = nil, bio: String? = nil, phone: String? = nil, location: String? = nil, isVolunteer: Bool? = nil) {
        self.name = name
        self.bio = bio
        self.phone = phone
        self.location = location
        self.isVolunteer = isVolunteer
    }
}

/// Request body for PUT /api-v1-profile?action=address
struct AddressAPIRequest: Encodable, Sendable {
    let addressLine1: String
    let addressLine2: String?
    let addressLine3: String?
    let city: String
    let stateProvince: String?
    let postalCode: String?
    let country: String
    let lat: Double?
    let lng: Double?
    let radiusMeters: Int?

    init(
        addressLine1: String,
        addressLine2: String? = nil,
        addressLine3: String? = nil,
        city: String,
        stateProvince: String? = nil,
        postalCode: String? = nil,
        country: String,
        lat: Double? = nil,
        lng: Double? = nil,
        radiusMeters: Int? = nil
    ) {
        self.addressLine1 = addressLine1
        self.addressLine2 = addressLine2
        self.addressLine3 = addressLine3
        self.city = city
        self.stateProvince = stateProvince
        self.postalCode = postalCode
        self.country = country
        self.lat = lat
        self.lng = lng
        self.radiusMeters = radiusMeters
    }
}

/// Request body for POST /api-v1-profile?action=avatar
struct UploadAvatarAPIRequest: Encodable, Sendable {
    let imageData: String
    let mimeType: String
    let fileName: String?

    init(imageData: String, mimeType: String = "image/jpeg", fileName: String? = nil) {
        self.imageData = imageData
        self.mimeType = mimeType
        self.fileName = fileName
    }
}

/// Response from DELETE /api-v1-profile?action=account
struct DeleteAccountResponseDTO: Codable, Sendable {
    let success: Bool
    let message: String?
    let deletedUserId: String?
}

// MARK: - Service

actor ProfileAPIService {
    nonisolated static let shared = ProfileAPIService()
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    // MARK: - GET Endpoints

    /// Get current user's profile
    func getProfile() async throws -> ProfileDTO {
        try await client.get("api-v1-profile")
    }

    /// Get current user's address
    func getAddress() async throws -> AddressDTO? {
        // The edge function returns null when no address exists, which decodes as nil in the envelope
        try await client.get("api-v1-profile", params: ["action": "address"])
    }

    /// Get dashboard analytics (profile + stats + impact + counts)
    func getDashboard(includeListings: Bool = false) async throws -> ProfileDashboardDTO {
        var params = ["action": "dashboard"]
        if includeListings {
            params["includeListings"] = "true"
        }
        return try await client.get("api-v1-profile", params: params)
    }

    // MARK: - PUT Endpoints

    /// Update profile fields
    func updateProfile(_ request: UpdateProfileAPIRequest) async throws -> ProfileDTO {
        try await client.put("api-v1-profile", body: request)
    }

    /// Update or create address
    func updateAddress(_ request: AddressAPIRequest) async throws -> AddressDTO {
        try await client.put("api-v1-profile", body: request, params: ["action": "address"])
    }

    // MARK: - POST Endpoints

    /// Upload avatar image (base64 encoded)
    func uploadAvatar(_ request: UploadAvatarAPIRequest) async throws -> AvatarDTO {
        try await client.post("api-v1-profile", body: request, params: ["action": "avatar"])
    }

    // MARK: - DELETE Endpoints

    /// Delete avatar
    func deleteAvatar() async throws {
        try await client.deleteVoid("api-v1-profile", params: ["action": "avatar"])
    }

    /// Delete account (Apple App Store compliance)
    func deleteAccount() async throws -> DeleteAccountResponseDTO {
        try await client.delete("api-v1-profile", params: ["action": "account"])
    }
}
