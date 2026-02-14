//
//  SearchViewModel.swift
//  Foodshare
//
//  ViewModel for search and filtering
//  Enhanced with voice search, suggestions, saved searches, and search analytics
//

import Foundation
import Observation
import OSLog
import Speech

struct SearchFilters: Sendable, Equatable {
    var categoryId: Int?
    var maxDistanceKm = 10.0
    var postType: String?
    var showArrangedOnly = false
    var showAvailableOnly = true
    var sortBy: SortOption = .distance
    var expiringWithinHours: Int?

    enum SortOption: String, CaseIterable, Sendable, Codable {
        case distance = "Distance"
        case newest = "Newest"
        case oldest = "Oldest"
        case expiringSoon = "Expiring Soon"
        case mostViewed = "Popular"

        var icon: String {
            switch self {
            case .distance: "location"
            case .newest: "clock"
            case .oldest: "clock.arrow.circlepath"
            case .expiringSoon: "exclamationmark.clock"
            case .mostViewed: "flame"
            }
        }
    }

    static let `default` = SearchFilters()

    var isDefault: Bool {
        self == .default
    }
}

@MainActor
@Observable
final class SearchViewModel {
    // MARK: - Search State

    var searchQuery = ""
    var results: [FoodItem] = []
    var categories: [Category] = []
    var filters = SearchFilters.default
    var isLoading = false
    var isSearching = false
    var error: AppError?
    var showError = false

    // MARK: - Search History & Suggestions

    var recentSearches: [String] = []
    var savedSearches: [SavedSearch] = []
    var searchSuggestions: [String] = []
    var popularSearches: [String] = ["Fresh vegetables", "Bread", "Dairy", "Fruits", "Cooked meals"]

    // MARK: - Voice Search State

    var isVoiceSearchActive = false
    var voiceSearchText = ""
    var voiceSearchError: String?

    // MARK: - Search Analytics (Server-Provided)

    var searchStats: SearchStats = .empty
    private(set) var totalCount = 0
    private(set) var hasMore = false

    // MARK: - Debounce

    private var searchTask: Task<Void, Never>?
    private let debounceDelay: UInt64 = 300_000_000 // 300ms in nanoseconds

    // MARK: - Dependencies

