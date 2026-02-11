package com.foodshare.features.challenges.presentation.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.foodshare.features.challenges.presentation.LeaderboardEntry
import com.foodshare.ui.design.components.cards.GlassCard
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing

/**
 * Highlighted card showing the current user's rank when they are
 * not in the top 3.
 */
@Composable
fun CurrentUserRankCard(
    entry: LeaderboardEntry,
    modifier: Modifier = Modifier
) {
    GlassCard(
        modifier = modifier.fillMaxWidth(),
        cornerRadius = CornerRadius.large
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    brush = Brush.linearGradient(
                        listOf(
                            LiquidGlassColors.brandPink.copy(alpha = 0.15f),
                            LiquidGlassColors.brandTeal.copy(alpha = 0.15f)
                        )
                    )
                )
                .padding(Spacing.md),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Rank badge
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(
                        brush = Brush.linearGradient(
                            listOf(
                                LiquidGlassColors.brandPink,
                                LiquidGlassColors.brandTeal
                            )
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "#${entry.rank}",
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
            }

            Spacer(modifier = Modifier.width(Spacing.md))

            // Avatar
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .border(
                        width = 2.dp,
                        brush = LiquidGlassGradients.brand,
                        shape = CircleShape
                    )
                    .background(Color.White.copy(alpha = 0.1f)),
                contentAlignment = Alignment.Center
            ) {
                if (entry.avatarUrl != null) {
                    AsyncImage(
                        model = entry.avatarUrl,
                        contentDescription = "Your avatar",
                        modifier = Modifier
                            .fillMaxSize()
                            .clip(CircleShape),
                        contentScale = ContentScale.Crop
                    )
                } else {
                    Icon(
                        imageVector = Icons.Default.Person,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.width(Spacing.md))

            // Name & label
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = entry.displayName,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Text(
                    text = "Your Ranking",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White.copy(alpha = 0.7f)
                )
            }

            // Score
            Column(horizontalAlignment = Alignment.End) {
                Text(
                    text = formatScore(entry.score),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = LiquidGlassColors.brandPink
                )
                Text(
                    text = "pts",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White.copy(alpha = 0.7f)
                )
            }
        }
    }
}

/**
 * Single row in the ranked list (4th place and below).
 */
@Composable
fun LeaderboardListItem(
    entry: LeaderboardEntry,
    modifier: Modifier = Modifier
) {
    val highlightAlpha = if (entry.isCurrentUser) 0.15f else 0f

    GlassCard(
        modifier = modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    color = if (entry.isCurrentUser)
                        LiquidGlassColors.brandPink.copy(alpha = highlightAlpha)
                    else
                        Color.Transparent
                )
                .padding(horizontal = Spacing.md, vertical = Spacing.sm),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Rank number
            Text(
                text = "#${entry.rank}",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
                color = if (entry.isCurrentUser)
                    LiquidGlassColors.brandPink
                else
                    Color.White.copy(alpha = 0.7f),
                modifier = Modifier.width(40.dp)
            )

            // Avatar
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .border(
                        width = if (entry.isCurrentUser) 2.dp else 1.dp,
                        color = if (entry.isCurrentUser)
                            LiquidGlassColors.brandPink
                        else
                            Color.White.copy(alpha = 0.2f),
                        shape = CircleShape
                    )
                    .background(Color.White.copy(alpha = 0.1f)),
                contentAlignment = Alignment.Center
            ) {
                if (entry.avatarUrl != null) {
                    AsyncImage(
                        model = entry.avatarUrl,
                        contentDescription = "${entry.displayName}'s avatar",
                        modifier = Modifier
                            .fillMaxSize()
                            .clip(CircleShape),
                        contentScale = ContentScale.Crop
                    )
                } else {
                    Icon(
                        imageVector = Icons.Default.Person,
                        contentDescription = null,
                        tint = Color.White.copy(alpha = 0.5f),
                        modifier = Modifier.size(20.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.width(Spacing.md))

            // Name
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = entry.displayName,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = if (entry.isCurrentUser)
                            FontWeight.Bold else FontWeight.Normal,
                        color = Color.White,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    if (entry.isCurrentUser) {
                        Spacer(modifier = Modifier.width(Spacing.xxxs))
                        Text(
                            text = "(You)",
                            style = MaterialTheme.typography.bodySmall,
                            color = LiquidGlassColors.brandPink
                        )
                    }
                }
            }

            // Score
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = Icons.Default.Star,
                    contentDescription = null,
                    tint = LiquidGlassColors.medalGold.copy(alpha = 0.7f),
                    modifier = Modifier.size(16.dp)
                )
                Spacer(modifier = Modifier.width(Spacing.xxxs))
                Text(
                    text = formatScore(entry.score),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
            }
        }
    }
}

/**
 * Format a numeric score for display with K suffix for large numbers.
 */
private fun formatScore(score: Int): String = when {
    score >= 10_000 -> "${score / 1000}K"
    score >= 1_000 -> "%.1fK".format(score / 1000.0)
    else -> score.toString()
}
