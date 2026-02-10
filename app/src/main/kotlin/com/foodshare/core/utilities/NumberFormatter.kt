package com.foodshare.core.utilities

import java.text.DecimalFormat

/**
 * Number formatting utilities.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for number formatting
 * - No JNI required for these pure formatting operations
 */
object NumberFormatter {

    private val decimalFormat = DecimalFormat("#.#")

    /**
     * Format a number in compact form (e.g., 1.2K, 3.5M).
     *
     * @param number The number to format
     * @return Compact string representation
     */
    fun formatCompact(number: Long): String {
        return when {
            number < 0 -> "-${formatCompact(-number)}"
            number < 1000 -> number.toString()
            number < 10_000 -> "${decimalFormat.format(number / 1000.0)}K"
            number < 1_000_000 -> "${number / 1000}K"
            number < 10_000_000 -> "${decimalFormat.format(number / 1_000_000.0)}M"
            number < 1_000_000_000 -> "${number / 1_000_000}M"
            number < 10_000_000_000 -> "${decimalFormat.format(number / 1_000_000_000.0)}B"
            else -> "${number / 1_000_000_000}B"
        }
    }

    /**
     * Format a number in compact form (Int overload).
     */
    fun formatCompact(number: Int): String = formatCompact(number.toLong())

    /**
     * Format a count with optional suffix (e.g., "5 items", "1 item").
     *
     * @param count The count
     * @param singular Singular form of the noun
     * @param plural Plural form of the noun (defaults to singular + "s")
     * @return Formatted string
     */
    fun formatCount(count: Int, singular: String, plural: String = "${singular}s"): String {
        return "$count ${if (count == 1) singular else plural}"
    }

    /**
     * Format a percentage.
     *
     * @param value Value between 0 and 1
     * @param decimalPlaces Number of decimal places
     * @return Formatted percentage string
     */
    fun formatPercentage(value: Double, decimalPlaces: Int = 0): String {
        val percentage = (value * 100)
        return if (decimalPlaces == 0) {
            "${percentage.toInt()}%"
        } else {
            "%.${decimalPlaces}f%%".format(percentage)
        }
    }

    /**
     * Format a rating (e.g., "4.5").
     *
     * @param rating The rating value
     * @param maxRating Maximum possible rating (for context)
     * @return Formatted rating string
     */
    fun formatRating(rating: Double, maxRating: Double = 5.0): String {
        return decimalFormat.format(rating.coerceIn(0.0, maxRating))
    }

    /**
     * Format a price.
     *
     * @param amount Amount in smallest currency unit (e.g., cents)
     * @param currencySymbol Currency symbol
     * @param decimalPlaces Decimal places for display
     * @return Formatted price string
     */
    fun formatPrice(amount: Long, currencySymbol: String = "€", decimalPlaces: Int = 2): String {
        val value = amount / Math.pow(10.0, decimalPlaces.toDouble())
        return if (decimalPlaces > 0) {
            "$currencySymbol%.${decimalPlaces}f".format(value)
        } else {
            "$currencySymbol${value.toLong()}"
        }
    }
}

/**
 * Extension to format number compactly.
 */
val Long.compact: String
    get() = NumberFormatter.formatCompact(this)

/**
 * Extension to format Int compactly.
 */
val Int.compact: String
    get() = NumberFormatter.formatCompact(this)
