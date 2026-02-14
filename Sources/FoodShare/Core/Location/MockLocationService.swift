import Foundation

/// Mock location service for testing
actor MockLocationService: LocationService {
    var mockLocation: Location?
    var mockError: Error?
    var shouldAuthorize = true
    var permissionRequested = false
    var isMonitoring = false

    func requestPermission() async throws {
        permissionRequested = true

        if !shouldAuthorize {
            throw LocationError.permissionDenied
        }
    }

    func getCurrentLocation() async throws -> Location {
        if let error = mockError {
            throw error
        }

        guard shouldAuthorize else {
            throw LocationError.permissionDenied
        }

        guard let location = mockLocation else {
            throw LocationError.locationUnavailable
        }

        return location
    }

    func startMonitoring() async throws -> AsyncStream<Location> {
        guard shouldAuthorize else {
            throw LocationError.permissionDenied
        }

        isMonitoring = true

        return AsyncStream { continuation in
            if let location = self.mockLocation {
                continuation.yield(location)
            }
            continuation.finish()
        }
    }

    func stopMonitoring() async {
        isMonitoring = false
    }

    var isAuthorized: Bool {
        shouldAuthorize
    }

    func reset() {
        mockLocation = nil
        mockError = nil
        shouldAuthorize = true
        permissionRequested = false
        isMonitoring = false
    }
}
