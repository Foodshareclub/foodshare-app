package com.foodshare.core.deeplink

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.net.URI
import java.net.URLDecoder
import java.net.URLEncoder

/**
 * Deep link parsing and routing logic.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for URL parsing and routing
 * - Route resolution, link building are pure functions
 * - No JNI required for these stateless operations
 *
 * Features:
 * - URL parsing (app scheme and web URLs)
 * - Route resolution
 * - Deep link building
 */
object DeepLinkBridge {

    const val SCHEME = "foodshare"
    const val WEB_HOST = "foodshare.app"

    // Route patterns for parsing
    private val routePatterns = mapOf(
        "listing" to RouteType.LISTING,
        "profile" to RouteType.PROFILE,
        "chat" to RouteType.CHAT,
        "arrangement" to RouteType.ARRANGEMENT,
        "reviews" to RouteType.REVIEWS,
        "submit-review" to RouteType.SUBMIT_REVIEW,
        "messages" to RouteType.MESSAGES,
        "search" to RouteType.SEARCH,
        "tab" to RouteType.TAB,
        "forum" to RouteType.FORUM,
        "forum-post" to RouteType.FORUM_POST,
        "settings" to RouteType.SETTINGS,
        "notifications" to RouteType.NOTIFICATIONS,
        "favorites" to RouteType.FAVORITES,
        "my-listings" to RouteType.MY_LISTINGS
    )

    // ========================================================================
    // Parsing
    // ========================================================================

