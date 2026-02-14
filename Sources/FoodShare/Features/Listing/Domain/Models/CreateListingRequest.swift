//
//  CreateListingRequest.swift
//  Foodshare
//
//  Request models for creating and updating food listings.
//

#if !SKIP
import CoreLocation
#endif
import Foundation

// MARK: - CreateListingRequest

/// Request model for creating a new food listing.
///
/// Use this model to encapsulate all data needed to create a listing.
/// Call `validate()` before submission to ensure data integrity.
///
/// ## Example
/// ```swift
/// let request = CreateListingRequest(
///     userId: currentUser.id,
///     title: "Fresh Apples",
///     description: "Organic apples from my garden",
///     quantity: "5 apples",
///     categoryId: 1,
///     expiryDate: Date().addingTimeInterval(86400 * 3),
///     pickupLocation: userLocation,
///     pickupAddress: "123 Main St",
///     images: [imageData]
/// )
/// try request.validate()
/// ```
struct CreateListingRequest: Sendable {
    /// The ID of the user creating the listing (profile_id in posts table)
    let userId: UUID

    /// Title of the food listing (post_name, 3-100 characters)
    let title: String

    /// Optional detailed description of the food item (post_description)
    let description: String?

    /// Optional category ID for filtering
    let categoryId: Int?

    /// Post type matching web app categories (food, things, borrow, wanted, zerowaste, vegan)
    let postType: String

    /// Pickup time description (e.g., "Anytime today", "After 5pm")
    let pickupTime: String?

    /// Pickup location coordinates
    let pickupLocation: CLLocationCoordinate2D

    /// Human-readable pickup address (post_address)
    let pickupAddress: String?

    /// Image data for the listing (1-3 images required)
    let images: [Data]

    /// Validates the request data before submission.
    ///
    /// - Throws: `ListingError` if validation fails:
    ///   - `.invalidTitle` if title is not 3-100 characters
    ///   - `.invalidImageCount` if not 1-3 images
    func validate() throws {
        guard title.count >= 3, title.count <= 100 else {
            throw ListingError.invalidTitle
        }

        guard images.count >= 1, images.count <= 3 else {
            throw ListingError.invalidImageCount
        }
    }

    /// Creates a copy of this request with a different user ID.
    ///
    /// - Parameter userId: The user ID to set
    /// - Returns: A new request with the specified user ID
    func with(userId: UUID) -> CreateListingRequest {
        CreateListingRequest(
            userId: userId,
            title: title,
            description: description,
            categoryId: categoryId,
            postType: postType,
            pickupTime: pickupTime,
            pickupLocation: pickupLocation,
            pickupAddress: pickupAddress,
            images: images,
        )
    }
}

// MARK: - UpdateListingRequest

/// Request model for updating an existing food listing.
///
/// Only non-nil properties will be updated. Call `validate()` to ensure
/// any provided values meet requirements.
///
/// ## Example
/// ```swift
/// let request = UpdateListingRequest(
///     listingId: 123,
///     title: "Updated Title",
///     status: "arranged"
/// )
/// try request.validate()
/// ```
struct UpdateListingRequest: Sendable {
    /// The ID of the listing to update
    let listingId: Int

    /// New title (post_name, 3-100 characters if provided)
    let title: String?

    /// New description (post_description)
    let description: String?

    /// New category ID
    let categoryId: Int?

    /// Whether the listing is active (is_active)
    let isActive: Bool?

    /// Whether the listing is arranged (is_arranged)
    let isArranged: Bool?

    /// Validates any provided update values.
    ///
    /// - Throws: `ListingError` if validation fails for any non-nil field
    func validate() throws {
        if let title {
            guard title.count >= 3, title.count <= 100 else {
                throw ListingError.invalidTitle
            }
        }
    }
}

// MARK: - ListingError

/// Errors that can occur during listing creation or update.
///
/// Thread-safe for Swift 6 concurrency.
enum ListingError: LocalizedError, Sendable {
    /// Title is not between 3-100 characters (client-side optimistic check)
    case invalidTitle

    /// Image count is not between 1-3 (client-side optimistic check)
    case invalidImageCount

    /// Image upload to storage failed
    case uploadFailed

    /// Server-side validation failed (authoritative)
    case serverValidationFailed([ListingValidationError])

    /// Server returned an error during operation
    case serverError(String)

    /// Resource not found (listing doesn't exist)
    case notFound

    /// User not authorized to perform this action
    case forbidden

    var errorDescription: String? {
        switch self {
        case .invalidTitle:
            "Title must be between 3 and 100 characters"
        case .invalidImageCount:
            "Please add 1-3 photos"
        case .uploadFailed:
            "Failed to upload images"
        case let .serverValidationFailed(errors):
            errors.first?.message ?? "Validation failed"
        case let .serverError(message):
            message
        case .notFound:
            "Listing not found"
        case .forbidden:
            "You don't have permission to perform this action"
        }
    }

    /// All validation errors (for displaying multiple errors)
    var validationErrors: [ListingValidationError] {
        if case let .serverValidationFailed(errors) = self {
            return errors
        }
        return []
    }
}

// MARK: - Test Fixtures

extension CreateListingRequest {
    /// Create a fixture for testing
    static func fixture(
        userId: UUID = UUID(),
        title: String = "Fresh Apples",
        description: String? = "Delicious organic apples",
        categoryId: Int? = 1,
        postType: String = "food",
        pickupTime: String? = "Anytime today",
        pickupLocation: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        pickupAddress: String? = "123 Main St, London",
        images: [Data] = [Data()],
    ) -> CreateListingRequest {
        CreateListingRequest(
            userId: userId,
            title: title,
            description: description,
            categoryId: categoryId,
            postType: postType,
            pickupTime: pickupTime,
            pickupLocation: pickupLocation,
            pickupAddress: pickupAddress,
            images: images,
        )
    }
}

extension UpdateListingRequest {
    /// Create a fixture for testing
    static func fixture(
        listingId: Int = 1,
        title: String? = nil,
        description: String? = nil,
        categoryId: Int? = nil,
        isActive: Bool? = nil,
        isArranged: Bool? = nil,
    ) -> UpdateListingRequest {
        UpdateListingRequest(
            listingId: listingId,
            title: title,
            description: description,
            categoryId: categoryId,
            isActive: isActive,
            isArranged: isArranged,
        )
    }
}
