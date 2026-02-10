package com.foodshare.features.map.presentation

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import androidx.core.content.ContextCompat
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.errors.ErrorBridge
import com.foodshare.core.utilities.DistanceCalculator
import com.foodshare.core.validation.ValidationBridge
import com.foodshare.domain.model.FoodListing
import com.foodshare.domain.repository.FeedRepository
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.Priority
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.tasks.CancellationTokenSource
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import javax.inject.Inject

/**
 * Location source type for UI feedback
 */
enum class LocationSource {
    GPS,
    NETWORK,
    IP_GEOLOCATION,
    DEFAULT,
    NONE;

    val displayText: String
        get() = when (this) {
            GPS -> "Using precise location"
            NETWORK -> "Using network location"
            IP_GEOLOCATION -> "Using approximate location"
            DEFAULT -> "Using default location"
            NONE -> "Location unavailable"
        }

    val shouldShowBanner: Boolean
        get() = this != GPS && this != NETWORK
}

/**
 * UI State for Map screen
 */
data class MapUiState(
    val listings: List<FoodListing> = emptyList(),
    val userLocation: LatLng? = null,
    val locationSource: LocationSource = LocationSource.NONE,
    val locationAccuracy: Float? = null,
    val isLoading: Boolean = false,
    val isLoadingLocation: Boolean = false,
    val selectedListing: FoodListing? = null,
    val searchRadiusKm: Double = 5.0,
    val error: String? = null,
    val locationPermissionGranted: Boolean = false,
    val locationPermissionDenied: Boolean = false
) {
    val hasLocation: Boolean get() = userLocation != null
    val itemCount: Int get() = listings.size

    /**
     * Search radius formatted for display.
     */
    val searchRadiusDisplay: String
        get() = DistanceCalculator.formatMeters(searchRadiusKm * 1000)

    /**
     * Search radius with suffix for display.
     */
    val searchRadiusDisplayWithSuffix: String
        get() = DistanceCalculator.formatMetersWithSuffix(searchRadiusKm * 1000)

    /**
     * Location accuracy formatted for display.
     */
    val locationAccuracyDisplay: String?
        get() = locationAccuracy?.let {
            DistanceCalculator.formatMeters(it.toDouble())
        }

    /**
     * Check if coordinates are valid using Swift validation.
     */
    val hasValidLocation: Boolean
        get() = userLocation?.let {
            ValidationBridge.isValidCoordinate(it.latitude, it.longitude)
        } ?: false

    /**
     * Calculate distance from user to a given point.
     */
    fun distanceFromUser(latitude: Double, longitude: Double): String? {
        val location = userLocation ?: return null
        if (!ValidationBridge.isValidCoordinate(latitude, longitude)) return null
        val distanceKm = DistanceCalculator.distanceKm(
            location.latitude, location.longitude,
            latitude, longitude
        )
        return DistanceCalculator.formatMetersWithSuffix(distanceKm * 1000)
    }
}

/**
 * ViewModel for Map feature
 *
 * SYNC: Mirrors Swift MapViewModel
 */
