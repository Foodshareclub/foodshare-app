package com.foodshare.ui.design.components.cards

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.ui.semantics.Role
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.RemoveRedEye
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.foodshare.domain.model.FoodListing
import com.foodshare.domain.model.ListingStatus
import com.foodshare.domain.model.PostType
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassAnimations
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing

/**
 * Card style variants matching iOS GlassListingCard
 */
enum class CardStyle {
    Standard,
    Compact,
    Featured,
    Modern
}

/**
 * Glass-styled listing card with category support
 *
 * Premium glassmorphism effects matching iOS Liquid Glass design
 */
@Composable
fun GlassListingCard(
    listing: FoodListing,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    style: CardStyle = CardStyle.Modern,
    onFavoriteClick: (() -> Unit)? = null,
    isFavorite: Boolean = false
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()

    val scale by animateFloatAsState(
        targetValue = if (isPressed) LiquidGlassAnimations.Scale.cardPressed else 1f,
        animationSpec = LiquidGlassAnimations.cardPress,
        label = "cardScale"
    )

    val category = PostType.fromString(listing.postType) ?: PostType.FOOD
    val categoryColor = getCategoryColor(category)
    val cornerRadius = getCornerRadius(style)

    Surface(
        modifier = modifier
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .shadow(
                elevation = 8.dp,
                shape = RoundedCornerShape(cornerRadius),
                ambientColor = categoryColor.copy(alpha = 0.15f),
                spotColor = categoryColor.copy(alpha = 0.1f)
            )
            .clip(RoundedCornerShape(cornerRadius))
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                role = Role.Button,
                onClick = onClick
            ),
        shape = RoundedCornerShape(cornerRadius),
        color = Color.Transparent
    ) {
        Box(
            modifier = Modifier
                .background(brush = LiquidGlassGradients.glassSurface)
                .border(
                    width = 1.dp,
                    color = LiquidGlassColors.Glass.border,
                    shape = RoundedCornerShape(cornerRadius)
                )
        ) {
            when (style) {
                CardStyle.Modern -> ModernCardLayout(
                    listing = listing,
                    category = category,
                    categoryColor = categoryColor,
                    cornerRadius = cornerRadius,
                    onFavoriteClick = onFavoriteClick,
                    isFavorite = isFavorite
                )
                else -> StandardCardLayout(
                    listing = listing,
                    category = category,
                    categoryColor = categoryColor,
                    cornerRadius = cornerRadius,
                    style = style
                )
            }
        }
    }
}

@Composable
private fun ModernCardLayout(
    listing: FoodListing,
    category: PostType,
    categoryColor: Color,
    cornerRadius: Dp,
    onFavoriteClick: (() -> Unit)?,
    isFavorite: Boolean
) {
    Column {
        // Square image with overlays
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(1f)
                .clip(
                    RoundedCornerShape(
                        topStart = cornerRadius,
                        topEnd = cornerRadius,
                        bottomStart = 0.dp,
                        bottomEnd = 0.dp
                    )
                )
        ) {
            // Main image
            ListingImage(
                imageUrl = listing.displayImageUrl,
                category = category,
                categoryColor = categoryColor,
                modifier = Modifier.fillMaxSize()
            )

            // Top overlay - Category badge & Favorite button
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(Spacing.sm),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                CategoryBadge(
                    category = category,
                    categoryColor = categoryColor
                )

                if (onFavoriteClick != null) {
                    FavoriteButton(
                        isFavorite = isFavorite,
                        onClick = onFavoriteClick
                    )
                }
            }

            // Bottom overlay - Time badge
            Box(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(Spacing.sm)
            ) {
                TimeBadge(text = com.foodshare.core.utilities.RelativeTimeFormatter.format(listing.createdAt))
            }
        }

        // Content section
        ModernContentSection(
            listing = listing,
            category = category,
            categoryColor = categoryColor
        )
    }
}

