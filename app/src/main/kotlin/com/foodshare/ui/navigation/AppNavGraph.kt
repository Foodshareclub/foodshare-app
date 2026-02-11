package com.foodshare.ui.navigation

import android.net.Uri
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.foodshare.features.auth.presentation.AuthScreen
import com.foodshare.features.auth.presentation.AuthState
import com.foodshare.features.auth.presentation.AuthViewModel
import com.foodshare.features.auth.presentation.BiometricLockScreen
import com.foodshare.features.auth.presentation.BiometricSetupPromptScreen
import com.foodshare.features.auth.presentation.GuestUpgradePromptScreen
import com.foodshare.features.auth.presentation.MFAEnrollmentScreen
import com.foodshare.features.auth.presentation.MFAVerificationScreen
import com.foodshare.features.auth.presentation.SignInPromptScreen
import com.foodshare.features.challenges.presentation.ChallengeDetailScreen
import com.foodshare.features.challenges.presentation.ChallengesScreen
import com.foodshare.features.forum.presentation.CreateForumPostScreen
import com.foodshare.features.forum.presentation.ForumPostDetailScreen
import com.foodshare.features.forum.presentation.ForumScreen
import com.foodshare.features.forum.presentation.SavedPostsScreen
import com.foodshare.features.listing.presentation.ListingDetailScreen
import com.foodshare.features.activity.presentation.ActivityScreen
import com.foodshare.features.map.presentation.MapScreen
import com.foodshare.features.notifications.presentation.NotificationsScreen
import com.foodshare.features.onboarding.data.OnboardingPreferences
import com.foodshare.features.onboarding.presentation.OnboardingScreen
import com.foodshare.features.messaging.presentation.ConversationScreen
import com.foodshare.features.messaging.presentation.MessagesListScreen
import com.foodshare.features.mylistings.presentation.MyListingsScreen
import com.foodshare.features.reviews.presentation.SubmitReviewScreen
import com.foodshare.features.reviews.presentation.UserReviewsScreen
import com.foodshare.features.search.presentation.SearchScreen
import com.foodshare.features.settings.presentation.AppLockSettingsScreen
import com.foodshare.features.settings.presentation.BlockedUsersScreen
import com.foodshare.features.settings.presentation.DataExportScreen
import com.foodshare.features.settings.presentation.LanguagePickerScreen
import com.foodshare.features.settings.presentation.LegalDocumentScreen
import com.foodshare.features.settings.presentation.NotificationsSettingsScreen
import com.foodshare.features.settings.presentation.PrivacySettingsScreen
import com.foodshare.features.settings.presentation.SecurityScoreScreen
import com.foodshare.features.settings.presentation.SettingsScreen
import com.foodshare.features.settings.presentation.TwoFactorAuthScreen
import com.foodshare.features.debug.TranslationTestScreen
import com.foodshare.features.profile.presentation.EditProfileScreen
import com.foodshare.features.fridges.presentation.CommunityFridgesScreen
import com.foodshare.features.fridges.presentation.CommunityFridgeDetailScreen
import com.foodshare.features.insights.presentation.InsightsScreen
import com.foodshare.features.arrangement.presentation.ArrangementScreen
import com.foodshare.features.donation.presentation.DonationScreen
import com.foodshare.features.admin.presentation.AdminDashboardScreen
import com.foodshare.features.feedback.presentation.FeedbackScreen
import com.foodshare.features.reports.presentation.ReportPostSheet
import com.foodshare.features.subscription.presentation.SubscriptionScreen
import com.foodshare.features.support.presentation.SupportDonationScreen
import com.foodshare.features.support.presentation.HelpScreen
import com.foodshare.features.profile.presentation.ArrangementHistoryScreen
import com.foodshare.features.profile.presentation.BadgesDetailScreen
import com.foodshare.features.profile.presentation.InviteScreen
import com.foodshare.features.profile.presentation.NewsletterSubscriptionScreen
import com.foodshare.features.profile.presentation.EmailPreferencesScreen
import com.foodshare.features.settings.presentation.LoginSecurityScreen
import com.foodshare.features.settings.presentation.AccessibilitySettingsScreen
import com.foodshare.features.settings.presentation.SettingsBackupScreen
import com.foodshare.features.settings.presentation.AccountDeletionScreen
import com.foodshare.features.challenges.presentation.LeaderboardScreen
import com.foodshare.features.listing.presentation.ShareNowScreen

