//
//  SupabaseProfileRepository.swift
//  Foodshare
//
//  Supabase implementation of profile repository with offline-first support
//  Features retry logic with exponential backoff for transient failures
//



#if !SKIP
import CoreData
import Foundation
import OSLog
import Supabase

@MainActor
final class SupabaseProfileRepository: BaseSupabaseRepository, ProfileRepository {
    private let coreDataStack: CoreDataStack
    private let networkMonitor: NetworkMonitor
    private let profileAPI: ProfileAPIService

    private let cacheConfiguration = CacheConfiguration(
        maxAge: 1800, // 30 minutes for profile data
        maxItems: 50,
        syncOnLaunch: true,
        backgroundSync: true,
    )

    init(
        supabase: Supabase.SupabaseClient,
        coreDataStack: CoreDataStack = .shared,
        networkMonitor: NetworkMonitor = .shared,
        profileAPI: ProfileAPIService = .shared,
    ) {
        self.coreDataStack = coreDataStack
        self.networkMonitor = networkMonitor
        self.profileAPI = profileAPI
        super.init(supabase: supabase, subsystem: "com.flutterflow.foodshare", category: "ProfileRepository")
    }

    private var currentCachePolicy: OfflineCachePolicy {
        if networkMonitor.isOffline {
            .cacheOnly
        } else if networkMonitor.isConstrained {
            .cacheFirst
        } else {
            .cacheFallback
        }
    }

    func fetchProfile(userId: UUID) async throws -> UserProfile {
        logger.debug("fetchProfile called for user: \(userId.uuidString)")

        // Deduplicate concurrent requests for the same profile
        do {
            return try await RequestDeduplicator.shared.fetchProfile(id: userId) {
                try await self.fetchProfileInternal(userId: userId)
            }
        } catch let error as DeduplicationError {
            guard error.isDeduplicated else { throw error }
            // Request already in flight - wait briefly and retry once
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            return try await fetchProfileInternal(userId: userId)
        }
    }