@HiltViewModel
class MapViewModel @Inject constructor(
    private val feedRepository: FeedRepository,
    private val fusedLocationClient: FusedLocationProviderClient,
    @ApplicationContext private val context: Context
) : ViewModel() {

    private val _uiState = MutableStateFlow(MapUiState())
    val uiState: StateFlow<MapUiState> = _uiState.asStateFlow()

    // Default location (Dublin, Ireland)
    private val defaultLocation = LatLng(53.3498, -6.2603)

    init {
        checkLocationPermission()
    }

    fun checkLocationPermission() {
        val hasPermission = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED ||
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        _uiState.update {
            it.copy(
                locationPermissionGranted = hasPermission,
                locationPermissionDenied = !hasPermission && it.locationPermissionDenied
            )
        }

        if (hasPermission) {
            loadCurrentLocation()
        } else {
            // Use default location
            _uiState.update {
                it.copy(
                    userLocation = defaultLocation,
                    locationSource = LocationSource.DEFAULT
                )
            }
            loadListings(defaultLocation)
        }
    }

    fun onPermissionResult(granted: Boolean) {
        _uiState.update {
            it.copy(
                locationPermissionGranted = granted,
                locationPermissionDenied = !granted
            )
        }

        if (granted) {
            loadCurrentLocation()
        } else {
            // Use default location
            _uiState.update {
                it.copy(
                    userLocation = defaultLocation,
                    locationSource = LocationSource.DEFAULT
                )
            }
            loadListings(defaultLocation)
        }
    }

    private fun loadCurrentLocation() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoadingLocation = true) }

            try {
                val cancellationToken = CancellationTokenSource()
                val location: Location? = fusedLocationClient.getCurrentLocation(
                    Priority.PRIORITY_HIGH_ACCURACY,
                    cancellationToken.token
                ).await()

                if (location != null) {
                    // Validate coordinates using Swift validation (matches iOS)
                    if (!ValidationBridge.isValidCoordinate(location.latitude, location.longitude)) {
                        _uiState.update {
                            it.copy(
                                userLocation = defaultLocation,
                                locationSource = LocationSource.DEFAULT,
                                locationAccuracy = null,
                                isLoadingLocation = false,
                                error = "Invalid coordinates received"
                            )
                        }
                        loadListings(defaultLocation)
                        return@launch
                    }

                    val latLng = LatLng(location.latitude, location.longitude)
                    val accuracy = if (location.hasAccuracy()) location.accuracy else null

                    _uiState.update {
                        it.copy(
                            userLocation = latLng,
                            locationSource = if (accuracy != null && accuracy < 100f)
                                LocationSource.GPS
                            else
                                LocationSource.NETWORK,
                            locationAccuracy = accuracy,
                            isLoadingLocation = false
                        )
                    }
                    loadListings(latLng)
                } else {
                    // Fallback to default
                    _uiState.update {
                        it.copy(
                            userLocation = defaultLocation,
                            locationSource = LocationSource.DEFAULT,
                            locationAccuracy = null,
                            isLoadingLocation = false
                        )
                    }
                    loadListings(defaultLocation)
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        userLocation = defaultLocation,
                        locationSource = LocationSource.DEFAULT,
                        locationAccuracy = null,
                        isLoadingLocation = false,
                        error = ErrorBridge.mapLocationError(e)
                    )
                }
                loadListings(defaultLocation)
            }
        }
    }

    fun loadListings(location: LatLng? = null) {
        val targetLocation = location ?: _uiState.value.userLocation ?: return

        // Validate coordinates using Swift validation (matches iOS)
        if (!ValidationBridge.isValidCoordinate(targetLocation.latitude, targetLocation.longitude)) {
            _uiState.update {
                it.copy(
                    isLoading = false,
                    error = "Invalid location coordinates"
                )
            }
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            // Clamp radius to valid range using Swift validation
            val clampedRadius = ValidationBridge.clampSearchRadius(_uiState.value.searchRadiusKm)

            feedRepository.getNearbyListings(
                latitude = targetLocation.latitude,
                longitude = targetLocation.longitude,
                radiusKm = clampedRadius,
                limit = 50
            )
                .onSuccess { listings ->
                    _uiState.update {
                        it.copy(
                            listings = listings,
                            isLoading = false
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = ErrorBridge.mapFeedError(error)
                        )
                    }
                }
        }
    }

    fun selectListing(listing: FoodListing?) {
        _uiState.update { it.copy(selectedListing = listing) }
    }

    fun recenterOnUser() {
        val location = _uiState.value.userLocation
        if (location != null) {
            loadListings(location)
        } else if (_uiState.value.locationPermissionGranted) {
            loadCurrentLocation()
        }
    }

    fun updateSearchRadius(radiusKm: Double) {
        // Clamp radius to valid range using Swift validation (matches iOS)
        val clampedRadius = ValidationBridge.clampSearchRadius(radiusKm)
        _uiState.update { it.copy(searchRadiusKm = clampedRadius) }
        loadListings()
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}
