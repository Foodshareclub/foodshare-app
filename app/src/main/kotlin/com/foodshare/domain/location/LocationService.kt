package com.foodshare.domain.location

import kotlinx.coroutines.flow.Flow

/**
 * Location service interface for abstracting location provider
 *
 * Ported from iOS: FoodShare/Core/Services/LocationService.swift
 */
interface LocationService {

    /**
     * Get the current device location
     *
     * @return Result containing LocationData or error
     */
    suspend fun getCurrentLocation(): Result<LocationData>

    /**
     * Get address from coordinates (reverse geocoding)
     *
     * @param latitude Latitude coordinate
     * @param longitude Longitude coordinate
     * @return Result containing address string or error
     */
    suspend fun getAddressFromCoordinates(latitude: Double, longitude: Double): Result<String>

    /**
     * Get coordinates from address (forward geocoding)
     *
     * @param address Address string
     * @return Result containing LocationData or error
     */
    suspend fun getCoordinatesFromAddress(address: String): Result<LocationData>

    /**
     * Observe location updates
     *
     * @return Flow of location updates
     */
    fun observeLocation(): Flow<LocationData>

    /**
     * Check if location permission is granted
     */
    fun hasLocationPermission(): Boolean

    /**
     * Check if location services are enabled
     */
    fun isLocationEnabled(): Boolean
}

/**
 * Location data container
 */
data class LocationData(
    val latitude: Double,
    val longitude: Double,
    val address: String? = null,
    val city: String? = null,
    val country: String? = null,
    val accuracy: Float? = null
) {
    /**
     * Format for display in UI
     */
    val displayAddress: String
        get() = address ?: "$latitude, $longitude"

    /**
     * Short format showing city if available
     */
    val shortDisplay: String
        get() = city ?: address?.take(50) ?: "$latitude, $longitude"

    companion object {
        val DEFAULT = LocationData(
            latitude = 37.7749,
            longitude = -122.4194,
            city = "San Francisco"
        )
    }
}
