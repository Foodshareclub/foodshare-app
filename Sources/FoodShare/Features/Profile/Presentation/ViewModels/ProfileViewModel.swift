//
//  ProfileViewModel.swift
//  Foodshare
//
//  Refactored with Swift 6 bleeding-edge practices:
//  - Typed loading states with enums
//  - Actor-based caching
//  - Structured concurrency with TaskGroups
//  - Proper @Observable patterns
//



#if !SKIP
import Foundation
import Observation
import OSLog

// MARK: - Profile Cache Actor

/// Thread-safe cache for profile data using Swift actors
actor ProfileCache {
    private var profile: UserProfile?
    private var lastFetchTime: Date?
    private let validityDuration: TimeInterval

    init(validityDuration: TimeInterval = 300) {
        self.validityDuration = validityDuration
    }

    var isValid: Bool {
        guard let lastFetch = lastFetchTime else { return false }
        return Date().timeIntervalSince(lastFetch) < validityDuration
    }

    func get() -> UserProfile? {
        guard isValid else { return nil }
        return profile
    }

    func set(_ profile: UserProfile) {
        self.profile = profile
        lastFetchTime = Date()
    }

    func invalidate() {
        profile = nil
        lastFetchTime = nil
    }
}

// MARK: - Profile ViewModel

/// ViewModel for managing user profile data, badges, reviews, and impact statistics.
///
/// Uses Swift 6 patterns including:
/// - `@Observable` macro for reactive state management
/// - `@MainActor` isolation for UI thread safety
/// - Actor-based caching via `ProfileCache`
/// - Structured concurrency with `TaskGroup` for parallel data loading
///
/// ## Usage
/// ```swift
/// let viewModel = ProfileViewModel(
///     repository: profileRepository,
///     forumRepository: forumRepository,
///     reviewRepository: reviewRepository,
///     userId: currentUserId
/// )
/// await viewModel.loadProfile()
/// ```
@MainActor
@Observable
final class ProfileViewModel {
    // MARK: - Published State

    /// Current loading state for the user profile
    private(set) var profileState: LoadingState<UserProfile> = .idle
    /// Current loading state for user badges
    private(set) var badgesState: LoadingState<BadgeCollection> = .idle
    /// Current loading state for user reviews
    private(set) var reviewsState: LoadingState<[Review]> = .idle
    /// Forum statistics for the user (posts, replies, etc.)
    private(set) var userStats: ForumUserStats?
    /// Server-calculated analytics (completion, rank, impact) - single source of truth
    private(set) var analytics: ProfileAnalytics?

    /// Whether the profile is currently being edited
    var isEditing = false
    /// Whether a save operation is in progress
    var isSaving = false
    /// Current alert to display to the user
    var alertItem: AlertItem?

    // MARK: - Computed Properties

    var profile: UserProfile? {
        profileState.value
    }
    var hasProfile: Bool {
        profile != nil
    }
    var isLoading: Bool {
        profileState.isLoading
    }
    var isRefreshing: Bool {
        profileState.isLoading && hasProfile
    }

    var error: AppError? {
        profileState.error
    }
    var showError: Bool {
        get { alertItem != nil }
        set { if !newValue { alertItem = nil } }
    }
    var errorMessage: String {
        alertItem?.message ?? "An error occurred"
    }

    /// Localized error message (use in Views with translation service)
    func localizedErrorMessage(using t: EnhancedTranslationService) -> String {
        alertItem?.message ?? t.t("error.generic")
    }

    var displayName: String {
        profile?.nickname ?? "User"
    }

