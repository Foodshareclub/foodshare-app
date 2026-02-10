package com.foodshare.core.validation

import com.foodshare.core.network.EdgeFunctionClient
import kotlinx.serialization.Serializable

/**
 * Server-side validation client.
 *
 * Calls Edge Functions for validation as the single source of truth.
 * Use this after local Swift validation for security-critical operations.
 *
 * Validation Flow:
 * 1. Swift client validation (instant UX feedback)
 * 2. If valid -> Server validation (security + business rules)
 * 3. If valid -> Database insert (RLS + constraints)
 *
 * Edge Functions:
 * - validate-listing
 * - validate-profile
 * - validate-review
 */
object ServerValidation {

    /**
     * Validate a listing on the server.
     *
     * @param client EdgeFunctionClient instance
     * @param title Listing title
     * @param description Listing description
     * @param quantity Item quantity
     * @param expiresAt Optional expiration date (ISO 8601)
     * @return ValidationResult from server
     */
    suspend fun validateListing(
        client: EdgeFunctionClient,
        title: String,
        description: String = "",
        quantity: Int = 1,
        expiresAt: String? = null
    ): Result<ServerValidationResult> {
        return client.invoke(
            functionName = "validate-listing",
            body = ValidateListingRequest(
                title = title,
                description = description,
                quantity = quantity,
                expiresAt = expiresAt
            )
        )
    }

    /**
     * Validate a profile on the server.
     *
     * @param client EdgeFunctionClient instance
     * @param nickname User nickname
     * @param bio User bio
     * @return ValidationResult from server
     */
    suspend fun validateProfile(
        client: EdgeFunctionClient,
        nickname: String? = null,
        bio: String? = null
    ): Result<ServerValidationResult> {
        return client.invoke(
            functionName = "validate-profile",
            body = ValidateProfileRequest(
                nickname = nickname,
                bio = bio
            )
        )
    }

    /**
     * Validate a review on the server.
     *
     * @param client EdgeFunctionClient instance
     * @param rating Review rating (1-5)
     * @param comment Optional review comment
     * @param revieweeId ID of user being reviewed
     * @return ValidationResult from server
     */
    suspend fun validateReview(
        client: EdgeFunctionClient,
        rating: Int,
        comment: String? = null,
        revieweeId: String? = null
    ): Result<ServerValidationResult> {
        return client.invoke(
            functionName = "validate-review",
            body = ValidateReviewRequest(
                rating = rating,
                comment = comment,
                revieweeId = revieweeId
            )
        )
    }
}

// =============================================================================
// Request/Response Types
// =============================================================================

@Serializable
internal data class ValidateListingRequest(
    val title: String,
    val description: String? = null,
    val quantity: Int? = null,
    val expiresAt: String? = null
)

@Serializable
internal data class ValidateProfileRequest(
    val nickname: String? = null,
    val bio: String? = null
)

@Serializable
internal data class ValidateReviewRequest(
    val rating: Int,
    val comment: String? = null,
    val revieweeId: String? = null
)

/**
 * Server validation result matching Edge Function response.
 */
@Serializable
data class ServerValidationResult(
    val isValid: Boolean,
    val errors: List<String> = emptyList()
) {
    /**
     * Convert to local ValidationResult for UI consumption.
     */
    fun toValidationResult(): ValidationResult {
        return ValidationResult(
            isValid = isValid,
            errors = errors.map { ValidationError.Custom(it) }
        )
    }

    val firstError: String?
        get() = errors.firstOrNull()

    companion object {
        val valid = ServerValidationResult(isValid = true, errors = emptyList())
    }
}

// =============================================================================
// Extension Functions for EdgeFunctionClient
// =============================================================================

/**
 * Validate a listing via Edge Function.
 */
suspend fun EdgeFunctionClient.validateListing(
    title: String,
    description: String = "",
    quantity: Int = 1,
    expiresAt: String? = null
): Result<ServerValidationResult> {
    return ServerValidation.validateListing(this, title, description, quantity, expiresAt)
}

/**
 * Validate a profile via Edge Function.
 */
suspend fun EdgeFunctionClient.validateProfile(
    nickname: String? = null,
    bio: String? = null
): Result<ServerValidationResult> {
    return ServerValidation.validateProfile(this, nickname, bio)
}

/**
 * Validate a review via Edge Function.
 */
suspend fun EdgeFunctionClient.validateReview(
    rating: Int,
    comment: String? = null,
    revieweeId: String? = null
): Result<ServerValidationResult> {
    return ServerValidation.validateReview(this, rating, comment, revieweeId)
}
