//
//  SupabaseReviewRepository.swift
//  Foodshare
//
//  Supabase implementation of ReviewRepository
//  Uses ReviewAPIService (Edge Function) as primary path with direct Supabase fallback
//



#if !SKIP
import Foundation
import OSLog
import Supabase

// MARK: - RPC Parameter Structs

private struct PostOwner: Decodable {
    let profileId: UUID
}

private struct ReviewsWithAverageParams: Codable, Sendable {
    let p_post_id: Int
    let p_user_id: String?
}

private struct UserReviewsWithAverageParams: Codable, Sendable {
    let p_user_id: String
    let p_viewer_id: String?
}

/// Supabase implementation of review repository
@MainActor
final class SupabaseReviewRepository: BaseSupabaseRepository, ReviewRepository {
    private let reviewAPI: ReviewAPIService

    init(supabase: Supabase.SupabaseClient, reviewAPI: ReviewAPIService = .shared) {
        self.reviewAPI = reviewAPI
        super.init(supabase: supabase, subsystem: "com.flutterflow.foodshare", category: "ReviewRepository")
    }

    private let reviewSelectQuery = """
        *,
        profiles(id, nickname, avatar_url, is_verified)
    """

    // MARK: - Fetch Reviews for Post

    func fetchReviews(forPostId postId: Int) async throws -> [Review] {
        do {
            // Try API first
            let dtos = try await reviewAPI.getReviews(postId: postId)
            logger.debug("Fetched \(dtos.count) reviews for post \(postId) via API")
            return dtos.map { $0.toDomain() }
        } catch {
            logger.warning("API fetch reviews for post \(postId) failed, falling back to direct query: \(error.localizedDescription)")
        }

        // Fallback: direct Supabase query
        do {
            // Get current user ID for blocking filter
            let currentUserId = try? await supabase.auth.session.user.id

            // Use RPC with blocking filter if user is authenticated
            if let userId = currentUserId {
                let result = try await fetchReviewsWithAverage(forPostId: postId, userId: userId)
                return result.reviews
            }

            // Fallback to direct query (no blocking filter for anonymous users)
            let response = try await supabase
                .from("reviews")
                .select(reviewSelectQuery)
                .eq("post_id", value: postId)
                .order("created_at", ascending: false)
                .execute()
            return try decoder.decode([Review].self, from: response.data)
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Fetch Reviews by User (reviews they wrote)

    func fetchReviews(byUserId userId: UUID) async throws -> [Review] {
        do {
            // Try API first
            let dtos = try await reviewAPI.getReviews(userId: userId.uuidString)
            logger.debug("Fetched \(dtos.count) reviews by user \(userId) via API")
            return dtos.map { $0.toDomain() }
        } catch {
            logger.warning("API fetch reviews by user \(userId) failed, falling back to direct query: \(error.localizedDescription)")
        }

        // Fallback: direct Supabase query
        do {
            let response = try await supabase
                .from("reviews")
                .select(reviewSelectQuery)
                .eq("profile_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
            return try decoder.decode([Review].self, from: response.data)
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Fetch Reviews for User (reviews they received)

    func fetchReviews(forUserId userId: UUID) async throws -> [Review] {
        do {
            // Try API first
            let dtos = try await reviewAPI.getReviews(userId: userId.uuidString)
            logger.debug("Fetched \(dtos.count) reviews for user \(userId) via API")
            return dtos.map { $0.toDomain() }
        } catch {
            logger.warning("API fetch reviews for user \(userId) failed, falling back to direct query: \(error.localizedDescription)")
        }

        // Fallback: direct Supabase query
        do {
            // Get current user ID for blocking filter
            let currentUserId = try? await supabase.auth.session.user.id

            // Use RPC with blocking filter if user is authenticated
            if let viewerId = currentUserId {
                let result = try await fetchReviewsWithAverage(forUserId: userId, viewerId: viewerId)
                return result.reviews
            }

            // Fallback to direct query (no blocking filter for anonymous users)
            let response = try await supabase
                .from("reviews")
                .select("""
                    *,
                    profiles(id, nickname, avatar_url, is_verified),
                    posts!inner(profile_id)
                """)
                .eq("posts.profile_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
            return try decoder.decode([Review].self, from: response.data)
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Create Review

    func createReview(_ request: CreateReviewRequest) async throws -> Review {
        do {
            // Try API first
            let submitRequest = SubmitReviewRequest(
                revieweeId: request.profileId.uuidString,
                postId: request.postId ?? 0,
                rating: request.reviewedRating,
                feedback: request.feedback.isEmpty ? nil : request.feedback
            )
            let dto = try await reviewAPI.submitReview(submitRequest)
            logger.debug("Created review \(dto.id) via API")

            // Update profile stats after creating review (non-blocking)
            Task { await updateProfileStats(for: request) }

            return dto.toDomain()
        } catch {
            logger.warning("API create review failed, falling back to direct insert: \(error.localizedDescription)")
        }

        // Fallback: direct Supabase insert
        do {
            let response = try await supabase
                .from("reviews")
                .insert(request)
                .select()
                .single()
                .execute()
            let review = try decoder.decode(Review.self, from: response.data)

            // Update profile stats after creating review (non-blocking)
            Task { await updateProfileStats(for: request) }

            return review
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Delete Review (direct Supabase - may not be in API)

    func deleteReview(id: Int, userId: UUID) async throws {
        do {
            _ = try await supabase
                .from("reviews")
                .delete()
                .eq("id", value: id)
                .eq("profile_id", value: userId.uuidString)
                .execute()
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Has Reviewed (direct Supabase - simple count check)

    func hasReviewed(postId: Int, userId: UUID) async throws -> Bool {
        do {
            let response = try await supabase
                .from("reviews")
                .select("id", head: true, count: CountOption.exact)
                .eq("post_id", value: postId)
                .eq("profile_id", value: userId.uuidString)
                .execute()
            return (response.count ?? 0) > 0
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Server-Side Average Rating (kept as RPC - server-side aggregation)

    func fetchReviewsWithAverage(forPostId postId: Int) async throws -> ReviewsWithAverageResult {
        // Get current user ID for blocking filter
        let currentUserId = try? await supabase.auth.session.user.id

        let dto: ReviewsWithAverageDTO = try await executeRPC(
            "get_reviews_with_average",
            params: ReviewsWithAverageParams(
                p_post_id: postId,
                p_user_id: currentUserId?.uuidString,
            ),
        )

        return ReviewsWithAverageResult(
            reviews: dto.reviews,
            averageRating: dto.averageRating,
            totalCount: dto.totalCount,
        )
    }

    func fetchReviewsWithAverage(forPostId postId: Int, userId: UUID) async throws -> ReviewsWithAverageResult {
        let dto: ReviewsWithAverageDTO = try await executeRPC(
            "get_reviews_with_average",
            params: ReviewsWithAverageParams(
                p_post_id: postId,
                p_user_id: userId.uuidString,
            ),
        )

        return ReviewsWithAverageResult(
            reviews: dto.reviews,
            averageRating: dto.averageRating,
            totalCount: dto.totalCount,
        )
    }

    func fetchReviewsWithAverage(forUserId userId: UUID) async throws -> ReviewsWithAverageResult {
        // Get current user ID for blocking filter
        let currentUserId = try? await supabase.auth.session.user.id

        let dto: ReviewsWithAverageDTO = try await executeRPC(
            "get_user_reviews_with_average",
            params: UserReviewsWithAverageParams(
                p_user_id: userId.uuidString,
                p_viewer_id: currentUserId?.uuidString,
            ),
        )

        return ReviewsWithAverageResult(
            reviews: dto.reviews,
            averageRating: dto.averageRating,
            totalCount: dto.totalCount,
        )
    }

    func fetchReviewsWithAverage(forUserId userId: UUID, viewerId: UUID) async throws -> ReviewsWithAverageResult {
        let dto: ReviewsWithAverageDTO = try await executeRPC(
            "get_user_reviews_with_average",
            params: [
                "p_user_id": userId.uuidString,
                "p_viewer_id": viewerId.uuidString,
            ],
        )

        return ReviewsWithAverageResult(
            reviews: dto.reviews,
            averageRating: dto.averageRating,
            totalCount: dto.totalCount,
        )
    }

    // MARK: - Private

    private func updateProfileStats(for request: CreateReviewRequest) async {
        guard let postId = request.postId else { return }

        do {
            let postOwner: PostOwner = try await fetchOne(
                from: "posts",
                select: "profile_id",
                id: postId,
            )

            try await executeRPC(
                "update_user_rating",
                params: ["user_id": postOwner.profileId.uuidString],
            )
        } catch {
            logger.warning("Failed to update profile stats: \(error.localizedDescription)")
        }
    }
}

// MARK: - DTOs

/// DTO for decoding the get_reviews_with_average RPC response
private struct ReviewsWithAverageDTO: Decodable {
    let reviews: [Review]
    let averageRating: Double
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case reviews
        case averageRating = "average_rating"
        case totalCount = "total_count"
    }
}

// MARK: - ReviewDTO → Domain Mapping

extension ReviewDTO {
    /// Convert API DTO to domain Review model
    func toDomain() -> Review {
        Review(
            id: id,
            profileId: profileId ?? UUID(),
            postId: postId,
            forumId: nil,
            challengeId: nil,
            reviewedRating: reviewedRating,
            feedback: feedback ?? "",
            notes: "",
            createdAt: createdAt ?? Date(),
            reviewer: nil
        )
    }
}


#endif