    /// Internal profile fetch implementation (called by deduplicator)
    /// Primary: Edge Function API, Fallback: direct Supabase, Last resort: CoreData cache
    private func fetchProfileInternal(userId: UUID) async throws -> UserProfile {
        // Try Edge Function API first
        do {
            let dto = try await profileAPI.getProfile()
            let profile = dto.toDomain()

            logger.debug("Profile fetched via API: \(profile.nickname)")

            // Cache in background (non-blocking)
            Task.detached { [coreDataStack = self.coreDataStack] in
                try? await coreDataStack.cacheProfile(profile)
            }

            return profile
        } catch {
            logger.warning("API fetch failed: \(error.localizedDescription), falling back to direct Supabase")
        }

        // Fallback: Direct Supabase queries
        do {
            let profileResponses: [BasicProfileDTO] = try await supabase
                .from("profiles")
                .select("id,nickname,avatar_url,bio,about_me,created_time,search_radius_km")
                .eq("id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            guard let basicProfile = profileResponses.first else {
                // Profile doesn't exist - create a default one
                logger.info("Profile not found for \(userId.uuidString), creating default")
                return try await createDefaultProfile(userId: userId)
            }

            // Fetch stats separately (more reliable than embedded join)
            let statsResponses: [ProfileStatsDTO] = try await supabase
                .from("profile_stats")
                .select("rating_average,items_shared,items_received,rating_count")
                .eq("profile_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            // Combine basic profile with stats
            let stats = statsResponses.first
            let profile = UserProfile(
                id: UUID(uuidString: basicProfile.id) ?? UUID(),
                nickname: basicProfile.nickname,
                avatarUrl: basicProfile.avatarUrl,
                bio: basicProfile.bio,
                aboutMe: basicProfile.aboutMe,
                ratingAverage: stats?.ratingAverage ?? 0.0,
                itemsShared: stats?.itemsShared ?? 0,
                itemsReceived: stats?.itemsReceived ?? 0,
                ratingCount: stats?.ratingCount ?? 0,
                createdTime: ISO8601DateFormatter().date(from: basicProfile.createdTime) ?? Date(),
                searchRadiusKm: basicProfile.searchRadiusKm,
                preferredLocale: basicProfile.preferredLocale,
            )

            logger.debug("Profile fetched via Supabase fallback: \(profile.nickname)")

            // Cache in background (non-blocking)
            Task.detached { [coreDataStack = self.coreDataStack] in
                try? await coreDataStack.cacheProfile(profile)
            }

            return profile

        } catch {
            logger.warning("Supabase fetch failed: \(error.localizedDescription), trying cache")

            // Network failed - try cache fallback
            if let cachedProfile = try? await coreDataStack.fetchCachedProfile(for: userId) {
                logger.debug("Using cached profile for \(userId.uuidString)")
                return cachedProfile
            }

            // No cache available - rethrow the original error
            throw error
        }
    }

    /// Creates a default profile for a user who somehow doesn't have one
    /// This can happen if the auth trigger failed or the user was created before the trigger existed
    private func createDefaultProfile(userId: UUID) async throws -> UserProfile {
        logger.info("Creating default profile for user: \(userId.uuidString)")

        // Get email from auth session if available
        let email: String? = try? await supabase.auth.session.user.email

        let defaultProfile = CreateProfileDTO(
            id: userId.uuidString,
            email: email,
            nickname: "User\(String(userId.uuidString.prefix(4)))",
        )

        do {
            _ = try await supabase
                .from("profiles")
                .upsert(defaultProfile, onConflict: "id", ignoreDuplicates: true)
                .execute()
            logger.info("Default profile created successfully")
        } catch {
            // Profile might already exist (race condition) - just fetch it
            logger.debug("Profile upsert skipped (may already exist): \(error.localizedDescription)")
        }

        // Wait a moment for database triggers to complete (profile_stats creation)
        try await Task.sleep(nanoseconds: 500_000_000)

        // Fetch the profile we just created using the same two-query approach
        return try await fetchProfile(userId: userId)
    }

    // MARK: - Offline-First Methods

    func fetchProfileOfflineFirst(userId: UUID) async throws -> OfflineDataResult<UserProfile> {
        let dataSource = OfflineFirstDataSource<UserProfile, UserProfile>(
            configuration: cacheConfiguration,
            fetchLocal: { [coreDataStack, logger] in
                logger.debug("🔍 [DIAGNOSTIC] fetchLocal closure - START for user: \(userId.uuidString)")

                // Return as array for OfflineFirstDataSource compatibility
                if let profile = try? await coreDataStack.fetchCachedProfile(for: userId) {
                    logger
                        .debug(
                            "🔍 [DIAGNOSTIC] fetchLocal - Found cached profile: id=\(profile.id.uuidString), nickname=\(profile.nickname)",
                        )
                    return [profile]
                }

                logger.debug("🔍 [DIAGNOSTIC] fetchLocal - No cached profile found")
                return []
            },
            fetchRemote: { [profileAPI, supabase, logger] in
                logger.debug("[DIAGNOSTIC] fetchRemote closure - START")

                // Primary: Edge Function API
                do {
                    let dto = try await profileAPI.getProfile()
                    let profile = dto.toDomain()
                    logger.debug("[DIAGNOSTIC] fetchRemote - Profile via API: id=\(profile.id.uuidString), nickname=\(profile.nickname)")
                    return [profile]
                } catch {
                    logger.warning("[DIAGNOSTIC] fetchRemote - API failed: \(error.localizedDescription), falling back to Supabase")
                }

                // Fallback: Direct Supabase join query
                let responses: [UserProfileDTO] = try await supabase
                    .from("profiles")
                    .select("""
                        id,nickname,avatar_url,bio,about_me,created_time,search_radius_km,\
                        profile_stats(rating_average,items_shared,items_received,rating_count)
                    """)
                    .eq("id", value: userId.uuidString)
                    .limit(1)
                    .execute()
                    .value

                logger.debug("[DIAGNOSTIC] fetchRemote closure - Supabase returned \(responses.count) profiles")

                let domainProfiles = responses.map { $0.toDomain() }
                logger.debug("[DIAGNOSTIC] fetchRemote closure - Returning \(domainProfiles.count) domain profiles")

                return domainProfiles
            },
            saveToCache: { [coreDataStack] profiles in
                for profile in profiles {
                    try await coreDataStack.cacheProfile(profile)
                }
            },
        )

        do {
            let result = try await dataSource.fetch(policy: currentCachePolicy)
            let sourceDescription = result.isCached ? "cache" : "remote"
            logger.debug("Fetched profile for \(userId.uuidString), source: \(sourceDescription)")
            return result
        } catch {
            logger.error("Failed to fetch profile: \(error.localizedDescription)")
            throw error
        }
    }

    func updateProfile(userId: UUID, request: UpdateProfileRequest) async throws -> UserProfile {
        // Primary: Edge Function API
        do {
            // Upload avatar via API first if provided
            if let avatarData = request.avatarData {
                let base64String = avatarData.base64EncodedString()
                let avatarRequest = UploadAvatarAPIRequest(imageData: base64String, mimeType: "image/jpeg")
                _ = try await profileAPI.uploadAvatar(avatarRequest)
                logger.info("Avatar uploaded via API for user: \(userId.uuidString)")
            }

            // Update profile fields via API
            let apiRequest = UpdateProfileAPIRequest(
                name: request.nickname,
                bio: request.bio,
                location: request.aboutMe,
            )
            _ = try await profileAPI.updateProfile(apiRequest)

            logger.info("Profile updated via API for user: \(userId.uuidString)")

            // Re-fetch to get the canonical domain model
            return try await fetchProfile(userId: userId)
        } catch {
            logger.warning("API update failed: \(error.localizedDescription), falling back to direct Supabase")
        }

        // Fallback: Direct Supabase
        var avatarUrl: String?
        if let avatarData = request.avatarData {
            avatarUrl = try await uploadAvatar(userId: userId, imageData: avatarData)
        }

        let updateDTO = UpdateProfileDTO(
            nickname: request.nickname,
            bio: request.bio,
            aboutMe: request.aboutMe,
            avatarUrl: avatarUrl,
        )

        _ = try await supabase
            .from("profiles")
            .update(updateDTO)
            .eq("id", value: userId.uuidString)
            .execute()

        logger.info("Profile updated via Supabase fallback for user: \(userId.uuidString)")

        return try await fetchProfile(userId: userId)
    }

    func fetchUserStats(userId: UUID) async throws -> UserStats {
        // Primary: Edge Function dashboard API
        do {
            let dashboard = try await profileAPI.getDashboard()
            if let stats = dashboard.stats {
                let userStats = UserStats(
                    shared: stats.itemsShared ?? 0,
                    received: stats.itemsReceived ?? 0,
                    rating: stats.rating ?? 0.0,
                )
                logger.debug("User stats fetched via API for user: \(userId.uuidString)")
                return userStats
            }
        } catch {
            logger.warning("API dashboard fetch failed: \(error.localizedDescription), falling back to RPC")
        }

        // Fallback: Single RPC call
        let params = UserStatsParams(pUserId: userId)
        return try await executeRPC("get_user_stats", params: params)
    }

    func uploadAvatar(userId: UUID, imageData: Data) async throws -> String {
        // Primary: Edge Function API (handles compression via api-v1-images)
        do {
            let base64String = imageData.base64EncodedString()
            let request = UploadAvatarAPIRequest(imageData: base64String, mimeType: "image/jpeg")
            let result = try await profileAPI.uploadAvatar(request)
            logger.info("Avatar uploaded via API for user: \(userId.uuidString)")
            return result.url
        } catch {
            logger.warning("API avatar upload failed: \(error.localizedDescription), falling back to direct Storage")
        }

        // Fallback: Direct Supabase Storage upload
        let filename = "\(userId.uuidString)-avatar.jpg"
        let path = "avatars/\(filename)"

        _ = try await supabase.storage
            .from("avatars")
            .upload(
                path,
                data: imageData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: true,
                ),
            )

        let publicURL = try supabase.storage
            .from("avatars")
            .getPublicURL(path: path)

        logger.info("Avatar uploaded via Storage fallback for user: \(userId.uuidString)")
        return publicURL.absoluteString
    }