@Composable
private fun StandardCardLayout(
    listing: FoodListing,
    category: PostType,
    categoryColor: Color,
    cornerRadius: Dp,
    style: CardStyle
) {
    val imageHeight = when (style) {
        CardStyle.Standard -> 180.dp
        CardStyle.Compact -> 120.dp
        CardStyle.Featured -> 220.dp
        CardStyle.Modern -> 160.dp
    }

    Column {
        // Image section
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(imageHeight)
                .clip(
                    RoundedCornerShape(
                        topStart = cornerRadius,
                        topEnd = cornerRadius,
                        bottomStart = 0.dp,
                        bottomEnd = 0.dp
                    )
                )
        ) {
            ListingImage(
                imageUrl = listing.displayImageUrl,
                category = category,
                categoryColor = categoryColor,
                modifier = Modifier.fillMaxSize()
            )

            // Gradient overlay for text readability
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(Color.Transparent, Color.Black.copy(alpha = 0.3f)),
                            startY = 100f
                        )
                    )
            )

            // Badges
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(Spacing.sm),
                verticalArrangement = Arrangement.SpaceBetween
            ) {
                // Top row - category and status
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    CategoryBadge(category = category, categoryColor = categoryColor)

                    if (listing.status != ListingStatus.AVAILABLE) {
                        StatusBadge(status = listing.status)
                    }
                }

                // Bottom row - distance
                listing.distanceDisplay?.let { distance ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.End
                    ) {
                        DistanceBadge(distance = distance)
                    }
                }
            }
        }

        // Content section
        StandardContentSection(listing = listing)
    }
}

@Composable
private fun ListingImage(
    imageUrl: String?,
    category: PostType,
    categoryColor: Color,
    modifier: Modifier = Modifier
) {
    if (imageUrl != null) {
        AsyncImage(
            model = imageUrl,
            contentDescription = "Listing image",
            contentScale = ContentScale.Crop,
            modifier = modifier
        )
    } else {
        // Placeholder with category icon
        Box(
            modifier = modifier.background(
                Brush.linearGradient(
                    colors = listOf(
                        categoryColor.copy(alpha = 0.3f),
                        categoryColor.copy(alpha = 0.5f)
                    )
                )
            ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = getCategoryIcon(category),
                contentDescription = getCategoryLabel(category),
                tint = Color.White.copy(alpha = 0.6f),
                modifier = Modifier.size(48.dp)
            )
        }
    }
}

@Composable
private fun CategoryBadge(
    category: PostType,
    categoryColor: Color
) {
    Row(
        modifier = Modifier
            .clip(CircleShape)
            .background(categoryColor.copy(alpha = 0.9f))
            .padding(horizontal = Spacing.sm, vertical = Spacing.xxs),
        horizontalArrangement = Arrangement.spacedBy(Spacing.xxs),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = getCategoryIcon(category),
            contentDescription = getCategoryLabel(category),
            tint = Color.White,
            modifier = Modifier.size(12.dp)
        )
        Text(
            text = getCategoryLabel(category),
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            color = Color.White
        )
    }
}

@Composable
private fun StatusBadge(status: ListingStatus) {
    val color = when (status) {
        ListingStatus.AVAILABLE -> LiquidGlassColors.success
        ListingStatus.ARRANGED -> LiquidGlassColors.warning
        ListingStatus.INACTIVE -> Color.Gray
    }

    Text(
        text = status.displayName,
        style = MaterialTheme.typography.labelSmall,
        fontWeight = FontWeight.SemiBold,
        color = Color.White,
        modifier = Modifier
            .clip(CircleShape)
            .background(color.copy(alpha = 0.9f))
            .padding(horizontal = Spacing.sm, vertical = Spacing.xxs)
    )
}

@Composable
private fun DistanceBadge(distance: String) {
    Row(
        modifier = Modifier
            .clip(CircleShape)
            .background(Color.Black.copy(alpha = 0.5f))
            .padding(horizontal = Spacing.sm, vertical = Spacing.xxs),
        horizontalArrangement = Arrangement.spacedBy(Spacing.xxs),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Default.LocationOn,
            contentDescription = "Location",
            tint = Color.White,
            modifier = Modifier.size(12.dp)
        )
        Text(
            text = distance,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Medium,
            color = Color.White
        )
    }
}

