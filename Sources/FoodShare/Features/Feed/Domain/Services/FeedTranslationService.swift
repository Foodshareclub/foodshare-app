//
//  FeedTranslationService.swift
//  FoodShare
//
//  Service layer for handling translations of food items.
//  Provides batched translation fetching with timeout and error handling.
//

import Foundation
import OSLog

/// Type alias for translation results: [itemId: [field: translation]]
typealias TranslationMap = [String: [String: String?]]

// MARK: - Feed Translation Service Protocol

/// Protocol for feed item translation operations
@MainActor
protocol FeedTranslationServiceProtocol {
    /// Fetches and applies translations for food items
    /// - Parameter items: The items to translate
    /// - Returns: Items with translations applied
    func translateItems(_ items: inout [FoodItem]) async

    /// Fetches translations for a specific batch of items
    /// - Parameter items: The items to translate
    /// - Returns: Updated items with translations
    func fetchTranslationsForBatch(_ items: [FoodItem]) async -> [FoodItem]

    /// Checks if translation is needed for the current locale
    var isTranslationNeeded: Bool { get }

    /// The current locale code
    var currentLocale: String { get }
}

// MARK: - Feed Translation Service

/// Default implementation of FeedTranslationServiceProtocol
@MainActor
final class FeedTranslationService: FeedTranslationServiceProtocol {
    // MARK: - Properties

    private let translationService: EnhancedTranslationService
    private let batchSize: Int
    private let timeoutSeconds: TimeInterval
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "FeedTranslationService")

    // MARK: - Initialization

    init(
        translationService: EnhancedTranslationService = .shared,
        batchSize: Int = 20,
        timeoutSeconds: TimeInterval = 5
    ) {
        self.translationService = translationService
        self.batchSize = batchSize
        self.timeoutSeconds = timeoutSeconds
    }

    // MARK: - FeedTranslationServiceProtocol

    var isTranslationNeeded: Bool {
        translationService.currentLocale != "en"
    }

    var currentLocale: String {
        translationService.currentLocale
    }

    func translateItems(_ items: inout [FoodItem]) async {
        guard isTranslationNeeded, !items.isEmpty else { return }

        // Process in batches to avoid overwhelming the API
        let batches = stride(from: 0, to: items.count, by: batchSize).map {
            Array(items[$0..<min($0 + batchSize, items.count)])
        }

        for batch in batches {
            await processBatch(batch, in: &items)
        }

        let translatedCount = items.filter { $0.translationLocale != nil }.count
        logger.debug("Applied translations to \(translatedCount) items")
    }

    func fetchTranslationsForBatch(_ items: [FoodItem]) async -> [FoodItem] {
        guard isTranslationNeeded, !items.isEmpty else { return items }

        var result = items
        await processBatch(items, in: &result)
        return result
    }

    // MARK: - Private Helpers

    private func processBatch(_ batch: [FoodItem], in items: inout [FoodItem]) async {
        let itemIds = batch.map { Int64($0.id) }

        do {
            let translations = try await fetchWithTimeout(itemIds: itemIds)
            guard !translations.isEmpty else { return }

            applyTranslations(translations, to: batch, in: &items)

        } catch FeedTranslationError.timeout {
            logger.warning("Translation request timed out for batch of \(batch.count) items - using original text")
        } catch is CancellationError {
            // Task cancelled, don't log as error
        } catch {
            logger.warning("Translation fetch failed: \(error.localizedDescription) - using original text")
        }
    }

    private func fetchWithTimeout(itemIds: [Int64]) async throws -> TranslationMap {
        try await withThrowingTaskGroup(of: TranslationMap.self) { group in
            group.addTask { [translationService] in
                await translationService.fetchPostTranslations(postIds: itemIds)
            }

            group.addTask { [timeoutSeconds] in
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                throw FeedTranslationError.timeout
            }

            if let result = try await group.next() {
                group.cancelAll()
                return result
            }
            return [:]
        }
    }

    private func applyTranslations(
        _ translations: TranslationMap,
        to batch: [FoodItem],
        in items: inout [FoodItem]
    ) {
        for item in batch {
            let itemId = String(item.id)
            guard let itemTrans = translations[itemId],
                  let index = items.firstIndex(where: { $0.id == item.id }) else {
                continue
            }

            var updatedItem = items[index]

            if let title = itemTrans["title"] ?? nil {
                updatedItem.titleTranslated = title
            }
            if let desc = itemTrans["description"] ?? nil {
                updatedItem.descriptionTranslated = desc
            }

            if updatedItem.titleTranslated != nil || updatedItem.descriptionTranslated != nil {
                updatedItem.translationLocale = currentLocale
                items[index] = updatedItem
            }
        }
    }
}

// MARK: - Translation Error

enum FeedTranslationError: Error {
    case timeout
    case noTranslationsAvailable
    case networkError(String)
}

// MARK: - FoodItem Translation Extensions

extension FoodItem {
    /// Returns the display title (translated if available)
    var displayTitle: String {
        titleTranslated ?? title
    }

    /// Returns the display description (translated if available)
    var displayDescription: String? {
        descriptionTranslated ?? description
    }

}
