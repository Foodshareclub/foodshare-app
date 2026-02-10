package com.foodshare.features.map.presentation

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.foodshare.domain.model.FoodListing
import com.foodshare.features.map.presentation.components.ListingDetailSheet
import com.foodshare.features.map.presentation.components.MapMarker
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.Spacing
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.*

/**
 * Main Map screen displaying food listings on a map.
 *
 * SYNC: Mirrors Swift MapView
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MapScreen(
    onNavigateToListing: (Int) -> Unit,
    viewModel: MapViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    // Permission launcher
    val locationPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val granted = permissions[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
                permissions[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        viewModel.onPermissionResult(granted)
    }

    // Request permission on first load if not granted
    LaunchedEffect(Unit) {
        if (!uiState.locationPermissionGranted && !uiState.locationPermissionDenied) {
            locationPermissionLauncher.launch(
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                )
            )
        }
    }

    // Map camera state
    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(
            uiState.userLocation ?: LatLng(53.3498, -6.2603),
            14f
        )
    }

    // Update camera when user location changes
    LaunchedEffect(uiState.userLocation) {
        uiState.userLocation?.let { location ->
            cameraPositionState.animate(
                CameraUpdateFactory.newLatLngZoom(location, 14f),
                durationMs = 1000
            )
        }
    }

    // Bottom sheet state
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = false)
    var showBottomSheet by remember { mutableStateOf(false) }

    // Show sheet when listing selected
    LaunchedEffect(uiState.selectedListing) {
        showBottomSheet = uiState.selectedListing != null
    }

    Box(modifier = Modifier.fillMaxSize()) {
        // Google Map
        GoogleMap(
            modifier = Modifier.fillMaxSize(),
            cameraPositionState = cameraPositionState,
            properties = MapProperties(
                isMyLocationEnabled = uiState.locationPermissionGranted,
                mapType = MapType.NORMAL
            ),
            uiSettings = MapUiSettings(
                zoomControlsEnabled = false,
                myLocationButtonEnabled = false,
                mapToolbarEnabled = false
            ),
            onMapClick = {
                viewModel.selectListing(null)
            }
        ) {
            // Food listing markers
            uiState.listings.forEach { listing ->
                if (listing.latitude != null && listing.longitude != null) {
                    MapMarker(
                        listing = listing,
                        isSelected = uiState.selectedListing?.id == listing.id,
                        onClick = {
                            viewModel.selectListing(listing)
                        }
                    )
                }
            }
        }

        // Loading indicator
        AnimatedVisibility(
            visible = uiState.isLoading || uiState.isLoadingLocation,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier.align(Alignment.Center)
        ) {
            Surface(
                shape = RoundedCornerShape(16.dp),
                color = MaterialTheme.colorScheme.surface.copy(alpha = 0.9f),
                shadowElevation = 8.dp
            ) {
                Row(
                    modifier = Modifier.padding(Spacing.md),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Spacing.sm)
                ) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(24.dp),
                        strokeWidth = 2.dp
                    )
                    Text(
                        text = if (uiState.isLoadingLocation) "Getting location..." else "Loading...",
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            }
        }

        // Location source banner
        AnimatedVisibility(
            visible = uiState.locationSource.shouldShowBanner,
            enter = slideInVertically() + fadeIn(),
            exit = slideOutVertically() + fadeOut(),
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = Spacing.lg)
        ) {
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = when (uiState.locationSource) {
                    LocationSource.IP_GEOLOCATION -> Color(0xFFF39C12).copy(alpha = 0.9f)
                    LocationSource.DEFAULT -> MaterialTheme.colorScheme.errorContainer
                    else -> MaterialTheme.colorScheme.surfaceVariant
                }
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = Spacing.md, vertical = Spacing.xs),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Spacing.xs)
                ) {
                    Icon(
                        imageVector = Icons.Default.LocationOn,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        text = uiState.locationSource.displayText,
                        style = MaterialTheme.typography.labelSmall
                    )
                }
            }
        }

        // Item count badge
        AnimatedVisibility(
            visible = uiState.itemCount > 0,
            enter = scaleIn() + fadeIn(),
            exit = scaleOut() + fadeOut(),
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(top = Spacing.lg, end = Spacing.md)
        ) {
            Surface(
                shape = RoundedCornerShape(16.dp),
                color = LiquidGlassColors.brandGreen.copy(alpha = 0.9f)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = Spacing.sm, vertical = Spacing.xs),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Icon(
                        Icons.Default.Eco,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp),
                        tint = Color.White
                    )
                    Text(
                        text = "${uiState.itemCount}",
                        style = MaterialTheme.typography.labelMedium,
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }

        // Control buttons
        Column(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = Spacing.md, bottom = Spacing.xl),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm)
        ) {
            // Recenter button
            FloatingActionButton(
                onClick = { viewModel.recenterOnUser() },
                containerColor = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    Icons.Default.MyLocation,
                    contentDescription = "Recenter"
                )
            }

            // Refresh button
            FloatingActionButton(
                onClick = { viewModel.loadListings() },
                containerColor = LiquidGlassColors.brandPink,
                contentColor = Color.White,
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    Icons.Default.Refresh,
                    contentDescription = "Refresh"
                )
            }
        }

        // Error snackbar
        uiState.error?.let { error ->
            Snackbar(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(Spacing.md),
                action = {
                    TextButton(onClick = { viewModel.clearError() }) {
                        Text("Dismiss")
                    }
                }
            ) {
                Text(error)
            }
        }
    }

    // Bottom sheet for selected listing
    if (showBottomSheet && uiState.selectedListing != null) {
        ModalBottomSheet(
            onDismissRequest = {
                viewModel.selectListing(null)
                showBottomSheet = false
            },
            sheetState = sheetState,
            dragHandle = { BottomSheetDefaults.DragHandle() }
        ) {
            ListingDetailSheet(
                listing = uiState.selectedListing!!,
                onViewDetails = { onNavigateToListing(it.id) },
                onDismiss = {
                    viewModel.selectListing(null)
                    showBottomSheet = false
                }
            )
        }
    }
}