    /// Localized display name (use in Views with translation service)
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        profile?.nickname ?? t.t("profile.default_name")
    }

    var sharedCount: String {
        String(profile?.itemsShared ?? 0)
    }
    var receivedCount: String {
        String(profile?.itemsReceived ?? 0)
    }

    var ratingText: String {
        guard let profile, profile.ratingCount > 0 else { return "—" }
        return String(format: "%.1f", profile.ratingAverage)
    }

    var memberSince: String {
        guard let profile else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return "Member since \(formatter.string(from: profile.createdTime))"
    }

    /// Localized member since text (use in Views with translation service)
    func localizedMemberSince(using t: EnhancedTranslationService) -> String {
        guard let profile else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let dateFormatted = formatter.string(from: profile.createdTime)
        return t.t("profile.member_since_format", args: ["date": dateFormatted])
    }

    var memberDuration: String {
        guard let profile else { return "" }
        let components = Calendar.current.dateComponents([.year, .month], from: profile.createdTime, to: Date())
        if let years = components.year, years > 0 {
            return years == 1 ? "1 year" : "\(years) years"
        } else if let months = components.month, months > 0 {
            return months == 1 ? "1 month" : "\(months) months"
        }
        return "New member"
    }

    /// Localized member duration text (use in Views with translation service)
    func localizedMemberDuration(using t: EnhancedTranslationService) -> String {
        guard let profile else { return "" }
        let components = Calendar.current.dateComponents([.year, .month], from: profile.createdTime, to: Date())
        if let years = components.year, years > 0 {
            let key = years == 1 ? "profile.duration.year" : "profile.duration.years"
            return t.t(key, args: ["count": String(years)])
        } else if let months = components.month, months > 0 {
            let key = months == 1 ? "profile.duration.month" : "profile.duration.months"
            return t.t(key, args: ["count": String(months)])
        }
        return t.t("profile.new_member")
    }

    // MARK: - Badge Properties

    var badgeCollection: BadgeCollection? {
        badgesState.value
    }
    var hasBadges: Bool {
        !(badgeCollection?.earnedBadges.isEmpty ?? true)
    }
    var isLoadingBadges: Bool {
        badgesState.isLoading
    }
    /// Whether badges have been loaded (used for lazy loading)
    var badgesLoaded: Bool {
        badgesState.value != nil || badgesState.error != nil
    }

    // MARK: - Review Properties

    var reviews: [Review] {
        reviewsState.value ?? []
    }
    var hasReviews: Bool {
        !reviews.isEmpty
    }
    var isLoadingReviews: Bool {
        reviewsState.isLoading
    }
    var reviewCount: Int {
        reviews.count
    }
    /// Whether reviews have been loaded (used for lazy loading)
    var reviewsLoaded: Bool {
        reviewsState.value != nil || reviewsState.error != nil
    }

    // MARK: - Profile Completion (from server analytics)

    var profileCompletion: ProfileCompletion {
        // Use server-calculated values when available (single source of truth)
        if let serverData = analytics?.completion {
            return ProfileCompletion(
                percentage: serverData.percentage,
                missingFields: serverData.missingFields,
            )
        }
        // Fallback to client-side calculation only if analytics not loaded yet
        guard let profile else { return ProfileCompletion(percentage: 0, missingFields: []) }
        var completed = 0
        var missing: [String] = []
        if !profile.nickname.isEmpty { completed += 1 } else { missing.append("Display name") }
        if profile.avatarUrl != nil { completed += 1 } else { missing.append("Profile photo") }
        if let bio = profile.bio, !bio.isEmpty { completed += 1 } else { missing.append("Bio") }
        if let location = profile.location, !location.isEmpty { completed += 1 } else { missing.append("Location") }
        if profile.itemsShared > 0 || profile.itemsReceived > 0 { completed += 1 }
        else { missing.append("First food share") }
        return ProfileCompletion(percentage: Double(completed) / 5.0 * 100, missingFields: missing)
    }

    /// Localized profile completion (use in Views with translation service)
    func localizedProfileCompletion(using t: EnhancedTranslationService) -> ProfileCompletion {
        // Use server-calculated values when available (single source of truth)
        if let serverData = analytics?.completion {
            // Translate server-provided missing fields
            let localizedFields = serverData.missingFields.map { field -> String in
                switch field.lowercased() {
                case "display name": return t.t("profile.completion.display_name")
                case "profile photo": return t.t("profile.completion.profile_photo")
                case "bio": return t.t("profile.completion.bio")
                case "location": return t.t("profile.completion.location")
                case "first food share": return t.t("profile.completion.first_food_share")
                default: return field
                }
            }
            return ProfileCompletion(percentage: serverData.percentage, missingFields: localizedFields)
        }
        // Fallback to client-side calculation only if analytics not loaded yet
        guard let profile else { return ProfileCompletion(percentage: 0, missingFields: []) }
        var completed = 0
        var missing: [String] = []
        if !profile.nickname.isEmpty { completed += 1 } else { missing.append(t.t("profile.completion.display_name")) }
        if profile.avatarUrl != nil { completed += 1 } else { missing.append(t.t("profile.completion.profile_photo")) }
        if let bio = profile.bio, !bio.isEmpty { completed += 1 } else { missing.append(t.t("profile.completion.bio")) }
        if let location = profile.location,
           !location.isEmpty { completed += 1 } else { missing.append(t.t("profile.completion.location")) }
        if profile.itemsShared > 0 || profile.itemsReceived > 0 { completed += 1 }
        else { missing.append(t.t("profile.completion.first_food_share")) }
        return ProfileCompletion(percentage: Double(completed) / 5.0 * 100, missingFields: missing)
    }

    var isProfileComplete: Bool {
        profileCompletion.percentage >= 100
    }

    // MARK: - Impact Stats (from server analytics)

    var impactStats: ImpactStats {
        // Use server-calculated values when available (single source of truth)
        if let serverData = analytics {
            return ImpactStats(
                mealsShared: serverData.impact.mealsShared,
                mealsReceived: serverData.impact.mealsReceived,
                co2SavedKg: serverData.impact.co2SavedKg,
                waterSavedLiters: serverData.impact.waterSavedLiters,
                communityRank: serverData.rank.tier,
            )
        }
        // Fallback to client-side calculation only if analytics not loaded yet
        guard let profile else { return .empty }
        let config = AppConfiguration.shared
        return ImpactStats(
            mealsShared: profile.itemsShared,
            mealsReceived: profile.itemsReceived,
            co2SavedKg: Double(profile.itemsShared) * config.co2KgPerItem,
            waterSavedLiters: Double(profile.itemsShared) * config.waterLitersPerItem,
            communityRank: "Loading...",
        )
    }

    /// Server analytics data for advanced UI (progress to next tier, equivalents, etc.)
    var serverAnalytics: ProfileAnalytics? {
        analytics
    }

    // MARK: - Dependencies

    private let repository: ProfileRepository
    private let forumRepository: ForumRepository?
    private let reviewRepository: ReviewRepository?
    private let userId: UUID?
    private let cache: ProfileCache
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "ProfileViewModel")

    // MARK: - User Identification

    /// Whether this profile belongs to the current user
    var isOwnProfile: Bool {
        guard let userId, let currentUserId = profile?.id else { return false }
        return userId == currentUserId
    }

    // MARK: - Initialization

    init(
        repository: ProfileRepository,
        forumRepository: ForumRepository? = nil,
        reviewRepository: ReviewRepository? = nil,
        userId: UUID? = nil,
        cache: ProfileCache = ProfileCache(),
    ) {
        self.repository = repository
        self.forumRepository = forumRepository
        self.reviewRepository = reviewRepository
        self.userId = userId
        self.cache = cache
    }

    // MARK: - Actions

    /// Load profile with smart caching
    func loadProfile(forceRefresh: Bool = false) async {
        guard let userId else {
            alertItem = AlertItem(title: "Error", message: "User ID not available")
            return
        }

        // Check cache first
        if !forceRefresh, let cached = await cache.get() {
            profileState = .loaded(cached)
            logger.debug("Using cached profile")
            await loadSupplementaryData()
            return
        }

        guard !profileState.isLoading else { return }
        profileState = .loading

        do {
            let profile = try await repository.fetchProfile(userId: userId)
            await cache.set(profile)
            profileState = .loaded(profile)
            logger.info("Profile loaded for \(userId.uuidString)")
            await loadSupplementaryData()
        } catch let dbError as DatabaseError {
            let appError = AppError.from(dbError)
            profileState = .failed(appError)
            alertItem = AlertItem(title: "Error", message: appError.localizedDescription)
            logger.error("Database error loading profile: \(dbError.localizedDescription)")
        } catch {
            let appError = (error as? AppError) ?? .networkError(error.localizedDescription)
            profileState = .failed(appError)
            alertItem = AlertItem(title: "Error", message: appError.localizedDescription)
            logger.error("Failed to load profile: \(error.localizedDescription)")
        }
    }

    /// Refresh profile (pull-to-refresh)
    func refresh() async {
        await loadProfile(forceRefresh: true)
        HapticManager.light()
    }

    /// Load analytics only - badges and reviews are loaded lazily when their sections are expanded
    private func loadSupplementaryData() async {
        // Only load analytics eagerly - it's needed for profile completion display
        await loadAnalytics()
        // Note: Badges and reviews are now loaded lazily via loadBadgesIfNeeded() and loadReviewsIfNeeded()
    }

    /// Load badges only when the badges section is expanded (lazy loading)
    func loadBadgesIfNeeded() async {
        guard !badgesLoaded, !isLoadingBadges else { return }
        await loadBadges()
    }

    /// Load reviews only when the reviews section is expanded (lazy loading)
    func loadReviewsIfNeeded() async {
        guard !reviewsLoaded, !isLoadingReviews else { return }
        await loadReviews()
    }

    /// Load server-calculated analytics (completion, rank, impact)
    private func loadAnalytics() async {
        guard let userId else { return }

        do {
            let serverAnalytics = try await repository.fetchProfileAnalytics(userId: userId)
            analytics = serverAnalytics
            logger
                .info(
                    "Analytics loaded - completion: \(serverAnalytics.completion.percentage)%, rank: \(serverAnalytics.rank.tier)",
                )
        } catch {
            // Analytics are non-critical - fallback to client-side calculation
            logger.warning("Analytics unavailable, using client fallback: \(error.localizedDescription)")
        }
    }

    /// Load badges
    func loadBadges() async {
        guard let userId, let forumRepository, !badgesState.isLoading else { return }
        badgesState = .loading

        do {
            async let collectionTask = forumRepository.fetchBadgeCollection(profileId: userId)
            async let statsTask = forumRepository.fetchOrCreateUserStats(profileId: userId)
            let (collection, stats) = try await (collectionTask, statsTask)

            badgesState = .loaded(collection)
            userStats = stats
            logger.debug("Loaded \(collection.earnedBadges.count) badges")
        } catch {
            // Don't fail the entire profile - badges are optional
            badgesState = .idle
            logger.warning("Badges unavailable: \(error.localizedDescription)")
        }
    }

    /// Load reviews
    func loadReviews() async {
        guard let userId, let reviewRepository, !reviewsState.isLoading else { return }
        reviewsState = .loading

        do {
            let reviews = try await reviewRepository.fetchReviews(forUserId: userId)
            reviewsState = .loaded(reviews)
            logger.debug("Loaded \(reviews.count) reviews")
        } catch {
            reviewsState = .failed(.networkError(error.localizedDescription))
            logger.warning("Failed to load reviews: \(error.localizedDescription)")
        }
    }

    /// Update profile
    func updateProfile(
        nickname: String?,
        bio: String?,
        location: String?,
        avatarData: Data? = nil,
        searchRadiusKm: Int? = nil,
    ) async {
        guard let userId else { return }

        // Validation
        if let nickname, nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            alertItem = AlertItem(title: "Validation Error", message: "Display name cannot be empty")
            HapticManager.error()
            return
        }

        if let bio, bio.count > 200 {
            alertItem = AlertItem(title: "Validation Error", message: "Bio must be 200 characters or less")
            HapticManager.error()
            return
        }

        if let searchRadiusKm, !(1 ... 800).contains(searchRadiusKm) {
            alertItem = AlertItem(title: "Validation Error", message: "Search radius must be between 1 and 800 km")
            HapticManager.error()
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let request = UpdateProfileRequest(
                nickname: nickname,
                bio: bio,
                aboutMe: location,
                searchRadiusKm: searchRadiusKm,
                preferredLocale: nil,
                avatarData: avatarData,
            )
            let updated = try await repository.updateProfile(userId: userId, request: request)
            await cache.set(updated)
            profileState = .loaded(updated)
            isEditing = false
            logger.info("Profile updated successfully")
            HapticManager.success()
        } catch {
            alertItem = AlertItem(title: "Update Failed", message: error.localizedDescription)
            logger.error("Failed to update profile: \(error.localizedDescription)")
            HapticManager.error()
        }
    }

    /// Enter profile editing mode
    func startEditing() {
        isEditing = true
        HapticManager.light()
    }

    /// Cancel profile editing and discard changes
    func cancelEditing() {
        isEditing = false
        HapticManager.light()
    }

    /// Dismiss the current error alert
    func dismissError() {
        alertItem = nil
    }

    /// Invalidate the profile cache, forcing a fresh fetch on next load
    func invalidateCache() async {
        await cache.invalidate()
    }

    // MARK: - Private Helpers

    private func communityRank(for profile: UserProfile) -> String {
        let total = profile.itemsShared + profile.itemsReceived
        switch total {
        case 0: return "Newcomer"
        case 1 ... 5: return "Food Saver"
        case 6 ... 15: return "Community Helper"
        case 16 ... 30: return "Sharing Champion"
        case 31 ... 50: return "Food Hero"
        case 51 ... 100: return "Sustainability Star"
        default: return "Legend"
        }
    }

    /// Localized community rank (use in Views with translation service)
    func localizedCommunityRank(for profile: UserProfile, using t: EnhancedTranslationService) -> String {
        let total = profile.itemsShared + profile.itemsReceived
        switch total {
        case 0: return t.t("profile.rank.newcomer")
        case 1 ... 5: return t.t("profile.rank.food_saver")
        case 6 ... 15: return t.t("profile.rank.community_helper")
        case 16 ... 30: return t.t("profile.rank.sharing_champion")
        case 31 ... 50: return t.t("profile.rank.food_hero")
        case 51 ... 100: return t.t("profile.rank.sustainability_star")
        default: return t.t("profile.rank.legend")
        }
    }
}

