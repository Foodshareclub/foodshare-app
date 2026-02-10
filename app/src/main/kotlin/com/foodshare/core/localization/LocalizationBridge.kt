package com.foodshare.core.localization

import com.foodshare.swift.generated.DistanceFormatter as SwiftDistanceFormatter
import com.foodshare.swift.generated.RelativeDateFormatter as SwiftRelativeDateFormatter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Bridge for localization and formatting.
 *
 * Architecture (Frameo pattern):
 * - Uses swift-java generated formatters (DistanceFormatter, RelativeDateFormatter)
 * - String lookups use local Kotlin implementation (Android resources)
 * - Formatting matches iOS via shared Swift formatters
 *
 * Benefits:
 * - Consistent formatting across iOS and Android
 * - No manual JNI code required
 * - Local string management for Android's resource system
 */
object LocalizationBridge {

    // String lookup storage - populated from Android resources or defaults
    private val strings = mutableMapOf<String, String>()
    private val plurals = mutableMapOf<String, (Int) -> String>()

    private var currentLocale: String = "en"

    init {
        initializeDefaultStrings()
    }

    // ========================================================================
    // String Keys
    // ========================================================================

    /** Well-known string keys for type safety. */
    object Keys {
        // Errors
        const val ERROR_GENERIC = "error.generic"
        const val ERROR_NETWORK = "error.network"
        const val ERROR_TIMEOUT = "error.timeout"
        const val ERROR_NOT_FOUND = "error.not_found"
        const val ERROR_SERVER = "error.server"
        const val ERROR_UNAUTHORIZED = "error.unauthorized"
        const val ERROR_RATE_LIMIT = "error.rate_limit"

        // Auth
        const val AUTH_WELCOME = "auth.welcome"
        const val AUTH_SIGN_IN_PROMPT = "auth.sign_in_prompt"
        const val AUTH_SIGN_UP_PROMPT = "auth.sign_up_prompt"
        const val AUTH_INVALID_CREDENTIALS = "auth.invalid_credentials"
        const val AUTH_EMAIL_NOT_CONFIRMED = "auth.email_not_confirmed"
        const val AUTH_ACCOUNT_EXISTS = "auth.account_exists"
        const val AUTH_SESSION_EXPIRED = "auth.session_expired"

        // Listings
        const val LISTING_CREATED = "listing.created"
        const val LISTING_UPDATED = "listing.updated"
        const val LISTING_DELETED = "listing.deleted"
        const val LISTING_EXPIRES_SOON = "listing.expires_soon"
        const val LISTING_EXPIRED = "listing.expired"

        // Reviews
        const val REVIEW_SUBMITTED = "review.submitted"
        const val REVIEW_THANK_YOU = "review.thank_you"

        // Chat
        const val CHAT_NEW_MESSAGE = "chat.new_message"
        const val CHAT_TYPING = "chat.typing"

        // Empty states
        const val EMPTY_LISTINGS = "empty.listings"
        const val EMPTY_REVIEWS = "empty.reviews"
        const val EMPTY_MESSAGES = "empty.messages"
        const val EMPTY_SEARCH = "empty.search"
        const val EMPTY_FAVORITES = "empty.favorites"

        // Confirmations
        const val CONFIRM_DELETE = "confirm.delete"
        const val CONFIRM_LOGOUT = "confirm.logout"

        // Buttons
        const val BUTTON_SAVE = "button.save"
        const val BUTTON_CANCEL = "button.cancel"
        const val BUTTON_DELETE = "button.delete"
        const val BUTTON_RETRY = "button.retry"

        // Status
        const val STATUS_LOADING = "status.loading"
        const val STATUS_OFFLINE = "status.offline"
        const val STATUS_SYNCING = "status.syncing"

        // Favorites
        const val FAVORITE_ADDED = "favorite.added"
        const val FAVORITE_REMOVED = "favorite.removed"

        // Search
        const val SEARCH_RESULTS_COUNT = "search.results_count"
        const val SEARCH_PLACEHOLDER = "search.placeholder"
    }

    // ========================================================================
    // String Lookups
    // ========================================================================

    /**
     * Get localized string by key.
     *
     * @param key The string key
     * @return Localized string or key if not found
     */
    fun getString(key: String): String {
        return strings[key] ?: key
    }

