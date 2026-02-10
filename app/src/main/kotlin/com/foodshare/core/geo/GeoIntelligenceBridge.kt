package com.foodshare.core.geo

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlin.math.*

// Swift-generated imports
import com.foodshare.swift.generated.GeoIntelligenceEngine as SwiftGeoEngine
import com.foodshare.swift.generated.GeoBoundingBox as SwiftBoundingBox
import com.foodshare.swift.generated.OptimizedRoute as SwiftOptimizedRoute
import com.foodshare.swift.generated.SwiftGeofenceResult
import com.foodshare.swift.generated.TravelTimeEstimate as SwiftTravelTime
import com.foodshare.swift.generated.SwiftCoordinate

/**
 * Bridge to Swift GeoIntelligence Engine.
 * Phase 12: Geographic Intelligence with clustering, geofencing, route optimization
 *
 * Migrated to Swift for cross-platform consistency with iOS.
 * Core algorithms (distance, geofence, route, geohash) delegate to Swift.
 * Complex stateful operations (clustering, hotspots) remain in Kotlin.
 */
object GeoIntelligenceBridge {

    private val json = Json { ignoreUnknownKeys = true }
    private const val EARTH_RADIUS_KM = 6371.0

    // MARK: - Distance Calculations (Swift)

    /**
     * Calculate distance between two coordinates using Haversine formula.
     * Delegates to Swift GeoIntelligenceEngine.
     */
    fun calculateDistance(from: Coordinate, to: Coordinate): Double {
        return SwiftGeoEngine.calculateDistance(from.lat, from.lng, to.lat, to.lng)
    }

    /**
     * Calculate distance matrix between origins and destinations.
     */
    fun calculateDistanceMatrix(
        origins: List<Coordinate>,
        destinations: List<Coordinate>
    ): DistanceMatrix {
        val distances = origins.map { origin ->
            destinations.map { destination ->
                calculateDistance(origin, destination)
            }
        }

        return DistanceMatrix(
            origins = origins,
            destinations = destinations,
            distances = distances
        )
    }

    // MARK: - Bounding Box (Swift)

    /**
     * Calculate bounding box around a center point.
     * Delegates to Swift GeoIntelligenceEngine.
     */
    fun calculateBoundingBox(center: Coordinate, radiusKm: Double): BoundingBox {
        val swiftResult: SwiftBoundingBox = SwiftGeoEngine.calculateBoundingBox(
            center.lat, center.lng, radiusKm
        )
        return swiftResult.use { result ->
            BoundingBox(
                northEast = GeoCoordinate(latitude = result.maxLat, longitude = result.maxLng),
                southWest = GeoCoordinate(latitude = result.minLat, longitude = result.minLng)
            )
        }
    }

    // MARK: - Clustering (DBSCAN - Kotlin)
    // Note: Kept in Kotlin due to stateful mutable operations

    /**
     * Cluster locations using DBSCAN algorithm.
     */
    fun clusterLocations(
        locations: List<LocationPoint>,
        config: ClusterConfig = ClusterConfig()
    ): List<Cluster> {
        val clusters = mutableListOf<Cluster>()
        val visited = mutableSetOf<String>()
        val noise = mutableListOf<LocationPoint>()

        for (point in locations) {
            if (point.id in visited) continue
            visited.add(point.id)

            val neighbors = getNeighbors(point, locations, config.epsilonKm)

            if (neighbors.size < config.minPoints) {
                noise.add(point)
            } else {
                val clusterPoints = mutableListOf(point)
                val seeds = neighbors.filter { it.id !in visited }.toMutableList()

                while (seeds.isNotEmpty()) {
                    val currentPoint = seeds.removeAt(0)
                    if (currentPoint.id in visited) continue
                    visited.add(currentPoint.id)

                    clusterPoints.add(currentPoint)

                    val currentNeighbors = getNeighbors(currentPoint, locations, config.epsilonKm)
                    if (currentNeighbors.size >= config.minPoints) {
                        seeds.addAll(currentNeighbors.filter { it.id !in visited })
                    }
                }

                val centroid = calculateCentroid(clusterPoints)
                clusters.add(Cluster(
                    id = java.util.UUID.randomUUID().toString(),
                    centroid = centroid,
                    points = clusterPoints,
                    radius = calculateClusterRadius(centroid, clusterPoints)
                ))
            }
        }

        return clusters
    }

    private fun getNeighbors(
        point: LocationPoint,
        allPoints: List<LocationPoint>,
        epsilon: Double
    ): List<LocationPoint> {
        return allPoints.filter { other ->
            other.id != point.id &&
            calculateDistance(point.coordinate, other.coordinate) <= epsilon
        }
    }

    private fun calculateCentroid(points: List<LocationPoint>): Coordinate {
        if (points.isEmpty()) return Coordinate(0.0, 0.0)

        val sumLat = points.sumOf { it.coordinate.lat }
        val sumLng = points.sumOf { it.coordinate.lng }

        return Coordinate(
            lat = sumLat / points.size,
            lng = sumLng / points.size
        )
    }