    /// Update the user's search radius preference in the database
    /// - Parameters:
    ///   - userId: The user's UUID
    ///   - radiusKm: The search radius in kilometers (1-800)
    func updateSearchRadius(userId: UUID, radiusKm: Int) async throws {
        // Clamp radius to valid range
        let clampedRadius = max(1, min(800, radiusKm))

        _ = try await supabase
            .from("profiles")
            .update(["search_radius_km": clampedRadius])
            .eq("id", value: userId.uuidString)
            .execute()

        logger.info("Search radius updated to \(clampedRadius)km for user: \(userId.uuidString)")
    }

    // MARK: - Server-Side Analytics

    /// Fetch server-calculated profile analytics
    /// Primary: Edge Function dashboard API, Fallback: RPC
    func fetchProfileAnalytics(userId: UUID) async throws -> ProfileAnalytics {
        logger.debug("Fetching profile analytics for user: \(userId.uuidString)")

        // Primary: Edge Function dashboard API
        do {
            let dashboard = try await profileAPI.getDashboard()
            // Map dashboard DTO to the existing ProfileAnalytics domain model
            let analytics = ProfileAnalytics(
                success: true,
                userId: userId,
                completion: ProfileCompletionData(
                    percentage: 0, // Dashboard endpoint doesn't return completion breakdown
                    completedCount: 0,
                    totalFields: 0,
                    completedFields: [],
                    missingFields: [],
                    isComplete: false,
                    nextStep: nil,
                ),
                rank: CommunityRankData(
                    tier: "newcomer",
                    nextTier: nil,
                    progressToNextTier: 0,
                    totalExchanges: (dashboard.stats?.itemsShared ?? 0) + (dashboard.stats?.itemsReceived ?? 0),
                ),
                impact: ImpactMetricsData(
                    mealsShared: dashboard.stats?.itemsShared ?? 0,
                    mealsReceived: dashboard.stats?.itemsReceived ?? 0,
                    foodSavedKg: dashboard.impact?.foodSavedKg ?? 0,
                    co2SavedKg: dashboard.impact?.co2SavedKg ?? 0,
                    waterSavedLiters: 0,
                    moneySavedUsd: 0,
                    equivalentTrees: 0,
                    equivalentCarMiles: 0,
                ),
                ratingAverage: dashboard.stats?.rating ?? 0,
                ratingCount: dashboard.stats?.ratingCount ?? 0,
                calculatedAt: Date(),
            )
            logger.info("Profile analytics fetched via API for user: \(userId.uuidString)")
            return analytics
        } catch {
            logger.warning("API dashboard failed: \(error.localizedDescription), falling back to RPC")
        }

        // Fallback: RPC call
        let result: ProfileAnalytics = try await executeRPC(
            "get_profile_analytics",
            params: ["p_user_id": userId.uuidString],
        )

        logger
            .info(
                "Profile analytics fetched via RPC - completion: \(result.completion.percentage)%, rank: \(result.rank.tier)",
            )
        return result
    }

