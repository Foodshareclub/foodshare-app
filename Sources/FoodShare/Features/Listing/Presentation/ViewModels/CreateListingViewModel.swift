//
//  CreateListingViewModel.swift
//  Foodshare
//
//  ViewModel for creating food listings
//  Enhanced with draft saving, validation feedback, and image optimization
//

#if !SKIP
import CoreLocation
#endif
import Foundation
import Observation
import OSLog
#if !SKIP
import UIKit
#endif

@MainActor
@Observable
final class CreateListingViewModel {
    // MARK: - State (what the UI displays)

    var title = "" {
        didSet { scheduleValidation() }
    }
    var description = "" {
        didSet { scheduleValidation() }
    }
    var pickupTime = ""
    var availableHours = ""
    var pickupAddress = "" {
        didSet { scheduleValidation() }
    }
    var selectedCategoryId: Int?
    var postType = "food"
    var selectedImages: [Data] = [] {
        didSet { scheduleValidation() }
    }
    var expiryDate: Date?
    var quantity = ""
    var dietaryInfo: Set<DietaryTag> = []
    var isLoading = false
    var isUploadingImages = false
    var error: String?
    var showError = false
    var createdListing: FoodItem?

    // MARK: - Validation State

    var titleError: String?
    var descriptionError: String?
    var imageError: String?
    var locationError: String?
    
    // MARK: - Debounced Validation
    
    private var validationTask: Task<Void, Never>?
    private let validationDebounceInterval: Duration = .milliseconds(300)

    // MARK: - Progress State

    var uploadProgress: Double = 0
    var currentStep: CreateListingStep = .details

    // MARK: - Draft State

    var hasDraft: Bool { draftId != nil }
    private var draftId: UUID?
    private var lastSavedAt: Date?

    // MARK: - Edit Mode

    private(set) var editingItem: FoodItem?
    var isEditMode: Bool { editingItem != nil }

    // MARK: - Dependencies

