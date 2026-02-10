package com.foodshare.features.map.presentation.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.foodshare.domain.model.FoodListing
import com.foodshare.domain.model.PostType
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.MarkerComposable
import com.google.maps.android.compose.MarkerState

/**
 * Custom map marker for food listings.
 *
 * SYNC: Mirrors Swift LiquidGlassMapMarker
 */
@Composable
fun MapMarker(
    listing: FoodListing,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    val position = LatLng(listing.latitude ?: 0.0, listing.longitude ?: 0.0)
    val markerState = MarkerState(position = position)

    val postType = PostType.fromString(listing.postType)
    val markerColor = getMarkerColor(postType)
    val markerIcon = getMarkerIcon(postType)

    MarkerComposable(
        state = markerState,
        title = listing.title,
        snippet = listing.distanceDisplay,
        onClick = {
            onClick()
            true
        }
    ) {
        LiquidGlassMarkerContent(
            icon = markerIcon,
            color = markerColor,
            isSelected = isSelected
        )
    }
}

@Composable
private fun LiquidGlassMarkerContent(
    icon: ImageVector,
    color: Color,
    isSelected: Boolean
) {
    val size = if (isSelected) 52.dp else 44.dp
    val iconSize = if (isSelected) 24.dp else 20.dp
    val borderWidth = if (isSelected) 3.dp else 2.dp

    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Main circle with frosted glass effect
        Box(
            modifier = Modifier
                .size(size)
                .shadow(
                    elevation = if (isSelected) 12.dp else 6.dp,
                    shape = CircleShape,
                    ambientColor = color.copy(alpha = 0.3f),
                    spotColor = color.copy(alpha = 0.3f)
                )
                .clip(CircleShape)
                .background(
                    if (isSelected)
                        color.copy(alpha = 0.9f)
                    else
                        Color.White.copy(alpha = 0.85f)
                )
                .border(
                    width = borderWidth,
                    color = if (isSelected) Color.White else color,
                    shape = CircleShape
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(iconSize),
                tint = if (isSelected) Color.White else color
            )
        }

        // Pointer below the circle
        Box(
            modifier = Modifier
                .size(width = 12.dp, height = 8.dp)
                .background(
                    color = if (isSelected) color else Color.White.copy(alpha = 0.85f)
                )
        )
    }
}

/**
 * Get marker color based on post type
 */
private fun getMarkerColor(postType: PostType?): Color {
    return when (postType) {
        PostType.FOOD -> Color(0xFF2ECC71)       // Green
        PostType.FRIDGE -> Color(0xFF1ABC9C)     // Teal
        PostType.FOODBANK -> Color(0xFF3498DB)   // Blue
        PostType.THING -> Color(0xFF9B59B6)      // Purple
        PostType.BORROW -> Color(0xFFE67E22)     // Orange
        PostType.WANTED -> Color(0xFFF39C12)     // Yellow
        PostType.VOLUNTEER -> Color(0xFFE91E63)  // Pink
        PostType.CHALLENGE -> Color(0xFFFFD700)  // Gold
        PostType.ZEROWASTE -> Color(0xFF27AE60)  // Dark green
        PostType.VEGAN -> Color(0xFF8BC34A)      // Light green
        PostType.BUSINESS -> Color(0xFF607D8B)   // Gray blue
        PostType.COMMUNITY -> Color(0xFF00BCD4)  // Cyan
        null -> Color(0xFF2ECC71)                // Default green
    }
}

/**
 * Get marker icon based on post type
 */
private fun getMarkerIcon(postType: PostType?): ImageVector {
    return when (postType) {
        PostType.FOOD -> Icons.Default.Eco
        PostType.FRIDGE -> Icons.Default.Kitchen
        PostType.FOODBANK -> Icons.Default.Warehouse
        PostType.THING -> Icons.Default.Inventory2
        PostType.BORROW -> Icons.Default.SwapHoriz
        PostType.WANTED -> Icons.Default.Search
        PostType.VOLUNTEER -> Icons.Default.VolunteerActivism
        PostType.CHALLENGE -> Icons.Default.EmojiEvents
        PostType.ZEROWASTE -> Icons.Default.Recycling
        PostType.VEGAN -> Icons.Default.Grass
        PostType.BUSINESS -> Icons.Default.Store
        PostType.COMMUNITY -> Icons.Default.Groups
        null -> Icons.Default.Eco
    }
}