    // MARK: - Address Methods

    /// Fetch user's address
    /// Primary: Edge Function API, Fallback: direct Supabase query
    func fetchAddress(profileId: UUID) async throws -> Address? {
        logger.debug("Fetching address for profile: \(profileId.uuidString)")

        // Primary: Edge Function API
        do {
            let dto: AddressDTO? = try await profileAPI.getAddress()
            if let dto {
                let address = dto.toDomain(profileId: profileId)
                logger.debug("Address fetched via API")
                return address
            }
            logger.debug("No address found via API")
            return nil
        } catch {
            logger.warning("API address fetch failed: \(error.localizedDescription), falling back to Supabase")
        }

        // Fallback: Direct Supabase query
        do {
            let addresses: [Address] = try await supabase
                .from("user_addresses")
                .select()
                .eq("profile_id", value: profileId.uuidString)
                .limit(1)
                .execute()
                .value

            let address = addresses.first
            if address != nil {
                logger.debug("Address fetched via Supabase fallback")
            } else {
                logger.debug("No address found for profile")
            }
            return address
        } catch {
            // If no rows found, return nil instead of throwing
            logger.debug("Address fetch returned no results: \(error.localizedDescription)")
            return nil
        }
    }

    /// Upsert (insert or update) user's address
    /// Primary: Edge Function API, Fallback: direct Supabase upsert
    func upsertAddress(profileId: UUID, address: EditableAddress) async throws -> Address {
        logger.debug("Upserting address for profile: \(profileId.uuidString)")

        // Primary: Edge Function API
        do {
            let apiRequest = AddressAPIRequest(
                addressLine1: address.addressLine1.isEmpty ? " " : address.addressLine1,
                addressLine2: address.addressLine2.isEmpty ? nil : address.addressLine2,
                city: address.city.isEmpty ? " " : address.city,
                stateProvince: address.stateProvince.isEmpty ? nil : address.stateProvince,
                postalCode: address.postalCode.isEmpty ? nil : address.postalCode,
                country: address.country.isEmpty ? " " : address.country,
                lat: address.latitude,
                lng: address.longitude,
            )
            let dto = try await profileAPI.updateAddress(apiRequest)
            let result = dto.toDomain(profileId: profileId)
            logger.info("Address upserted via API for profile: \(profileId.uuidString)")
            return result
        } catch {
            logger.warning("API address upsert failed: \(error.localizedDescription), falling back to Supabase")
        }

        // Fallback: Direct Supabase upsert
        let dto = AddressUpsertDTO(
            profileId: profileId,
            addressLine1: address.addressLine1.isEmpty ? nil : address.addressLine1,
            addressLine2: address.addressLine2.isEmpty ? nil : address.addressLine2,
            city: address.city.isEmpty ? nil : address.city,
            stateProvince: address.stateProvince.isEmpty ? nil : address.stateProvince,
            postalCode: address.postalCode.isEmpty ? nil : address.postalCode,
            country: address.country.isEmpty ? nil : address.country,
            latitude: address.latitude,
            longitude: address.longitude,
        )

        let result: Address = try await supabase
            .from("user_addresses")
            .upsert(dto, onConflict: "profile_id")
            .select()
            .single()
            .execute()
            .value

        logger.info("Address upserted via Supabase fallback for profile: \(profileId.uuidString)")
        return result
    }

