//
//  LimitedDictionary.swift
//  Foodshare
//
//  Thread-safe LRU dictionary with automatic eviction and memory warning cleanup.
//  Used for managing animation states and other ephemeral view data.
//

import Foundation
#if !SKIP
import UIKit
#endif

/// A thread-safe dictionary with LRU eviction policy and memory warning cleanup.
/// Useful for managing transient UI state like animation flags.
@MainActor
final class LimitedDictionary<Key: Hashable, Value> {
    private var storage: [Key: Value] = [:]
    private var accessOrder: [Key] = []
    private let maxCapacity: Int
    // nonisolated(unsafe) allows access from deinit - safe because observer removal is thread-safe
    nonisolated(unsafe) private var memoryWarningObserver: NSObjectProtocol?

    /// Initialize with maximum capacity (default 50 entries)
    init(maxCapacity: Int = 50) {
        self.maxCapacity = maxCapacity
        setupMemoryWarningObserver()
    }

    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Subscript Access

    subscript(key: Key) -> Value? {
        get {
            if let value = storage[key] {
                // Move to end of access order (most recently used)
                if let index = accessOrder.firstIndex(of: key) {
                    accessOrder.remove(at: index)
                    accessOrder.append(key)
                }
                return value
            }
            return nil
        }
        set {
            if let value = newValue {
                // Remove from current position if exists
                if let index = accessOrder.firstIndex(of: key) {
                    accessOrder.remove(at: index)
                }

                // Evict LRU items if at capacity
                while accessOrder.count >= maxCapacity {
                    if let lruKey = accessOrder.first {
                        accessOrder.removeFirst()
                        storage.removeValue(forKey: lruKey)
                    }
                }

                // Insert new value
                storage[key] = value
                accessOrder.append(key)
            } else {
                // Remove value
                storage.removeValue(forKey: key)
                if let index = accessOrder.firstIndex(of: key) {
                    accessOrder.remove(at: index)
                }
            }
        }
    }

    // MARK: - Bulk Operations

    /// Remove all entries
    func removeAll() {
        storage.removeAll()
        accessOrder.removeAll()
    }

    /// Remove entries for keys not in the provided set (cleanup stale entries)
    func retainOnly<S: Sequence>(keys: S) where S.Element == Key {
        let keySet = Set(keys)
        let keysToRemove = storage.keys.filter { !keySet.contains($0) }
        for key in keysToRemove {
            storage.removeValue(forKey: key)
            if let index = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: index)
            }
        }
    }

    /// Current number of entries
    var count: Int {
        storage.count
    }

    /// Check if key exists
    func contains(_ key: Key) -> Bool {
        storage[key] != nil
    }

    // MARK: - Memory Warning Handling

    private func setupMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }

    private func handleMemoryWarning() {
        // On memory warning, evict oldest 50% of entries
        let entriesToRemove = accessOrder.count / 2
        for _ in 0..<entriesToRemove {
            if let lruKey = accessOrder.first {
                accessOrder.removeFirst()
                storage.removeValue(forKey: lruKey)
            }
        }
    }
}

// MARK: - Convenience Extensions

extension LimitedDictionary where Value == Bool {
    /// Set value to true for key
    func markTrue(_ key: Key) {
        self[key] = true
    }

    /// Check if value is true for key
    func isTrue(_ key: Key) -> Bool {
        self[key] == true
    }
}

extension LimitedDictionary: @preconcurrency ExpressibleByDictionaryLiteral {
    @MainActor
    convenience init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(maxCapacity: max(50, elements.count))
        for (key, value) in elements {
            self[key] = value
        }
    }
}
