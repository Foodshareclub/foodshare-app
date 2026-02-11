package com.foodshare.features.forum.presentation.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.HowToVote
import androidx.compose.material.icons.outlined.Poll
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.foodshare.features.forum.domain.model.ForumPoll
import com.foodshare.features.forum.domain.model.ForumPollOption
import com.foodshare.features.forum.domain.model.PollType
import com.foodshare.ui.design.components.polls.GlassPollCard
import com.foodshare.ui.design.components.polls.PollOption
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.Spacing

/**
 * Forum poll section that displays a poll within a forum post.
 * Handles both voting and results display states using the GlassPollCard component.
 *
 * SYNC: This mirrors the iOS ForumPollSection SwiftUI view.
 */
@Composable
fun ForumPollSection(
    poll: ForumPoll,
    selectedOptionIds: Set<String>,
    isVoting: Boolean,
    onSelectOption: (String) -> Unit,
    onCastVote: () -> Unit,
    modifier: Modifier = Modifier
) {
    val options = poll.options ?: return
    if (options.isEmpty()) return

    val pollOptions = remember(options, poll.totalVotes, selectedOptionIds, poll.shouldShowResults) {
        mapToPollOptions(
            options = options,
            totalVotes = poll.totalVotes,
            selectedOptionIds = selectedOptionIds,
            showResults = poll.shouldShowResults
        )
    }

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm)
    ) {
        // Poll header with type indicator
        PollHeader(poll = poll)

        // Main poll card using the existing GlassPollCard component
        GlassPollCard(
            question = poll.question,
            options = pollOptions,
            totalVotes = poll.totalVotes,
            onVote = { index ->
                val option = options.getOrNull(index)
                if (option != null) {
                    onSelectOption(option.id)
                }
            },
            hasVoted = poll.shouldShowResults,
            modifier = Modifier.fillMaxWidth()
        )

        // Vote button (shown when user can vote and has selected options)
        AnimatedVisibility(
            visible = poll.canVote && selectedOptionIds.isNotEmpty() && !poll.hasVoted,
            enter = fadeIn(),
            exit = fadeOut()
        ) {
            VoteButton(
                isVoting = isVoting,
                selectedCount = selectedOptionIds.size,
                pollType = poll.pollType,
                onCastVote = onCastVote
            )
        }

        // Poll footer with metadata
        PollFooter(poll = poll)
    }
}

/**
 * Poll header showing poll type badge and status.
 */
@Composable
private fun PollHeader(
    poll: ForumPoll
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Poll type badge
        Surface(
            shape = RoundedCornerShape(CornerRadius.small),
            color = LiquidGlassColors.brandTeal.copy(alpha = 0.1f)
        ) {
            Row(
                modifier = Modifier.padding(horizontal = Spacing.xxs, vertical = Spacing.xxxs),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.xxxs)
            ) {
                Icon(
                    imageVector = Icons.Outlined.Poll,
                    contentDescription = null,
                    modifier = Modifier.size(14.dp),
                    tint = LiquidGlassColors.brandTeal
                )
                Text(
                    text = poll.pollType.displayName,
                    style = MaterialTheme.typography.labelSmall,
                    color = LiquidGlassColors.brandTeal
                )
            }
        }

        // Status badge
        if (poll.hasEnded) {
            Surface(
                shape = RoundedCornerShape(CornerRadius.small),
                color = LiquidGlassColors.Text.secondary.copy(alpha = 0.1f)
            ) {
                Text(
                    text = "Ended",
                    style = MaterialTheme.typography.labelSmall,
                    color = LiquidGlassColors.Text.secondary,
                    modifier = Modifier.padding(horizontal = Spacing.xxs, vertical = Spacing.xxxs)
                )
            }
        } else if (poll.hasVoted) {
            Surface(
                shape = RoundedCornerShape(CornerRadius.small),
                color = LiquidGlassColors.success.copy(alpha = 0.1f)
            ) {
                Text(
                    text = "Voted",
                    style = MaterialTheme.typography.labelSmall,
                    color = LiquidGlassColors.success,
                    modifier = Modifier.padding(horizontal = Spacing.xxs, vertical = Spacing.xxxs)
                )
            }
        }
    }
}

/**
 * Vote submission button.
 */
@Composable
private fun VoteButton(
    isVoting: Boolean,
    selectedCount: Int,
    pollType: PollType,
    onCastVote: () -> Unit
) {
    Button(
        onClick = onCastVote,
        enabled = !isVoting && selectedCount > 0,
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(CornerRadius.medium),
        colors = ButtonDefaults.buttonColors(
            containerColor = LiquidGlassColors.brandTeal,
            contentColor = Color.White
        )
    ) {
        if (isVoting) {
            CircularProgressIndicator(
                modifier = Modifier.size(16.dp),
                strokeWidth = 2.dp,
                color = Color.White
            )
            Spacer(modifier = Modifier.width(Spacing.xxs))
            Text(
                text = "Submitting...",
                style = MaterialTheme.typography.labelLarge
            )
        } else {
            Icon(
                imageVector = Icons.Outlined.HowToVote,
                contentDescription = null,
                modifier = Modifier.size(18.dp)
            )
            Spacer(modifier = Modifier.width(Spacing.xxs))
            val label = when {
                pollType == PollType.MULTIPLE && selectedCount > 1 ->
                    "Vote ($selectedCount selected)"
                else -> "Vote"
            }
            Text(
                text = label,
                style = MaterialTheme.typography.labelLarge
            )
        }
    }
}

/**
 * Poll footer with total votes count and time remaining.
 */
@Composable
private fun PollFooter(
    poll: ForumPoll
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Total votes
        Text(
            text = "${poll.totalVotes} ${if (poll.totalVotes == 1) "vote" else "votes"}",
            style = MaterialTheme.typography.bodySmall,
            color = LiquidGlassColors.Text.secondary
        )

        // Time remaining
        poll.timeRemainingText?.let { timeText ->
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.xxxs)
            ) {
                Icon(
                    imageVector = Icons.Outlined.Schedule,
                    contentDescription = null,
                    modifier = Modifier.size(14.dp),
                    tint = LiquidGlassColors.Text.secondary
                )
                Text(
                    text = timeText,
                    style = MaterialTheme.typography.bodySmall,
                    color = LiquidGlassColors.Text.secondary
                )
            }
        }

        // Anonymous indicator
        if (poll.isAnonymous) {
            Text(
                text = "Anonymous",
                style = MaterialTheme.typography.bodySmall,
                color = LiquidGlassColors.Text.secondary,
                fontWeight = FontWeight.Medium
            )
        }
    }
}

// MARK: - Helpers

/**
 * Convert ForumPollOption list to GlassPollCard PollOption list.
 * Maps domain model to the UI component's expected data format.
 */
private fun mapToPollOptions(
    options: List<ForumPollOption>,
    totalVotes: Int,
    selectedOptionIds: Set<String>,
    showResults: Boolean
): List<PollOption> {
    return options
        .sortedBy { it.sortOrder }
        .map { option ->
            PollOption(
                text = option.optionText,
                voteCount = if (showResults) option.votesCount else 0,
                isSelected = selectedOptionIds.contains(option.id)
            )
        }
}
