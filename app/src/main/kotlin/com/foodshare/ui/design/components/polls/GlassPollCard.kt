package com.foodshare.ui.design.components.polls

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.foodshare.ui.design.components.cards.GlassCard
import com.foodshare.ui.design.tokens.*

/**
 * Data class representing a poll option
 */
data class PollOption(
    val text: String,
    val voteCount: Int,
    val isSelected: Boolean = false
)

/**
 * Poll card with animated progress bars and vote tracking
 * Displays poll question, options with progress indicators, and vote counts
 */
@Composable
fun GlassPollCard(
    question: String,
    options: List<PollOption>,
    totalVotes: Int,
    onVote: (Int) -> Unit,
    hasVoted: Boolean,
    modifier: Modifier = Modifier
) {
    require(options.isNotEmpty()) { "Poll must have at least one option" }

    GlassCard(
        modifier = modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.md)
        ) {
            // Poll question
            Text(
                text = question,
                style = MaterialTheme.typography.titleMedium,
                color = LiquidGlassColors.Text.primary
            )

            // Total votes display
            Text(
                text = "$totalVotes ${if (totalVotes == 1) "vote" else "votes"}",
                style = MaterialTheme.typography.bodySmall,
                color = LiquidGlassColors.Text.secondary
            )

            Spacer(modifier = Modifier.height(Spacing.xs))

            // Poll options
            options.forEachIndexed { index, option ->
                PollOptionRow(
                    option = option,
                    totalVotes = totalVotes,
                    hasVoted = hasVoted,
                    onClick = { if (!hasVoted) onVote(index) }
                )
            }
        }
    }
}

/**
 * Individual poll option row with animated progress bar
 */
@Composable
private fun PollOptionRow(
    option: PollOption,
    totalVotes: Int,
    hasVoted: Boolean,
    onClick: () -> Unit
) {
    val percentage = if (totalVotes > 0) {
        (option.voteCount.toFloat() / totalVotes.toFloat())
    } else {
        0f
    }

    val animatedPercentage by animateFloatAsState(
        targetValue = if (hasVoted) percentage else 0f,
        animationSpec = tween(durationMillis = LiquidGlassAnimations.Duration.standard),
        label = "progress_${option.text}"
    )

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(CornerRadius.medium))
            .background(LiquidGlassColors.Glass.micro)
            .border(
                width = if (option.isSelected) 2.dp else 1.dp,
                color = if (option.isSelected) {
                    LiquidGlassColors.brandPink
                } else {
                    LiquidGlassColors.Glass.border
                },
                shape = RoundedCornerShape(CornerRadius.medium)
            )
            .clickable(enabled = !hasVoted, onClick = onClick)
            .height(56.dp)
    ) {
        // Animated progress bar
        if (hasVoted) {
            Box(
                modifier = Modifier
                    .fillMaxHeight()
                    .fillMaxWidth(animatedPercentage)
                    .background(
                        color = if (option.isSelected) {
                            LiquidGlassColors.brandPink.copy(alpha = 0.2f)
                        } else {
                            LiquidGlassColors.brandTeal.copy(alpha = 0.1f)
                        }
                    )
            )
        }

        // Option content
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = Spacing.md),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = option.text,
                style = MaterialTheme.typography.bodyMedium,
                color = LiquidGlassColors.Text.primary,
                modifier = Modifier.weight(1f)
            )

            if (hasVoted) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "${(percentage * 100).toInt()}%",
                        style = MaterialTheme.typography.bodyMedium,
                        color = if (option.isSelected) {
                            LiquidGlassColors.brandPink
                        } else {
                            LiquidGlassColors.Text.secondary
                        }
                    )

                    Text(
                        text = "(${option.voteCount})",
                        style = MaterialTheme.typography.bodySmall,
                        color = LiquidGlassColors.Text.secondary
                    )
                }
            }
        }
    }
}
