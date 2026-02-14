//
//  EditProfileViewModel.swift
//  FoodShare
//
//  Dedicated ViewModel for editing user profile with:
//  - Form state management
//  - Image selection, processing, and upload
//  - Validation with inline errors
//  - Save with success feedback
//

import Foundation
import Observation
import OSLog
import PhotosUI
import SwiftUI
#if !SKIP
import UIKit
#endif

// MARK: - Validation Error

/// Validation errors for profile form fields
enum ProfileValidationError: LocalizedError, Sendable {
    case nicknameRequired
    case nicknameTooShort
    case nicknameTooLong
    case bioTooLong
    case locationTooLong
    case searchRadiusInvalid

    var errorDescription: String? {
        switch self {
        case .nicknameRequired: "Display name is required"
        case .nicknameTooShort: "Display name must be at least 2 characters"
        case .nicknameTooLong: "Display name must be less than 50 characters"
        case .bioTooLong: "Bio must be less than 500 characters"
        case .locationTooLong: "Location must be less than 200 characters"
        case .searchRadiusInvalid: "Search radius must be between 1 and 800 km"
        }
    }

    var fieldKey: String {
        switch self {
        case .nicknameRequired, .nicknameTooShort, .nicknameTooLong: "nickname"
        case .bioTooLong: "bio"
        case .locationTooLong: "location"
        case .searchRadiusInvalid: "searchRadius"
        }
    }
}

// MARK: - Edit Profile ViewModel

@MainActor
@Observable
final class EditProfileViewModel {
    // MARK: - Form State

    var nickname = ""
    var bio = ""
    var location = ""
    var searchRadiusKm = 5.0

    // MARK: - Address State

    var address: EditableAddress = .empty
    var showAddressPicker = false
    private var originalAddress: Address?

    // MARK: - Image State

    var selectedPhotoItem: PhotosPickerItem?
    var selectedImageData: Data?
    var previewImage: UIImage?

    // MARK: - UI State

    private(set) var isSaving = false
    private(set) var isUploadingAvatar = false
    private(set) var validationErrors: [String: ProfileValidationError] = [:]
    var showSuccessToast = false
    var errorMessage: String?
    var showError = false

    // MARK: - Computed Properties

    var hasChanges: Bool {
        guard let profile = originalProfile else { return selectedImageData != nil || addressChanged }
        let nicknameChanged = nickname != profile.nickname
        let bioChanged = bio != (profile.bio ?? "")
        let locationChanged = location != (profile.location ?? "")
        let radiusChanged = Int(searchRadiusKm) != (profile.searchRadiusKm ?? 5)
        let avatarChanged = selectedImageData != nil
        return nicknameChanged || bioChanged || locationChanged || radiusChanged || avatarChanged || addressChanged
    }

    /// Check if address has been modified
    var addressChanged: Bool {
        address != EditableAddress(from: originalAddress)
    }

    var nicknameError: String? {
        validationErrors["nickname"]?.errorDescription
    }

    var bioError: String? {
        validationErrors["bio"]?.errorDescription
    }

    var locationError: String? {
        validationErrors["location"]?.errorDescription
    }

    var searchRadiusError: String? {
        validationErrors["searchRadius"]?.errorDescription
    }

    var bioCharacterCount: Int {
        bio.count
    }
    var bioCharacterLimit: Int {
        500
    }
    var isBioOverLimit: Bool {
        bioCharacterCount > bioCharacterLimit
    }

    var displayAvatarUrl: String? {
        originalProfile?.avatarUrl
    }

    // MARK: - Dependencies