    /**
     * Parse a deep link URL into route information.
     *
     * @param url Deep link URL (foodshare:// or https://foodshare.app/...)
     * @return ParsedDeepLink or null if invalid
     */
    fun parse(url: String): ParsedDeepLink? {
        if (url.isBlank()) return null

        return try {
            val normalizedUrl = normalizeUrl(url)
            val uri = URI(normalizedUrl)

            val pathSegments = uri.path?.trim('/')?.split("/") ?: emptyList()
            val routeString = pathSegments.firstOrNull() ?: ""
            val routeType = routePatterns[routeString] ?: RouteType.UNKNOWN

            val id = pathSegments.getOrNull(1)
            val params = parseQueryParams(uri.query)

            ParsedDeepLink(
                routeType = routeType,
                routeString = routeString,
                id = id,
                params = params,
                originalURL = url,
                isValid = routeType != RouteType.UNKNOWN
            )
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Parse and resolve a deep link to a navigation destination.
     *
     * @param url Deep link URL
     * @return ResolvedRoute or null if invalid
     */
    fun parseAndResolve(url: String): ResolvedRoute? {
        val parsed = parse(url) ?: return null
        return resolveRoute(parsed)
    }

    /**
     * Resolve a parsed deep link to a navigation destination.
     *
     * @param parsed ParsedDeepLink to resolve
     * @return ResolvedRoute with screen and params
     */
    fun resolveRoute(parsed: ParsedDeepLink): ResolvedRoute? {
        if (!parsed.isValid) return null

        val params = mutableMapOf<String, String>()
        params.putAll(parsed.params)
        parsed.id?.let { params["id"] = it }

        val (screen, action) = when (parsed.routeType) {
            RouteType.LISTING -> "listing_detail" to RouteAction.NAVIGATE
            RouteType.PROFILE -> "profile" to RouteAction.NAVIGATE
            RouteType.CHAT -> "conversation" to RouteAction.NAVIGATE
            RouteType.ARRANGEMENT -> "arrangement_detail" to RouteAction.NAVIGATE
            RouteType.REVIEWS -> "reviews" to RouteAction.NAVIGATE
            RouteType.SUBMIT_REVIEW -> "submit_review" to RouteAction.PRESENT
            RouteType.MESSAGES -> "messages" to RouteAction.SWITCH_TAB
            RouteType.SEARCH -> "search" to RouteAction.SWITCH_TAB
            RouteType.TAB -> (parsed.id ?: "feed") to RouteAction.SWITCH_TAB
            RouteType.FORUM -> "forum" to RouteAction.NAVIGATE
            RouteType.FORUM_POST -> "forum_post_detail" to RouteAction.NAVIGATE
            RouteType.SETTINGS -> "settings" to RouteAction.NAVIGATE
            RouteType.NOTIFICATIONS -> "notifications" to RouteAction.NAVIGATE
            RouteType.FAVORITES -> "favorites" to RouteAction.NAVIGATE
            RouteType.MY_LISTINGS -> "my_listings" to RouteAction.NAVIGATE
            RouteType.UNKNOWN -> return null
        }

        return ResolvedRoute(screen = screen, action = action, params = params)
    }

    // ========================================================================
    // Building
    // ========================================================================

    /**
     * Build a listing deep link.
     */
    fun listing(id: String): String = "$SCHEME://listing/$id"

    /**
     * Build a listing deep link with Int ID (convenience).
     */
    fun listing(id: Int): String = listing(id.toString())

    /**
     * Build a profile deep link.
     */
    fun profile(userId: String): String = "$SCHEME://profile/$userId"

    /**
     * Build a chat deep link.
     */
    fun chat(conversationId: String): String = "$SCHEME://chat/$conversationId"

    /**
     * Build a search deep link.
     */
    fun search(query: String? = null): String {
        return if (query != null) {
            "$SCHEME://search?q=${URLEncoder.encode(query, "UTF-8")}"
        } else {
            "$SCHEME://search"
        }
    }

    /**
     * Build an arrangement deep link.
     */
    fun arrangement(arrangementId: String): String = "$SCHEME://arrangement/$arrangementId"

    /**
     * Build a reviews deep link.
     */
    fun reviews(userId: String): String = "$SCHEME://reviews/$userId"

    /**
     * Build a submit review deep link.
     */
    fun submitReview(
        revieweeId: String,
        postId: String? = null,
        transactionType: String = "shared"
    ): String {
        val base = "$SCHEME://submit-review/$revieweeId"
        val params = buildList {
            postId?.let { add("postId=$it") }
            add("transactionType=$transactionType")
        }.joinToString("&")
        return "$base?$params"
    }

    /**
     * Build a messages list deep link.
     */
    fun messages(): String = "$SCHEME://messages"

    /**
     * Build a tab deep link.
     */
    fun tab(tabName: String): String = "$SCHEME://tab/$tabName"

    /**
     * Build a forum deep link.
     */
    fun forum(): String = "$SCHEME://forum"

    /**
     * Build a forum post deep link.
     */
    fun forumPost(postId: String): String = "$SCHEME://forum-post/$postId"

    /**
     * Build a settings deep link.
     */
    fun settings(): String = "$SCHEME://settings"

    /**
     * Build a notifications deep link.
     */
    fun notifications(): String = "$SCHEME://notifications"

    /**
     * Build a favorites deep link.
     */
    fun favorites(): String = "$SCHEME://favorites"

    // ========================================================================
    // Validation
    // ========================================================================

    /**
     * Check if a URL is a valid Foodshare deep link.
     */
    fun isValidDeepLink(url: String): Boolean {
        return parse(url)?.isValid == true
    }

    /**
     * Check if a URL uses the app scheme.
     */
    fun isAppScheme(url: String): Boolean {
        return url.startsWith("$SCHEME://")
    }

    /**
     * Check if a URL is a Foodshare web URL.
     */
    fun isWebUrl(url: String): Boolean {
        return url.startsWith("https://$WEB_HOST/") ||
               url.startsWith("http://$WEB_HOST/")
    }

    // ========================================================================
    // Helpers
    // ========================================================================

    /**
     * Normalize URL (convert web URLs to app scheme).
     */
    private fun normalizeUrl(url: String): String {
        return when {
            url.startsWith("$SCHEME://") -> url
            url.startsWith("https://$WEB_HOST/") -> {
                val path = url.removePrefix("https://$WEB_HOST")
                "$SCHEME:/$path"
            }
            url.startsWith("http://$WEB_HOST/") -> {
                val path = url.removePrefix("http://$WEB_HOST")
                "$SCHEME:/$path"
            }
            else -> url
        }
    }

    /**
     * Parse query string into map.
     */
    private fun parseQueryParams(query: String?): Map<String, String> {
        if (query.isNullOrBlank()) return emptyMap()

        return query.split("&")
            .mapNotNull { param ->
                val parts = param.split("=", limit = 2)
                if (parts.size == 2) {
                    val key = URLDecoder.decode(parts[0], "UTF-8")
                    val value = URLDecoder.decode(parts[1], "UTF-8")
                    key to value
                } else null
            }
            .toMap()
    }
}

// ========================================================================
// Data Classes
// ========================================================================

/**
 * Route types for deep links.
 */
@Serializable
enum class RouteType {
    @SerialName("listing") LISTING,
    @SerialName("profile") PROFILE,
    @SerialName("chat") CHAT,
    @SerialName("arrangement") ARRANGEMENT,
    @SerialName("reviews") REVIEWS,
    @SerialName("submit-review") SUBMIT_REVIEW,
    @SerialName("messages") MESSAGES,
    @SerialName("search") SEARCH,
    @SerialName("tab") TAB,
    @SerialName("forum") FORUM,
    @SerialName("forum-post") FORUM_POST,
    @SerialName("settings") SETTINGS,
    @SerialName("notifications") NOTIFICATIONS,
    @SerialName("favorites") FAVORITES,
    @SerialName("my-listings") MY_LISTINGS,
    @SerialName("unknown") UNKNOWN
}

/**
 * Parsed deep link information.
 */
@Serializable
data class ParsedDeepLink(
    val routeType: RouteType,
    val routeString: String,
    val id: String? = null,
    val params: Map<String, String> = emptyMap(),
    val originalURL: String,
    val isValid: Boolean = true
)

/**
 * Route navigation action.
 */
@Serializable
enum class RouteAction {
    @SerialName("navigate") NAVIGATE,
    @SerialName("switchTab") SWITCH_TAB,
    @SerialName("present") PRESENT,
    @SerialName("replace") REPLACE
}

/**
 * Resolved navigation route.
 */
@Serializable
data class ResolvedRoute(
    val screen: String,
    val action: RouteAction = RouteAction.NAVIGATE,
    val params: Map<String, String> = emptyMap()
) {
    /**
     * Get param value by key.
     */
    fun getParam(key: String): String? = params[key]

    /**
     * Get param as Int.
     */
    fun getIntParam(key: String): Int? = params[key]?.toIntOrNull()
}

// ========================================================================
// Extension Functions
// ========================================================================

/** Parse this string as a deep link. */
fun String.asDeepLink(): ParsedDeepLink? = DeepLinkBridge.parse(this)

/** Parse and resolve this deep link URL. */
fun String.resolveAsDeepLink(): ResolvedRoute? = DeepLinkBridge.parseAndResolve(this)

/** Check if this string is a valid Foodshare deep link. */
fun String.isValidFoodshareLink(): Boolean = DeepLinkBridge.isValidDeepLink(this)