/**
 * Navigation destinations
 */
object NavRoutes {
    const val ONBOARDING = "onboarding"
    const val AUTH = "auth"
    const val MAIN = "main"
    const val FEED = "feed"
    const val CREATE = "create"
    const val PROFILE = "profile"
    const val LISTING_DETAIL = "listing/{id}"
    const val MY_LISTINGS = "my-listings"
    const val SETTINGS = "settings"

    // Messaging
    const val MESSAGES = "messages"
    const val CONVERSATION = "conversation/{roomId}"

    // Search
    const val SEARCH = "search"

    // Reviews
    const val USER_REVIEWS = "reviews/{userId}"
    const val SUBMIT_REVIEW = "submit-review/{revieweeId}?postId={postId}&transactionType={transactionType}"

    // Forum
    const val FORUM = "forum"
    const val FORUM_POST = "forum/post/{postId}"
    const val FORUM_CREATE_POST = "forum/create"
    const val FORUM_NOTIFICATIONS = "forum/notifications"
    const val FORUM_SAVED = "forum/saved"

    // Challenges
    const val CHALLENGES = "challenges"
    const val CHALLENGE_DETAIL = "challenges/{challengeId}"

    // Map
    const val MAP = "map"

    // Activity
    const val ACTIVITY = "activity"

    // Notifications
    const val NOTIFICATIONS = "notifications"

    // Debug
    const val TRANSLATION_TEST = "debug/translation-test"

    // Profile
    const val EDIT_PROFILE = "edit-profile"

    // Settings
    const val NOTIFICATION_SETTINGS = "settings/notifications"
    const val PRIVACY_SETTINGS = "settings/privacy"
    const val SECURITY_SCORE = "settings/security-score"
    const val BLOCKED_USERS = "settings/blocked-users"
    const val TWO_FACTOR_AUTH = "settings/two-factor-auth"
    const val LANGUAGE_PICKER = "settings/language"
    const val DATA_EXPORT = "settings/data-export"
    const val LEGAL_DOCUMENT = "settings/legal/{documentType}"
    const val APP_LOCK_SETTINGS = "settings/app-lock"

    // Auth Enhancement
    const val MFA_ENROLLMENT = "auth/mfa-enrollment"
    const val MFA_VERIFICATION = "auth/mfa-verification"
    const val BIOMETRIC_LOCK = "auth/biometric-lock"
    const val BIOMETRIC_SETUP = "auth/biometric-setup"
    const val SIGN_IN_PROMPT = "auth/sign-in-prompt"
    const val GUEST_UPGRADE = "auth/guest-upgrade"

    // Community Fridges
    const val COMMUNITY_FRIDGES = "community-fridges"
    const val FRIDGE_DETAIL = "community-fridges/{fridgeId}"

    // Insights
    const val INSIGHTS = "insights"

    // Arrangement & Donation
    const val ARRANGEMENT = "arrangement/{arrangementId}"
    const val CREATE_ARRANGEMENT = "create-arrangement/{listingId}/{ownerId}"
    const val DONATION = "donation"

    // Admin, Feedback, Reports, Subscription, Support
    const val ADMIN_DASHBOARD = "admin-dashboard"
    const val FEEDBACK = "feedback"
    const val REPORT_POST = "report/{postId}/{postName}"
    const val SUBSCRIPTION = "subscription"
    const val SUPPORT_DONATION = "support-donation"
    const val HELP = "help"

    // Profile sub-screens
    const val BADGES_DETAIL = "profile/badges/{userId}"
    const val ARRANGEMENT_HISTORY = "profile/arrangement-history"
    const val INVITE = "profile/invite"
    const val NEWSLETTER = "profile/newsletter"
    const val EMAIL_PREFERENCES = "profile/email-preferences"