    /**
     * Get localized string with argument substitution.
     *
     * @param key The string key
     * @param args Key-value pairs for substitution
     * @return Localized string with arguments replaced
     */
    fun getString(key: String, vararg args: Pair<String, String>): String {
        var result = getString(key)
        args.forEach { (placeholder, value) ->
            result = result.replace("{$placeholder}", value)
        }
        return result
    }

    /**
     * Get pluralized string.
     *
     * @param key The base string key
     * @param count The count for pluralization
     * @return Pluralized string
     */
    fun getPlural(key: String, count: Int): String {
        return plurals[key]?.invoke(count) ?: "$count items"
    }

    // ========================================================================
    // Formatting
    // ========================================================================

    /**
     * Format timestamp as relative time (e.g., "2 hours ago").
     * Uses Swift RelativeDateFormatter for iOS/Android consistency.
     *
     * @param timestamp Unix timestamp in milliseconds
     * @return Relative time string
     */
    fun formatRelativeTime(timestamp: Long): String {
        return try {
            // Convert timestamp to ISO date string for Swift formatter
            val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
            isoFormat.timeZone = TimeZone.getTimeZone("UTC")
            val isoDate = isoFormat.format(Date(timestamp))
            SwiftRelativeDateFormatter.format(isoDate)
        } catch (e: Exception) {
            formatRelativeTimeFallback(timestamp)
        }
    }

    /**
     * Format distance in human-readable form.
     * Uses Swift DistanceFormatter for iOS/Android consistency.
     *
     * @param meters Distance in meters
     * @param useImperial Whether to use imperial units (currently ignored, uses metric)
     * @return Formatted distance string
     */
    fun formatDistance(meters: Double, useImperial: Boolean = false): String {
        return try {
            SwiftDistanceFormatter.format(meters)
        } catch (e: Exception) {
            formatDistanceFallback(meters, useImperial)
        }
    }

    /**
     * Format quantity with unit.
     *
     * @param amount The quantity amount
     * @param unit The unit string
     * @return Formatted quantity string
     */
    fun formatQuantity(amount: Int, unit: String): String {
        return "$amount $unit"
    }

    /**
     * Truncate text with ellipsis.
     *
     * @param text Text to truncate
     * @param maxLength Maximum length
     * @param suffix Suffix to append (default "...")
     * @return Truncated text
     */
    fun truncate(text: String, maxLength: Int, suffix: String = "..."): String {
        return if (text.length <= maxLength) text else text.take(maxLength - suffix.length) + suffix
    }

    // ========================================================================
    // Locale Settings
    // ========================================================================

    /**
     * Set the current locale for localization.
     *
     * @param locale The locale string (e.g., "en", "es", "fr")
     */
    fun setLocale(locale: String) {
        currentLocale = locale
    }

    /**
     * Check if current locale is right-to-left.
     *
     * @return true if RTL language
     */
    fun isRTL(): Boolean {
        val rtlLocales = setOf("ar", "he", "fa", "ur")
        return currentLocale in rtlLocales
    }

    // ========================================================================
    // Convenience Methods
    // ========================================================================

    // Errors
    fun errorNetwork(): String = getString(Keys.ERROR_NETWORK)
    fun errorTimeout(): String = getString(Keys.ERROR_TIMEOUT)
    fun errorGeneric(): String = getString(Keys.ERROR_GENERIC)
    fun errorServer(): String = getString(Keys.ERROR_SERVER)
    fun errorUnauthorized(): String = getString(Keys.ERROR_UNAUTHORIZED)
    fun errorRateLimit(): String = getString(Keys.ERROR_RATE_LIMIT)
    fun errorNotFound(item: String): String = getString(Keys.ERROR_NOT_FOUND, "item" to item)