    /// Delete user's address
    func deleteAddress(profileId: UUID) async throws {
        logger.debug("Deleting address for profile: \(profileId.uuidString)")

        _ = try await supabase
            .from("user_addresses")
            .delete()
            .eq("profile_id", value: profileId.uuidString)
            .execute()

        logger.info("Address deleted for profile: \(profileId.uuidString)")
    }

    // MARK: - Blocking

    func blockUser(userId: UUID, blockedUserId: UUID, reason: String?) async throws {
        logger.debug("Blocking user \(blockedUserId.uuidString) by \(userId.uuidString)")

        let blockDTO = BlockUserDTO(
            userId: userId.uuidString,
            blockedUserId: blockedUserId.uuidString,
            reason: reason,
        )

        _ = try await supabase
            .from("blocked_users")
            .insert(blockDTO)
            .execute()

        logger.info("User blocked successfully")
    }

    func unblockUser(userId: UUID, blockedUserId: UUID) async throws {
        logger.debug("Unblocking user \(blockedUserId.uuidString) by \(userId.uuidString)")

        _ = try await supabase
            .from("blocked_users")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("blocked_user_id", value: blockedUserId.uuidString)
            .execute()

        logger.info("User unblocked successfully")
    }

    func getBlockedUsers(userId: UUID) async throws -> [BlockedUser] {
        logger.debug("Fetching blocked users for \(userId.uuidString)")

        let result: [BlockedUserDTO] = try await supabase
            .from("blocked_users")
            .select("""
                id,
                blocked_user_id,
                blocked_at,
                reason,
                blocked_profile:profiles!blocked_user_id(nickname, avatar_url)
            """)
            .eq("user_id", value: userId.uuidString)
            .order("blocked_at", ascending: false)
            .execute()
            .value

        return result.map { $0.toDomain() }
    }

    func isUserBlocked(userId: UUID, targetUserId: UUID) async throws -> Bool {
        logger.debug("Checking if \(targetUserId.uuidString) is blocked by \(userId.uuidString)")

        let result: [BlockedUserDTO] = try await supabase
            .from("blocked_users")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .eq("blocked_user_id", value: targetUserId.uuidString)
            .limit(1)
            .execute()
            .value

        return !result.isEmpty
    }
}

// MARK: - API DTO Domain Mapping

extension ProfileDTO {
    /// Convert Edge Function profile response to domain model
    func toDomain() -> UserProfile {
        UserProfile(
            id: id,
            nickname: name ?? "Unknown",
            avatarUrl: avatarUrl,
            bio: bio,
            aboutMe: location,
            ratingAverage: ratingAverage ?? 0.0,
            itemsShared: 0, // Not returned by GET profile; use dashboard for stats
            itemsReceived: 0,
            ratingCount: ratingCount ?? 0,
            createdTime: createdAt ?? Date(),
            searchRadiusKm: nil,
            preferredLocale: nil,
        )
    }
}