@Composable
private fun TimeBadge(text: String) {
    Row(
        modifier = Modifier
            .clip(CircleShape)
            .background(Color.Black.copy(alpha = 0.6f))
            .padding(horizontal = Spacing.sm, vertical = Spacing.xxs),
        horizontalArrangement = Arrangement.spacedBy(Spacing.xxs),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Default.AccessTime,
            contentDescription = "Time posted",
            tint = Color.White,
            modifier = Modifier.size(12.dp)
        )
        Text(
            text = text,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Medium,
            color = Color.White
        )
    }
}

@Composable
private fun FavoriteButton(
    isFavorite: Boolean,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .size(32.dp)
            .clip(CircleShape)
            .background(Color.Black.copy(alpha = 0.4f))
            .clickable(role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = if (isFavorite) Icons.Default.Favorite else Icons.Default.FavoriteBorder,
            contentDescription = if (isFavorite) "Remove from favorites" else "Add to favorites",
            tint = if (isFavorite) LiquidGlassColors.brandPink else Color.White,
            modifier = Modifier.size(16.dp)
        )
    }
}

@Composable
private fun ModernContentSection(
    listing: FoodListing,
    category: PostType,
    categoryColor: Color
) {
    Column(
        modifier = Modifier.padding(Spacing.sm),
        verticalArrangement = Arrangement.spacedBy(Spacing.xs)
    ) {
        // User row - Avatar + Name + Distance
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // User avatar placeholder
                Box(
                    modifier = Modifier
                        .size(28.dp)
                        .clip(CircleShape)
                        .background(categoryColor.copy(alpha = 0.2f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Person,
                        contentDescription = "User",
                        tint = categoryColor,
                        modifier = Modifier.size(14.dp)
                    )
                }

                Text(
                    text = "Sharer",
                    style = MaterialTheme.typography.bodySmall,
                    color = LiquidGlassColors.Text.secondary
                )
            }

            // Distance badge
            listing.distanceDisplay?.let { distance ->
                Row(
                    horizontalArrangement = Arrangement.spacedBy(2.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.LocationOn,
                        contentDescription = "Location",
                        tint = LiquidGlassColors.Text.secondary,
                        modifier = Modifier.size(12.dp)
                    )
                    Text(
                        text = distance,
                        style = MaterialTheme.typography.labelSmall,
                        color = LiquidGlassColors.Text.secondary
                    )
                }
            }
        }

        // Title - 2 lines max
        Text(
            text = listing.title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Medium,
            color = LiquidGlassColors.Text.primary,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis
        )

        // Location - single line
        listing.postAddress?.let { address ->
            Text(
                text = address,
                style = MaterialTheme.typography.labelSmall,
                color = LiquidGlassColors.Text.tertiary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
private fun StandardContentSection(listing: FoodListing) {
    Column(
        modifier = Modifier.padding(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm)
    ) {
        // Title
        Text(
            text = listing.title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = LiquidGlassColors.Text.primary,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis
        )

        // Description
        listing.description?.let { desc ->
            if (desc.isNotBlank()) {
                Text(
                    text = desc,
                    style = MaterialTheme.typography.bodySmall,
                    color = LiquidGlassColors.Text.secondary,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }

        // Metadata row
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Pickup time
            listing.pickupTime?.let { time ->
                Row(
                    horizontalArrangement = Arrangement.spacedBy(Spacing.xxs),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.AccessTime,
                        contentDescription = "Pickup time",
                        tint = LiquidGlassColors.Text.secondary,
                        modifier = Modifier.size(14.dp)
                    )
                    Text(
                        text = time,
                        style = MaterialTheme.typography.labelSmall,
                        color = LiquidGlassColors.Text.secondary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f, fill = false)
                    )
                }
            }

            Spacer(Modifier.width(Spacing.sm))

            Row(
                horizontalArrangement = Arrangement.spacedBy(Spacing.md),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Views
                Row(
                    horizontalArrangement = Arrangement.spacedBy(Spacing.xxs),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.RemoveRedEye,
                        contentDescription = "Views",
                        tint = LiquidGlassColors.Text.tertiary,
                        modifier = Modifier.size(14.dp)
                    )
                    Text(
                        text = "${listing.postViews}",
                        style = MaterialTheme.typography.labelSmall,
                        color = LiquidGlassColors.Text.tertiary
                    )
                }

                // Likes
                listing.postLikeCounter?.let { likes ->
                    if (likes > 0) {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(Spacing.xxs),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = Icons.Default.Favorite,
                                contentDescription = "Likes",
                                tint = LiquidGlassColors.error.copy(alpha = 0.8f),
                                modifier = Modifier.size(14.dp)
                            )
                            Text(
                                text = "$likes",
                                style = MaterialTheme.typography.labelSmall,
                                color = LiquidGlassColors.error.copy(alpha = 0.8f)
                            )
                        }
                    }
                }
            }
        }
    }
}