    private let repository: ProfileRepository
    private let userId: UUID
    private var originalProfile: UserProfile?
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "EditProfileViewModel")

    // MARK: - Initialization

    init(repository: ProfileRepository, userId: UUID, profile: UserProfile? = nil) {
        self.repository = repository
        self.userId = userId
        self.originalProfile = profile

        // Initialize form with current profile data
        if let profile {
            nickname = profile.nickname
            bio = profile.bio ?? ""
            location = profile.location ?? ""
            searchRadiusKm = Double(profile.searchRadiusKm ?? 5)
        } else {
            // Fetch profile if not provided
            Task {
                await loadProfile()
            }
        }
    }

    // MARK: - Profile Loading

    /// Load profile from repository if not provided at init
    func loadProfile() async {
        do {
            let profile = try await repository.fetchProfile(userId: userId)
            self.originalProfile = profile
            self.nickname = profile.nickname
            self.bio = profile.bio ?? ""
            self.location = profile.location ?? ""
            self.searchRadiusKm = Double(profile.searchRadiusKm ?? 5)

            // Fetch address separately
            if let fetchedAddress = try? await repository.fetchAddress(profileId: userId) {
                self.originalAddress = fetchedAddress
                self.address = EditableAddress(from: fetchedAddress)
            }
        } catch {
            logger.error("Failed to fetch profile: \(error.localizedDescription)")
        }
    }

    // MARK: - Photo Selection

    /// Load and process the selected photo item
    func loadSelectedPhoto() async {
        guard let item = selectedPhotoItem else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                await processSelectedImage(data)
            }
        } catch {
            logger.error("Failed to load photo: \(error.localizedDescription)")
            errorMessage = "Failed to load photo"
            showError = true
            HapticManager.error()
        }
    }

    /// Process selected image: resize and compress
    private func processSelectedImage(_ data: Data) async {
        guard let originalImage = UIImage(data: data) else {
            logger.error("Failed to create UIImage from data")
            return
        }

        // Resize to 512x512 for avatars
        let resizedImage = resizeImage(originalImage, targetSize: CGSize(width: 512, height: 512))

        // Compress to JPEG with 0.8 quality
        guard let compressedData = resizedImage.jpegData(compressionQuality: 0.8) else {
            logger.error("Failed to compress image")
            return
        }

        selectedImageData = compressedData
        previewImage = resizedImage
        HapticManager.success()
        logger.debug("Image processed: \(compressedData.count) bytes")
    }

    /// Resize image maintaining aspect ratio
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)

        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Clear selected photo
    func clearSelectedPhoto() {
        selectedPhotoItem = nil
        selectedImageData = nil
        previewImage = nil
    }

    // MARK: - Validation

    /// Validate all form fields
    @discardableResult
    func validate() -> Bool {
        validationErrors.removeAll()

        // Nickname validation
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedNickname.isEmpty {
            validationErrors["nickname"] = .nicknameRequired
        } else if trimmedNickname.count < 2 {
            validationErrors["nickname"] = .nicknameTooShort
        } else if trimmedNickname.count > 50 {
            validationErrors["nickname"] = .nicknameTooLong
        }

        // Bio validation (optional)
        if bio.count > 500 {
            validationErrors["bio"] = .bioTooLong
        }

        // Location validation (optional)
        if location.count > 200 {
            validationErrors["location"] = .locationTooLong
        }

        // Search radius validation (max 800km = ~500 miles)
        if searchRadiusKm < 1 || searchRadiusKm > 800 {
            validationErrors["searchRadius"] = .searchRadiusInvalid
        }

        return validationErrors.isEmpty
    }

    /// Clear validation error for a specific field
    func clearValidationError(for field: String) {
        validationErrors.removeValue(forKey: field)
    }

    // MARK: - Save

    /// Save profile changes
    func save() async -> Bool {
        // Validate first
        guard validate() else {
            HapticManager.error()
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            // Upload avatar if selected
            var avatarDataToUpload: Data?
            if selectedImageData != nil {
                isUploadingAvatar = true
                avatarDataToUpload = selectedImageData
            }

            // Create update request
            let request = UpdateProfileRequest(
                nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                bio: bio.isEmpty ? nil : bio.trimmingCharacters(in: .whitespacesAndNewlines),
                aboutMe: location.isEmpty ? nil : location.trimmingCharacters(in: .whitespacesAndNewlines),
                searchRadiusKm: Int(searchRadiusKm),
                preferredLocale: nil,
                avatarData: avatarDataToUpload,
            )

            // Update profile
            let updatedProfile = try await repository.updateProfile(userId: userId, request: request)
            originalProfile = updatedProfile
            isUploadingAvatar = false

            // Save address if changed
            if addressChanged {
                if address.hasContent {
                    let savedAddress = try await repository.upsertAddress(profileId: userId, address: address)
                    originalAddress = savedAddress
                    logger.info("Address saved successfully")
                } else if originalAddress != nil {
                    // Address was cleared - delete it
                    try await repository.deleteAddress(profileId: userId)
                    originalAddress = nil
                    logger.info("Address deleted")
                }
            }

            // Clear selected image after successful upload
            clearSelectedPhoto()

            // Show success
            showSuccessToast = true
            HapticManager.success()
            logger.info("Profile saved successfully")

            return true

        } catch {
            isUploadingAvatar = false
            errorMessage = error.localizedDescription
            showError = true
            HapticManager.error()
            logger.error("Failed to save profile: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Helpers

    /// Reset form to original profile values
    func resetToOriginal() {
        guard let profile = originalProfile else { return }
        nickname = profile.nickname
        bio = profile.bio ?? ""
        location = profile.location ?? ""
        searchRadiusKm = Double(profile.searchRadiusKm ?? 5)
        address = EditableAddress(from: originalAddress)
        clearSelectedPhoto()
        validationErrors.removeAll()
    }

    /// Update profile reference (for external refresh)
    func updateProfile(_ profile: UserProfile) {
        originalProfile = profile
        nickname = profile.nickname
        bio = profile.bio ?? ""
        location = profile.location ?? ""
        searchRadiusKm = Double(profile.searchRadiusKm ?? 5)
    }

    /// Update address from picker
    func updateAddress(_ newAddress: EditableAddress) {
        address = newAddress
    }
}