    // Settings sub-screens (new)
    const val LOGIN_SECURITY = "settings/login-security"
    const val ACCESSIBILITY_SETTINGS = "settings/accessibility"
    const val SETTINGS_BACKUP = "settings/backup"
    const val ACCOUNT_DELETION = "settings/account-deletion"

    // Leaderboard & Share
    const val LEADERBOARD = "leaderboard"
    const val SHARE_NOW = "share-now"

    fun listingDetail(id: Int) = "listing/$id"
    fun arrangement(id: String) = "arrangement/$id"
    fun createArrangement(listingId: Int, ownerId: String) = "create-arrangement/$listingId/$ownerId"
    fun challengeDetail(challengeId: Int) = "challenges/$challengeId"
    fun forumPost(postId: Int) = "forum/post/$postId"
    fun conversation(roomId: String) = "conversation/$roomId"
    fun userReviews(userId: String) = "reviews/$userId"
    fun submitReview(
        revieweeId: String,
        postId: String? = null,
        transactionType: String = "shared"
    ): String {
        val base = "submit-review/$revieweeId"
        val params = buildList {
            postId?.let { add("postId=$it") }
            add("transactionType=$transactionType")
        }.joinToString("&")
        return "$base?$params"
    }

    fun badgesDetail(userId: String) = "profile/badges/$userId"
    fun legalDocument(documentType: String) = "settings/legal/$documentType"
    fun fridgeDetail(fridgeId: String) = "community-fridges/$fridgeId"
    fun reportPost(postId: Int, postName: String) = "report/$postId/${Uri.encode(postName)}"
}

/**
 * Main app navigation graph
 */
