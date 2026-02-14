//
//  CommunityFridgesViewModel.swift
//  Foodshare
//
//  ViewModel for community fridges list and map
//

#if !SKIP
import CoreLocation
#endif
import Foundation
import Observation

@MainActor
@Observable
final class CommunityFridgesViewModel {
    // MARK: - State

    var fridges: [CommunityFridge] = []
    var selectedFridge: CommunityFridge?
    var isLoading = false
    var isRefreshing = false
    var error: AppError?
    var showError = false
    var searchRadius = 10.0 // km

    // MARK: - Filter State

    var showActiveOnly = true
    var showWithFoodOnly = false

    // MARK: - Dependencies

    private let fetchFridgesUseCase: FetchNearbyFridgesUseCase
    private let locationService: LocationService

    // MARK: - Cache Configuration

    /// Last fetch time for fridges cache
    private var lastFetchTime: Date?
    /// Fridges cache TTL: 5 minutes
    private let fridgesCacheTTL: TimeInterval = 300

    /// Check if fridges cache is still valid
    private var isCacheValid: Bool {
        guard let lastFetch = lastFetchTime, !fridges.isEmpty else { return false }
        return Date().timeIntervalSince(lastFetch) < fridgesCacheTTL
    }

    // MARK: - Initialization

    init(
        fetchFridgesUseCase: FetchNearbyFridgesUseCase,
        locationService: LocationService,
    ) {
        self.fetchFridgesUseCase = fetchFridgesUseCase
        self.locationService = locationService
    }

    // MARK: - Computed Properties

    var filteredFridges: [CommunityFridge] {
        var result = fridges

        if showActiveOnly {
            result = result.filter { $0.status == .active }
        }

        if showWithFoodOnly {
            result = result.filter { fridge in
                guard let foodStatus = fridge.foodStatusEnum else { return true }
                return foodStatus != .nearlyEmpty
            }
        }

        return result
    }

    var hasFridges: Bool {
        !filteredFridges.isEmpty
    }

    var activeFridgesCount: Int {
        fridges.count(where: { $0.status == .active })
    }

    var fridgesWithFood: Int {
        fridges.count(where: { fridge in
            guard let foodStatus = fridge.foodStatusEnum else { return false }
            return foodStatus != .nearlyEmpty
        })
    }

    // MARK: - Actions

    func loadFridges(forceRefresh: Bool = false) async {
        guard !isLoading else { return }

        // Check cache validity unless force refresh
        if !forceRefresh, isCacheValid {
            return
        }

        isLoading = true
        error = nil
        showError = false
        defer {
            isLoading = false
            lastFetchTime = Date()
        }

        await fetchFridgesInternal()
    }

    func refresh() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        defer {
            isRefreshing = false
            lastFetchTime = Date()
        }

        await fetchFridgesInternal()
    }

    /// Shared fetch logic for both loadFridges and refresh
    private func fetchFridgesInternal() async {
        do {
            let location = try await locationService.getCurrentLocation()
            fridges = try await fetchFridgesUseCase.execute(
                near: location,
                radius: searchRadius,
                limit: 100,
            )
        } catch let appError as AppError {
            error = appError
            showError = !isRefreshing // Only show error for initial load, not refresh
        } catch {
            self.error = .networkError(error.localizedDescription)
            showError = !isRefreshing
        }
    }

    func selectFridge(_ fridge: CommunityFridge) {
        selectedFridge = fridge
    }

    func clearSelection() {
        selectedFridge = nil
    }

    func dismissError() {
        error = nil
        showError = false
    }

    func updateSearchRadius(_ radius: Double) {
        searchRadius = radius
        Task {
            await loadFridges()
        }
    }
}
