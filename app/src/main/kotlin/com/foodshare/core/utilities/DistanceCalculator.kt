package com.foodshare.core.utilities

import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Distance calculation and formatting utilities.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations using Haversine formula
 * - No JNI required for these pure math operations
 */
object DistanceCalculator {

    private const val EARTH_RADIUS_KM = 6371.0

    /**
     * Calculate distance between two coordinates using Haversine formula
     *
     * @param fromLat Latitude of origin point
     * @param fromLon Longitude of origin point
     * @param toLat Latitude of destination point
     * @param toLon Longitude of destination point
     * @return Distance in kilometers
     */
    fun distanceKm(
        fromLat: Double,
        fromLon: Double,
        toLat: Double,
        toLon: Double
    ): Double {
        val lat1Rad = Math.toRadians(fromLat)
        val lat2Rad = Math.toRadians(toLat)
        val deltaLat = Math.toRadians(toLat - fromLat)
        val deltaLon = Math.toRadians(toLon - fromLon)

        val a = sin(deltaLat / 2).pow(2) +
                cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2).pow(2)
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return EARTH_RADIUS_KM * c
    }

    /**
     * Calculate distance between two coordinates in miles
     */
    fun distanceMiles(
        fromLat: Double,
        fromLon: Double,
        toLat: Double,
        toLon: Double
    ): Double {
        return distanceKm(fromLat, fromLon, toLat, toLon) * 0.621371
    }

    /**
     * Format distance for display
     *
     * @param distanceKm Distance in kilometers
     * @return Formatted string like "500m" or "1.2km"
     */
    fun formatDistance(distanceKm: Double): String {
        return formatMeters(distanceKm * 1000)
    }

    /**
     * Format distance in meters for display
     *
     * @param meters Distance in meters
     * @return Formatted string like "500m" or "1.2km"
     */
    fun formatMeters(meters: Double): String {
        return when {
            meters < 0 -> "0m"
            meters < 1000 -> "${meters.toInt()}m"
            meters < 10000 -> "%.1fkm".format(meters / 1000)
            else -> "${(meters / 1000).toInt()}km"
        }
    }

    /**
     * Format distance with "away" suffix
     *
     * @param meters Distance in meters
     * @return Formatted string like "500m away" or "1.2km away"
     */
    fun formatMetersWithSuffix(meters: Double): String {
        return "${formatMeters(meters)} away"
    }

    /**
     * Calculate radius from map span (for region-based search)
     *
     * @param latitudeDelta Latitude span of the map region
     * @param longitudeDelta Longitude span of the map region
     * @param centerLatitude Center latitude for accurate calculation
     * @return Radius in kilometers that encompasses the region
     */
    fun radiusFromSpan(
        latitudeDelta: Double,
        longitudeDelta: Double,
        centerLatitude: Double
    ): Double {
        // Calculate the diagonal distance
        val latDistance = latitudeDelta * 111.0 // ~111km per degree latitude
        val lonDistance = longitudeDelta * 111.0 * cos(Math.toRadians(centerLatitude))

        // Use half the diagonal as radius
        return sqrt(latDistance.pow(2) + lonDistance.pow(2)) / 2
    }

    /**
     * Check if a point is within radius of another point
     */
    fun isWithinRadius(
        centerLat: Double,
        centerLon: Double,
        pointLat: Double,
        pointLon: Double,
        radiusKm: Double
    ): Boolean {
        return distanceKm(centerLat, centerLon, pointLat, pointLon) <= radiusKm
    }
}

/**
 * Calculate distance from this coordinate pair to another
 */
fun Pair<Double, Double>.distanceTo(other: Pair<Double, Double>): Double {
    return DistanceCalculator.distanceKm(
        fromLat = this.first,
        fromLon = this.second,
        toLat = other.first,
        toLon = other.second
    )
}