extension AddressDTO {
    /// Convert Edge Function address response to domain model
    func toDomain(profileId: UUID) -> Address {
        Address(
            id: UUID(), // API doesn't return the row ID
            profileId: self.profileId ?? profileId,
            addressLine1: addressLine1,
            addressLine2: addressLine2,
            city: city,
            stateProvince: stateProvince,
            postalCode: postalCode,
            country: country,
            latitude: lat,
            longitude: lng,
            createdAt: Date(),
            updatedAt: Date(),
        )
    }
}

// MARK: - DTOs

struct BlockUserDTO: Encodable {
    let userId: String
    let blockedUserId: String
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case blockedUserId = "blocked_user_id"
        case reason
    }
}

/// Basic profile data without stats (for more reliable queries)
struct BasicProfileDTO: Codable {
    let id: String
    let nickname: String
    let avatarUrl: String?
    let bio: String?
    let aboutMe: String?
    let createdTime: String
    let searchRadiusKm: Int?
    let preferredLocale: String?

    enum CodingKeys: String, CodingKey {
        case id, nickname, bio
        case avatarUrl = "avatar_url"
        case aboutMe = "about_me"
        case createdTime = "created_time"
        case searchRadiusKm = "search_radius_km"
        case preferredLocale = "preferred_locale"
    }
}

/// Legacy DTO - kept for backward compatibility but no longer used
struct UserProfileDTO: Codable {
    let id: String
    let nickname: String
    let avatarUrl: String?
    let bio: String?
    let aboutMe: String?
    let createdTime: String
    let searchRadiusKm: Int?
    let preferredLocale: String?
    let profileStats: [ProfileStatsDTO]?

    enum CodingKeys: String, CodingKey {
        case id, nickname, bio
        case avatarUrl = "avatar_url"
        case aboutMe = "about_me"
        case createdTime = "created_time"
        case searchRadiusKm = "search_radius_km"
        case preferredLocale = "preferred_locale"
        case profileStats = "profile_stats"
    }

    func toDomain() -> UserProfile {
        UserProfile(
            id: UUID(uuidString: id) ?? UUID(),
            nickname: nickname,
            avatarUrl: avatarUrl,
            bio: bio,
            aboutMe: aboutMe,
            ratingAverage: profileStats?.first?.ratingAverage ?? 0.0,
            itemsShared: profileStats?.first?.itemsShared ?? 0,
            itemsReceived: profileStats?.first?.itemsReceived ?? 0,
            ratingCount: profileStats?.first?.ratingCount ?? 0,
            createdTime: ISO8601DateFormatter().date(from: createdTime) ?? Date(),
            searchRadiusKm: searchRadiusKm,
            preferredLocale: preferredLocale,
        )
    }
}

struct ProfileStatsDTO: Codable {
    let ratingAverage: Double?
    let itemsShared: Int?
    let itemsReceived: Int?
    let ratingCount: Int?

    enum CodingKeys: String, CodingKey {
        case ratingAverage = "rating_average"
        case itemsShared = "items_shared"
        case itemsReceived = "items_received"
        case ratingCount = "rating_count"
    }
}

/// Parameters for the get_user_stats RPC
private struct UserStatsParams: Encodable {
    let pUserId: UUID

    enum CodingKeys: String, CodingKey {
        case pUserId = "p_user_id"
    }
}

/// Response from the get_user_stats RPC
private struct UserStatsRPCResponse: Decodable {
    let shared: Int
    let received: Int
    let rating: Double
}

extension UserStatsRPCResponse {
    func toDomain() -> UserStats {
        UserStats(shared: shared, received: received, rating: rating)
    }
}

struct UpdateProfileDTO: Encodable {
    let nickname: String?
    let bio: String?
    let aboutMe: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case nickname, bio
        case aboutMe = "about_me"
        case avatarUrl = "avatar_url"
    }
}

struct CreateProfileDTO: Encodable {
    let id: String
    let email: String?
    let nickname: String
}

/// DTO for upserting user addresses
struct AddressUpsertDTO: Encodable {
    let profileId: UUID
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let stateProvince: String?
    let postalCode: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case addressLine1 = "address_line1"
        case addressLine2 = "address_line2"
        case city
        case stateProvince = "state_province"
        case postalCode = "postal_code"
        case country
        case latitude
        case longitude
    }
}


#endif
