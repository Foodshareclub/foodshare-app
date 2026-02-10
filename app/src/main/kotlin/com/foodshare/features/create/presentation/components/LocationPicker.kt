package com.foodshare.features.create.presentation.components

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import com.foodshare.domain.location.LocationData
import com.foodshare.domain.location.LocationService
import com.foodshare.ui.design.components.buttons.GlassButton
import com.foodshare.ui.design.components.buttons.GlassButtonStyle
import com.foodshare.ui.design.components.inputs.GlassTextField
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.Spacing
import kotlinx.coroutines.launch

/**
 * Location picker component with current location and manual entry
 *
 * Features:
 * - Use current location button
 * - Manual address entry
 * - Address geocoding
 * - Permission handling
 */
@Composable
fun LocationPicker(
    currentAddress: String,
    currentLocation: LocationData?,
    onAddressChange: (String) -> Unit,
    onLocationSelected: (LocationData) -> Unit,
    locationService: LocationService,
    modifier: Modifier = Modifier
) {
    var isLoadingLocation by remember { mutableStateOf(false) }
    var locationError by remember { mutableStateOf<String?>(null) }
    var showManualEntry by remember { mutableStateOf(currentAddress.isNotEmpty()) }
    val scope = rememberCoroutineScope()

    // Permission launcher
    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val fineGranted = permissions[Manifest.permission.ACCESS_FINE_LOCATION] == true
        val coarseGranted = permissions[Manifest.permission.ACCESS_COARSE_LOCATION] == true

        if (fineGranted || coarseGranted) {
            // Permission granted, get location
            scope.launch {
                fetchCurrentLocation(
                    locationService = locationService,
                    onLoading = { isLoadingLocation = it },
                    onSuccess = { location ->
                        onLocationSelected(location)
                        onAddressChange(location.displayAddress)
                        locationError = null
                    },
                    onError = { error ->
                        locationError = error
                    }
                )
            }
        } else {
            locationError = "Location permission is required"
            showManualEntry = true
        }
    }

    Column(modifier = modifier) {
        Text(
            text = "Pickup Location",
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.Medium,
            color = Color.White
        )

        Spacer(Modifier.height(Spacing.xs))

        // Use Current Location Button
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(CornerRadius.medium))
                .background(LiquidGlassColors.Glass.surface)
                .border(
                    width = 1.dp,
                    color = if (currentLocation != null && !showManualEntry)
                        LiquidGlassColors.brandTeal
                    else
                        LiquidGlassColors.Glass.border,
                    shape = RoundedCornerShape(CornerRadius.medium)
                )
                .clickable(enabled = !isLoadingLocation) {
                    if (locationService.hasLocationPermission()) {
                        scope.launch {
                            fetchCurrentLocation(
                                locationService = locationService,
                                onLoading = { isLoadingLocation = it },
                                onSuccess = { location ->
                                    onLocationSelected(location)
                                    onAddressChange(location.displayAddress)
                                    locationError = null
                                    showManualEntry = false
                                },
                                onError = { error ->
                                    locationError = error
                                    showManualEntry = true
                                }
                            )
                        }
                    } else {
                        permissionLauncher.launch(
                            arrayOf(
                                Manifest.permission.ACCESS_FINE_LOCATION,
                                Manifest.permission.ACCESS_COARSE_LOCATION
                            )
                        )
                    }
                }
                .padding(Spacing.md)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f)
                ) {
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .clip(CircleShape)
                            .background(LiquidGlassColors.brandTeal.copy(alpha = 0.2f)),
                        contentAlignment = Alignment.Center
                    ) {
                        if (isLoadingLocation) {
                            CircularProgressIndicator(
                                color = LiquidGlassColors.brandTeal,
                                strokeWidth = 2.dp,
                                modifier = Modifier.size(20.dp)
                            )
                        } else {
                            Icon(
                                imageVector = Icons.Default.MyLocation,
                                contentDescription = null,
                                tint = LiquidGlassColors.brandTeal,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    }

                    Column {
                        Text(
                            text = "Use Current Location",
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Medium,
                            color = Color.White
                        )
                        if (currentLocation != null && !showManualEntry) {
                            Text(
                                text = currentLocation.shortDisplay,
                                style = MaterialTheme.typography.bodySmall,
                                color = Color.White.copy(alpha = 0.6f),
                                maxLines = 1
                            )
                        }
                    }
                }

                if (currentLocation != null && !showManualEntry) {
                    Icon(
                        imageVector = Icons.Default.Check,
                        contentDescription = "Selected",
                        tint = LiquidGlassColors.success,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }

        // Error message
        AnimatedVisibility(
            visible = locationError != null,
            enter = fadeIn(),
            exit = fadeOut()
        ) {
            Text(
                text = locationError ?: "",
                style = MaterialTheme.typography.bodySmall,
                color = LiquidGlassColors.error,
                modifier = Modifier.padding(top = Spacing.xs)
            )
        }

        Spacer(Modifier.height(Spacing.sm))

        // Toggle for manual entry
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center
        ) {
            Text(
                text = if (showManualEntry) "or use current location" else "or enter address manually",
                style = MaterialTheme.typography.bodySmall,
                color = LiquidGlassColors.brandTeal,
                modifier = Modifier.clickable {
                    showManualEntry = !showManualEntry
                    if (!showManualEntry && currentLocation != null) {
                        onAddressChange(currentLocation.displayAddress)
                    }
                }
            )
        }

        // Manual Entry Section
        AnimatedVisibility(
            visible = showManualEntry,
            enter = fadeIn(),
            exit = fadeOut()
        ) {
            Column {
                Spacer(Modifier.height(Spacing.sm))

                GlassTextField(
                    value = currentAddress,
                    onValueChange = onAddressChange,
                    placeholder = "Enter address...",
                    imeAction = ImeAction.Done,
                    modifier = Modifier.fillMaxWidth()
                )

                // Geocode button when address is entered
                if (currentAddress.length >= 5) {
                    Spacer(Modifier.height(Spacing.xs))

                    GlassButton(
                        text = "Verify Address",
                        onClick = {
                            scope.launch {
                                isLoadingLocation = true
                                locationService.getCoordinatesFromAddress(currentAddress)
                                    .onSuccess { location ->
                                        onLocationSelected(location)
                                        location.address?.let { onAddressChange(it) }
                                        locationError = null
                                    }
                                    .onFailure {
                                        locationError = "Could not verify address"
                                    }
                                isLoadingLocation = false
                            }
                        },
                        style = GlassButtonStyle.Secondary,
                        isLoading = isLoadingLocation,
                        icon = Icons.Default.LocationOn,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
        }
    }
}

/**
 * Fetch current location with loading and error handling
 */
private suspend fun fetchCurrentLocation(
    locationService: LocationService,
    onLoading: (Boolean) -> Unit,
    onSuccess: (LocationData) -> Unit,
    onError: (String) -> Unit
) {
    onLoading(true)

    locationService.getCurrentLocation()
        .onSuccess { location ->
            // Try to get address for the location
            locationService.getAddressFromCoordinates(location.latitude, location.longitude)
                .onSuccess { address ->
                    onSuccess(location.copy(address = address))
                }
                .onFailure {
                    // Use location without address
                    onSuccess(location)
                }
        }
        .onFailure { error ->
            onError(error.message ?: "Failed to get location")
        }

    onLoading(false)
}

/**
 * Simplified location picker with just address input (for basic use)
 */
@Composable
fun SimpleLocationPicker(
    address: String,
    onAddressChange: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        Text(
            text = "Pickup Location",
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.Medium,
            color = Color.White
        )

        Spacer(Modifier.height(Spacing.xs))

        GlassTextField(
            value = address,
            onValueChange = onAddressChange,
            placeholder = "Enter pickup address...",
            imeAction = ImeAction.Done,
            modifier = Modifier.fillMaxWidth()
        )
    }
}
