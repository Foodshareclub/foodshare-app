package com.foodshare.core.utilities

import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter as JavaDateTimeFormatter
import java.time.temporal.ChronoUnit

/**
 * Date and time formatting utilities.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for date/time formatting
 * - No JNI required for these pure formatting operations
 */
object DateTimeFormatter {

    private val isoFormatter = JavaDateTimeFormatter.ISO_INSTANT
    private val timeFormatter = JavaDateTimeFormatter.ofPattern("h:mm a")
    private val dateFormatter = JavaDateTimeFormatter.ofPattern("MMM d")
    private val dateYearFormatter = JavaDateTimeFormatter.ofPattern("MMM d, yyyy")
    private val fullDateTimeFormatter = JavaDateTimeFormatter.ofPattern("MMM d, yyyy 'at' h:mm a")

    /**
     * Format a timestamp as a relative date string (e.g., "5 minutes ago", "2 days ago").
     *
     * @param isoTimestamp ISO 8601 formatted timestamp string
     * @return Human-readable relative date string
     */
    fun formatRelativeDate(isoTimestamp: String): String {
        return try {
            val instant = parseTimestamp(isoTimestamp)
            val now = Instant.now()
            formatRelativeDate(instant, now)
        } catch (e: Exception) {
            isoTimestamp
        }
    }

    /**
     * Format a timestamp as a relative date string.
     *
     * @param timestamp The instant to format
     * @param now The current instant (defaults to now)
     * @return Human-readable relative date string
     */
    fun formatRelativeDate(timestamp: Instant, now: Instant = Instant.now()): String {
        val duration = Duration.between(timestamp, now)
        val seconds = duration.seconds
        val isInFuture = seconds < 0
        val absSeconds = kotlin.math.abs(seconds)

        // Format based on time difference
        return when {
            absSeconds < 60 -> "Just now"

            absSeconds < 3600 -> { // Less than 1 hour
                val minutes = absSeconds / 60
                val unit = if (minutes == 1L) "minute" else "minutes"
                if (isInFuture) "in $minutes $unit" else "$minutes $unit ago"
            }

            absSeconds < 86400 -> { // Less than 24 hours
                val hours = absSeconds / 3600
                val unit = if (hours == 1L) "hour" else "hours"
                if (isInFuture) "in $hours $unit" else "$hours $unit ago"
            }

            absSeconds < 172800 -> { // Less than 48 hours
                if (isInFuture) "Tomorrow" else "Yesterday"
            }

            absSeconds < 604800 -> { // Less than 7 days
                val days = absSeconds / 86400
                val unit = if (days == 1L) "day" else "days"
                if (isInFuture) "in $days $unit" else "$days $unit ago"
            }

            else -> {
                // For dates more than a week away, show the date
                val dateTime = ZonedDateTime.ofInstant(timestamp, ZoneId.systemDefault())
                val nowYear = ZonedDateTime.ofInstant(now, ZoneId.systemDefault()).year

                if (dateTime.year == nowYear) {
                    dateTime.format(dateFormatter)
                } else {
                    dateTime.format(dateYearFormatter)
                }
            }
        }
    }

    /**
     * Format a timestamp as a time string (e.g., "2:30 PM").
     *
     * @param isoTimestamp ISO 8601 formatted timestamp string
     * @return Time string in local timezone
     */
    fun formatTime(isoTimestamp: String): String {
        return try {
            val instant = parseTimestamp(isoTimestamp)
            val dateTime = ZonedDateTime.ofInstant(instant, ZoneId.systemDefault())
            dateTime.format(timeFormatter)
        } catch (e: Exception) {
            isoTimestamp
        }
    }

    /**
     * Format a timestamp as a short date string (e.g., "Jan 5").
     *
     * @param isoTimestamp ISO 8601 formatted timestamp string
     * @return Short date string
     */
    fun formatDateShort(isoTimestamp: String): String {
        return try {
            val instant = parseTimestamp(isoTimestamp)
            val dateTime = ZonedDateTime.ofInstant(instant, ZoneId.systemDefault())
            dateTime.format(dateFormatter)
        } catch (e: Exception) {
            isoTimestamp
        }
    }

    /**
     * Format a timestamp as a full date string (e.g., "Jan 5, 2026").
     *
     * @param isoTimestamp ISO 8601 formatted timestamp string
     * @return Full date string with year
     */
    fun formatDateFull(isoTimestamp: String): String {
        return try {
            val instant = parseTimestamp(isoTimestamp)
            val dateTime = ZonedDateTime.ofInstant(instant, ZoneId.systemDefault())
            dateTime.format(dateYearFormatter)
        } catch (e: Exception) {
            isoTimestamp
        }
    }

    /**
     * Format a timestamp as a full date and time string (e.g., "Jan 5, 2026 at 2:30 PM").
     *
     * @param isoTimestamp ISO 8601 formatted timestamp string
     * @return Full date and time string
     */
    fun formatDateTime(isoTimestamp: String): String {
        return try {
            val instant = parseTimestamp(isoTimestamp)
            val dateTime = ZonedDateTime.ofInstant(instant, ZoneId.systemDefault())
            dateTime.format(fullDateTimeFormatter)
        } catch (e: Exception) {
            isoTimestamp
        }
    }

    /**
     * Check if a timestamp is today.
     */
    fun isToday(isoTimestamp: String): Boolean {
        return try {
            val instant = parseTimestamp(isoTimestamp)
            val dateTime = ZonedDateTime.ofInstant(instant, ZoneId.systemDefault())
            val today = LocalDate.now(ZoneId.systemDefault())
            dateTime.toLocalDate() == today
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Check if a timestamp is yesterday.
     */
    fun isYesterday(isoTimestamp: String): Boolean {
        return try {
            val instant = parseTimestamp(isoTimestamp)
            val dateTime = ZonedDateTime.ofInstant(instant, ZoneId.systemDefault())
            val yesterday = LocalDate.now(ZoneId.systemDefault()).minusDays(1)
            dateTime.toLocalDate() == yesterday
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Parse various timestamp formats into an Instant.
     */
    private fun parseTimestamp(timestamp: String): Instant {
        // Try ISO instant format first
        return try {
            Instant.parse(timestamp)
        } catch (e: Exception) {
            // Try parsing with timezone offset
            try {
                ZonedDateTime.parse(timestamp).toInstant()
            } catch (e2: Exception) {
                // Try parsing as local date time (assume UTC)
                try {
                    LocalDateTime.parse(timestamp).atZone(ZoneId.of("UTC")).toInstant()
                } catch (e3: Exception) {
                    throw IllegalArgumentException("Cannot parse timestamp: $timestamp", e3)
                }
            }
        }
    }

    /**
     * Get the time elapsed since a timestamp in a short format.
     * For messages/chat display.
     */
    fun getTimeAgo(isoTimestamp: String): String {
        return try {
            val instant = parseTimestamp(isoTimestamp)
            val now = Instant.now()
            val duration = Duration.between(instant, now)
            val seconds = duration.seconds

            when {
                seconds < 60 -> "now"
                seconds < 3600 -> "${seconds / 60}m"
                seconds < 86400 -> "${seconds / 3600}h"
                seconds < 604800 -> "${seconds / 86400}d"
                else -> formatDateShort(isoTimestamp)
            }
        } catch (e: Exception) {
            isoTimestamp
        }
    }
}

/**
 * Extension to format ISO timestamp as relative date.
 */
val String.relativeDate: String
    get() = DateTimeFormatter.formatRelativeDate(this)

/**
 * Extension to format ISO timestamp as time.
 */
val String.formattedTime: String
    get() = DateTimeFormatter.formatTime(this)
