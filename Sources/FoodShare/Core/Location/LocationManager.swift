
#if !SKIP
#if !SKIP
import CoreLocation
#endif
import Foundation
import Observation

/// Protocol defining location service operations
protocol LocationService: Sendable {
    /// Request location permission
    func requestPermission() async throws

    /// Get current location
    func getCurrentLocation() async throws -> Location

    /// Start monitoring location updates
    func startMonitoring() async throws -> AsyncStream<Location>

    /// Stop monitoring location updates
    func stopMonitoring() async

    /// Check if location services are authorized
    var isAuthorized: Bool { get async }
}

/// Core Location wrapper that implements LocationService
@MainActor
@Observable
final class LocationManager: NSObject, LocationService {
    private let locationManager = CLLocationManager()
    private var continuation: AsyncStream<Location>.Continuation?
    private var locationContinuation: CheckedContinuation<Location, Error>?
    private var authorizationContinuation: CheckedContinuation<Void, Error>?

    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// Last known location (cached from updates)
    private(set) var currentLocation: Location?

    /// Timestamp when currentLocation was last updated
    private var locationTimestamp: Date?

    /// Maximum age for cached location (60 seconds)
    private let maxLocationAge: TimeInterval = 60.0

    /// Clears the cached location
    func clearCache() {
        currentLocation = nil
        locationTimestamp = nil
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = AppConfiguration.shared.locationUpdateDistanceM
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestPermission() async throws {
        await AppLogger.shared.debug("requestPermission() called, current status: \(authorizationStatus.rawValue)")

        // Check if location services are enabled at device level
        guard CLLocationManager.locationServicesEnabled() else {
            await AppLogger.shared.warning("Location services disabled at device level")
            throw LocationError.locationServicesDisabled
        }

        guard authorizationStatus == .notDetermined else {
            if authorizationStatus == .denied || authorizationStatus == .restricted {
                await AppLogger.shared.warning("Permission denied or restricted")
                throw LocationError.permissionDenied
            }
            await AppLogger.shared.debug("Already authorized, returning")
            return
        }

        await AppLogger.shared.debug("Requesting authorization...")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.authorizationContinuation = continuation
            self.locationManager.requestWhenInUseAuthorization()
        }
        await AppLogger.shared.debug("Permission request completed, status: \(self.authorizationStatus.rawValue)")
    }

    func getCurrentLocation() async throws -> Location {
        await AppLogger.shared.debug("getCurrentLocation() called, isAuthorized: \(isAuthorized)")
        guard isAuthorized else {
            await AppLogger.shared.warning("Not authorized, throwing permissionDenied")
            throw LocationError.permissionDenied
        }

        // Return cached location if available and fresh (within maxLocationAge)
        if let cached = currentLocation,
           let timestamp = locationTimestamp,
           Date().timeIntervalSince(timestamp) < maxLocationAge {
            await AppLogger.shared.debug("Returning cached location (age: \(Date().timeIntervalSince(timestamp))s)")
            return cached
        }

        // Clear stale cache
        if let timestamp = locationTimestamp, Date().timeIntervalSince(timestamp) >= maxLocationAge {
            await AppLogger.shared
                .debug(
                    "Cached location is stale (age: \(Date().timeIntervalSince(timestamp))s), requesting fresh location",
                )
            currentLocation = nil
            locationTimestamp = nil
        }

        await AppLogger.shared.debug("Requesting location from CLLocationManager...")
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            // Use startUpdatingLocation for more reliable location delivery
            locationManager.startUpdatingLocation()

            // Timeout after configured duration
            Task { @MainActor in
                let timeoutNanoseconds = UInt64(Constants.locationRequestTimeout * 1_000_000_000)
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                if let stored = self.locationContinuation {
                    self.locationContinuation = nil // Clear FIRST to prevent race
                    await AppLogger.shared.warning("Location request timed out")
                    locationManager.stopUpdatingLocation()
                    stored.resume(throwing: LocationError.timeout)
                }
            }
        }
    }

    func startMonitoring() async throws -> AsyncStream<Location> {
        guard isAuthorized else {
            throw LocationError.permissionDenied
        }

        return AsyncStream { continuation in
            self.continuation = continuation
            locationManager.startUpdatingLocation()

            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor in
                    await self?.stopMonitoring()
                }
            }
        }
    }

    func stopMonitoring() async {
        locationManager.stopUpdatingLocation()
        continuation?.finish()
        continuation = nil
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            await AppLogger.shared.debug("didUpdateLocations received \(locations.count) locations")
            guard let clLocation = locations.last else {
                await AppLogger.shared.debug("No locations in array")
                return
            }

            let location = Location(
                latitude: clLocation.coordinate.latitude,
                longitude: clLocation.coordinate.longitude,
            )
            await AppLogger.shared.debug("Location update received")

            // Cache the current location with timestamp
            currentLocation = location
            locationTimestamp = Date()

            // Resume single location request if pending
            if let locContinuation = locationContinuation {
                locationContinuation = nil // Clear FIRST to prevent race
                await AppLogger.shared.debug("Resuming location continuation")
                locationManager.stopUpdatingLocation()
                locContinuation.resume(returning: location)
            }

            // Send to monitoring stream
            continuation?.yield(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            await AppLogger.shared.error("Location manager failed", error: error)
            let locationError: LocationError = if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    .permissionDenied
                case .locationUnknown:
                    .locationUnavailable
                default:
                    .unknown(error)
                }
            } else {
                .unknown(error)
            }
            await AppLogger.shared.debug("Mapped to LocationError type")

            // Resume single location request if pending
            if let continuation = locationContinuation {
                locationContinuation = nil // Clear FIRST to prevent race
                await AppLogger.shared.debug("Resuming continuation with error")
                continuation.resume(throwing: locationError)
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            let previousStatus = authorizationStatus
            authorizationStatus = status
            await AppLogger.shared.debug("Authorization changed from \(previousStatus.rawValue) to \(status.rawValue)")

            // Resume pending authorization request if status changed from notDetermined
            if previousStatus == .notDetermined, status != .notDetermined {
                if let continuation = authorizationContinuation {
                    if status == .denied || status == .restricted {
                        await AppLogger.shared.debug("Resuming authorization continuation with error")
                        continuation.resume(throwing: LocationError.permissionDenied)
                    } else {
                        await AppLogger.shared.debug("Resuming authorization continuation with success")
                        continuation.resume()
                    }
                    authorizationContinuation = nil
                }
            }
        }
    }
}

#endif
