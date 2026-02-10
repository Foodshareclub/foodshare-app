package com.foodshare.core.geo

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlin.math.*
import kotlin.random.Random

/**
 * Geo-spatial utilities.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for geo calculations
 * - Distance, clustering, obfuscation are pure functions
 * - No JNI required for these stateless operations
 *
 * Features:
 * - Haversine distance calculations
 * - Location clustering (DBSCAN-inspired)
 * - Privacy obfuscation
 * - Polygon containment tests
 */
object GeoBridge {

    // Earth radius in kilometers
    private const val EARTH_RADIUS_KM = 6371.0
    private const val EARTH_RADIUS_MI = 3958.8

    // ========================================================================
    // Distance Calculations (Haversine formula)
    // ========================================================================

    /**
     * Calculate distance between two coordinates using Haversine formula.
     *
     * @param from Starting coordinate
     * @param to Ending coordinate
     * @param unit Distance unit (km or mi)
     * @return Distance in specified unit
     */
    fun calculateDistance(
        from: GeoCoordinate,
        to: GeoCoordinate,
        unit: DistanceUnit = DistanceUnit.KILOMETERS
    ): Double {
        return calculateDistance(from.latitude, from.longitude, to.latitude, to.longitude, unit)
    }

    /**
     * Calculate distance between two lat/lon pairs using Haversine formula.
     */
    fun calculateDistance(
        fromLat: Double,
        fromLon: Double,
        toLat: Double,
        toLon: Double,
        unit: DistanceUnit = DistanceUnit.KILOMETERS
    ): Double {
        val lat1Rad = Math.toRadians(fromLat)
        val lat2Rad = Math.toRadians(toLat)
        val deltaLat = Math.toRadians(toLat - fromLat)
        val deltaLon = Math.toRadians(toLon - fromLon)

        val a = sin(deltaLat / 2).pow(2) +
                cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2).pow(2)
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))

        val radius = when (unit) {
            DistanceUnit.KILOMETERS -> EARTH_RADIUS_KM
            DistanceUnit.MILES -> EARTH_RADIUS_MI
            DistanceUnit.METERS -> EARTH_RADIUS_KM * 1000
        }

        return radius * c
    }

    // ========================================================================
    // Location Clustering (DBSCAN-inspired)
    // ========================================================================

    /**
     * Cluster locations based on distance threshold.
     *
     * @param locations Locations to cluster
     * @param radiusKm Clustering radius in kilometers
     * @param minClusterSize Minimum cluster size (default 1)
     * @return List of location clusters
     */
    fun clusterLocations(
        locations: List<ClusterableLocation>,
        radiusKm: Double,
        minClusterSize: Int = 1
    ): List<LocationCluster> {
        if (locations.isEmpty()) return emptyList()

        val visited = mutableSetOf<String>()
        val clusters = mutableListOf<LocationCluster>()
        var clusterIndex = 0

        for (location in locations) {
            if (location.id in visited) continue
            visited.add(location.id)

            // Find neighbors within radius
            val neighbors = locations.filter { other ->
                other.id != location.id &&
                calculateDistance(location.coordinate, other.coordinate) <= radiusKm
            }

            if (neighbors.size + 1 >= minClusterSize) {
                val clusterMembers = mutableListOf(location)
                val pending = neighbors.toMutableList()

                while (pending.isNotEmpty()) {
                    val point = pending.removeAt(0)
                    if (point.id in visited) continue
                    visited.add(point.id)
                    clusterMembers.add(point)

                    val pointNeighbors = locations.filter { other ->
                        other.id != point.id &&
                        other.id !in visited &&
                        calculateDistance(point.coordinate, other.coordinate) <= radiusKm
                    }
                    pending.addAll(pointNeighbors)
                }

                // Calculate cluster centroid
                val centroid = GeoCoordinate(
                    latitude = clusterMembers.map { it.coordinate.latitude }.average(),
                    longitude = clusterMembers.map { it.coordinate.longitude }.average()
                )

                val bounds = calculateBoundingBox(clusterMembers.map { it.coordinate })
                    ?: BoundingBox(centroid, centroid)

                clusters.add(LocationCluster(
                    id = "cluster_${clusterIndex++}",
                    centroid = centroid,
                    bounds = bounds,
                    memberIds = clusterMembers.map { it.id },
                    count = clusterMembers.size
                ))
            }
        }

        return clusters
    }

    // ========================================================================
    // Location Privacy
    // ========================================================================

    /**
     * Obfuscate a location for privacy by adding random offset.
     *
     * @param coordinate Location to obfuscate
     * @param level Obfuscation level
     * @return Obfuscated coordinate
     */
    fun obfuscateLocation(
        coordinate: GeoCoordinate,
        level: ObfuscationLevel = ObfuscationLevel.NEIGHBORHOOD
    ): GeoCoordinate {
        if (level == ObfuscationLevel.NONE) return coordinate

        // Obfuscation radius in meters
        val radiusMeters = when (level) {
            ObfuscationLevel.NONE -> 0.0
            ObfuscationLevel.NEIGHBORHOOD -> 500.0
            ObfuscationLevel.CITY -> 5000.0
            ObfuscationLevel.REGION -> 50000.0
        }

        // Generate random offset
        val angle = Random.nextDouble() * 2 * PI
        val distance = Random.nextDouble() * radiusMeters

        // Convert distance to lat/lon offset
        val latOffset = (distance * cos(angle)) / 111320.0  // ~111km per degree latitude
        val lonOffset = (distance * sin(angle)) / (111320.0 * cos(Math.toRadians(coordinate.latitude)))

        return GeoCoordinate(
            latitude = coordinate.latitude + latOffset,
            longitude = coordinate.longitude + lonOffset
        )
    }

    /**
     * Get public-safe location with obfuscation.
     *
     * @param coordinate Original coordinate
     * @param precision Privacy precision level
     * @return Public location with privacy info
     */
    fun getPublicLocation(
        coordinate: GeoCoordinate,
        precision: ObfuscationLevel = ObfuscationLevel.NEIGHBORHOOD
    ): PublicLocation {
        val radiusMeters = when (precision) {
            ObfuscationLevel.NONE -> 0.0
            ObfuscationLevel.NEIGHBORHOOD -> 500.0
            ObfuscationLevel.CITY -> 5000.0
            ObfuscationLevel.REGION -> 50000.0
        }

        return PublicLocation(
            displayCoordinate = obfuscateLocation(coordinate, precision),
            precisionLevel = precision,
            radiusMeters = radiusMeters
        )
    }

    // ========================================================================
    // Delivery Zones
    // ========================================================================

    /**
     * Find delivery zone containing a point.
     *
     * @param coordinate Point to check
     * @param zones Available delivery zones
     * @return Matching zone or null
     */
    fun findDeliveryZone(
        coordinate: GeoCoordinate,
        zones: List<DeliveryZone>
    ): DeliveryZone? {
        return zones.firstOrNull { zone ->
            zone.isActive && isPointInPolygon(coordinate, zone.polygon)
        }
    }

    /**
     * Check if a point is inside a polygon using ray casting algorithm.
     *
     * @param point Point to check
     * @param polygon Polygon vertices
     * @return true if point is inside
     */
    fun isPointInPolygon(
        point: GeoCoordinate,
        polygon: List<GeoCoordinate>
    ): Boolean {
        if (polygon.size < 3) return false

        var inside = false
        var j = polygon.size - 1

        for (i in polygon.indices) {
            val yi = polygon[i].latitude
            val xi = polygon[i].longitude
            val yj = polygon[j].latitude
            val xj = polygon[j].longitude

            if (((yi > point.latitude) != (yj > point.latitude)) &&
                (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi)) {
                inside = !inside
            }
            j = i
        }

        return inside
    }

    // ========================================================================
    // Bounding Box
    // ========================================================================

    /**
     * Calculate bounding box for a list of coordinates.
     *
     * @param coordinates List of coordinates
     * @return Bounding box or null if empty
     */
    fun calculateBoundingBox(coordinates: List<GeoCoordinate>): BoundingBox? {
        if (coordinates.isEmpty()) return null

        val minLat = coordinates.minOf { it.latitude }
        val maxLat = coordinates.maxOf { it.latitude }
        val minLon = coordinates.minOf { it.longitude }
        val maxLon = coordinates.maxOf { it.longitude }

        return BoundingBox(
            northEast = GeoCoordinate(maxLat, maxLon),
            southWest = GeoCoordinate(minLat, minLon)
        )
    }

    // ========================================================================
    // Convenience Methods
    // ========================================================================

    /**
     * Check if a coordinate is valid.
     */
    fun isValidCoordinate(coordinate: GeoCoordinate): Boolean {
        return coordinate.latitude >= -90 && coordinate.latitude <= 90 &&
               coordinate.longitude >= -180 && coordinate.longitude <= 180
    }

    /**
     * Get human-readable distance string.
     */
    fun formatDistance(distanceKm: Double, useMetric: Boolean = true): String {
        return if (useMetric) {
            if (distanceKm < 1) {
                "${(distanceKm * 1000).toInt()} m"
            } else {
                "%.1f km".format(distanceKm)
            }
        } else {
            val miles = distanceKm * 0.621371
            if (miles < 0.1) {
                "${(miles * 5280).toInt()} ft"
            } else {
                "%.1f mi".format(miles)
            }
        }
    }
}

