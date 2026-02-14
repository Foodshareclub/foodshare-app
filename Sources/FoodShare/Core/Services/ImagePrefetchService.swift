//
//  ImagePrefetchService.swift
//  Foodshare
//
//  Service for prefetching images before they're needed.
//  Uses Kingfisher's prefetching capabilities to load images
//  that will likely be scrolled into view soon.
//

import Foundation
import Kingfisher
import OSLog

/// Service for prefetching images to improve scroll performance.
///
/// When the user is scrolling through a list, this service can prefetch
/// images for items that are about to become visible, reducing perceived
/// latency and jank.
///
/// Usage:
/// ```swift
/// // Prefetch images for upcoming items
/// let urls = upcomingItems.compactMap { $0.imageURL }
/// ImagePrefetchService.shared.prefetch(urls: urls)
///
/// // Cancel prefetching when leaving screen
/// ImagePrefetchService.shared.cancelPrefetching()
/// ```
@MainActor
final class ImagePrefetchService {
    // MARK: - Singleton

    static let shared = ImagePrefetchService()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "ImagePrefetch")
    private var prefetcher: ImagePrefetcher?

    /// Maximum number of images to prefetch at once
    private let maxPrefetchCount = 10

    /// Track URLs currently being prefetched to avoid duplicates
    private var prefetchingURLs: Set<URL> = []

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Prefetch images for the given URLs.
    ///
    /// Images are downloaded in the background and cached for later use.
    /// Already-cached images are skipped automatically by Kingfisher.
    ///
    /// - Parameter urls: URLs of images to prefetch
    func prefetch(urls: [URL]) {
        // Filter out already-prefetching URLs and limit count
        let newURLs = urls
            .filter { !prefetchingURLs.contains($0) }
            .prefix(maxPrefetchCount)

        guard !newURLs.isEmpty else { return }

        // Track these URLs
        for url in newURLs {
            prefetchingURLs.insert(url)
        }

        logger.debug("📥 Prefetching \(newURLs.count) images")

        // Create new prefetcher for this batch
        let urlArray = Array(newURLs)
        prefetcher = ImagePrefetcher(
            urls: urlArray,
            options: [.backgroundDecode],
            completionHandler: { [weak self] (
                skippedResources: [Resource],
                failedResources: [Resource],
                completedResources: [Resource],
            ) in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    // Remove from tracking
                    for url in newURLs {
                        self.prefetchingURLs.remove(url)
                    }
                    self.logger
                        .debug(
                            "✅ Prefetch complete: \(completedResources.count) loaded, \(skippedResources.count) cached, \(failedResources.count) failed",
                        )
                }
            },
        )
        prefetcher?.start()
    }

    /// Prefetch images for food items that are about to become visible.
    ///
    /// Call this when items near the scroll threshold become visible.
    ///
    /// - Parameter items: Food items to prefetch images for
    func prefetchForItems(_ items: [FoodItem]) {
        let urls = items.compactMap { item -> URL? in
            guard let firstImage = item.images?.first else { return nil }
            return URL(string: firstImage)
        }
        prefetch(urls: urls)
    }

    /// Prefetch avatar images for users.
    ///
    /// - Parameter avatarURLs: Avatar URL strings to prefetch
    func prefetchAvatars(_ avatarURLs: [String?]) {
        let urls = avatarURLs.compactMap { urlString -> URL? in
            guard let urlString else { return nil }
            return URL(string: urlString)
        }
        prefetch(urls: urls)
    }

    /// Cancel all ongoing prefetch operations.
    ///
    /// Call this when leaving a screen to free up resources.
    func cancelPrefetching() {
        prefetcher?.stop()
        prefetcher = nil
        prefetchingURLs.removeAll()
        logger.debug("🛑 Prefetching cancelled")
    }

    /// Get cache status for debugging
    func getCacheStats() -> (limit: Int, currentSize: Int) {
        let cache = KingfisherManager.shared.cache
        let limit = Int(cache.diskStorage.config.sizeLimit)
        return (limit, limit) // Note: currentSize is approximated as limit
    }

    /// Clear image cache (use sparingly, e.g., on memory warning)
    func clearCache() {
        KingfisherManager.shared.cache.clearCache()
        logger.info("🗑️ Image cache cleared")
    }
}

// MARK: - Integration with FoodItem Lists

extension ImagePrefetchService {
    /// Prefetch images for items about to scroll into view.
    ///
    /// Call this from `onItemAppeared(at:)` in ViewModels to prefetch
    /// images for the next batch of items.
    ///
    /// - Parameters:
    ///   - visibleIndex: Index of the item that just became visible
    ///   - allItems: All items in the list
    ///   - prefetchCount: Number of items ahead to prefetch (default: 5)
    func prefetchAhead(
        visibleIndex: Int,
        allItems: [FoodItem],
        prefetchCount: Int = 5,
    ) {
        // Calculate range of items to prefetch
        let startIndex = visibleIndex + 1
        let endIndex = min(startIndex + prefetchCount, allItems.count)

        guard startIndex < endIndex else { return }

        let itemsToPrefetch = Array(allItems[startIndex ..< endIndex])
        prefetchForItems(itemsToPrefetch)
    }
}
