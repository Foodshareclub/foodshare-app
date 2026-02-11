package com.foodshare.features.challenges.presentation.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.foodshare.features.challenges.presentation.LeaderboardEntry
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.Spacing

/**
 * Podium view showing the top 3 users:
 * - 2nd place on the left (slightly lower)
 * - 1st place in the center (tallest)
 * - 3rd place on the right (lowest)
 */
@Composable
fun PodiumSection(
    topThree: List<LeaderboardEntry>,
    modifier: Modifier = Modifier
) {
    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(topThree) { visible = true }

    val first = topThree.getOrNull(0)
    val second = topThree.getOrNull(1)
    val third = topThree.getOrNull(2)

    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(animationSpec = tween(600)) + slideInVertically(
            animationSpec = tween(600),
            initialOffsetY = { it / 4 }
        )
    ) {
        Row(
            modifier = modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.md),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.Bottom
        ) {
            // 2nd place - Silver (left, medium height)
            second?.let {
                PodiumItem(
                    entry = it,
                    podiumHeight = 100.dp,
                    avatarSize = 64.dp,
                    medalColor = LiquidGlassColors.medalSilver,
                    medalGradient = Brush.linearGradient(
                        listOf(
                            LiquidGlassColors.medalSilver,
                            LiquidGlassColors.medalSilver.copy(alpha = 0.6f)
                        )
                    ),
                    medalEmoji = "2",
                    modifier = Modifier.weight(1f)
                )
            } ?: Spacer(modifier = Modifier.weight(1f))

            Spacer(modifier = Modifier.width(Spacing.sm))

            // 1st place - Gold (center, tallest)
            first?.let {
                PodiumItem(
                    entry = it,
                    podiumHeight = 140.dp,
                    avatarSize = 80.dp,
                    medalColor = LiquidGlassColors.medalGold,
                    medalGradient = Brush.linearGradient(
                        listOf(
                            LiquidGlassColors.medalGold,
                            Color(0xFFFFA500) // Orange accent
                        )
                    ),
                    medalEmoji = "1",
                    isFirst = true,
                    modifier = Modifier.weight(1.2f)
                )
            } ?: Spacer(modifier = Modifier.weight(1.2f))

            Spacer(modifier = Modifier.width(Spacing.sm))

            // 3rd place - Bronze (right, shortest)
            third?.let {
                PodiumItem(
                    entry = it,
                    podiumHeight = 80.dp,
                    avatarSize = 56.dp,
                    medalColor = LiquidGlassColors.medalBronze,
                    medalGradient = Brush.linearGradient(
                        listOf(
                            LiquidGlassColors.medalBronze,
                            LiquidGlassColors.medalBronze.copy(alpha = 0.6f)
                        )
                    ),
                    medalEmoji = "3",
                    modifier = Modifier.weight(1f)
                )
            } ?: Spacer(modifier = Modifier.weight(1f))
        }
    }
}

/**
 * A single podium item showing avatar, name, score, and podium bar.
 */
@Composable
private fun PodiumItem(
    entry: LeaderboardEntry,
    podiumHeight: androidx.compose.ui.unit.Dp,
    avatarSize: androidx.compose.ui.unit.Dp,
    medalColor: Color,
    medalGradient: Brush,
    medalEmoji: String,
    isFirst: Boolean = false,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Crown icon for 1st place
        if (isFirst) {
            Icon(
                imageVector = Icons.Default.EmojiEvents,
                contentDescription = "Champion",
                tint = LiquidGlassColors.medalGold,
                modifier = Modifier.size(28.dp)
            )
            Spacer(modifier = Modifier.height(Spacing.xxxs))
        }

        // Avatar with medal border
        Box(contentAlignment = Alignment.Center) {
            // Glow ring
            Box(
                modifier = Modifier
                    .size(avatarSize + 8.dp)
                    .clip(CircleShape)
                    .background(medalColor.copy(alpha = 0.3f))
            )

            // Avatar
            Box(
                modifier = Modifier
                    .size(avatarSize)
                    .clip(CircleShape)
                    .border(
                        width = 3.dp,
                        brush = medalGradient,
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
                        tint = Color.White,
                        modifier = Modifier.size(avatarSize * 0.5f)
                    )
                }
            }

            // Medal badge
            Box(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .offset(x = 4.dp, y = 4.dp)
                    .size(24.dp)
                    .clip(CircleShape)
                    .background(brush = medalGradient),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = medalEmoji,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
            }
        }

        Spacer(modifier = Modifier.height(Spacing.sm))

        // Name
        Text(
            text = entry.displayName,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.SemiBold,
            color = Color.White,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )

        // Score
        Text(
            text = formatScore(entry.score),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = medalColor,
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(Spacing.sm))

        // Podium bar
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(podiumHeight)
                .clip(RoundedCornerShape(topStart = CornerRadius.medium, topEnd = CornerRadius.medium))
                .background(brush = medalGradient.let {
                    Brush.verticalGradient(
                        listOf(
                            medalColor.copy(alpha = 0.6f),
                            medalColor.copy(alpha = 0.2f)
                        )
                    )
                })
                .border(
                    width = 1.dp,
                    color = medalColor.copy(alpha = 0.4f),
                    shape = RoundedCornerShape(topStart = CornerRadius.medium, topEnd = CornerRadius.medium)
                ),
            contentAlignment = Alignment.Center
        ) {
            // Rank number on the podium
            Text(
                text = "#${entry.rank}",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = Color.White.copy(alpha = 0.4f)
            )
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