    private fun calculateClusterRadius(centroid: Coordinate, points: List<LocationPoint>): Double {
        if (points.isEmpty()) return 0.0
        return points.maxOfOrNull { calculateDistance(centroid, it.coordinate) } ?: 0.0
    }

    // MARK: - Geofencing (Swift)

    /**
     * Check if a coordinate is inside a geofence.
     * Delegates to Swift GeoIntelligenceEngine.
     */
    fun checkGeofence(location: Coordinate, geofence: Geofence): GeofenceResult {
        val swiftResult: SwiftGeofenceResult = SwiftGeoEngine.checkGeofence(
            location.lat, location.lng,
            geofence.center.lat, geofence.center.lng,
            geofence.radiusKm
        )
        return swiftResult.use { result ->
            GeofenceResult(
                geofenceId = geofence.id,
                isInside = result.isInside,
                distanceFromCenter = result.distanceFromCenter,
                distanceFromEdge = result.distanceFromEdge
            )
        }
    }

    /**
     * Check multiple geofences.
     */
    fun checkGeofences(location: Coordinate, geofences: List<Geofence>): List<GeofenceResult> {
        return geofences.map { checkGeofence(location, it) }
    }

    // MARK: - Route Optimization (Swift)

    /**
     * Optimize route using nearest neighbor heuristic.
     * Delegates to Swift GeoIntelligenceEngine.
     */
    fun optimizeRoute(
        start: Coordinate,
        waypoints: List<Coordinate>,
        returnToStart: Boolean = false
    ): OptimizedRoute {
        if (waypoints.isEmpty()) {
            return OptimizedRoute(
                orderedWaypoints = emptyList(),
                totalDistanceKm = 0.0,
                segments = emptyList()
            )
        }

        val waypointLats = waypoints.joinToString(",") { it.lat.toString() }
        val waypointLngs = waypoints.joinToString(",") { it.lng.toString() }

        val swiftResult: SwiftOptimizedRoute = SwiftGeoEngine.optimizeRoute(
            start.lat, start.lng,
            waypointLats, waypointLngs,
            returnToStart
        )

        return swiftResult.use { result ->
            // Parse waypoint indices from Swift result
            val indices = result.waypointIndices
                .split(",")
                .filter { it.isNotEmpty() }
                .map { it.toInt() }

            // Reconstruct ordered waypoints
            val orderedWaypoints = indices.map { waypoints[it] }

            // Reconstruct segments
            val segments = mutableListOf<RouteSegment>()
            var current = start
            for (waypoint in orderedWaypoints) {
                val segmentDistance = calculateDistance(current, waypoint)
                segments.add(RouteSegment(
                    from = current,
                    to = waypoint,
                    distanceKm = segmentDistance
                ))
                current = waypoint
            }

            // Add return segment if needed
            if (returnToStart && orderedWaypoints.isNotEmpty()) {
                val returnDistance = calculateDistance(current, start)
                segments.add(RouteSegment(
                    from = current,
                    to = start,
                    distanceKm = returnDistance
                ))
            }

            OptimizedRoute(
                orderedWaypoints = orderedWaypoints,
                totalDistanceKm = result.totalDistanceKm,
                segments = segments
            )
        }
    }

    // MARK: - Hotspot Detection (Kotlin)
    // Note: Kept in Kotlin due to stateful grid operations

    /**
     * Detect activity hotspots.
     */
    fun detectHotspots(
        activities: List<ActivityLocation>,
        config: HotspotConfig = HotspotConfig()
    ): List<Hotspot> {
        // Group activities by grid cell
        val gridCells = mutableMapOf<String, MutableList<ActivityLocation>>()

        for (activity in activities) {
            val cellKey = getGridCellKey(activity.coordinate, config.gridSizeKm)
            gridCells.getOrPut(cellKey) { mutableListOf() }.add(activity)
        }

        // Find cells exceeding threshold
        val hotspots = mutableListOf<Hotspot>()

        for ((_, cellActivities) in gridCells) {
            if (cellActivities.size >= config.minActivities) {
                val centroid = calculateCentroid(
                    cellActivities.map { LocationPoint(it.id, it.coordinate) }
                )

                // Calculate intensity
                val intensity = cellActivities.size.toDouble() / config.minActivities

                hotspots.add(Hotspot(
                    id = java.util.UUID.randomUUID().toString(),
                    center = centroid,
                    activityCount = cellActivities.size,
                    intensity = minOf(intensity, 5.0), // Cap at 5x
                    radiusKm = config.gridSizeKm,
                    activities = cellActivities
                ))
            }
        }

        return hotspots.sortedByDescending { it.intensity }
    }

    private fun getGridCellKey(coordinate: Coordinate, gridSizeKm: Double): String {
        // Convert grid size to degrees (approximate)
        val gridSizeDeg = gridSizeKm / 111.0
        val latCell = (coordinate.lat / gridSizeDeg).toInt()
        val lngCell = (coordinate.lng / gridSizeDeg).toInt()
        return "$latCell,$lngCell"
    }