// ========================================================================
// Data Classes
// ========================================================================

@Serializable
data class GeoCoordinate(
    val latitude: Double,
    val longitude: Double
) {
    val isValid: Boolean
        get() = latitude >= -90 && latitude <= 90 &&
                longitude >= -180 && longitude <= 180
}

@Serializable
data class BoundingBox(
    val northEast: GeoCoordinate,
    val southWest: GeoCoordinate
) {
    fun contains(point: GeoCoordinate): Boolean {
        return point.latitude >= southWest.latitude &&
               point.latitude <= northEast.latitude &&
               point.longitude >= southWest.longitude &&
               point.longitude <= northEast.longitude
    }

    val center: GeoCoordinate
        get() = GeoCoordinate(
            latitude = (northEast.latitude + southWest.latitude) / 2,
            longitude = (northEast.longitude + southWest.longitude) / 2
        )
}

@Serializable
enum class DistanceUnit(val value: String) {
    @SerialName("km") KILOMETERS("km"),
    @SerialName("mi") MILES("mi"),
    @SerialName("m") METERS("m")
}

@Serializable
enum class ObfuscationLevel(val value: String) {
    @SerialName("none") NONE("none"),
    @SerialName("neighborhood") NEIGHBORHOOD("neighborhood"),
    @SerialName("city") CITY("city"),
    @SerialName("region") REGION("region")
}

