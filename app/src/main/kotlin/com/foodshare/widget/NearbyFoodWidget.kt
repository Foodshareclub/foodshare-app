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
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.compose.ui.graphics.Color
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
import androidx.glance.unit.ColorProvider
import androidx.glance.color.ColorProvider
import com.foodshare.MainActivity
import com.flutterflow.foodshare.R

private const val MAX_LISTINGS = 5

/**
 * Nearby Food Widget - Shows the 3-5 nearest available food listings.
 *
 * Displays:
 * - Listing title (truncated)
 * - Distance from user
 * - Time since posted
 * - Tap navigates to listing detail via deep link
 *
 * Widget uses a dark themed background for visibility on home screens.
 * Data is fetched by WidgetDataService and cached in SharedPreferences
 * for offline display.
 *
 * SYNC: Mirrors iOS NearbyFoodWidget
 */
class NearbyFoodWidget : GlanceAppWidget() {

    companion object {
        private const val MAX_LISTINGS = 5
    }

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val listings = WidgetDataService.getNearbyListings(context)

        provideContent {
            GlanceTheme {
                NearbyFoodContent(
                    context = context,
                    listings = listings
                )
            }
        }
    }
}

// ============================================================================
// Widget Content
// ============================================================================

@Composable
private fun NearbyFoodContent(
    context: Context,
    listings: List<WidgetListing>
) {
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(WidgetColors.darkBackground)
            .padding(12.dp)
            .cornerRadius(16.dp),
    ) {
        // Header
        WidgetHeader(
            title = "Nearby Food",
            iconRes = R.drawable.ic_launcher_foreground
        )

        Spacer(modifier = GlanceModifier.height(8.dp))

        if (listings.isEmpty()) {
            EmptyState()
        } else {
            listings.take(MAX_LISTINGS).forEachIndexed { index, listing ->
                NearbyListingRow(context = context, listing = listing)
                if (index < listings.size - 1 && index < MAX_LISTINGS - 1) {
                    Spacer(modifier = GlanceModifier.height(6.dp))
                    DividerLine()
                    Spacer(modifier = GlanceModifier.height(6.dp))
                }
            }
        }

        Spacer(modifier = GlanceModifier.height(8.dp))

        // Footer - "See All" link
        Text(
            text = "See all nearby food",
            style = TextStyle(
                color = WidgetColors.accent,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center
            ),
            modifier = GlanceModifier
                .fillMaxWidth()
                .clickable(
                    actionStartActivity(
                        Intent(context, MainActivity::class.java).apply {
                            action = Intent.ACTION_VIEW
                            data = Uri.parse("foodshare://feed")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP
                        }
                    )
                )
        )
    }
}

@Composable
private fun WidgetHeader(title: String, iconRes: Int) {
    Row(
        modifier = GlanceModifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Image(
            provider = ImageProvider(iconRes),
            contentDescription = "FoodShare",
            modifier = GlanceModifier.size(20.dp)
        )
        Spacer(modifier = GlanceModifier.width(6.dp))
        Text(
            text = title,
            style = TextStyle(
                color = WidgetColors.textPrimary,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            )
        )
    }
}

@Composable
private fun NearbyListingRow(context: Context, listing: WidgetListing) {
    Row(
        modifier = GlanceModifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .clickable(
                actionStartActivity(
                    Intent(context, MainActivity::class.java).apply {
                        action = Intent.ACTION_VIEW
                        data = Uri.parse("foodshare://listing/${listing.id}")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                )
            ),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Food type indicator
        FoodTypeIndicator(postType = listing.postType)

        Spacer(modifier = GlanceModifier.width(8.dp))

        // Listing info
        Column(
            modifier = GlanceModifier.defaultWeight()
        ) {
            Text(
                text = listing.title.take(30) + if (listing.title.length > 30) "..." else "",
                style = TextStyle(
                    color = WidgetColors.textPrimary,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium
                ),
                maxLines = 1
            )
            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (listing.distance != null) {
                    Text(
                        text = listing.distance,
                        style = TextStyle(
                            color = WidgetColors.textSecondary,
                            fontSize = 11.sp
                        )
                    )
                    Text(
                        text = " \u2022 ",
                        style = TextStyle(
                            color = WidgetColors.textTertiary,
                            fontSize = 11.sp
                        )
                    )
                }
                Text(
                    text = listing.timeAgo,
                    style = TextStyle(
                        color = WidgetColors.textSecondary,
                        fontSize = 11.sp
                    )
                )
            }
        }

        // Chevron
        Text(
            text = "\u203A",
            style = TextStyle(
                color = WidgetColors.textTertiary,
                fontSize = 18.sp
            )
        )
    }
}

@Composable
private fun FoodTypeIndicator(postType: String?) {
    val pair: Pair<String, androidx.glance.unit.ColorProvider> = when (postType?.lowercase()) {
        "food" -> "\uD83C\uDF3F" to WidgetColors.greenBadge
        "fridge" -> "\u2744\uFE0F" to WidgetColors.blueBadge
        "foodbank" -> "\uD83C\uDFE2" to WidgetColors.purpleBadge
        "thing" -> "\uD83D\uDCE6" to WidgetColors.orangeBadge
        "wanted" -> "\uD83D\uDD0D" to WidgetColors.yellowBadge
        else -> "\uD83C\uDF3F" to WidgetColors.greenBadge
    }
    val emoji = pair.first
    val bgColor = pair.second

    Box(
        modifier = GlanceModifier
            .size(32.dp)
            .cornerRadius(8.dp)
            .background(bgColor),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = emoji,
            style = TextStyle(fontSize = 16.sp)
        )
    }
}

