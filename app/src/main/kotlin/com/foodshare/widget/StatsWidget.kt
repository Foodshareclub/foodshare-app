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
import androidx.glance.unit.ColorProvider
import androidx.glance.color.ColorProvider
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
 * Stats Widget - Displays the user's impact statistics.
 *
 * Shows:
 * - Items shared count (green card)
 * - Items received count (blue card)
 * - Community rank (purple card)
 * - Environmental impact (CO2 saved) (orange card)
 *
 * Each stat is shown in a colored card with an emoji indicator.
 * Tapping the widget navigates to the user's profile page.
 *
 * SYNC: Mirrors iOS StatsWidget
 */
class StatsWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val stats = WidgetDataService.getUserStats(context)

        provideContent {
            GlanceTheme {
                StatsWidgetContent(
                    context = context,
                    stats = stats
                )
            }
        }
    }
}

// ============================================================================
// Widget Content
// ============================================================================

@Composable
private fun StatsWidgetContent(
    context: Context,
    stats: WidgetUserStats
) {
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(WidgetColors.darkBackground)
            .padding(12.dp)
            .cornerRadius(16.dp)
            .clickable(
                actionStartActivity(
                    Intent(context, MainActivity::class.java).apply {
                        action = Intent.ACTION_VIEW
                        data = Uri.parse("foodshare://profile")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                )
            ),
    ) {
        // Header
        StatsHeader()

        Spacer(modifier = GlanceModifier.height(10.dp))

        // Stats grid (2x2)
        Row(
            modifier = GlanceModifier.fillMaxWidth()
        ) {
            StatCard(
                emoji = "\uD83C\uDF3F",
                label = "Shared",
                value = formatStatValue(stats.itemsShared),
                accentColor = WidgetColors.statGreen,
                modifier = GlanceModifier.defaultWeight()
            )
            Spacer(modifier = GlanceModifier.width(8.dp))
            StatCard(
                emoji = "\uD83D\uDE4F",
                label = "Received",
                value = formatStatValue(stats.itemsReceived),
                accentColor = WidgetColors.statBlue,
                modifier = GlanceModifier.defaultWeight()
            )
        }

        Spacer(modifier = GlanceModifier.height(8.dp))

        Row(
            modifier = GlanceModifier.fillMaxWidth()
        ) {
            StatCard(
                emoji = "\uD83C\uDFC6",
                label = "Rank",
                value = formatRank(stats.communityRank),
                accentColor = WidgetColors.statPurple,
                modifier = GlanceModifier.defaultWeight()
            )
            Spacer(modifier = GlanceModifier.width(8.dp))
            StatCard(
                emoji = "\uD83C\uDF0D",
                label = "CO\u2082 Saved",
                value = formatCO2(stats.co2SavedKg),
                accentColor = WidgetColors.statOrange,
                modifier = GlanceModifier.defaultWeight()
            )
        }

        Spacer(modifier = GlanceModifier.height(10.dp))

        // Streak indicator
        if (stats.currentStreak > 0) {
            StreakBanner(streakDays = stats.currentStreak)
        }

        // Last updated
        Text(
            text = "Updated ${stats.lastUpdated}",
            style = TextStyle(
                color = WidgetColors.textTertiary,
                fontSize = 10.sp,
                textAlign = TextAlign.Center
            ),
            modifier = GlanceModifier.fillMaxWidth()
        )
    }
}

@Composable
private fun StatsHeader() {
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
            text = "Your Impact",
            style = TextStyle(
                color = WidgetColors.textPrimary,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            )
        )
    }
}

@Composable
private fun StatCard(
    emoji: String,
    label: String,
    value: String,
    accentColor: ColorProvider,
    modifier: GlanceModifier = GlanceModifier
) {
    Column(
        modifier = modifier
            .cornerRadius(12.dp)
            .background(WidgetColors.cardBackground)
            .padding(10.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Emoji with colored background
        Box(
            modifier = GlanceModifier
                .size(36.dp)
                .cornerRadius(18.dp)
                .background(accentColor),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = emoji,
                style = TextStyle(fontSize = 18.sp)
            )
        }

        Spacer(modifier = GlanceModifier.height(6.dp))

        // Value
        Text(
            text = value,
            style = TextStyle(
                color = WidgetColors.textPrimary,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            )
        )

        // Label
        Text(
            text = label,
            style = TextStyle(
                color = WidgetColors.textSecondary,
                fontSize = 11.sp,
                textAlign = TextAlign.Center
            )
        )
    }
}

@Composable
private fun StreakBanner(streakDays: Int) {
    Box(
        modifier = GlanceModifier
            .fillMaxWidth()
            .cornerRadius(8.dp)
            .background(WidgetColors.cardBackground)
            .padding(horizontal = 12.dp, vertical = 6.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = "\uD83D\uDD25 $streakDays day streak!",
            style = TextStyle(
                color = WidgetColors.accent,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center
            )
        )
    }
    Spacer(modifier = GlanceModifier.height(6.dp))
}

// ============================================================================
// Formatting Helpers
// ============================================================================

/**
 * Format a stat value for display.
 * Shows exact value for < 1000, "1.2k" for thousands, "1.2M" for millions.
 */
private fun formatStatValue(value: Int): String {
    return when {
        value >= 1_000_000 -> String.format("%.1fM", value / 1_000_000.0)
        value >= 10_000 -> String.format("%.0fk", value / 1_000.0)
        value >= 1_000 -> String.format("%.1fk", value / 1_000.0)
        else -> value.toString()
    }
}

/**
 * Format community rank for display.
 * Shows "#1" for top ranks, or ordinal for others.
 */
private fun formatRank(rank: Int): String {
    if (rank <= 0) return "--"
    return "#$rank"
}

/**
 * Format CO2 saved for display.
 */
private fun formatCO2(kg: Double): String {
    return when {
        kg >= 1000 -> String.format("%.1ft", kg / 1000.0)
        kg >= 1 -> String.format("%.0fkg", kg)
        kg > 0 -> String.format("%.0fg", kg * 1000)
        else -> "0kg"
    }
}

// ============================================================================
// Widget Receiver
// ============================================================================

/**
 * Broadcast receiver for the StatsWidget.
 * Registered in AndroidManifest.xml.
 */
class StatsWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = StatsWidget()
}

// ============================================================================
// Widget Data Model
// ============================================================================

/**
 * User stats model for widget display.
 */
data class WidgetUserStats(
    val itemsShared: Int = 0,
    val itemsReceived: Int = 0,
    val communityRank: Int = 0,
    val co2SavedKg: Double = 0.0,
    val currentStreak: Int = 0,
    val lastUpdated: String = "just now"
)
