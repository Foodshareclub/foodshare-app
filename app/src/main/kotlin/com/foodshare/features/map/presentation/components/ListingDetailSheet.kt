package com.foodshare.features.map.presentation.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.foodshare.domain.model.FoodListing
import com.foodshare.domain.model.PostType
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.Spacing

/**
 * Bottom sheet showing listing details when a map marker is tapped.
 *
 * SYNC: Mirrors Swift LiquidGlassMapDetailSheet
 */
@Composable
fun ListingDetailSheet(
    listing: FoodListing,
    onViewDetails: (FoodListing) -> Unit,
    onDismiss: () -> Unit
) {
    val postType = PostType.fromString(listing.postType)
    val statusColor = when {
        !listing.isActive -> Color(0xFF95A5A6)
        listing.isArranged -> Color(0xFFF39C12)
        else -> Color(0xFF2ECC71)
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.md)
            .padding(bottom = Spacing.xl)
    ) {
        // Image
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(180.dp)
                .clip(RoundedCornerShape(16.dp))
        ) {
            if (listing.displayImageUrl != null) {
                AsyncImage(
                    model = listing.displayImageUrl,
                    contentDescription = listing.title,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop
                )
            } else {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            getPostTypeColor(postType).copy(alpha = 0.2f)
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = getPostTypeIcon(postType),
                        contentDescription = null,
                        modifier = Modifier.size(64.dp),
                        tint = getPostTypeColor(postType)
                    )
                }
            }

            // Status badge
            Surface(
                shape = RoundedCornerShape(8.dp),
                color = statusColor,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(Spacing.sm)
            ) {
                Text(
                    text = listing.status.displayName,
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.White,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                    fontWeight = FontWeight.Bold
                )
            }

            // Distance badge
            listing.distanceDisplay?.let { distance ->
                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = Color.Black.copy(alpha = 0.6f),
                    modifier = Modifier
                        .align(Alignment.BottomStart)
                        .padding(Spacing.sm)
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Icon(
                            Icons.Default.LocationOn,
                            contentDescription = null,
                            modifier = Modifier.size(12.dp),
                            tint = Color.White
                        )
                        Text(
                            text = distance,
                            style = MaterialTheme.typography.labelSmall,
                            color = Color.White
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(Spacing.md))

        // Title
        Text(
            text = listing.title,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis
        )

        // Post type
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            modifier = Modifier.padding(top = Spacing.xs)
        ) {
            Surface(
                shape = RoundedCornerShape(4.dp),
                color = getPostTypeColor(postType).copy(alpha = 0.1f)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Icon(
                        imageVector = getPostTypeIcon(postType),
                        contentDescription = null,
                        modifier = Modifier.size(12.dp),
                        tint = getPostTypeColor(postType)
                    )
                    Text(
                        text = postType?.displayName ?: "Food",
                        style = MaterialTheme.typography.labelSmall,
                        color = getPostTypeColor(postType)
                    )
                }
            }
        }

        // Description
        listing.description?.let { description ->
            Spacer(modifier = Modifier.height(Spacing.sm))
            Text(
                text = description,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis
            )
        }

        Spacer(modifier = Modifier.height(Spacing.sm))

        // Info row
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(Spacing.md)
        ) {
            // Views
            InfoItem(
                icon = Icons.Outlined.RemoveRedEye,
                text = "${listing.postViews} views"
            )

            // Likes
            listing.postLikeCounter?.let { likes ->
                InfoItem(
                    icon = Icons.Outlined.FavoriteBorder,
                    text = "$likes likes"
                )
            }
        }

        // Address
        listing.postAddress?.let { address ->
            Spacer(modifier = Modifier.height(Spacing.sm))
            Row(
                verticalAlignment = Alignment.Top,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Icon(
                    Icons.Outlined.Place,
                    contentDescription = null,
                    modifier = Modifier.size(16.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = address,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }

        // Pickup time
        listing.pickupTime?.let { time ->
            Spacer(modifier = Modifier.height(Spacing.xs))
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Icon(
                    Icons.Outlined.Schedule,
                    contentDescription = null,
                    modifier = Modifier.size(16.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = time,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        Spacer(modifier = Modifier.height(Spacing.lg))

        // Action button
        Button(
            onClick = { onViewDetails(listing) },
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(
                containerColor = if (listing.isAvailable)
                    LiquidGlassColors.brandPink
                else
                    MaterialTheme.colorScheme.surfaceVariant
            ),
            enabled = listing.isAvailable
        ) {
            Icon(
                imageVector = if (listing.isAvailable) Icons.Default.OpenInNew else Icons.Default.Block,
                contentDescription = null
            )
            Spacer(modifier = Modifier.width(Spacing.xs))
            Text(
                text = if (listing.isAvailable) "View Details" else "Not Available"
            )
        }
    }
}

@Composable
private fun InfoItem(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    text: String
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(14.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            text = text,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

private fun getPostTypeColor(postType: PostType?): Color {
    return when (postType) {
        PostType.FOOD -> Color(0xFF2ECC71)
        PostType.FRIDGE -> Color(0xFF1ABC9C)
        PostType.FOODBANK -> Color(0xFF3498DB)
        PostType.THING -> Color(0xFF9B59B6)
        PostType.BORROW -> Color(0xFFE67E22)
        PostType.WANTED -> Color(0xFFF39C12)
        PostType.VOLUNTEER -> Color(0xFFE91E63)
        PostType.CHALLENGE -> Color(0xFFFFD700)
        PostType.ZEROWASTE -> Color(0xFF27AE60)
        PostType.VEGAN -> Color(0xFF8BC34A)
        PostType.BUSINESS -> Color(0xFF607D8B)
        PostType.COMMUNITY -> Color(0xFF00BCD4)
        null -> Color(0xFF2ECC71)
    }
}

private fun getPostTypeIcon(postType: PostType?): androidx.compose.ui.graphics.vector.ImageVector {
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