@Composable
private fun EmptyState() {
    Column(
        modifier = GlanceModifier
            .fillMaxWidth()
            .padding(vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = "\uD83C\uDF3D",
            style = TextStyle(fontSize = 28.sp)
        )
        Spacer(modifier = GlanceModifier.height(8.dp))
        Text(
            text = "No nearby food right now",
            style = TextStyle(
                color = WidgetColors.textSecondary,
                fontSize = 13.sp,
                textAlign = TextAlign.Center
            )
        )
        Spacer(modifier = GlanceModifier.height(4.dp))
        Text(
            text = "Check back soon!",
            style = TextStyle(
                color = WidgetColors.textTertiary,
                fontSize = 11.sp,
                textAlign = TextAlign.Center
            )
        )
    }
}

@Composable
private fun DividerLine() {
    Box(
        modifier = GlanceModifier
            .fillMaxWidth()
            .height(1.dp)
            .background(WidgetColors.divider)
    ) {}
}

// ============================================================================
// Widget Receiver
// ============================================================================

/**
 * Broadcast receiver for the NearbyFoodWidget.
 * Registered in AndroidManifest.xml.
 */
class NearbyFoodWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = NearbyFoodWidget()
}

// ============================================================================
// Widget Colors
// ============================================================================

/**
 * Shared color constants for all FoodShare widgets.
 */
object WidgetColors {
    val darkBackground = ColorProvider(
        day = Color(android.graphics.Color.parseColor("#1A1A2E")),
        night = Color(android.graphics.Color.parseColor("#0F0F1A"))
    )

    val cardBackground = ColorProvider(
        day = Color(android.graphics.Color.parseColor("#232342")),
        night = Color(android.graphics.Color.parseColor("#1A1A30"))
    )

    val textPrimary = ColorProvider(
        day = Color(android.graphics.Color.parseColor("#FFFFFF")),
        night = Color(android.graphics.Color.parseColor("#F0F0F0"))
    )

    val textSecondary = ColorProvider(
        day = Color(android.graphics.Color.parseColor("#B0B0C0")),
        night = Color(android.graphics.Color.parseColor("#9090A0"))
    )

    val textTertiary = ColorProvider(
        day = Color(android.graphics.Color.parseColor("#707088")),
        night = Color(android.graphics.Color.parseColor("#606078"))
    )

    val accent = ColorProvider(
        day = Color(android.graphics.Color.parseColor("#2ECC71")),
        night = Color(android.graphics.Color.parseColor("#27AE60"))
    )

    val divider = ColorProvider(
        day = Color(android.graphics.Color.parseColor("#2A2A48")),
        night = Color(android.graphics.Color.parseColor("#1F1F35"))
    )

    // Badge colors
    val greenBadge = ColorProvider(
        day = Color(android.graphics.Color.parseColor("#1B4332")),
        night = Color(android.graphics.Color.parseColor("#163828"))
    )

    val blueBadge = ColorProvider(
        day = Color(android.graphics.Color.parseColor("#1B3A4B")),
        night = Color(android.graphics.Color.parseColor("#152F3E"))
    )

    val purpleBadge = ColorProvider(
        day = Color(android.graphics.Color.parseColor("#2D1B4E")),
        night = Color(android.graphics.Color.parseColor("#231440"))
    )

    val orangeBadge = ColorProvider(
        day = Color(android.graphics.Color.parseColor("#4E2D1B")),
        night = Color(android.graphics.Color.parseColor("#402314"))
    )

    val yellowBadge = ColorProvider(
        day = Color(android.graphics.Color.parseColor("#4E4B1B")),
        night = Color(android.graphics.Color.parseColor("#403E14"))
    )

    // Stat card colors
    val statGreen = ColorProvider(
        day = Color(android.graphics.Color.parseColor("#2ECC71")),
        night = Color(android.graphics.Color.parseColor("#27AE60"))
    )

    val statBlue = ColorProvider(
        day = Color(android.graphics.Color.parseColor("#3498DB")),
        night = Color(android.graphics.Color.parseColor("#2980B9"))
    )

    val statPurple = ColorProvider(
        day = Color(android.graphics.Color.parseColor("#9B59B6")),
        night = Color(android.graphics.Color.parseColor("#8E44AD"))
    )

    val statOrange = ColorProvider(
        day = Color(android.graphics.Color.parseColor("#E67E22")),
        night = Color(android.graphics.Color.parseColor("#D35400"))
    )

    // Progress bar colors
    val progressBackground = ColorProvider(
        day = Color(android.graphics.Color.parseColor("#2A2A48")),
        night = Color(android.graphics.Color.parseColor("#1F1F35"))
    )

    val progressFill = ColorProvider(
        day = Color(android.graphics.Color.parseColor("#F39C12")),
        night = Color(android.graphics.Color.parseColor("#E67E22"))
    )
}

// ============================================================================
// Shared Widget Data Model
// ============================================================================

/**
 * Lightweight listing model for widget display.
 */
data class WidgetListing(
    val id: Int,
    val title: String,
    val postType: String? = null,
    val distance: String? = null,
    val timeAgo: String = "",
    val imageUrl: String? = null
)