@Serializable
data class ClusterableLocation(
    val id: String,
    val coordinate: GeoCoordinate,
    val weight: Double = 1.0
)

@Serializable
data class LocationCluster(
    val id: String,
    val centroid: GeoCoordinate,
    val bounds: BoundingBox,
    val memberIds: List<String>,
    val count: Int
) {
    val isSingleItem: Boolean get() = count == 1
}

@Serializable
data class PublicLocation(
    val displayCoordinate: GeoCoordinate,
    val precisionLevel: ObfuscationLevel,
    val radiusMeters: Double
)

@Serializable
data class DeliveryZone(
    val id: String,
    val name: String,
    val polygon: List<GeoCoordinate>,
    val isActive: Boolean = true
)

// ========================================================================
// Extension Functions
// ========================================================================

/** Calculate distance to another coordinate. */
fun GeoCoordinate.distanceTo(
    other: GeoCoordinate,
    unit: DistanceUnit = DistanceUnit.KILOMETERS
): Double = GeoBridge.calculateDistance(this, other, unit)

/** Obfuscate this coordinate for privacy. */
fun GeoCoordinate.obfuscate(
    level: ObfuscationLevel = ObfuscationLevel.NEIGHBORHOOD
): GeoCoordinate = GeoBridge.obfuscateLocation(this, level)

/** Get public-safe version of this coordinate. */
fun GeoCoordinate.toPublicLocation(
    precision: ObfuscationLevel = ObfuscationLevel.NEIGHBORHOOD
): PublicLocation = GeoBridge.getPublicLocation(this, precision)

/** Check if this coordinate is within a delivery zone. */
fun GeoCoordinate.isInDeliveryZone(zone: DeliveryZone): Boolean =
    GeoBridge.isPointInPolygon(this, zone.polygon)
