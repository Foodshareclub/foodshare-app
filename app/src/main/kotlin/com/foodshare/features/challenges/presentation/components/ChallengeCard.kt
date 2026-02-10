package com.foodshare.features.challenges.presentation.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.foodshare.features.challenges.domain.model.*
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.Spacing

/**
 * Card component for displaying a challenge.
 */
@Composable
fun ChallengeCard(
    challengeWithStatus: ChallengeWithStatus,
    isLiked: Boolean,
    likeCount: Int,
    onClick: () -> Unit,
    onAccept: () -> Unit,
    onComplete: () -> Unit,
    onLikeToggle: () -> Unit,
    modifier: Modifier = Modifier
) {
    val challenge = challengeWithStatus.challenge
    val status = challengeWithStatus.status

    Card(
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(16.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column {
            // Image header
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(140.dp)
            ) {
                if (challenge.imageUrl != null) {
                    AsyncImage(
                        model = challenge.imageUrl,
                        contentDescription = null,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop
                    )
                } else {
                    // Gradient placeholder
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(
                                brush = Brush.linearGradient(
                                    colors = listOf(
                                        Color(challenge.difficulty.color),
                                        Color(challenge.difficulty.color).copy(alpha = 0.6f)
                                    )
                                )
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Default.EmojiEvents,
                            contentDescription = null,
                            modifier = Modifier.size(48.dp),
                            tint = Color.White.copy(alpha = 0.7f)
                        )
                    }
                }

                // Difficulty badge
                DifficultyBadge(
                    difficulty = challenge.difficulty,
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(Spacing.sm)
                )

                // Status badge
                StatusBadge(
                    status = status,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(Spacing.sm)
                )
            }

            // Content
            Column(
                modifier = Modifier.padding(Spacing.md)
            ) {
                // Title
                Text(
                    text = challenge.title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )

                Spacer(modifier = Modifier.height(Spacing.xs))

                // Description
                Text(
                    text = challenge.displayDescription,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )

                Spacer(modifier = Modifier.height(Spacing.sm))

                // Stats row
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(Spacing.md),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    StatItem(
                        icon = Icons.Outlined.Star,
                        value = challenge.formattedScore,
                        label = "pts"
                    )
                    StatItem(
                        icon = Icons.Outlined.Group,
                        value = challenge.formattedParticipants,
                        label = "joined"
                    )
                    StatItem(
                        icon = Icons.Outlined.RemoveRedEye,
                        value = challenge.viewsCount.toString(),
                        label = "views"
                    )

                    Spacer(modifier = Modifier.weight(1f))

                    // Like button
                    Row(
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        IconButton(
                            onClick = onLikeToggle,
                            modifier = Modifier.size(32.dp)
                        ) {
                            Icon(
                                imageVector = if (isLiked) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                                contentDescription = "Like",
                                tint = if (isLiked) LiquidGlassColors.brandPink else MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                        Text(
                            text = likeCount.toString(),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                Spacer(modifier = Modifier.height(Spacing.sm))

                // Action button
                when (status) {
                    ChallengeUserStatus.NOT_JOINED -> {
                        Button(
                            onClick = onAccept,
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = LiquidGlassColors.brandPink
                            )
                        ) {
                            Icon(Icons.Default.Add, contentDescription = null)
                            Spacer(modifier = Modifier.width(Spacing.xs))
                            Text("Join Challenge")
                        }
                    }
                    ChallengeUserStatus.ACCEPTED -> {
                        Button(
                            onClick = onComplete,
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Color(0xFF4CAF50)
                            )
                        ) {
                            Icon(Icons.Default.Check, contentDescription = null)
                            Spacer(modifier = Modifier.width(Spacing.xs))
                            Text("Mark Complete")
                        }
                    }
                    ChallengeUserStatus.COMPLETED -> {
                        OutlinedButton(
                            onClick = { },
                            modifier = Modifier.fillMaxWidth(),
                            enabled = false
                        ) {
                            Icon(Icons.Default.CheckCircle, contentDescription = null)
                            Spacer(modifier = Modifier.width(Spacing.xs))
                            Text("Completed!")
                        }
                    }
                    ChallengeUserStatus.REJECTED -> {
                        TextButton(
                            onClick = onAccept,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("Reconsider?")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DifficultyBadge(
    difficulty: ChallengeDifficulty,
    modifier: Modifier = Modifier
) {
    Surface(
        shape = RoundedCornerShape(8.dp),
        color = Color(difficulty.color),
        modifier = modifier
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Icon(
                imageVector = when (difficulty) {
                    ChallengeDifficulty.EASY -> Icons.Default.SentimentSatisfied
                    ChallengeDifficulty.MEDIUM -> Icons.Default.SentimentNeutral
                    ChallengeDifficulty.HARD -> Icons.Default.LocalFireDepartment
                    ChallengeDifficulty.EXTREME -> Icons.Default.Whatshot
                },
                contentDescription = null,
                modifier = Modifier.size(14.dp),
                tint = Color.White
            )
            Text(
                text = difficulty.displayName,
                style = MaterialTheme.typography.labelSmall,
                color = Color.White,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
private fun StatusBadge(
    status: ChallengeUserStatus,
    modifier: Modifier = Modifier
) {
    val (color, icon) = when (status) {
        ChallengeUserStatus.NOT_JOINED -> return // Don't show badge
        ChallengeUserStatus.ACCEPTED -> Pair(Color(0xFF2196F3), Icons.Default.PlayArrow)
        ChallengeUserStatus.COMPLETED -> Pair(Color(0xFF4CAF50), Icons.Default.Check)
        ChallengeUserStatus.REJECTED -> Pair(Color(0xFF9E9E9E), Icons.Default.Close)
    }

    Surface(
        shape = CircleShape,
        color = color,
        modifier = modifier.size(28.dp)
    ) {
        Box(contentAlignment = Alignment.Center) {
            Icon(
                imageVector = icon,
                contentDescription = status.displayName,
                modifier = Modifier.size(16.dp),
                tint = Color.White
            )
        }
    }
}

@Composable
private fun StatItem(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    value: String,
    label: String
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
            text = value,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.Medium
        )
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}
