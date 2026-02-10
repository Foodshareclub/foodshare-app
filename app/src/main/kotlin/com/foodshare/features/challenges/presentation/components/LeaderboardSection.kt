package com.foodshare.features.challenges.presentation.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.foodshare.features.challenges.domain.model.ChallengeLeaderboardEntry
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.Spacing

/**
 * Leaderboard section showing top performers for a challenge.
 */
@Composable
fun LeaderboardSection(
    entries: List<ChallengeLeaderboardEntry>,
    isLoading: Boolean,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.xs)
        ) {
            Icon(
                Icons.Default.EmojiEvents,
                contentDescription = null,
                tint = Color(0xFFFFB300) // Gold
            )
            Text(
                text = "Leaderboard",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
        }

        Spacer(modifier = Modifier.height(Spacing.sm))

        if (isLoading) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }
        } else if (entries.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(120.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "No participants yet",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        } else {
            Card(
                shape = RoundedCornerShape(16.dp)
            ) {
                Column(
                    modifier = Modifier.padding(Spacing.sm)
                ) {
                    entries.forEachIndexed { index, entry ->
                        LeaderboardRow(
                            entry = entry,
                            isLast = index == entries.lastIndex
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun LeaderboardRow(
    entry: ChallengeLeaderboardEntry,
    isLast: Boolean
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = Spacing.sm),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Rank badge
        RankBadge(rank = entry.rank)

        Spacer(modifier = Modifier.width(Spacing.sm))

        // Avatar
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .border(
                    width = 2.dp,
                    brush = when (entry.rank) {
                        1 -> Brush.linearGradient(listOf(Color(0xFFFFD700), Color(0xFFFFA500)))
                        2 -> Brush.linearGradient(listOf(Color(0xFFC0C0C0), Color(0xFF808080)))
                        3 -> Brush.linearGradient(listOf(Color(0xFFCD7F32), Color(0xFF8B4513)))
                        else -> Brush.linearGradient(listOf(Color.Transparent, Color.Transparent))
                    },
                    shape = CircleShape
                )
        ) {
            AsyncImage(
                model = entry.avatarUrl,
                contentDescription = "Avatar",
                modifier = Modifier
                    .fillMaxSize()
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            )
        }

        Spacer(modifier = Modifier.width(Spacing.sm))

        // Name
        Text(
            text = entry.nickname,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = if (entry.rank <= 3) FontWeight.Bold else FontWeight.Normal,
            modifier = Modifier.weight(1f)
        )

        // Completion status
        if (entry.isCompleted) {
            Surface(
                shape = CircleShape,
                color = Color(0xFF4CAF50).copy(alpha = 0.2f),
                modifier = Modifier.size(24.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        Icons.Default.Check,
                        contentDescription = "Completed",
                        modifier = Modifier.size(14.dp),
                        tint = Color(0xFF4CAF50)
                    )
                }
            }
        }
    }

    if (!isLast) {
        HorizontalDivider(
            modifier = Modifier.padding(start = 72.dp),
            color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)
        )
    }
}

@Composable
private fun RankBadge(rank: Int) {
    val (backgroundColor, textColor) = when (rank) {
        1 -> Pair(
            Brush.linearGradient(listOf(Color(0xFFFFD700), Color(0xFFFFA500))),
            Color.White
        )
        2 -> Pair(
            Brush.linearGradient(listOf(Color(0xFFC0C0C0), Color(0xFF808080))),
            Color.White
        )
        3 -> Pair(
            Brush.linearGradient(listOf(Color(0xFFCD7F32), Color(0xFF8B4513))),
            Color.White
        )
        else -> Pair(
            Brush.linearGradient(listOf(
                MaterialTheme.colorScheme.surfaceVariant,
                MaterialTheme.colorScheme.surfaceVariant
            )),
            MaterialTheme.colorScheme.onSurfaceVariant
        )
    }

    Box(
        modifier = Modifier
            .size(32.dp)
            .clip(CircleShape)
            .background(backgroundColor),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = rank.toString(),
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.Bold,
            color = textColor
        )
    }
}
