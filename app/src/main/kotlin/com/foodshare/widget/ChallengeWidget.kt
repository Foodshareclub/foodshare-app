package com.foodshare.widget

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import com.foodshare.MainActivity
import com.flutterflow.foodshare.R

/**
 * Challenge Widget - Shows the user's active challenge with progress.
 *
 * Displays:
 * - Challenge title and emoji
 * - Progress bar with percentage
 * - Current / target count
 * - Days remaining
 * - Reward points
 *
 * Tapping navigates to the challenge detail screen via deep link.
 * If no active challenge exists, shows a prompt to join one.
 *
 * SYNC: Mirrors iOS ChallengeWidget
 */
class ChallengeWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val challenge = WidgetDataService.getActiveChallenge(context)

        provideContent {
            GlanceTheme {
                ChallengeWidgetContent(
                    context = context,
                    challenge = challenge
                )
            }
        }
    }
}

// ============================================================================
// Widget Content
// ============================================================================

@Composable
private fun ChallengeWidgetContent(
    context: Context,
    challenge: WidgetChallenge?
) {
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(WidgetColors.darkBackground)
            .padding(12.dp)
            .cornerRadius(16.dp),
    ) {
        // Header
        ChallengeHeader()

        Spacer(modifier = GlanceModifier.height(10.dp))

        if (challenge != null) {
            ActiveChallengeCard(context = context, challenge = challenge)
        } else {
            NoChallengeState(context = context)
        }
    }
}

@Composable
private fun ChallengeHeader() {
    Row(
        modifier = GlanceModifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Image(
            provider = ImageProvider(R.drawable.ic_launcher_foreground),
            contentDescription = "FoodShare",
            modifier = GlanceModifier.size(20.dp)
        )
        Spacer(modifier = GlanceModifier.width(6.dp))
        Text(
            text = "Active Challenge",
            style = TextStyle(
                color = WidgetColors.textPrimary,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            )
        )
    }
}

@Composable
private fun ActiveChallengeCard(
    context: Context,
    challenge: WidgetChallenge
) {
    Column(
        modifier = GlanceModifier
            .fillMaxWidth()
            .cornerRadius(12.dp)
            .background(WidgetColors.cardBackground)
            .padding(12.dp)
            .clickable(
                actionStartActivity(
                    Intent(context, MainActivity::class.java).apply {
                        action = Intent.ACTION_VIEW
                        data = Uri.parse("foodshare://challenges/${challenge.id}")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                )
            )
    ) {
        // Challenge title with emoji
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = challenge.emoji,
                style = TextStyle(fontSize = 24.sp)
            )
            Spacer(modifier = GlanceModifier.width(8.dp))
            Column(modifier = GlanceModifier.defaultWeight()) {
                Text(
                    text = challenge.title,
                    style = TextStyle(
                        color = WidgetColors.textPrimary,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold
                    ),
                    maxLines = 2
                )
                if (challenge.description.isNotBlank()) {
                    Text(
                        text = challenge.description.take(60) +
                            if (challenge.description.length > 60) "..." else "",
                        style = TextStyle(
                            color = WidgetColors.textSecondary,
                            fontSize = 11.sp
                        ),
                        maxLines = 1
                    )
                }
            }
        }

        Spacer(modifier = GlanceModifier.height(12.dp))

        // Progress bar
        ProgressBar(
            progress = challenge.progress,
            current = challenge.currentCount,
            target = challenge.targetCount
        )

        Spacer(modifier = GlanceModifier.height(10.dp))

        // Bottom row - days remaining + reward
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Days remaining
            DaysRemainingBadge(days = challenge.daysRemaining)

            Spacer(modifier = GlanceModifier.defaultWeight())

            // Reward
            if (challenge.rewardPoints > 0) {
                RewardBadge(points = challenge.rewardPoints)
            }
        }
    }
}

