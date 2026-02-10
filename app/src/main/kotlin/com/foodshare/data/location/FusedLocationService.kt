package com.foodshare.data.location

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Address
import android.location.Geocoder
import android.location.LocationManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.foodshare.core.error.AppError
import com.foodshare.domain.location.LocationData
import com.foodshare.domain.location.LocationService
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Google Fused Location Provider implementation of LocationService
 *
 * Uses FusedLocationProviderClient for accurate, battery-efficient location
 */
@Singleton
class FusedLocationService @Inject constructor(
    @ApplicationContext private val context: Context
) : LocationService {

    private val fusedLocationClient: FusedLocationProviderClient by lazy {
        LocationServices.getFusedLocationProviderClient(context)
    }

    private val geocoder: Geocoder by lazy {
        Geocoder(context, Locale.getDefault())
    }

    override suspend fun getCurrentLocation(): Result<LocationData> {
        if (!hasLocationPermission()) {
            return Result.failure(AppError.LocationPermissionDenied)
        }

        if (!isLocationEnabled()) {
            return Result.failure(AppError.LocationUnavailable)
        }

        return runCatching {
            suspendCancellableCoroutine { continuation ->
                val cancellationToken = CancellationTokenSource()

                try {
                    fusedLocationClient.getCurrentLocation(
                        Priority.PRIORITY_HIGH_ACCURACY,
                        cancellationToken.token
                    ).addOnSuccessListener { location ->
                        if (location != null) {
                            continuation.resume(
                                LocationData(
                                    latitude = location.latitude,
                                    longitude = location.longitude,
                                    accuracy = location.accuracy
                                )
                            )
                        } else {
                            continuation.resumeWithException(
                                AppError.LocationUnavailable
                            )
                        }
                    }.addOnFailureListener { e ->
                        continuation.resumeWithException(
                            AppError.Unknown("Failed to get location: ${e.message}", e)
                        )
                    }
                } catch (e: SecurityException) {
                    continuation.resumeWithException(AppError.LocationPermissionDenied)
                }

                continuation.invokeOnCancellation {
                    cancellationToken.cancel()
                }
            }
        }
    }

    override suspend fun getAddressFromCoordinates(
        latitude: Double,
        longitude: Double
    ): Result<String> = withContext(Dispatchers.IO) {
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // Android 13+ uses callback-based API
                suspendCancellableCoroutine { continuation ->
                    geocoder.getFromLocation(latitude, longitude, 1) { addresses ->
                        val address = addresses.firstOrNull()
                        if (address != null) {
                            continuation.resume(formatAddress(address))
                        } else {
                            continuation.resumeWithException(
                                AppError.Unknown("No address found for coordinates")
                            )
                        }
                    }
                }
            } else {
                // Legacy API
                @Suppress("DEPRECATION")
                val addresses = geocoder.getFromLocation(latitude, longitude, 1)
                addresses?.firstOrNull()?.let { formatAddress(it) }
                    ?: throw AppError.Unknown("No address found for coordinates")
            }
        }
    }

    override suspend fun getCoordinatesFromAddress(address: String): Result<LocationData> =
        withContext(Dispatchers.IO) {
            runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    suspendCancellableCoroutine { continuation ->
                        geocoder.getFromLocationName(address, 1) { addresses ->
                            val result = addresses.firstOrNull()
                            if (result != null) {
                                continuation.resume(
                                    LocationData(
                                        latitude = result.latitude,
                                        longitude = result.longitude,
                                        address = formatAddress(result),
                                        city = result.locality,
                                        country = result.countryName
                                    )
                                )
                            } else {
                                continuation.resumeWithException(
                                    AppError.Unknown("No location found for address")
                                )
                            }
                        }
                    }
                } else {
                    @Suppress("DEPRECATION")
                    val addresses = geocoder.getFromLocationName(address, 1)
                    val result = addresses?.firstOrNull()
                        ?: throw AppError.Unknown("No location found for address")

                    LocationData(
                        latitude = result.latitude,
                        longitude = result.longitude,
                        address = formatAddress(result),
                        city = result.locality,
                        country = result.countryName
                    )
                }
            }
        }

    override fun observeLocation(): Flow<LocationData> = callbackFlow {
        if (!hasLocationPermission()) {
            close(AppError.LocationPermissionDenied)
            return@callbackFlow
        }

        val locationRequest = com.google.android.gms.location.LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            10000L // 10 seconds interval
        ).apply {
            setMinUpdateIntervalMillis(5000L)
            setMaxUpdateDelayMillis(15000L)
        }.build()

        val locationCallback = object : com.google.android.gms.location.LocationCallback() {
            override fun onLocationResult(result: com.google.android.gms.location.LocationResult) {
                result.lastLocation?.let { location ->
                    trySend(
                        LocationData(
                            latitude = location.latitude,
                            longitude = location.longitude,
                            accuracy = location.accuracy
                        )
                    )
                }
            }
        }

        try {
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback,
                context.mainLooper
            )
        } catch (e: SecurityException) {
            close(AppError.LocationPermissionDenied)
        }

        awaitClose {
            fusedLocationClient.removeLocationUpdates(locationCallback)
        }
    }

    override fun hasLocationPermission(): Boolean {
        val fineLocation = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        val coarseLocation = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        return fineLocation || coarseLocation
    }

    override fun isLocationEnabled(): Boolean {
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }

    /**
     * Format Address object to readable string
     */
    private fun formatAddress(address: Address): String {
        return buildString {
            // Street address
            address.getAddressLine(0)?.let { append(it) }

            // If no address line, build from components
            if (isEmpty()) {
                address.thoroughfare?.let { append(it) }
                address.subThoroughfare?.let {
                    if (isNotEmpty()) append(" ")
                    append(it)
                }
                address.locality?.let {
                    if (isNotEmpty()) append(", ")
                    append(it)
                }
                address.adminArea?.let {
                    if (isNotEmpty()) append(", ")
                    append(it)
                }
            }
        }.ifEmpty { "${address.latitude}, ${address.longitude}" }
    }
}
