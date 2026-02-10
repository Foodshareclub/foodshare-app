package com.foodshare.features.reviews.presentation.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Interactive star rating component
 */
@Composable
fun RatingStars(
    rating: Int,
    onRatingChange: ((Int) -> Unit)? = null,
    size: Dp = 24.dp,
    activeColor: Color = MaterialTheme.colorScheme.primary,
    inactiveColor: Color = MaterialTheme.colorScheme.outlineVariant,
    modifier: Modifier = Modifier
) {
    Row(modifier = modifier) {
        (1..5).forEach { star ->
            Icon(
                imageVector = if (star <= rating) {
                    Icons.Filled.Star
                } else {
                    Icons.Outlined.StarOutline
                },
                contentDescription = "Star $star",
                tint = if (star <= rating) activeColor else inactiveColor,
                modifier = Modifier
                    .size(size)
                    .then(
                        if (onRatingChange != null) {
                            Modifier.clickable { onRatingChange(star) }
                        } else {
                            Modifier
                        }
                    )
            )
        }
    }
}

/**
 * Display-only star rating (smaller, non-interactive)
 */
@Composable
fun RatingStarsDisplay(
    rating: Double,
    size: Dp = 16.dp,
    modifier: Modifier = Modifier
) {
    val fullStars = rating.toInt()
    val hasHalfStar = rating - fullStars >= 0.5

    Row(modifier = modifier) {
        (1..5).forEach { star ->
            Icon(
                imageVector = when {
                    star <= fullStars -> Icons.Filled.Star
                    star == fullStars + 1 && hasHalfStar -> Icons.Filled.Star // Could use half-star icon
                    else -> Icons.Outlined.StarOutline
                },
                contentDescription = null,
                tint = if (star <= fullStars || (star == fullStars + 1 && hasHalfStar)) {
                    MaterialTheme.colorScheme.primary
                } else {
                    MaterialTheme.colorScheme.outlineVariant
                },
                modifier = Modifier.size(size)
            )
        }
    }
}
