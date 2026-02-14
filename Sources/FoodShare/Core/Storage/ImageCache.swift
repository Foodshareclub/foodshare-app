import Foundation
#if !SKIP
import UIKit
#endif

/// Protocol for image caching
protocol ImageCacheProtocol: Sendable {
    /// Get image from cache
    func image(for key: String) -> UIImage?

    /// Store image in cache
    func setImage(_ image: UIImage, for key: String)

    /// Remove image from cache
    func removeImage(for key: String)

    /// Clear all cached images
    func clearCache()
}

/// NSCache-based image cache implementation
final class ImageCache: ImageCacheProtocol, @unchecked Sendable {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private init() {
        // Configure cache limits
        cache.countLimit = 100 // Maximum 100 images
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB

        // Setup disk cache directory
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachesDirectory.appendingPathComponent("ImageCache")

        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Register for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func image(for key: String) -> UIImage? {
        let nsKey = key as NSString

        // Check memory cache first
        if let cachedImage = cache.object(forKey: nsKey) {
            return cachedImage
        }

        // Check disk cache
        if let diskImage = loadFromDisk(key: key) {
            // Store in memory cache for faster access
            cache.setObject(diskImage, forKey: nsKey)
            return diskImage
        }

        return nil
    }

    func setImage(_ image: UIImage, for key: String) {
        let nsKey = key as NSString

        // Store in memory cache
        cache.setObject(image, forKey: nsKey)

        // Store in disk cache
        saveToDisk(image: image, key: key)
    }

    func removeImage(for key: String) {
        let nsKey = key as NSString

        // Remove from memory cache
        cache.removeObject(forKey: nsKey)

        // Remove from disk cache
        let fileURL = cacheDirectory.appendingPathComponent(key.md5Hash)
        try? fileManager.removeItem(at: fileURL)
    }

    func clearCache() {
        // Clear memory cache
        cache.removeAllObjects()

        // Clear disk cache
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Private

    private func loadFromDisk(key: String) -> UIImage? {
        let fileURL = cacheDirectory.appendingPathComponent(key.md5Hash)

        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        return UIImage(data: data)
    }

    private func saveToDisk(image: UIImage, key: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return
        }

        let fileURL = cacheDirectory.appendingPathComponent(key.md5Hash)
        try? data.write(to: fileURL)
    }

    @objc private func handleMemoryWarning() {
        cache.removeAllObjects()
    }
}

// MARK: - String Extension

extension String {
    fileprivate var md5Hash: String {
        guard let data = data(using: .utf8) else { return self }
        var digest = [UInt8](repeating: 0, count: 16)

        // Simple hash for demo - in production use CryptoKit
        data.withUnsafeBytes { buffer in
            for (index, byte) in buffer.enumerated() {
                digest[index % 16] ^= byte
            }
        }

        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