    // Auth
    fun welcomeUser(name: String): String = getString(Keys.AUTH_WELCOME, "name" to name)
    fun authSignInPrompt(): String = getString(Keys.AUTH_SIGN_IN_PROMPT)
    fun authSignUpPrompt(): String = getString(Keys.AUTH_SIGN_UP_PROMPT)
    fun authInvalidCredentials(): String = getString(Keys.AUTH_INVALID_CREDENTIALS)
    fun authEmailNotConfirmed(): String = getString(Keys.AUTH_EMAIL_NOT_CONFIRMED)
    fun authAccountExists(): String = getString(Keys.AUTH_ACCOUNT_EXISTS)
    fun authSessionExpired(): String = getString(Keys.AUTH_SESSION_EXPIRED)

    // Listings
    fun listingCreated(): String = getString(Keys.LISTING_CREATED)
    fun listingUpdated(): String = getString(Keys.LISTING_UPDATED)
    fun listingDeleted(): String = getString(Keys.LISTING_DELETED)
    fun listingExpiresSoon(hours: Int): String = getPlural(Keys.LISTING_EXPIRES_SOON, hours)
    fun listingExpired(): String = getString(Keys.LISTING_EXPIRED)

    // Reviews
    fun reviewSubmitted(): String = getString(Keys.REVIEW_SUBMITTED)
    fun reviewThankYou(name: String): String = getString(Keys.REVIEW_THANK_YOU, "name" to name)

    // Chat
    fun chatNewMessage(from: String): String = getString(Keys.CHAT_NEW_MESSAGE, "from" to from)
    fun chatTyping(name: String): String = getString(Keys.CHAT_TYPING, "name" to name)

    // Empty states
    fun emptyListings(): String = getString(Keys.EMPTY_LISTINGS)
    fun emptyReviews(): String = getString(Keys.EMPTY_REVIEWS)
    fun emptyMessages(): String = getString(Keys.EMPTY_MESSAGES)
    fun emptySearch(query: String): String = getString(Keys.EMPTY_SEARCH, "query" to query)
    fun emptyFavorites(): String = getString(Keys.EMPTY_FAVORITES)

    // Confirmations
    fun confirmDelete(item: String): String = getString(Keys.CONFIRM_DELETE, "item" to item)
    fun confirmLogout(): String = getString(Keys.CONFIRM_LOGOUT)

    // Buttons
    fun buttonSave(): String = getString(Keys.BUTTON_SAVE)
    fun buttonCancel(): String = getString(Keys.BUTTON_CANCEL)
    fun buttonDelete(): String = getString(Keys.BUTTON_DELETE)
    fun buttonRetry(): String = getString(Keys.BUTTON_RETRY)

    // Status
    fun statusLoading(): String = getString(Keys.STATUS_LOADING)
    fun statusOffline(): String = getString(Keys.STATUS_OFFLINE)
    fun statusSyncing(): String = getString(Keys.STATUS_SYNCING)

    // Favorites
    fun favoriteAdded(): String = getString(Keys.FAVORITE_ADDED)
    fun favoriteRemoved(): String = getString(Keys.FAVORITE_REMOVED)

    // Search
    fun searchResultsCount(count: Int): String = getPlural(Keys.SEARCH_RESULTS_COUNT, count)
    fun searchPlaceholder(): String = getString(Keys.SEARCH_PLACEHOLDER)

    // ========================================================================
    // Private Fallbacks
    // ========================================================================

    private fun formatRelativeTimeFallback(timestamp: Long): String {
        val seconds = (System.currentTimeMillis() - timestamp) / 1000
        return when {
            seconds < 60 -> "just now"
            seconds < 3600 -> "${seconds / 60} minutes ago"
            seconds < 86400 -> "${seconds / 3600} hours ago"
            seconds < 604800 -> "${seconds / 86400} days ago"
            else -> "${seconds / 604800} weeks ago"
        }
    }

    private fun formatDistanceFallback(meters: Double, useImperial: Boolean): String {
        return if (useImperial) {
            val miles = meters / 1609.34
            if (miles < 0.1) "${(meters * 3.28084).toInt()} ft"
            else String.format("%.1f mi", miles)
        } else {
            if (meters < 1000) "${meters.toInt()} m"
            else String.format("%.1f km", meters / 1000)
        }
    }

    // ========================================================================
    // String Initialization
    // ========================================================================

