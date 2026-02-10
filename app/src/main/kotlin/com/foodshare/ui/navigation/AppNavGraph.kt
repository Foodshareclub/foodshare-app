package com.foodshare.ui.navigation

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
import com.foodshare.features.settings.presentation.SettingsScreen
import com.foodshare.features.debug.TranslationTestScreen

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

    fun listingDetail(id: Int) = "listing/$id"
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
                onNavigateBack = { navController.popBackStack() }
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
