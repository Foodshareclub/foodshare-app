//
//  DependencyContainer.swift
//  Foodshare
//
//  Enterprise-grade dependency injection container with factory pattern.
//  Manages all repository instances with lazy initialization and proper lifecycle.
//
//  Features:
//  - Generic lazy factory for thread-safe singleton creation
//  - Type-safe repository access via protocols
//  - Use case factory methods
//  - SwiftUI environment integration
//


#if !SKIP
import Foundation
import Supabase
import SwiftUI

// MARK: - Lazy Box

/// Thread-safe lazy initialization wrapper
/// Provides singleton semantics for repository instances
@MainActor
private final class LazyBox<T>: @unchecked Sendable {
    private var instance: T?
    private let factory: () -> T

    init(_ factory: @escaping () -> T) {
        self.factory = factory
    }

    var value: T {
        if let instance {
            return instance
        }
        let newInstance = factory()
        instance = newInstance
        return newInstance
    }

    func reset() {
        instance = nil
    }
}

// MARK: - Dependency Container

/// Centralized container for all app dependencies
/// Ensures repositories are created once and reused throughout the app lifecycle
@Observable
@MainActor
final class DependencyContainer {
    // MARK: - Supabase Client

    private let supabaseClient: SupabaseClient

    // MARK: - Repository Factories

    @ObservationIgnored
    private lazy var _feedRepository = LazyBox { [supabaseClient] in
        SupabaseFeedRepository(supabase: supabaseClient) as any FeedRepository
    }

    @ObservationIgnored
    private lazy var _foodItemRepository = LazyBox { [supabaseClient] in
        SupabaseFoodItemRepository(supabase: supabaseClient) as any FoodItemRepository
    }

    @ObservationIgnored
    private lazy var _listingRepository = LazyBox { [supabaseClient] in
        SupabaseListingRepository(supabase: supabaseClient) as any ListingRepository
    }

    @ObservationIgnored
    private lazy var _messagingRepository = LazyBox { [supabaseClient] in
        SupabaseMessagingRepository(supabase: supabaseClient) as any MessagingRepository
    }

    @ObservationIgnored
    private lazy var _notificationRepository = LazyBox { [supabaseClient] in
        SupabaseNotificationRepository(supabase: supabaseClient) as any NotificationRepository
    }

    @ObservationIgnored
    private lazy var _profileRepository = LazyBox { [supabaseClient] in
        SupabaseProfileRepository(supabase: supabaseClient) as any ProfileRepository
    }

    @ObservationIgnored
    private lazy var _challengeRepository = LazyBox { [supabaseClient] in
        SupabaseChallengeRepository(supabase: supabaseClient) as any ChallengeRepository
    }

    @ObservationIgnored
    private lazy var _forumRepository = LazyBox { [supabaseClient] in
        SupabaseForumRepository(supabase: supabaseClient) as any ForumRepository
    }

    @ObservationIgnored
    private lazy var _reviewRepository = LazyBox { [supabaseClient] in
        SupabaseReviewRepository(supabase: supabaseClient) as any ReviewRepository
    }

    @ObservationIgnored
    private lazy var _adminRepository = LazyBox { [supabaseClient] in
        SupabaseAdminRepository(supabase: supabaseClient) as any AdminRepository
    }

    @ObservationIgnored
    private lazy var _activityRepository = LazyBox { [supabaseClient] in
        SupabaseActivityRepository(supabase: supabaseClient) as any ActivityRepository
    }

    @ObservationIgnored
    private lazy var _searchRepository = LazyBox { [supabaseClient] in
        SupabaseSearchRepository(supabase: supabaseClient) as any SearchRepository
    }

    @ObservationIgnored
    private lazy var _reportRepository = LazyBox { [supabaseClient] in
        SupabaseReportRepository(supabase: supabaseClient) as any ReportRepository
    }

    @ObservationIgnored
    private lazy var _feedbackRepository = LazyBox { [supabaseClient] in
        SupabaseFeedbackRepository(supabase: supabaseClient) as any FeedbackRepository
    }

    // MARK: - Public Repository Accessors

    /// Feed repository for listing feed operations
    var feedRepository: any FeedRepository { _feedRepository.value }

    /// Food item repository for individual item operations
    var foodItemRepository: any FoodItemRepository { _foodItemRepository.value }

    /// Listing repository for create/edit listing operations
    var listingRepository: any ListingRepository { _listingRepository.value }

    /// Messaging repository for chat and conversations
    var messagingRepository: any MessagingRepository { _messagingRepository.value }

    /// Notification repository for push notifications
    var notificationRepository: any NotificationRepository { _notificationRepository.value }