    // MARK: - Location Privacy (Swift)

    /**
     * Obfuscate location for privacy.
     * Delegates to Swift GeoIntelligenceEngine.
     */
    fun obfuscateLocation(coordinate: Coordinate, precision: LocationPrecision): Coordinate {
        if (precision == LocationPrecision.EXACT) {
            return coordinate
        }

        val precisionLevel = when (precision) {
            LocationPrecision.EXACT -> 0
            LocationPrecision.STREET -> 1
            LocationPrecision.NEIGHBORHOOD -> 2
            LocationPrecision.CITY -> 3
            LocationPrecision.REGION -> 4
        }

        val swiftResult: SwiftCoordinate = SwiftGeoEngine.obfuscateLocation(
            coordinate.lat, coordinate.lng, precisionLevel
        )
        return swiftResult.use { result ->
            Coordinate(
                lat = result.lat,
                lng = result.lng
            )
        }
    }

    // MARK: - Geohash (Swift)

    /**
     * Encode coordinate to geohash.
     * Delegates to Swift GeoIntelligenceEngine.
     */
    fun encodeGeohash(coordinate: Coordinate, precision: Int = 8): String {
        return SwiftGeoEngine.encodeGeohash(coordinate.lat, coordinate.lng, precision)
    }

    /**
     * Decode geohash to bounding box.
     * Delegates to Swift GeoIntelligenceEngine.
     */
    fun decodeGeohash(hash: String): BoundingBox {
        val swiftResult: SwiftBoundingBox = SwiftGeoEngine.decodeGeohash(hash)
        return swiftResult.use { result ->
            BoundingBox(
                northEast = GeoCoordinate(latitude = result.maxLat, longitude = result.maxLng),
                southWest = GeoCoordinate(latitude = result.minLat, longitude = result.minLng)
            )
        }
    }

    // MARK: - Travel Time Estimation (Swift)

    /**
     * Estimate travel time between two points.
     * Delegates to Swift GeoIntelligenceEngine.
     */
    fun estimateTravelTime(
        from: Coordinate,
        to: Coordinate,
        mode: TravelMode
    ): TravelTimeEstimate {
        val modeInt = when (mode) {
            TravelMode.WALKING -> 0
            TravelMode.CYCLING -> 1
            TravelMode.DRIVING -> 2
            TravelMode.TRANSIT -> 3
        }

        val swiftResult: SwiftTravelTime = SwiftGeoEngine.estimateTravelTime(
            from.lat, from.lng, to.lat, to.lng, modeInt
        )
        return swiftResult.use { result ->
            TravelTimeEstimate(
                distanceKm = result.distanceKm,
                durationMinutes = result.durationMinutes,
                mode = mode,
                speedKmh = result.speedKmh
            )
        }
    }
}

// MARK: - Data Classes

@Serializable
data class Coordinate(
    val lat: Double,
    val lng: Double
)

@Serializable
data class LocationPoint(
    val id: String,
    val coordinate: Coordinate
)

@Serializable
data class ClusterConfig(
    val epsilonKm: Double = 1.0,
    val minPoints: Int = 3
)

@Serializable
data class Cluster(
    val id: String,
    val centroid: Coordinate,
    val points: List<LocationPoint>,
    val radius: Double
)

@Serializable
data class Geofence(
    val id: String,
    val center: Coordinate,
    val radiusKm: Double,
    val name: String = ""
)

@Serializable
data class GeofenceResult(
    val geofenceId: String,
    val isInside: Boolean,
    val distanceFromCenter: Double,
    val distanceFromEdge: Double
)

// BoundingBox is defined in GeoBridge.kt - using that definition

@Serializable
data class DistanceMatrix(
    val origins: List<Coordinate>,
    val destinations: List<Coordinate>,
    val distances: List<List<Double>>
)

@Serializable
data class OptimizedRoute(
    val orderedWaypoints: List<Coordinate>,
    val totalDistanceKm: Double,
    val segments: List<RouteSegment>
)

@Serializable
data class RouteSegment(
    val from: Coordinate,
    val to: Coordinate,
    val distanceKm: Double
)

@Serializable
data class ActivityLocation(
    val id: String,
    val coordinate: Coordinate,
    val timestamp: Long,
    val type: String
)

@Serializable
data class HotspotConfig(
    val gridSizeKm: Double = 1.0,
    val minActivities: Int = 5
)

@Serializable
data class Hotspot(
    val id: String,
    val center: Coordinate,
    val activityCount: Int,
    val intensity: Double,
    val radiusKm: Double,
    val activities: List<ActivityLocation>
)

@Serializable
enum class LocationPrecision {
    EXACT,
    STREET,
    NEIGHBORHOOD,
    CITY,
    REGION
}

@Serializable
enum class TravelMode {
    WALKING,
    CYCLING,
    DRIVING,
    TRANSIT
}

@Serializable
data class TravelTimeEstimate(
    val distanceKm: Double,
    val durationMinutes: Double,
    val mode: TravelMode,
    val speedKmh: Double
)