// MARK: - Alert Item

/// Model for displaying alerts in the profile view
struct AlertItem: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let message: String
}

// MARK: - Supporting Types

/// Tracks profile completion progress and missing fields
struct ProfileCompletion: Sendable {
    /// Completion percentage (0-100)
    let percentage: Double
    /// List of fields that still need to be filled
    let missingFields: [String]

    /// Whether the profile is fully complete
    var isComplete: Bool {
        percentage >= 100
    }
    /// Human-readable status text
    var statusText: String {
        isComplete ? "Profile complete!" : "\(Int(percentage))% complete"
    }
    /// The next field to complete, if any
    var nextStep: String? {
        missingFields.first
    }
}

/// Environmental and community impact statistics for a user
struct ImpactStats: Sendable {
    /// Number of food items shared with others
    let mealsShared: Int
    /// Number of food items received from others
    let mealsReceived: Int
    /// Estimated CO₂ saved in kilograms
    let co2SavedKg: Double
    /// Estimated water saved in liters
    let waterSavedLiters: Double
    /// User's community rank based on activity
    let communityRank: String

    /// Empty impact stats for users with no activity
    static let empty = ImpactStats(
        mealsShared: 0,
        mealsReceived: 0,
        co2SavedKg: 0,
        waterSavedLiters: 0,
        communityRank: "Newcomer",
    )

    /// Formatted CO₂ string (e.g., "2.5kg" or "1.2t")
    var formattedCO2: String {
        co2SavedKg >= 1000 ? String(format: "%.1ft", co2SavedKg / 1000) : String(format: "%.1fkg", co2SavedKg)
    }

    /// Formatted water string (e.g., "500L" or "2kL")
    var formattedWater: String {
        waterSavedLiters >= 1000
            ? String(format: "%.0fkL", waterSavedLiters / 1000)
            : String(
                format: "%.0fL",
                waterSavedLiters,
            )
    }
}


#endif
