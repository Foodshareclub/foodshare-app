

#if !SKIP
import Foundation
import OSLog

/// Generic cache protocol
protocol CacheService: Sendable {
    associatedtype Key: Hashable & Sendable
    associatedtype Value: Sendable

    /// Get value from cache
    func get(_ key: Key) async -> Value?

    /// Set value in cache
    func set(_ key: Key, value: Value) async

    /// Remove value from cache
    func remove(_ key: Key) async

    /// Clear all cached values
    func clear() async
}

/// Memory-based cache implementation
actor MemoryCache<Key: Hashable & Sendable, Value: Sendable>: CacheService {
    private var cache: [Key: CacheEntry<Value>] = [:]
    private let expirationInterval: TimeInterval?

    init(expirationInterval: TimeInterval? = nil) {
        self.expirationInterval = expirationInterval
    }

    func get(_ key: Key) async -> Value? {
        guard let entry = cache[key] else {
            return nil
        }

        // Check if expired
        if let expirationInterval,
           Date().timeIntervalSince(entry.timestamp) > expirationInterval {
            cache.removeValue(forKey: key)
            return nil
        }

        return entry.value
    }

    func set(_ key: Key, value: Value) async {
        cache[key] = CacheEntry(value: value, timestamp: Date())
    }

    func remove(_ key: Key) async {
        cache.removeValue(forKey: key)
    }

    func clear() async {
        cache.removeAll()
    }

    // MARK: - Private

    private struct CacheEntry<T: Sendable>: Sendable {
        let value: T
        let timestamp: Date
    }
}
#endif

#if !SKIP
/// Disk-based cache implementation
actor DiskCache<Key: Hashable & Sendable & CustomStringConvertible, Value: Codable & Sendable>: CacheService {
    private let cacheDirectory: URL
    private let expirationInterval: TimeInterval?
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "DiskCache")

    init(
        cacheName: String,
        expirationInterval: TimeInterval? = nil,
    ) {
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachesDirectory.appendingPathComponent(cacheName)
        self.expirationInterval = expirationInterval

        // Create cache directory if needed
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create cache directory at \(cacheName): \(error.localizedDescription)")
        }
    }

    func get(_ key: Key) async -> Value? {
        let fileURL = cacheDirectory.appendingPathComponent(key.description)

        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        // Check if expired
        if let expirationInterval,
           let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
           let modificationDate = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(modificationDate) > expirationInterval {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }

        return try? JSONDecoder().decode(Value.self, from: data)
    }

    func set(_ key: Key, value: Value) async {
        let fileURL = cacheDirectory.appendingPathComponent(key.description)

        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: fileURL)
        } catch let error as EncodingError {
            logger.error("Failed to encode cache value for key '\(key.description)': \(error.localizedDescription)")
        } catch {
            logger.error("Failed to write cache file for key '\(key.description)': \(error.localizedDescription)")
        }
    }

    func remove(_ key: Key) async {
        let fileURL = cacheDirectory.appendingPathComponent(key.description)
        try? fileManager.removeItem(at: fileURL)
    }

    func clear() async {
        do {
            try fileManager.removeItem(at: cacheDirectory)
        } catch {
            logger.warning("Failed to remove cache directory during clear: \(error.localizedDescription)")
        }

        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to recreate cache directory after clear: \(error.localizedDescription)")
        }
    }
}

#endif