@Composable
private fun ProgressBar(progress: Float, current: Int, target: Int) {
    Column(modifier = GlanceModifier.fillMaxWidth()) {
        // Progress label
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "$current / $target",
                style = TextStyle(
                    color = WidgetColors.textPrimary,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium
                )
            )
            Spacer(modifier = GlanceModifier.defaultWeight())
            Text(
                text = "${(progress * 100).toInt()}%",
                style = TextStyle(
                    color = WidgetColors.accent,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold
                )
            )
        }

        Spacer(modifier = GlanceModifier.height(4.dp))

        // Progress bar background
        Box(
            modifier = GlanceModifier
                .fillMaxWidth()
                .height(8.dp)
                .cornerRadius(4.dp)
                .background(WidgetColors.progressBackground)
        ) {
            // Progress fill
            // Glance does not support fractional widths directly,
            // so we use a row-based approximation
            Row(modifier = GlanceModifier.fillMaxWidth()) {
                if (progress > 0f) {
                    Box(
                        modifier = GlanceModifier
                            .height(8.dp)
                            .cornerRadius(4.dp)
                            .background(WidgetColors.progressFill)
                            .defaultWeight()
                    ) {}
                }
                if (progress < 1f) {
                    // Remaining space as invisible
                    val remainingWeight = ((1f - progress) / progress.coerceAtLeast(0.01f))
                    Box(
                        modifier = GlanceModifier
                            .height(8.dp)
                            .defaultWeight()
                    ) {}
                }
            }
        }
    }
}

@Composable
private fun DaysRemainingBadge(days: Int) {
    val pair: Pair<String, androidx.glance.unit.ColorProvider> = when {
        days <= 0 -> "Ended" to WidgetColors.textTertiary
        days == 1 -> "1 day left" to WidgetColors.statOrange
        days <= 3 -> "$days days left" to WidgetColors.statOrange
        else -> "$days days left" to WidgetColors.textSecondary
    }
    val text = pair.first
    val color = pair.second

    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = "\u23F3",
            style = TextStyle(fontSize = 12.sp)
        )
        Spacer(modifier = GlanceModifier.width(4.dp))
        Text(
            text = text,
            style = TextStyle(
                color = color,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium
            )
        )
    }
}

@Composable
private fun RewardBadge(points: Int) {
    Box(
        modifier = GlanceModifier
            .cornerRadius(12.dp)
            .background(WidgetColors.cardBackground)
            .padding(horizontal = 8.dp, vertical = 3.dp)
    ) {
        Text(
            text = "\u2B50 $points pts",
            style = TextStyle(
                color = WidgetColors.statOrange,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium
            )
        )
    }
}

@Composable
private fun NoChallengeState(context: Context) {
    Column(
        modifier = GlanceModifier
            .fillMaxWidth()
            .cornerRadius(12.dp)
            .background(WidgetColors.cardBackground)
            .padding(16.dp)
            .clickable(
                actionStartActivity(
                    Intent(context, MainActivity::class.java).apply {
                        action = Intent.ACTION_VIEW
                        data = Uri.parse("foodshare://challenges")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                )
            ),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = "\uD83C\uDFC6",
            style = TextStyle(fontSize = 32.sp)
        )

        Spacer(modifier = GlanceModifier.height(8.dp))

        Text(
            text = "No active challenge",
            style = TextStyle(
                color = WidgetColors.textPrimary,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center
            )
        )

        Spacer(modifier = GlanceModifier.height(4.dp))

        Text(
            text = "Join a challenge and start making a difference!",
            style = TextStyle(
                color = WidgetColors.textSecondary,
                fontSize = 12.sp,
                textAlign = TextAlign.Center
            )
        )

        Spacer(modifier = GlanceModifier.height(12.dp))

        Box(
            modifier = GlanceModifier
                .cornerRadius(8.dp)
                .background(WidgetColors.accent)
                .padding(horizontal = 16.dp, vertical = 6.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "Browse Challenges",
                style = TextStyle(
                    color = WidgetColors.darkBackground,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold
                )
            )
        }
    }
}

// ============================================================================
// Widget Receiver
// ============================================================================

/**
 * Broadcast receiver for the ChallengeWidget.
 * Registered in AndroidManifest.xml.
 */
class ChallengeWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = ChallengeWidget()
}

// ============================================================================
// Widget Data Model
// ============================================================================

/**
 * Challenge data model for widget display.
 */
data class WidgetChallenge(
    val id: Int,
    val title: String,
    val description: String = "",
    val emoji: String = "\uD83C\uDFC6",
    val currentCount: Int = 0,
    val targetCount: Int = 1,
    val daysRemaining: Int = 0,
    val rewardPoints: Int = 0
) {
    /**
     * Progress as a float between 0.0 and 1.0.
     */
    val progress: Float
        get() = if (targetCount <= 0) 0f
        else (currentCount.toFloat() / targetCount.toFloat()).coerceIn(0f, 1f)

    /**
     * Whether the challenge is completed.
     */
    val isCompleted: Boolean
        get() = currentCount >= targetCount
}