// Helper functions

private fun getCornerRadius(style: CardStyle): Dp = when (style) {
    CardStyle.Standard -> CornerRadius.xl
    CardStyle.Compact -> CornerRadius.large
    CardStyle.Featured -> 28.dp
    CardStyle.Modern -> CornerRadius.large
}

private fun getCategoryColor(category: PostType): Color = when (category) {
    PostType.FOOD -> LiquidGlassColors.Category.food
    PostType.THING -> LiquidGlassColors.Category.thing
    PostType.BORROW -> LiquidGlassColors.Category.borrow
    PostType.WANTED -> LiquidGlassColors.Category.wanted
    PostType.FRIDGE -> LiquidGlassColors.Category.fridge
    PostType.FOODBANK -> LiquidGlassColors.Category.foodbank
    PostType.BUSINESS -> LiquidGlassColors.Category.business
    PostType.VOLUNTEER -> LiquidGlassColors.Category.volunteer
    PostType.CHALLENGE -> LiquidGlassColors.Category.challenge
    PostType.ZEROWASTE -> LiquidGlassColors.Category.zerowaste
    PostType.VEGAN -> LiquidGlassColors.Category.vegan
    PostType.COMMUNITY -> LiquidGlassColors.Category.community
}

private fun getCategoryLabel(category: PostType): String = when (category) {
    PostType.FOOD -> "Free food"
    PostType.THING -> "Thing"
    PostType.BORROW -> "Borrow"
    PostType.WANTED -> "Wanted"
    PostType.FRIDGE -> "Fridge"
    PostType.FOODBANK -> "Food Bank"
    PostType.BUSINESS -> "Business"
    PostType.VOLUNTEER -> "Volunteer"
    PostType.CHALLENGE -> "Challenge"
    PostType.ZEROWASTE -> "Zero Waste"
    PostType.VEGAN -> "Vegan"
    PostType.COMMUNITY -> "Community"
}

private fun getCategoryIcon(category: PostType): ImageVector = when (category) {
    PostType.FOOD -> Icons.Default.FavoriteBorder // leaf equivalent
    PostType.THING -> Icons.Default.FavoriteBorder // box equivalent
    PostType.BORROW -> Icons.Default.FavoriteBorder
    PostType.WANTED -> Icons.Default.FavoriteBorder
    PostType.FRIDGE -> Icons.Default.FavoriteBorder
    PostType.FOODBANK -> Icons.Default.FavoriteBorder
    PostType.BUSINESS -> Icons.Default.FavoriteBorder
    PostType.VOLUNTEER -> Icons.Default.FavoriteBorder
    PostType.CHALLENGE -> Icons.Default.FavoriteBorder
    PostType.ZEROWASTE -> Icons.Default.FavoriteBorder
    PostType.VEGAN -> Icons.Default.FavoriteBorder
    PostType.COMMUNITY -> Icons.Default.FavoriteBorder
}