    /// Profile repository for user profile operations
    var profileRepository: any ProfileRepository { _profileRepository.value }

    /// Challenge repository for gamification challenges
    var challengeRepository: any ChallengeRepository { _challengeRepository.value }

    /// Forum repository for community discussions
    var forumRepository: any ForumRepository { _forumRepository.value }

    /// Review repository for user reviews
    var reviewRepository: any ReviewRepository { _reviewRepository.value }

    /// Admin repository for admin operations
    var adminRepository: any AdminRepository { _adminRepository.value }

    /// Activity repository for activity feed
    var activityRepository: any ActivityRepository { _activityRepository.value }

    /// Search repository for search operations
    var searchRepository: any SearchRepository { _searchRepository.value }

    /// Report repository for content reporting
    var reportRepository: any ReportRepository { _reportRepository.value }

    /// Feedback repository for user feedback
    var feedbackRepository: any FeedbackRepository { _feedbackRepository.value }

    // MARK: - Use Case Factories

    /// Creates a new instance of FetchNearbyItemsUseCase
    var fetchNearbyItemsUseCase: FetchNearbyItemsUseCase {
        DefaultFetchNearbyItemsUseCase(repository: foodItemRepository)
    }

    /// Creates a new instance of FetchCategoriesUseCase
    var fetchCategoriesUseCase: FetchCategoriesUseCase {
        DefaultFetchCategoriesUseCase(repository: feedRepository)
    }

    /// Creates a new instance of GeospatialSearchUseCase
    func geospatialSearchUseCase() -> GeospatialSearchUseCase {
        GeospatialSearchUseCase(repository: feedRepository)
    }

    /// Creates a new instance of SearchFoodItemsUseCase
    func searchFoodItemsUseCase() -> SearchFoodItemsUseCase {
        SearchFoodItemsUseCase(repository: searchRepository)
    }

    // MARK: - Feed Service Factories

    /// Creates a FeedDataService for loading feed data
    var feedDataService: any FeedDataServiceProtocol {
        FeedDataService(
            fetchNearbyItemsUseCase: fetchNearbyItemsUseCase,
            fetchCategoriesUseCase: fetchCategoriesUseCase
        )
    }

    /// Creates a FeedTranslationService for translating feed items
    var feedTranslationService: any FeedTranslationServiceProtocol {
        FeedTranslationService()
    }

    /// Creates a FeedPreferencesService for managing feed preferences
    var feedPreferencesService: any FeedPreferencesServiceProtocol {
        FeedPreferencesService()
    }

    // MARK: - Initialization

    init(supabaseClient: SupabaseClient) {
        self.supabaseClient = supabaseClient
    }

    // MARK: - Factory Methods

    /// Creates dependency container from AuthenticationService
    static func create(from authService: AuthenticationService) -> DependencyContainer {
        DependencyContainer(supabaseClient: authService.supabase)
    }

    // MARK: - Reset (for testing)

    #if DEBUG
        /// Resets all repository instances (useful for testing)
        func resetAll() {
            _feedRepository.reset()
            _foodItemRepository.reset()
            _listingRepository.reset()
            _messagingRepository.reset()
            _notificationRepository.reset()
            _profileRepository.reset()
            _challengeRepository.reset()
            _forumRepository.reset()
            _reviewRepository.reset()
            _adminRepository.reset()
            _activityRepository.reset()
            _searchRepository.reset()
            _reportRepository.reset()
            _feedbackRepository.reset()
        }
    #endif
}

// MARK: - Environment Key

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer? = nil
}

extension EnvironmentValues {
    var dependencies: DependencyContainer? {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - View Modifier

/// Convenience modifier for injecting dependencies
struct WithDependencies: ViewModifier {
    let container: DependencyContainer

    func body(content: Content) -> some View {
        content.environment(\.dependencies, container)
    }
}

extension View {
    /// Injects the dependency container into the view hierarchy
    func withDependencies(_ container: DependencyContainer) -> some View {
        modifier(WithDependencies(container: container))
    }
}

// MARK: - Preview Support

extension DependencyContainer {
    /// Creates a container for SwiftUI previews
    static var preview: DependencyContainer {
        DependencyContainer.create(from: .shared)
    }
}

#else
// MARK: - Android DependencyContainer (Skip)

import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class DependencyContainer {
    // Stub container for Android — repositories will be added in Phase 2+
    init() {}

    static func create(from authService: AuthenticationService) -> DependencyContainer {
        return DependencyContainer()
    }

    static var preview: DependencyContainer {
        return DependencyContainer()
    }
}

#endif
