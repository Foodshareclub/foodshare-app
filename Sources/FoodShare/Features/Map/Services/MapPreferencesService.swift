
#if !SKIP
import CoreHaptics
import CoreMotion
import Foundation
import MapKit
import Observation
import OSLog
import Supabase

@MainActor
@Observable
final class MapPreferencesService {
    private let redis: UpstashRedisClient
    private let supabase = AuthenticationService.shared.supabase
    private let logger = Logger(subsystem: "FoodShare", category: "MapPreferences")

    // L1 Cache - Memory
    private var memoryCache: MapPreferences?
    private var cacheTimestamp: Date?
    private let memoryCacheTTL: TimeInterval = 300

    // Battery-Aware Performance
    private var batteryLevel: Float = 1.0
    private var isLowPowerModeEnabled = false

    /// Haptic Feedback
    nonisolated(unsafe) private var hapticEngine: CHHapticEngine?

    // Motion-based Quality Adaptation
    nonisolated(unsafe) private let motionManager = CMMotionManager()
    private var currentMotionState: MotionState = .stationary

    // Debouncing
    private var saveTask: Task<Void, Never>?
    private let saveDebounceInterval: TimeInterval = 2.0

    /// Quality Management
    private var qualitySettings: MapQualitySettings?

    init(redis: UpstashRedisClient) {
        self.redis = redis
        startMotionDetection()
        setupBatteryMonitoring()
        setupHapticEngine()
    }