    private fun initializeDefaultStrings() {
        // Errors
        strings[Keys.ERROR_GENERIC] = "Something went wrong"
        strings[Keys.ERROR_NETWORK] = "Network error. Please check your connection."
        strings[Keys.ERROR_TIMEOUT] = "Request timed out. Please try again."
        strings[Keys.ERROR_NOT_FOUND] = "{item} not found"
        strings[Keys.ERROR_SERVER] = "Server error. Please try again later."
        strings[Keys.ERROR_UNAUTHORIZED] = "Please sign in to continue"
        strings[Keys.ERROR_RATE_LIMIT] = "Too many requests. Please wait a moment."

        // Auth
        strings[Keys.AUTH_WELCOME] = "Welcome, {name}!"
        strings[Keys.AUTH_SIGN_IN_PROMPT] = "Sign in to continue"
        strings[Keys.AUTH_SIGN_UP_PROMPT] = "Create an account"
        strings[Keys.AUTH_INVALID_CREDENTIALS] = "Invalid email or password"
        strings[Keys.AUTH_EMAIL_NOT_CONFIRMED] = "Please confirm your email"
        strings[Keys.AUTH_ACCOUNT_EXISTS] = "An account already exists with this email"
        strings[Keys.AUTH_SESSION_EXPIRED] = "Your session has expired. Please sign in again."

        // Listings
        strings[Keys.LISTING_CREATED] = "Listing created successfully"
        strings[Keys.LISTING_UPDATED] = "Listing updated"
        strings[Keys.LISTING_DELETED] = "Listing deleted"
        strings[Keys.LISTING_EXPIRED] = "This listing has expired"

        // Reviews
        strings[Keys.REVIEW_SUBMITTED] = "Review submitted"
        strings[Keys.REVIEW_THANK_YOU] = "Thanks for reviewing {name}!"

        // Chat
        strings[Keys.CHAT_NEW_MESSAGE] = "New message from {from}"
        strings[Keys.CHAT_TYPING] = "{name} is typing..."

        // Empty states
        strings[Keys.EMPTY_LISTINGS] = "No listings found"
        strings[Keys.EMPTY_REVIEWS] = "No reviews yet"
        strings[Keys.EMPTY_MESSAGES] = "No messages yet"
        strings[Keys.EMPTY_SEARCH] = "No results for \"{query}\""
        strings[Keys.EMPTY_FAVORITES] = "No favorites yet"

        // Confirmations
        strings[Keys.CONFIRM_DELETE] = "Delete {item}?"
        strings[Keys.CONFIRM_LOGOUT] = "Are you sure you want to sign out?"

        // Buttons
        strings[Keys.BUTTON_SAVE] = "Save"
        strings[Keys.BUTTON_CANCEL] = "Cancel"
        strings[Keys.BUTTON_DELETE] = "Delete"
        strings[Keys.BUTTON_RETRY] = "Retry"

        // Status
        strings[Keys.STATUS_LOADING] = "Loading..."
        strings[Keys.STATUS_OFFLINE] = "You're offline"
        strings[Keys.STATUS_SYNCING] = "Syncing..."

        // Favorites
        strings[Keys.FAVORITE_ADDED] = "Added to favorites"
        strings[Keys.FAVORITE_REMOVED] = "Removed from favorites"

        // Search
        strings[Keys.SEARCH_PLACEHOLDER] = "Search for food..."

        // Plurals
        plurals[Keys.LISTING_EXPIRES_SOON] = { count ->
            if (count == 1) "Expires in $count hour" else "Expires in $count hours"
        }
        plurals[Keys.SEARCH_RESULTS_COUNT] = { count ->
            if (count == 1) "$count result" else "$count results"
        }
    }
}

// ========================================================================
// Extension Functions
// ========================================================================

/** Convert timestamp to relative time string. */
fun Long.toRelativeTimeString(): String = LocalizationBridge.formatRelativeTime(this)

/** Convert distance in meters to formatted string. */
fun Double.toDistanceString(useImperial: Boolean = false): String =
    LocalizationBridge.formatDistance(this, useImperial)

/** Format quantity with unit. */
fun Int.formatWithUnit(unit: String): String = LocalizationBridge.formatQuantity(this, unit)

/** Truncate string to max length. */
fun String.truncate(maxLength: Int, suffix: String = "..."): String =
    LocalizationBridge.truncate(this, maxLength, suffix)
