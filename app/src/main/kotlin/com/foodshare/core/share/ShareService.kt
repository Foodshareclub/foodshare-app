package com.foodshare.core.share

import android.content.Context
import android.content.Intent
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Service for sharing content from the FoodShare app.
 *
 * Handles native Android share sheet integration for all shareable content
 * types: listings, forum posts, challenges, profiles, and the app itself.
 *
 * Each share method:
 * - Creates a descriptive share text with context
 * - Includes a deep link URL (foodshare.club/...)
 * - Uses Intent.createChooser() for the system share sheet
 *
 * SYNC: Mirrors Swift ShareService
 */
@Singleton
class ShareService @Inject constructor(
    @ApplicationContext private val context: Context
) {

    companion object {
        private const val BASE_URL = "https://foodshare.club"
    }

    // ========================================================================
    // Listing
    // ========================================================================

    /**
     * Share a listing via the native share sheet.
     *
     * @param title The listing title
     * @param description The listing description (truncated to 100 chars)
     * @param listingId The listing ID for the deep link
     */
    fun shareListing(title: String, description: String, listingId: Int) {
        val shareText = buildString {
            appendLine("Check out \"$title\" on FoodShare!")
            if (description.isNotBlank()) {
                appendLine(description.take(100))
            }
            appendLine()
            appendLine("$BASE_URL/listing/$listingId")
        }
        launchShareChooser(
            text = shareText,
            subject = "FoodShare: $title",
            chooserTitle = "Share listing"
        )
    }

    /**
     * Share a listing with explicit Context parameter.
     *
     * @param context The context to use for launching the share intent
     * @param listingId The listing ID for the deep link
     * @param title The listing title
     * @param description The listing description
     */
    fun shareListing(context: Context, listingId: Int, title: String, description: String) {
        val shareText = buildString {
            appendLine("Check out \"$title\" on FoodShare!")
            if (description.isNotBlank()) {
                appendLine(description.take(100))
            }
            appendLine()
            appendLine("$BASE_URL/listing/$listingId")
        }
        launchShareChooser(
            context = context,
            text = shareText,
            subject = "FoodShare: $title",
            chooserTitle = "Share listing"
        )
    }

    // ========================================================================
    // Forum Post
    // ========================================================================

    /**
     * Share a forum post via the native share sheet.
     *
     * @param context The context to use for launching the share intent
     * @param postId The forum post ID for the deep link
     * @param title The post title
     * @param excerpt A preview excerpt of the post content (truncated to 120 chars)
     */
    fun shareForumPost(context: Context, postId: Int, title: String, excerpt: String) {
        val shareText = buildString {
            appendLine("Check out this discussion on FoodShare:")
            appendLine("\"$title\"")
            if (excerpt.isNotBlank()) {
                appendLine()
                appendLine(excerpt.take(120))
                if (excerpt.length > 120) append("...")
            }
            appendLine()
            appendLine("$BASE_URL/forum/post/$postId")
        }
        launchShareChooser(
            context = context,
            text = shareText,
            subject = "FoodShare Forum: $title",
            chooserTitle = "Share forum post"
        )
    }

    // ========================================================================
    // Challenge
    // ========================================================================

    /**
     * Share a challenge via the native share sheet.
     *
     * @param context The context to use for launching the share intent
     * @param challengeId The challenge ID for the deep link
     * @param title The challenge title
     */
    fun shareChallenge(context: Context, challengeId: Int, title: String) {
        val shareText = buildString {
            appendLine("Join this FoodShare challenge: \"$title\"")
            appendLine()
            appendLine("Can you complete it? Accept the challenge and make a difference!")
            appendLine()
            appendLine("$BASE_URL/challenge/$challengeId")
        }
        launchShareChooser(
            context = context,
            text = shareText,
            subject = "FoodShare Challenge: $title",
            chooserTitle = "Share challenge"
        )
    }

    // ========================================================================
    // Profile
    // ========================================================================

    /**
     * Share a user profile via the native share sheet.
     *
     * @param context The context to use for launching the share intent
     * @param userId The user ID for the deep link
     * @param displayName The user's display name
     */
    fun shareProfile(context: Context, userId: String, displayName: String) {
        val shareText = buildString {
            appendLine("Check out $displayName's profile on FoodShare!")
            appendLine()
            appendLine("See how they're making a difference in their community.")
            appendLine()
            appendLine("$BASE_URL/profile/$userId")
        }
        launchShareChooser(
            context = context,
            text = shareText,
            subject = "FoodShare: $displayName's Profile",
            chooserTitle = "Share profile"
        )
    }

    // ========================================================================
    // App
    // ========================================================================

    /**
     * Share the FoodShare app via the native share sheet.
     */
    fun shareApp() {
        val shareText = "Join FoodShare and help reduce food waste! Download at $BASE_URL"
        launchShareChooser(
            text = shareText,
            subject = "Join FoodShare",
            chooserTitle = "Share FoodShare"
        )
    }

    // ========================================================================
    // Private Helpers
    // ========================================================================

    /**
     * Launch the system share chooser with the given text and subject.
     */
    private fun launchShareChooser(
        text: String,
        subject: String,
        chooserTitle: String
    ) {
        doLaunchShareChooser(this.context, text, subject, chooserTitle)
    }

    /**
     * Launch the system share chooser with an explicit context.
     */
    private fun launchShareChooser(
        context: Context,
        text: String,
        subject: String,
        chooserTitle: String
    ) {
        doLaunchShareChooser(context, text, subject, chooserTitle)
    }

    private fun doLaunchShareChooser(
        ctx: Context,
        text: String,
        subject: String,
        chooserTitle: String
    ) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
            putExtra(Intent.EXTRA_SUBJECT, subject)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val chooser = Intent.createChooser(intent, chooserTitle).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        ctx.startActivity(chooser)
    }
}