    private let repository: ListingRepository
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "CreateListingViewModel")

    // MARK: - Configuration

    private var maxImageSize: Int { AppConfiguration.shared.maxImageSizeBytes }
    private var maxImageDimension: CGFloat { CGFloat(AppConfiguration.shared.maxImageDimension) }
    private var jpegQuality: CGFloat { CGFloat(AppConfiguration.shared.jpegQuality) }

    // MARK: - Initialization

    init(repository: ListingRepository) {
        self.repository = repository
        loadDraft()
    }

    init(repository: ListingRepository, initialCategory: ListingCategory) {
        self.repository = repository
        postType = initialCategory.rawValue
        selectedCategoryId = nil
        loadDraft()
    }

    init(repository: ListingRepository, editingItem: FoodItem) {
        self.repository = repository
        self.editingItem = editingItem
        populateFromItem(editingItem)
    }
    
    // MARK: - Debounced Validation
    
    /// Schedule validation to run after debounce interval
    /// Cancels any pending validation task
    private func scheduleValidation() {
        validationTask?.cancel()
        validationTask = Task { [weak self] in
            try? await Task.sleep(for: self?.validationDebounceInterval ?? .milliseconds(300))
            guard !Task.isCancelled else { return }
            await self?.performValidation()
        }
    }
    
    /// Perform validation immediately (called after debounce)
    private func performValidation() {
        clearValidationErrors()
        _ = validateCurrentStep()
    }
    
    deinit {
        // Task captures [weak self], so no explicit cancellation needed
        // Task will not execute if self is nil
    }

    // MARK: - Step Navigation

    enum CreateListingStep: Int, CaseIterable {
        case details = 0
        case photos = 1
        case location = 2
        case review = 3

        var title: String {
            switch self {
            case .details: "Details"
            case .photos: "Photos"
            case .location: "Location"
            case .review: "Review"
            }
        }

        @MainActor
        func localizedTitle(using t: EnhancedTranslationService) -> String {
            switch self {
            case .details: t.t("create.step.details")
            case .photos: t.t("create.step.photos")
            case .location: t.t("create.step.location")
            case .review: t.t("create.step.review")
            }
        }

        var icon: String {
            switch self {
            case .details: "doc.text"
            case .photos: "photo.on.rectangle"
            case .location: "location"
            case .review: "checkmark.circle"
            }
        }
    }

    func nextStep() {
        guard let nextIndex = CreateListingStep.allCases.firstIndex(of: currentStep)?.advanced(by: 1),
              nextIndex < CreateListingStep.allCases.count else { return }

        if validateCurrentStep() {
            currentStep = CreateListingStep.allCases[nextIndex]
            HapticManager.pageChange()
            saveDraft()
        }
    }

    func previousStep() {
        guard let prevIndex = CreateListingStep.allCases.firstIndex(of: currentStep)?.advanced(by: -1),
              prevIndex >= 0 else { return }

        currentStep = CreateListingStep.allCases[prevIndex]
        HapticManager.pageChange()
    }

    func goToStep(_ step: CreateListingStep) {
        // Only allow going back or to completed steps
        guard step.rawValue <= currentStep.rawValue else { return }
        currentStep = step
        HapticManager.selection()
    }

    var canProceed: Bool {
        validateCurrentStep()
    }

    var isLastStep: Bool {
        currentStep == .review
    }

    var progress: Double {
        Double(currentStep.rawValue + 1) / Double(CreateListingStep.allCases.count)
    }

    // MARK: - Validation

    private func validateCurrentStep() -> Bool {
        clearValidationErrors()

        switch currentStep {
        case .details:
            return validateDetails()
        case .photos:
            return validatePhotos()
        case .location:
            return validateLocation()
        case .review:
            return validateAll()
        }
    }

    private func validateDetails() -> Bool {
        var isValid = true

        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            titleError = "Title is required"
            isValid = false
        } else if title.count < 3 {
            titleError = "Title must be at least 3 characters"
            isValid = false
        } else if title.count > 100 {
            titleError = "Title must be less than 100 characters"
            isValid = false
        }

        if description.count > 1000 {
            descriptionError = "Description must be less than 1000 characters"
            isValid = false
        }

        return isValid
    }

    private func validatePhotos() -> Bool {
        if selectedImages.isEmpty {
            imageError = "At least one photo is required"
            return false
        }
        return true
    }

    private func validateLocation() -> Bool {
        if pickupAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            locationError = "Pickup location is required"
            return false
        }
        return true
    }

    private func validateAll() -> Bool {
        validateDetails() && validatePhotos() && validateLocation()
    }

    private func clearValidationErrors() {
        titleError = nil
        descriptionError = nil
        imageError = nil
        locationError = nil
    }

    // MARK: - Actions

    func createListing(userId: UUID, latitude: Double, longitude: Double) async {
        guard validateAll() else {
            HapticManager.validationError()
            return
        }

        isLoading = true
        error = nil
        showError = false
        defer { isLoading = false }

        do {
            // Optimize images before upload
            let optimizedImages = await optimizeImages(selectedImages)

            let request = CreateListingRequest(
                userId: userId,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                categoryId: selectedCategoryId,
                postType: postType,
                pickupTime: pickupTime.isEmpty ? nil : pickupTime,
                pickupLocation: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                pickupAddress: pickupAddress.isEmpty ? nil : pickupAddress,
                images: optimizedImages,
            )

            try request.validate()
            createdListing = try await repository.createListing(request)

            // Clear draft on success
            clearDraft()
            HapticManager.success()
            logger.info("Listing created successfully")
        } catch {
            self.error = error.localizedDescription
            showError = true
            HapticManager.error()
            logger.error("Failed to create listing: \(error.localizedDescription)")
        }
    }

    func updateListing() async {
        guard let editingItem else { return }
        guard validateAll() else {
            HapticManager.validationError()
            return
        }

        isLoading = true
        error = nil
        showError = false
        defer { isLoading = false }

        do {
            let request = UpdateListingRequest(
                listingId: editingItem.id,
                title: title.isEmpty ? nil : title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                categoryId: selectedCategoryId,
                isActive: nil,
                isArranged: nil,
            )

            try request.validate()
            createdListing = try await repository.updateListing(request)
            HapticManager.success()
            logger.info("Listing updated successfully")
        } catch {
            self.error = error.localizedDescription
            showError = true
            HapticManager.error()
            logger.error("Failed to update listing: \(error.localizedDescription)")
        }
    }

    // MARK: - Image Management

    func addImage(_ imageData: Data) {
        guard selectedImages.count < 3 else {
            imageError = "Maximum 3 photos allowed"
            HapticManager.warning()
            return
        }

        if imageData.count > maxImageSize {
            imageError = "Image is too large (max 5MB)"
            HapticManager.warning()
            return
        }

        selectedImages.append(imageData)
        imageError = nil
        HapticManager.light()
        saveDraft()
    }

    func removeImage(at index: Int) {
        guard index < selectedImages.count else { return }
        selectedImages.remove(at: index)
        HapticManager.delete()
        saveDraft()
    }

    func reorderImages(from source: IndexSet, to destination: Int) {
        selectedImages.move(fromOffsets: source, toOffset: destination)
        HapticManager.light()
        saveDraft()
    }

    private func optimizeImages(_ images: [Data]) async -> [Data] {
        await withTaskGroup(of: Data?.self) { group in
            for imageData in images {
                group.addTask {
                    await self.optimizeImage(imageData)
                }
            }

            var optimized: [Data] = []
            for await result in group {
                if let data = result {
                    optimized.append(data)
                }
            }
            return optimized
        }
    }

    private func optimizeImage(_ data: Data) async -> Data? {
        guard let image = UIImage(data: data) else { return data }

        // Resize if needed
        let resized: UIImage
        if image.size.width > maxImageDimension || image.size.height > maxImageDimension {
            let scale = min(maxImageDimension / image.size.width, maxImageDimension / image.size.height)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            resized = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        } else {
            resized = image
        }

        return resized.jpegData(compressionQuality: jpegQuality)
    }

    // MARK: - Draft Management

    private func saveDraft() {
        guard !isEditMode else { return }

        let draft = ListingDraft(
            id: draftId ?? UUID(),
            title: title,
            description: description,
            pickupTime: pickupTime,
            pickupAddress: pickupAddress,
            postType: postType,
            categoryId: selectedCategoryId,
            quantity: quantity,
            savedAt: Date(),
        )

        draftId = draft.id

        if let encoded = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(encoded, forKey: "listingDraft")
        }

        lastSavedAt = Date()
        logger.debug("Draft saved")
    }

    private func loadDraft() {
        guard let data = UserDefaults.standard.data(forKey: "listingDraft"),
              let draft = try? JSONDecoder().decode(ListingDraft.self, from: data) else {
            return
        }

        // Only load if draft is less than 24 hours old
        guard draft.savedAt.timeIntervalSinceNow > -86400 else {
            clearDraft()
            return
        }

        draftId = draft.id
        title = draft.title
        description = draft.description
        pickupTime = draft.pickupTime
        pickupAddress = draft.pickupAddress
        postType = draft.postType
        selectedCategoryId = draft.categoryId
        quantity = draft.quantity
        lastSavedAt = draft.savedAt

        logger.info("Draft loaded from \(draft.savedAt)")
    }

    func clearDraft() {
        UserDefaults.standard.removeObject(forKey: "listingDraft")
        draftId = nil
        lastSavedAt = nil
    }

    private func populateFromItem(_ item: FoodItem) {
        title = item.postName
        description = item.postDescription ?? ""
        pickupTime = item.pickupTime ?? ""
        pickupAddress = item.postAddress ?? ""
        postType = item.postType
        selectedCategoryId = item.categoryId
    }

    // MARK: - Utility

    func dismissError() {
        error = nil
        showError = false
    }

    func reset() {
        title = ""
        description = ""
        pickupTime = ""
        availableHours = ""
        pickupAddress = ""
        selectedCategoryId = nil
        postType = "food"
        selectedImages = []
        expiryDate = nil
        quantity = ""
        dietaryInfo = []
        createdListing = nil
        error = nil
        showError = false
        currentStep = .details
        clearValidationErrors()
        clearDraft()
    }

    // MARK: - Computed Properties

    var canSubmit: Bool {
        validateAll()
    }

    var imageCountText: String {
        "\(selectedImages.count)/3 photos"
    }

    var titleCharacterCount: String {
        "\(title.count)/100"
    }

    var descriptionCharacterCount: String {
        "\(description.count)/1000"
    }

    var draftSavedText: String? {
        guard let savedAt = lastSavedAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Draft saved \(formatter.localizedString(for: savedAt, relativeTo: Date()))"
    }
}

