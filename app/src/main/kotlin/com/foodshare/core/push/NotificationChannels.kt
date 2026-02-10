package com.foodshare.core.push

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationManagerCompat

/**
 * Notification channel definitions for Android O+.
 *
 * SYNC: Channel IDs should match iOS notification categories
 * where applicable for consistent backend handling.
 */
object NotificationChannels {

    /**
     * Channel for direct messages between users.
     */
    const val MESSAGES = "messages"

    /**
     * Channel for new food listings nearby.
     */
    const val NEW_FOOD = "new_food"

    /**
     * Channel for pickup arrangements and confirmations.
     */
    const val ARRANGEMENTS = "arrangements"

    /**
     * Channel for favorites updates (price changes, availability).
     */
    const val FAVORITES = "favorites"

    /**
     * Channel for reviews and rating requests.
     */
    const val REVIEWS = "reviews"

    /**
     * Channel for system notifications (updates, announcements).
     */
    const val SYSTEM = "system"

    /**
     * All channel IDs for iteration.
     */
    val ALL_CHANNELS = listOf(
        MESSAGES,
        NEW_FOOD,
        ARRANGEMENTS,
        FAVORITES,
        REVIEWS,
        SYSTEM
    )

    /**
     * Channel configuration data.
     */
    data class ChannelConfig(
        val id: String,
        val name: String,
        val description: String,
        val importance: Int,
        val showBadge: Boolean = true,
        val enableVibration: Boolean = true,
        val enableLights: Boolean = true
    )

    /**
     * Channel configurations matching iOS notification settings.
     */
    private val channelConfigs = listOf(
        ChannelConfig(
            id = MESSAGES,
            name = "Messages",
            description = "Direct messages from other users",
            importance = NotificationManager.IMPORTANCE_HIGH,
            showBadge = true,
            enableVibration = true,
            enableLights = true
        ),
        ChannelConfig(
            id = NEW_FOOD,
            name = "New Food Nearby",
            description = "Notifications when new food is posted in your area",
            importance = NotificationManager.IMPORTANCE_DEFAULT,
            showBadge = true,
            enableVibration = true,
            enableLights = true
        ),
        ChannelConfig(
            id = ARRANGEMENTS,
            name = "Pickup Arrangements",
            description = "Updates about your pickup arrangements",
            importance = NotificationManager.IMPORTANCE_HIGH,
            showBadge = true,
            enableVibration = true,
            enableLights = true
        ),
        ChannelConfig(
            id = FAVORITES,
            name = "Favorites Updates",
            description = "Updates about your favorite listings",
            importance = NotificationManager.IMPORTANCE_DEFAULT,
            showBadge = true,
            enableVibration = false,
            enableLights = true
        ),
        ChannelConfig(
            id = REVIEWS,
            name = "Reviews",
            description = "Review requests and new reviews received",
            importance = NotificationManager.IMPORTANCE_DEFAULT,
            showBadge = true,
            enableVibration = true,
            enableLights = true
        ),
        ChannelConfig(
            id = SYSTEM,
            name = "System",
            description = "App updates and announcements",
            importance = NotificationManager.IMPORTANCE_LOW,
            showBadge = false,
            enableVibration = false,
            enableLights = false
        )
    )

    /**
     * Create all notification channels.
     *
     * Call this during app initialization. Safe to call multiple times -
     * existing channels with same ID will be updated.
     */
    fun createAll(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val notificationManager = context.getSystemService(NotificationManager::class.java)

        channelConfigs.forEach { config ->
            val channel = NotificationChannel(
                config.id,
                config.name,
                config.importance
            ).apply {
                description = config.description
                setShowBadge(config.showBadge)
                enableVibration(config.enableVibration)
                enableLights(config.enableLights)

                // Set light color based on channel
                if (config.enableLights) {
                    lightColor = when (config.id) {
                        MESSAGES -> 0xFF4CAF50.toInt()      // Green
                        ARRANGEMENTS -> 0xFF2196F3.toInt() // Blue
                        NEW_FOOD -> 0xFFFF9800.toInt()     // Orange
                        REVIEWS -> 0xFFFFD700.toInt()      // Gold
                        else -> 0xFFFFFFFF.toInt()         // White
                    }
                }
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    /**
     * Check if notifications are enabled for a channel.
     */
    fun isChannelEnabled(context: Context, channelId: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return NotificationManagerCompat.from(context).areNotificationsEnabled()
        }

        val notificationManager = context.getSystemService(NotificationManager::class.java)
        val channel = notificationManager.getNotificationChannel(channelId)
        return channel?.importance != NotificationManager.IMPORTANCE_NONE
    }

    /**
     * Check if any notifications are enabled.
     */
    fun areNotificationsEnabled(context: Context): Boolean {
        return NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    /**
     * Get channel configuration by ID.
     */
    fun getConfig(channelId: String): ChannelConfig? {
        return channelConfigs.find { it.id == channelId }
    }

    /**
     * Map notification type from backend to channel ID.
     */
    fun channelForType(type: String): String {
        return when (type.lowercase()) {
            "message", "chat", "dm" -> MESSAGES
            "new_food", "new_listing", "food_nearby" -> NEW_FOOD
            "arrangement", "pickup", "confirmation" -> ARRANGEMENTS
            "favorite", "favorite_update", "watchlist" -> FAVORITES
            "review", "review_request", "rating" -> REVIEWS
            else -> SYSTEM
        }
    }
}

/**
 * Extension to get proper notification channel for a notification type.
 */
fun String.toNotificationChannel(): String = NotificationChannels.channelForType(this)