    private let repository: FeedRepository
    private let searchRepository: SearchRepository
    private let locationService: LocationService
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "SearchViewModel")

    // MARK: - Voice Recognition

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?

    // MARK: - Lazy Loading State

    /// Whether categories have been loaded (for lazy loading)
    private var categoriesLoaded = false

    init(repository: FeedRepository, searchRepository: SearchRepository, locationService: LocationService) {
        self.repository = repository
        self.searchRepository = searchRepository
        self.locationService = locationService
        loadSearchHistory()
        setupSpeechRecognition()
        // Note: Categories are NOT loaded on init - they're loaded lazily when filter button is tapped
    }

    // MARK: - Computed Properties

    var hasResults: Bool {
        !results.isEmpty
    }

    /// Results are pre-filtered and sorted by server via search_food_items RPC
    var filteredResults: [FoodItem] {
        results
    }

    var activeFiltersCount: Int {
        var count = 0
        if filters.categoryId != nil { count += 1 }
        if filters.postType != nil { count += 1 }
        if filters.showArrangedOnly { count += 1 }
        if !filters.showAvailableOnly { count += 1 }
        if filters.maxDistanceKm != 10.0 { count += 1 }
        if filters.expiringWithinHours != nil { count += 1 }
        if filters.sortBy != .distance { count += 1 }
        return count
    }

    var hasActiveFilters: Bool {
        activeFiltersCount > 0
    }

    var isVoiceSearchAvailable: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    // MARK: - Search Actions

    /// Load categories - called lazily when filter button is tapped
    /// Uses global CategoriesCache for app-wide caching
    func loadCategories() async {
        // Skip if already loaded locally
        guard !categoriesLoaded else { return }

        do {
            // Use global cache - shared with Feed, Forum, Map
            categories = try await CategoriesCache.shared.getCategories()
            categoriesLoaded = true
        } catch {
            logger.warning("Failed to load categories: \(error.localizedDescription)")
        }
    }

    /// Load categories only when needed (when filter UI is accessed)
    func loadCategoriesIfNeeded() async {
        guard !categoriesLoaded else { return }
        await loadCategories()
    }

    /// Debounced search - call this when user types
    func searchDebounced() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: debounceDelay)
            guard !Task.isCancelled else { return }
            await search()
        }
    }

    func search() async {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            results = []
            totalCount = 0
            hasMore = false
            updateSuggestions(for: "")
            return
        }

        isSearching = true
        error = nil
        defer { isSearching = false }

        do {
            let location = try await locationService.getCurrentLocation()

            // Convert filter sort option to server format
            let serverSort: ServerSearchParams.SortOption = switch filters.sortBy {
            case .distance: .distance
            case .newest: .newest
            case .oldest: .oldest
            case .expiringSoon: .expiringSoon
            case .mostViewed: .popular
            }

            let params = ServerSearchParams(
                location: location.coordinate,
                radiusKm: filters.maxDistanceKm,
                searchQuery: trimmedQuery,
                categoryId: filters.categoryId,
                postType: filters.postType,
                availableOnly: filters.showAvailableOnly,
                arrangedOnly: filters.showArrangedOnly,
                sortBy: serverSort,
                limit: 100,
                offset: 0,
            )

            // Server-side search with filtering, sorting, and stats
            let searchResult = try await searchRepository.searchFoodItemsServerSide(params: params)

            results = searchResult.items
            totalCount = searchResult.totalCount
            hasMore = searchResult.hasMore

            // Use server-provided stats
            searchStats = SearchStats(
                totalResults: searchResult.totalCount,
                filteredResults: searchResult.items.count,
                categoryBreakdown: searchResult.categoryBreakdown,
                averageDistance: nil,
            )

            saveRecentSearch(trimmedQuery)
            logger
                .info(
                    "Search completed: '\(trimmedQuery)' returned \(searchResult.items.count) of \(searchResult.totalCount) results",
                )
        } catch {
            logger.error("Search failed: \(error.localizedDescription)")
            self.error = .networkError(error.localizedDescription)
            showError = true
        }
    }

    func searchNearby() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let location = try await locationService.getCurrentLocation()

            // Convert filter sort option to server format
            let serverSort: ServerSearchParams.SortOption = switch filters.sortBy {
            case .distance: .distance
            case .newest: .newest
            case .oldest: .oldest
            case .expiringSoon: .expiringSoon
            case .mostViewed: .popular
            }

            let params = ServerSearchParams(
                location: location.coordinate,
                radiusKm: filters.maxDistanceKm,
                searchQuery: nil,
                categoryId: filters.categoryId,
                postType: filters.postType,
                availableOnly: filters.showAvailableOnly,
                arrangedOnly: filters.showArrangedOnly,
                sortBy: serverSort,
                limit: 100,
                offset: 0,
            )

            // Server-side search with filtering, sorting, and stats
            let searchResult = try await searchRepository.searchFoodItemsServerSide(params: params)

            results = searchResult.items
            totalCount = searchResult.totalCount
            hasMore = searchResult.hasMore

            // Use server-provided stats
            searchStats = SearchStats(
                totalResults: searchResult.totalCount,
                filteredResults: searchResult.items.count,
                categoryBreakdown: searchResult.categoryBreakdown,
                averageDistance: nil,
            )
        } catch {
            self.error = .networkError(error.localizedDescription)
            showError = true
        }
    }

    // MARK: - Voice Search

    private func setupSpeechRecognition() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        audioEngine = AVAudioEngine()
    }

    func requestVoiceSearchPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startVoiceSearch() {
        guard let speechRecognizer, speechRecognizer.isAvailable,
              let audioEngine else
        {
            voiceSearchError = "Voice search is not available"
            return
        }

        // Cancel any existing task
        stopVoiceSearch()

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            isVoiceSearchActive = true
            voiceSearchText = ""
            voiceSearchError = nil
            HapticManager.medium()

            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor in
                    if let result {
                        self?.voiceSearchText = result.bestTranscription.formattedString

                        if result.isFinal {
                            self?.searchQuery = result.bestTranscription.formattedString
                            self?.stopVoiceSearch()
                            await self?.search()
                        }
                    }

                    if let error {
                        self?.voiceSearchError = error.localizedDescription
                        self?.stopVoiceSearch()
                    }
                }
            }

            // Auto-stop after 10 seconds
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if isVoiceSearchActive {
                    stopVoiceSearch()
                    if !voiceSearchText.isEmpty {
                        searchQuery = voiceSearchText
                        await search()
                    }
                }
            }
        } catch {
            voiceSearchError = "Failed to start voice recognition"
            isVoiceSearchActive = false
        }
    }

    func stopVoiceSearch() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isVoiceSearchActive = false
    }

    // MARK: - Saved Searches

    func saveCurrentSearch() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let saved = SavedSearch(
            id: UUID(),
            query: trimmed,
            filters: filters,
            createdAt: Date(),
        )

        savedSearches.removeAll { $0.query.lowercased() == trimmed.lowercased() }
        savedSearches.insert(saved, at: 0)

        if savedSearches.count > 20 {
            savedSearches = Array(savedSearches.prefix(20))
        }

        persistSearchHistory()
        HapticManager.success()
    }

    func applySavedSearch(_ saved: SavedSearch) {
        searchQuery = saved.query
        filters = saved.filters
        Task { await search() }
        HapticManager.light()
    }

    func deleteSavedSearch(_ saved: SavedSearch) {
        savedSearches.removeAll { $0.id == saved.id }
        persistSearchHistory()
    }

    // MARK: - Suggestions

    private func updateSuggestions(for query: String) {
        if query.isEmpty {
            searchSuggestions = popularSearches
            return
        }

        let lowercased = query.lowercased()

        // Combine recent searches and popular searches that match
        var suggestions: [String] = []

        suggestions.append(contentsOf: recentSearches.filter {
            $0.lowercased().contains(lowercased) && $0.lowercased() != lowercased
        })

        suggestions.append(contentsOf: popularSearches.filter {
            $0.lowercased().contains(lowercased) && !suggestions.contains($0)
        })

        searchSuggestions = Array(suggestions.prefix(5))
    }

    // MARK: - Filter & Clear Actions

    func clearFilters() {
        filters = .default
        HapticManager.light()
    }

    func selectCategory(_ category: Category?) {
        filters.categoryId = category?.id
    }

    func dismissError() {
        error = nil
        showError = false
    }

    func clearSearch() {
        searchQuery = ""
        results = []
        updateSuggestions(for: "")
    }

    func selectRecentSearch(_ query: String) {
        searchQuery = query
        Task { await search() }
    }

    func clearRecentSearches() {
        recentSearches = []
        persistSearchHistory()
    }

    // MARK: - Search History Persistence

    private func saveRecentSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        recentSearches.removeAll { $0.lowercased() == trimmed.lowercased() }
        recentSearches.insert(trimmed, at: 0)

        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }

        persistSearchHistory()
    }

    private func loadSearchHistory() {
        let defaults = UserDefaults.standard
        recentSearches = defaults.stringArray(forKey: "recentSearches") ?? []

        if let savedData = defaults.data(forKey: "savedSearches"),
           let decoded = try? JSONDecoder().decode([SavedSearch].self, from: savedData)
        {
            savedSearches = decoded
        }
    }

    private func persistSearchHistory() {
        let defaults = UserDefaults.standard
        defaults.set(recentSearches, forKey: "recentSearches")

        if let encoded = try? JSONEncoder().encode(savedSearches) {
            defaults.set(encoded, forKey: "savedSearches")
        }
    }

}

// MARK: - Supporting Types

struct SavedSearch: Codable, Identifiable, Sendable {
    let id: UUID
    let query: String
    let filters: SearchFilters
    let createdAt: Date

    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

extension SearchFilters: Codable {}

struct SearchStats: Sendable {
    let totalResults: Int
    let filteredResults: Int
    let categoryBreakdown: [String: Int]
    let averageDistance: Double?

    static let empty = SearchStats(
        totalResults: 0,
        filteredResults: 0,
        categoryBreakdown: [:],
        averageDistance: nil,
    )
}