// MARK: - Supporting Types

struct ListingDraft: Codable {
    let id: UUID
    let title: String
    let description: String
    let pickupTime: String
    let pickupAddress: String
    let postType: String
    let categoryId: Int?
    let quantity: String
    let savedAt: Date
}

enum DietaryTag: String, CaseIterable, Codable, Sendable {
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
    case glutenFree = "Gluten-Free"
    case dairyFree = "Dairy-Free"
    case nutFree = "Nut-Free"
    case organic = "Organic"
    case halal = "Halal"
    case kosher = "Kosher"

    var displayName: String {
        rawValue
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .vegetarian: t.t("dietary.vegetarian")
        case .vegan: t.t("dietary.vegan")
        case .glutenFree: t.t("dietary.gluten_free")
        case .dairyFree: t.t("dietary.dairy_free")
        case .nutFree: t.t("dietary.nut_free")
        case .organic: t.t("dietary.organic")
        case .halal: t.t("dietary.halal")
        case .kosher: t.t("dietary.kosher")
        }
    }

    var icon: String {
        switch self {
        case .vegetarian: "leaf"
        case .vegan: "leaf.circle"
        case .glutenFree: "wheat.slash"
        case .dairyFree: "drop.triangle"
        case .nutFree: "allergens"
        case .organic: "sparkles"
        case .halal: "checkmark.seal"
        case .kosher: "star.circle"
        }
    }
}