    // MARK: - Battery-Aware Performance

    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryLevel = UIDevice.current.batteryLevel
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            self?.updateBatteryAwareSettings()
        }

        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            self?.updateBatteryAwareSettings()
        }
    }

    private func updateBatteryAwareSettings() {
        batteryLevel = UIDevice.current.batteryLevel
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

        Task {
            var settings = await getOptimalQualitySettings()

            if batteryLevel < 0.2 || isLowPowerModeEnabled {
                settings.quality = "low"
                settings.concurrentTiles = 2
                settings.retina = false
                logger.info("Enabled power saving mode")
            } else if batteryLevel < 0.5 {
                settings.quality = settings.quality == "high" ? "medium" : settings.quality
                settings.concurrentTiles = max(3, settings.concurrentTiles - 1)
            }

            qualitySettings = settings
        }
    }

    // MARK: - Haptic Feedback

    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            logger.error("Failed to create haptic engine: \(error)")
        }
    }

    private func playHapticFeedback(for event: HapticEvent) {
        guard !isLowPowerModeEnabled,
              batteryLevel > 0.15,
              let engine = hapticEngine else { return }

        do {
            guard let pattern = createHapticPattern(for: event) else {
                logger.warning("Failed to create haptic pattern for event: \(event)")
                return
            }
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            logger.error("Failed to play haptic: \(error)")
        }
    }

    private func createHapticPattern(for event: HapticEvent) -> CHHapticPattern? {
        var events: [CHHapticEvent] = []

        switch event {
        case .mapSync:
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                ],
                relativeTime: 0,
            ))
        case .qualityChange:
            for i in 0 ..< 2 {
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7),
                    ],
                    relativeTime: TimeInterval(i) * 0.1,
                ))
            }
        case .preloadComplete:
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.2),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
                ],
                relativeTime: 0,
                duration: 0.1,
            ))
        }

        do {
            return try CHHapticPattern(events: events, parameters: [])
        } catch {
            logger.error("Failed to create haptic pattern: \(error)")
            return nil
        }
    }

    // MARK: - Motion Detection

    private func startMotionDetection() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 0.5
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion else { return }

            let acceleration = sqrt(
                pow(motion.userAcceleration.x, 2) +
                    pow(motion.userAcceleration.y, 2) +
                    pow(motion.userAcceleration.z, 2),
            )

            let newState: MotionState = acceleration > 0.1 ? .moving : .stationary

            if newState != self?.currentMotionState {
                self?.currentMotionState = newState
                self?.adaptQualityToMotion(newState)
            }
        }
    }

    private func adaptQualityToMotion(_ state: MotionState) {
        Task {
            var adaptedSettings = await getOptimalQualitySettings()

            switch state {
            case .moving:
                adaptedSettings.quality = adaptedSettings.quality == "high" ? "medium" : "low"
                adaptedSettings.concurrentTiles = max(2, adaptedSettings.concurrentTiles - 2)
                playHapticFeedback(for: .qualityChange)
            case .stationary:
                if batteryLevel > 0.5, !isLowPowerModeEnabled {
                    // Restore quality when stationary
                }
            }

            qualitySettings = adaptedSettings
            logger.info("Adapted quality for motion: \(state) -> \(adaptedSettings.quality)")
        }
    }

    // MARK: - Public API

    func saveMapState(center: CLLocationCoordinate2D, zoom: Double) {
        saveTask?.cancel()
        saveTask = Task {
            let debounceTime = getBatteryAwareDebounceTime()
            try? await Task.sleep(nanoseconds: UInt64(debounceTime * 1_000_000_000))
            await performSave(center: center, zoom: zoom)

            await MainActor.run {
                playHapticFeedback(for: .mapSync)
            }
        }
    }

    private func getBatteryAwareDebounceTime() -> TimeInterval {
        if isLowPowerModeEnabled || batteryLevel < 0.2 {
            5.0
        } else if currentMotionState == .moving {
            1.0
        } else {
            saveDebounceInterval
        }
    }

    func loadMapPreferences() async -> MapPreferences? {
        if let cached = getFromMemoryCache() {
            logger.info("Map preferences loaded from memory cache")
            return cached
        }

        if let cached = await getFromRedisCache() {
            updateMemoryCache(cached)
            logger.info("Map preferences loaded from Redis cache")
            return cached
        }

        if let preferences = await getFromDatabase() {
            await setRedisCache(preferences)
            updateMemoryCache(preferences)
            logger.info("Map preferences loaded from database")
            return preferences
        }

        return nil
    }

    func getOptimalQualitySettings() async -> MapQualitySettings {
        if let cached = qualitySettings {
            return cached
        }

        do {
            let response: QualityResponse = try await supabase.functions
                .invoke("map-services/quality", options: FunctionInvokeOptions(method: .get))

            qualitySettings = response.settings
            return response.settings

        } catch {
            logger.error("Failed to get quality settings: \(error)")
            return MapQualitySettings.default
        }
    }

    // MARK: - Cache Implementation

    private func performSave(center: CLLocationCoordinate2D, zoom: Double) async {
        let preferences = MapPreferences(
            lastCenterLat: center.latitude,
            lastCenterLng: center.longitude,
            lastZoomLevel: zoom,
            mapStyle: "standard",
            searchRadiusKm: 10.0,
            platform: "ios",
            deviceId: UIDevice.current.identifierForVendor?.uuidString,
            updatedAt: Date(),
        )

        updateMemoryCache(preferences)

        Task.detached { [weak self] in
            await self?.saveToRedisAndDatabase(preferences)
        }
    }

    private func saveToRedisAndDatabase(_ preferences: MapPreferences) async {
        async let redisResult: () = setRedisCache(preferences)
        async let dbResult: () = saveToDatabase(preferences)
        await (redisResult, dbResult)
    }

    private func getFromMemoryCache() -> MapPreferences? {
        guard let cache = memoryCache,
              let timestamp = cacheTimestamp,
              Date().timeIntervalSince(timestamp) < memoryCacheTTL else
        {
            return nil
        }
        return cache
    }

    private func updateMemoryCache(_ preferences: MapPreferences) {
        memoryCache = preferences
        cacheTimestamp = Date()
    }

    private func getFromRedisCache() async -> MapPreferences? {
        do {
            let key = "map_prefs:ios:\(getCurrentUserId())"
            guard let data = try await redis.get(key) else { return nil }
            return try JSONDecoder().decode(MapPreferences.self, from: Data(data.utf8))
        } catch {
            logger.error("Redis cache read failed: \(error)")
            return nil
        }
    }

    private func setRedisCache(_ preferences: MapPreferences) async {
        do {
            let key = "map_prefs:ios:\(getCurrentUserId())"
            let data = try JSONEncoder().encode(preferences)
            guard let json = String(data: data, encoding: .utf8) else {
                logger.error("Failed to convert JSON data to UTF-8 string")
                return
            }
            try await redis.setex(key, value: json, ttl: 3600)
        } catch {
            logger.error("Redis cache write failed: \(error)")
        }
    }

    private func getFromDatabase() async -> MapPreferences? {
        do {
            let response: MapPreferencesResponse = try await supabase.functions
                .invoke("map-services/preferences", options: FunctionInvokeOptions(
                    method: .get,
                    query: [URLQueryItem(name: "platform", value: "ios")],
                ))
            return response.preferences
        } catch {
            logger.error("Database read failed: \(error)")
            return nil
        }
    }

    private func saveToDatabase(_ preferences: MapPreferences) async {
        do {
            let request = MapPreferencesRequest(
                center: MapCenter(lat: preferences.lastCenterLat ?? 0, lng: preferences.lastCenterLng ?? 0),
                zoom: preferences.lastZoomLevel ?? 12,
                platform: "ios",
                deviceId: preferences.deviceId,
            )

            let _: MapPreferencesResponse = try await supabase.functions
                .invoke("map-services/preferences", options: FunctionInvokeOptions(body: request))
        } catch {
            logger.error("Database save failed: \(error)")
        }
    }

    private func getCurrentUserId() -> String {
        supabase.auth.currentUser?.id.uuidString ??
            UIDevice.current.identifierForVendor?.uuidString ??
            "anonymous"
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
        try? hapticEngine?.stop()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Supporting Types

enum HapticEvent: CustomStringConvertible {
    case mapSync
    case qualityChange
    case preloadComplete

    var description: String {
        switch self {
        case .mapSync: "mapSync"
        case .qualityChange: "qualityChange"
        case .preloadComplete: "preloadComplete"
        }
    }
}

enum MotionState: CustomStringConvertible {
    case stationary
    case moving

    var description: String {
        switch self {
        case .stationary: "stationary"
        case .moving: "moving"
        }
    }
}

struct MapQualitySettings: Codable {
    var quality: String
    var retina: Bool
    var vector: Bool
    var concurrentTiles: Int
    var compression: String

    static let `default` = MapQualitySettings(
        quality: "medium",
        retina: true,
        vector: true,
        concurrentTiles: 6,
        compression: "medium",
    )

    private enum CodingKeys: String, CodingKey {
        case quality, retina, vector, compression
        case concurrentTiles = "concurrent_tiles"
    }
}

struct QualityResponse: Codable {
    let success: Bool
    let settings: MapQualitySettings
}

struct MapPreferences: Codable {
    let lastCenterLat: Double?
    let lastCenterLng: Double?
    let lastZoomLevel: Double?
    let mapStyle: String?
    let searchRadiusKm: Double?
    let platform: String?
    let deviceId: String?
    let updatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case lastCenterLat = "last_center_lat"
        case lastCenterLng = "last_center_lng"
        case lastZoomLevel = "last_zoom_level"
        case mapStyle = "map_style"
        case searchRadiusKm = "search_radius_km"
        case platform, deviceId, updatedAt
    }
}

struct MapCenter: Codable {
    let lat: Double
    let lng: Double
}

struct MapPreferencesRequest: Codable {
    let center: MapCenter
    let zoom: Double
    let platform: String
    let deviceId: String?
}

struct MapPreferencesResponse: Codable {
    let success: Bool
    let preferences: MapPreferences?
}

#endif