@Composable
fun AppNavGraph(
    navController: NavHostController = rememberNavController(),
    authViewModel: AuthViewModel = hiltViewModel(),
    onboardingPreferences: OnboardingPreferences
) {
    val uiState by authViewModel.uiState.collectAsStateWithLifecycle()
    val isAuthenticated = uiState.authState is AuthState.Authenticated
    val hasCompletedOnboarding by onboardingPreferences.hasCompletedOnboarding.collectAsState(initial = true)

    val startDestination = when {
        !hasCompletedOnboarding -> NavRoutes.ONBOARDING
        isAuthenticated -> NavRoutes.MAIN
        else -> NavRoutes.AUTH
    }

    NavHost(
        navController = navController,
        startDestination = startDestination
    ) {
        // Onboarding flow
        composable(NavRoutes.ONBOARDING) {
            OnboardingScreen(
                onOnboardingComplete = {
                    navController.navigate(NavRoutes.AUTH) {
                        popUpTo(NavRoutes.ONBOARDING) { inclusive = true }
                    }
                }
            )
        }

        // Auth flow
        composable(NavRoutes.AUTH) {
            AuthScreen(
                viewModel = authViewModel,
                onAuthenticated = {
                    navController.navigate(NavRoutes.MAIN) {
                        popUpTo(NavRoutes.AUTH) { inclusive = true }
                    }
                },
                onContinueAsGuest = {
                    navController.navigate(NavRoutes.MAIN) {
                        popUpTo(NavRoutes.AUTH) { inclusive = true }
                    }
                }
            )
        }

        // Main app (with bottom navigation)
        composable(NavRoutes.MAIN) {
            MainScreen(
                onNavigateToAuth = {
                    navController.navigate(NavRoutes.AUTH) {
                        popUpTo(NavRoutes.MAIN) { inclusive = true }
                    }
                },
                onNavigateToListing = { id ->
                    navController.navigate(NavRoutes.listingDetail(id))
                },
                onNavigateToMyListings = {
                    navController.navigate(NavRoutes.MY_LISTINGS)
                },
                onNavigateToSettings = {
                    navController.navigate(NavRoutes.SETTINGS)
                },
                onNavigateToMessages = {
                    navController.navigate(NavRoutes.MESSAGES)
                },
                onNavigateToSearch = {
                    navController.navigate(NavRoutes.SEARCH)
                },
                onNavigateToConversation = { roomId ->
                    navController.navigate(NavRoutes.conversation(roomId))
                },
                onNavigateToUserReviews = { userId ->
                    navController.navigate(NavRoutes.userReviews(userId))
                },
                onNavigateToNotifications = {
                    navController.navigate(NavRoutes.NOTIFICATIONS)
                },
                onNavigateToTranslationTest = {
                    navController.navigate(NavRoutes.TRANSLATION_TEST)
                },
                onNavigateToEditProfile = {
                    navController.navigate(NavRoutes.EDIT_PROFILE)
                },
                onNavigateToAdminDashboard = {
                    navController.navigate(NavRoutes.ADMIN_DASHBOARD)
                }
            )
        }

        // Listing detail
        composable(
            route = NavRoutes.LISTING_DETAIL,
            arguments = listOf(
                navArgument("id") { type = NavType.IntType }
            )
        ) { backStackEntry ->
            val listingId = backStackEntry.arguments?.getInt("id")
            ListingDetailScreen(
                onNavigateBack = { navController.popBackStack() },
                onContactOwner = { ownerId ->
                    // Navigate to conversation - create or get room for this post
                    navController.navigate(NavRoutes.conversation("post:$listingId:$ownerId"))
                },
                onReportPost = { postId, postName ->
                    navController.navigate(NavRoutes.reportPost(postId, postName))
                }
            )
        }

        // My Listings
        composable(NavRoutes.MY_LISTINGS) {
            MyListingsScreen(
                onNavigateBack = { navController.popBackStack() },
                onNavigateToListing = { id ->
                    navController.navigate(NavRoutes.listingDetail(id))
                },
                onNavigateToCreate = {
                    navController.navigate(NavRoutes.CREATE)
                }
            )
        }

        // Settings
        composable(NavRoutes.SETTINGS) {
            SettingsScreen(
                onNavigateBack = { navController.popBackStack() },
                onNavigateToNotifications = {
                    navController.navigate(NavRoutes.NOTIFICATION_SETTINGS)
                },
                onNavigateToPrivacy = {
                    navController.navigate(NavRoutes.PRIVACY_SETTINGS)
                },
                onNavigateToSecurityScore = {
                    navController.navigate(NavRoutes.SECURITY_SCORE)
                },
                onNavigateToBlockedUsers = {
                    navController.navigate(NavRoutes.BLOCKED_USERS)
                },
                onNavigateToTwoFactorAuth = {
                    navController.navigate(NavRoutes.TWO_FACTOR_AUTH)
                },
                onNavigateToLanguage = {
                    navController.navigate(NavRoutes.LANGUAGE_PICKER)
                },
                onNavigateToDataExport = {
                    navController.navigate(NavRoutes.DATA_EXPORT)
                },
                onNavigateToLegalDocument = { docType ->
                    navController.navigate(NavRoutes.legalDocument(docType))
                },
                onNavigateToFeedback = {
                    navController.navigate(NavRoutes.FEEDBACK)
                },
                onNavigateToSupportDonation = {
                    navController.navigate(NavRoutes.SUPPORT_DONATION)
                },
                onNavigateToSubscription = {
                    navController.navigate(NavRoutes.SUBSCRIPTION)
                },
                onNavigateToHelp = {
                    navController.navigate(NavRoutes.HELP)
                },
                onNavigateToLoginSecurity = {
                    navController.navigate(NavRoutes.LOGIN_SECURITY)
                },
                onNavigateToAccessibility = {
                    navController.navigate(NavRoutes.ACCESSIBILITY_SETTINGS)
                },
                onNavigateToBackup = {
                    navController.navigate(NavRoutes.SETTINGS_BACKUP)
                },
                onNavigateToAccountDeletion = {
                    navController.navigate(NavRoutes.ACCOUNT_DELETION)
                }
            )
        }

        // Settings sub-screens
        composable(NavRoutes.NOTIFICATION_SETTINGS) {
            NotificationsSettingsScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable(NavRoutes.PRIVACY_SETTINGS) {
            PrivacySettingsScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable(NavRoutes.SECURITY_SCORE) {
            SecurityScoreScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable(NavRoutes.BLOCKED_USERS) {
            BlockedUsersScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable(NavRoutes.TWO_FACTOR_AUTH) {
            TwoFactorAuthScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable(NavRoutes.LANGUAGE_PICKER) {
            LanguagePickerScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable(NavRoutes.DATA_EXPORT) {
            DataExportScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable(
            route = NavRoutes.LEGAL_DOCUMENT,
            arguments = listOf(
                navArgument("documentType") { type = NavType.StringType }
            )
        ) {
            LegalDocumentScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Messages list
        composable(NavRoutes.MESSAGES) {
            MessagesListScreen(
                onNavigateToConversation = { roomId ->
                    navController.navigate(NavRoutes.conversation(roomId))
                }
            )
        }

        // Conversation
        composable(
            route = NavRoutes.CONVERSATION,
            arguments = listOf(
                navArgument("roomId") { type = NavType.StringType }
            )
        ) {
            ConversationScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Search
        composable(NavRoutes.SEARCH) {
            SearchScreen(
                onNavigateBack = { navController.popBackStack() },
                onNavigateToListing = { id ->
                    navController.navigate(NavRoutes.listingDetail(id))
                }
            )
        }

        // User Reviews
        composable(
            route = NavRoutes.USER_REVIEWS,
            arguments = listOf(
                navArgument("userId") { type = NavType.StringType }
            )
        ) {
            UserReviewsScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Submit Review
        composable(
            route = NavRoutes.SUBMIT_REVIEW,
            arguments = listOf(
                navArgument("revieweeId") { type = NavType.StringType },
                navArgument("postId") {
                    type = NavType.StringType
                    nullable = true
                    defaultValue = null
                },
                navArgument("transactionType") {
                    type = NavType.StringType
                    defaultValue = "shared"
                }
            )
        ) {
            SubmitReviewScreen(
                onNavigateBack = { navController.popBackStack() },
                onReviewSubmitted = { navController.popBackStack() }
            )
        }

        // Forum
        composable(NavRoutes.FORUM) {
            ForumScreen(
                onNavigateToPost = { postId ->
                    navController.navigate(NavRoutes.forumPost(postId))
                },
                onNavigateToCreatePost = {
                    navController.navigate(NavRoutes.FORUM_CREATE_POST)
                },
                onNavigateToNotifications = {
                    navController.navigate(NavRoutes.FORUM_NOTIFICATIONS)
                },
                onNavigateToSavedPosts = {
                    navController.navigate(NavRoutes.FORUM_SAVED)
                }
            )
        }

        // Forum post detail
        composable(
            route = NavRoutes.FORUM_POST,
            arguments = listOf(
                navArgument("postId") { type = NavType.IntType }
            )
        ) {
            ForumPostDetailScreen(
                onNavigateBack = { navController.popBackStack() },
                onReportPost = { postId, postName ->
                    navController.navigate(NavRoutes.reportPost(postId, postName))
                }
            )
        }

        // Forum create post
        composable(NavRoutes.FORUM_CREATE_POST) {
            CreateForumPostScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Forum notifications - redirect to main notifications
        composable(NavRoutes.FORUM_NOTIFICATIONS) {
            NotificationsScreen(
                onNavigateToListing = { id ->
                    navController.navigate(NavRoutes.listingDetail(id))
                },
                onNavigateToRoom = { roomId ->
                    navController.navigate(NavRoutes.conversation(roomId))
                },
                onNavigateToProfile = { userId ->
                    navController.navigate(NavRoutes.userReviews(userId))
                }
            )
        }

        // Forum saved posts
        composable(NavRoutes.FORUM_SAVED) {
            SavedPostsScreen(
                onNavigateBack = { navController.popBackStack() },
                onNavigateToPost = { postId ->
                    navController.navigate(NavRoutes.forumPost(postId))
                }
            )
        }

        // Challenges
        composable(NavRoutes.CHALLENGES) {
            ChallengesScreen(
                onNavigateToChallenge = { challengeId ->
                    navController.navigate(NavRoutes.challengeDetail(challengeId))
                }
            )
        }

        // Challenge detail
        composable(
            route = NavRoutes.CHALLENGE_DETAIL,
            arguments = listOf(
                navArgument("challengeId") { type = NavType.IntType }
            )
        ) {
            ChallengeDetailScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Map
        composable(NavRoutes.MAP) {
            MapScreen(
                onNavigateToListing = { id ->
                    navController.navigate(NavRoutes.listingDetail(id))
                }
            )
        }

        // Activity
        composable(NavRoutes.ACTIVITY) {
            ActivityScreen(
                onNavigateToListing = { id ->
                    navController.navigate(NavRoutes.listingDetail(id))
                },
                onNavigateToForum = { postId ->
                    navController.navigate(NavRoutes.forumPost(postId))
                },
                onNavigateToProfile = { userId ->
                    navController.navigate(NavRoutes.userReviews(userId))
                }
            )
        }

        // Notifications
        composable(NavRoutes.NOTIFICATIONS) {
            NotificationsScreen(
                onNavigateToListing = { id ->
                    navController.navigate(NavRoutes.listingDetail(id))
                },
                onNavigateToRoom = { roomId ->
                    navController.navigate(NavRoutes.conversation(roomId))
                },
                onNavigateToProfile = { userId ->
                    navController.navigate(NavRoutes.userReviews(userId))
                }
            )
        }

        // Debug: Translation Test
        composable(NavRoutes.TRANSLATION_TEST) {
            TranslationTestScreen(
                onBack = { navController.popBackStack() }
            )
        }

        // Edit Profile
        composable(NavRoutes.EDIT_PROFILE) {
            EditProfileScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // App Lock Settings
        composable(NavRoutes.APP_LOCK_SETTINGS) {
            AppLockSettingsScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // MFA Enrollment
        composable(NavRoutes.MFA_ENROLLMENT) {
            MFAEnrollmentScreen(
                onNavigateBack = { navController.popBackStack() },
                onEnrollmentComplete = { navController.popBackStack() }
            )
        }

        // MFA Verification
        composable(NavRoutes.MFA_VERIFICATION) {
            MFAVerificationScreen(
                onVerified = {
                    navController.navigate(NavRoutes.MAIN) {
                        popUpTo(NavRoutes.AUTH) { inclusive = true }
                    }
                },
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Biometric Lock
        composable(NavRoutes.BIOMETRIC_LOCK) {
            BiometricLockScreen(
                onUnlocked = { navController.popBackStack() },
                onBiometricUnlock = {
                    // TODO: Trigger biometric authentication
                    navController.popBackStack()
                }
            )
        }

        // Biometric Setup Prompt
        composable(NavRoutes.BIOMETRIC_SETUP) {
            BiometricSetupPromptScreen(
                onEnable = {
                    // TODO: Enable biometric authentication
                    navController.popBackStack()
                },
                onSkip = { navController.popBackStack() }
            )
        }

        // Sign In Prompt
        composable(NavRoutes.SIGN_IN_PROMPT) {
            SignInPromptScreen(
                onSignIn = {
                    navController.navigate(NavRoutes.AUTH) {
                        popUpTo(NavRoutes.SIGN_IN_PROMPT) { inclusive = true }
                    }
                },
                onDismiss = { navController.popBackStack() }
            )
        }

        // Guest Upgrade Prompt
        composable(NavRoutes.GUEST_UPGRADE) {
            GuestUpgradePromptScreen(
                onCreateAccount = {
                    navController.navigate(NavRoutes.AUTH) {
                        popUpTo(NavRoutes.GUEST_UPGRADE) { inclusive = true }
                    }
                },
                onContinueAsGuest = {
                    navController.navigate(NavRoutes.MAIN) {
                        popUpTo(NavRoutes.GUEST_UPGRADE) { inclusive = true }
                    }
                }
            )
        }

        // Community Fridges
        composable(NavRoutes.COMMUNITY_FRIDGES) {
            CommunityFridgesScreen(
                onNavigateToDetail = { fridgeId ->
                    navController.navigate(NavRoutes.fridgeDetail(fridgeId.toString()))
                },
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Fridge Detail
        composable(
            route = NavRoutes.FRIDGE_DETAIL,
            arguments = listOf(
                navArgument("fridgeId") { type = NavType.StringType }
            )
        ) {
            CommunityFridgeDetailScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Insights
        composable(NavRoutes.INSIGHTS) {
            InsightsScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Arrangement (view existing)
        composable(
            route = NavRoutes.ARRANGEMENT,
            arguments = listOf(
                navArgument("arrangementId") { type = NavType.StringType }
            )
        ) {
            ArrangementScreen(
                onNavigateBack = { navController.popBackStack() },
                onNavigateToReview = { listingId ->
                    navController.navigate(
                        NavRoutes.submitReview(
                            revieweeId = it.arguments?.getString("arrangementId") ?: "",
                            postId = listingId.toString()
                        )
                    )
                }
            )
        }

        // Create Arrangement
        composable(
            route = NavRoutes.CREATE_ARRANGEMENT,
            arguments = listOf(
                navArgument("listingId") { type = NavType.IntType },
                navArgument("ownerId") { type = NavType.StringType }
            )
        ) {
            ArrangementScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Donation
        composable(NavRoutes.DONATION) {
            DonationScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Admin Dashboard
        composable(NavRoutes.ADMIN_DASHBOARD) {
            AdminDashboardScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Feedback
        composable(NavRoutes.FEEDBACK) {
            FeedbackScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Report Post
        composable(
            route = NavRoutes.REPORT_POST,
            arguments = listOf(
                navArgument("postId") { type = NavType.IntType },
                navArgument("postName") { type = NavType.StringType }
            )
        ) {
            ReportPostSheet(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Subscription
        composable(NavRoutes.SUBSCRIPTION) {
            SubscriptionScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Support Donation (Ko-fi)
        composable(NavRoutes.SUPPORT_DONATION) {
            SupportDonationScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Help Center
        composable(NavRoutes.HELP) {
            HelpScreen(
                onNavigateBack = { navController.popBackStack() },
                onNavigateToLegalDocument = { docType ->
                    navController.navigate(NavRoutes.legalDocument(docType))
                }
            )
        }

        // ============================================================
        // Profile Sub-Screens
        // ============================================================

        // Badges Detail
        composable(
            route = NavRoutes.BADGES_DETAIL,
            arguments = listOf(
                navArgument("userId") { type = NavType.StringType }
            )
        ) {
            BadgesDetailScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Arrangement History
        composable(NavRoutes.ARRANGEMENT_HISTORY) {
            ArrangementHistoryScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Invite / Referral
        composable(NavRoutes.INVITE) {
            InviteScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Newsletter Subscription
        composable(NavRoutes.NEWSLETTER) {
            NewsletterSubscriptionScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Email Preferences
        composable(NavRoutes.EMAIL_PREFERENCES) {
            EmailPreferencesScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // ============================================================
        // Settings Sub-Screens (New)
        // ============================================================

        // Login & Security
        composable(NavRoutes.LOGIN_SECURITY) {
            LoginSecurityScreen(
                onNavigateBack = { navController.popBackStack() },
                onNavigateToMfaEnrollment = { navController.navigate(NavRoutes.MFA_ENROLLMENT) }
            )
        }

        // Accessibility Settings
        composable(NavRoutes.ACCESSIBILITY_SETTINGS) {
            AccessibilitySettingsScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Settings Backup
        composable(NavRoutes.SETTINGS_BACKUP) {
            SettingsBackupScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Account Deletion
        composable(NavRoutes.ACCOUNT_DELETION) {
            AccountDeletionScreen(
                onNavigateBack = { navController.popBackStack() },
                onAccountDeleted = {
                    navController.navigate(NavRoutes.AUTH) {
                        popUpTo(0) { inclusive = true }
                    }
                }
            )
        }

        // ============================================================
        // Leaderboard & Share
        // ============================================================

        // Leaderboard
        composable(NavRoutes.LEADERBOARD) {
            LeaderboardScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Share Now
        composable(NavRoutes.SHARE_NOW) {
            ShareNowScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }
    }
}

/**
 * Placeholder screen for unimplemented features
 */
@Composable
private fun PlaceholderScreen(title: String) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.headlineMedium
        )
    }
}
