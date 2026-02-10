package com.foodshare.ui.navigation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.automirrored.outlined.Chat
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.outlined.EmojiEvents
import androidx.compose.material.icons.outlined.Explore
import androidx.compose.material.icons.outlined.Forum
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.foodshare.features.challenges.presentation.ChallengesScreen
import com.foodshare.features.create.presentation.CreateListingScreen
import com.foodshare.features.feed.presentation.FeedScreen
import com.foodshare.features.forum.presentation.ForumScreen
import com.foodshare.features.messaging.presentation.MessagesListScreen
import com.foodshare.features.profile.presentation.ProfileScreen
import com.foodshare.ui.design.components.navigation.GlassTabBar
import com.foodshare.ui.design.components.navigation.GlassTabItem
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing

/**
 * Main screen with bottom navigation
 */
/**
 * Tab structure matching iOS:
 * 0 - Explore (Feed + Search)
 * 1 - Chats (Messages)
 * 2 - Challenges
 * 3 - Forum
 * 4 - Profile
 */
@Composable
fun MainScreen(
    onNavigateToAuth: () -> Unit,
    onNavigateToListing: (Int) -> Unit,
    onNavigateToMyListings: () -> Unit = {},
    onNavigateToSettings: () -> Unit = {},
    onNavigateToMessages: () -> Unit = {},
    onNavigateToSearch: () -> Unit = {},
    onNavigateToConversation: (String) -> Unit = {},
    onNavigateToUserReviews: (String) -> Unit = {},
    onNavigateToNotifications: () -> Unit = {},
    onNavigateToTranslationTest: () -> Unit = {},
    onNavigateToChallenge: (Int) -> Unit = {},
    onNavigateToForumPost: (Int) -> Unit = {}
) {
    var selectedTab by rememberSaveable { mutableIntStateOf(0) }
    var showCreateSheet by rememberSaveable { mutableIntStateOf(0) } // 0 = hidden

    // Tab items matching iOS structure
    val tabs = listOf(
        GlassTabItem(
            label = "Explore",
            icon = Icons.Outlined.Explore,
            selectedIcon = Icons.Filled.Explore
        ),
        GlassTabItem(
            label = "Chats",
            icon = Icons.AutoMirrored.Outlined.Chat,
            selectedIcon = Icons.AutoMirrored.Filled.Chat,
            badge = null // TODO: unread count
        ),
        GlassTabItem(
            label = "Challenges",
            icon = Icons.Outlined.EmojiEvents,
            selectedIcon = Icons.Filled.EmojiEvents
        ),
        GlassTabItem(
            label = "Forum",
            icon = Icons.Outlined.Forum,
            selectedIcon = Icons.Filled.Forum
        ),
        GlassTabItem(
            label = "Profile",
            icon = Icons.Outlined.Person,
            selectedIcon = Icons.Filled.Person
        )
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(brush = LiquidGlassGradients.darkAuth)
    ) {
        // Main content
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(bottom = 100.dp) // Space for tab bar
        ) {
            when (selectedTab) {
                0 -> FeedScreen(
                    onNavigateToListing = onNavigateToListing,
                    onNavigateToNotifications = onNavigateToNotifications
                )
                1 -> MessagesListScreen(
                    onNavigateToConversation = onNavigateToConversation
                )
                2 -> ChallengesScreen(
                    onNavigateToChallenge = onNavigateToChallenge
                )
                3 -> ForumScreen(
                    onNavigateToPost = onNavigateToForumPost,
                    onNavigateToCreatePost = { /* TODO */ },
                    onNavigateToNotifications = onNavigateToNotifications,
                    onNavigateToSavedPosts = { /* TODO */ }
                )
                4 -> ProfileScreen(
                    onSignOut = onNavigateToAuth,
                    onNavigateToSettings = onNavigateToSettings,
                    onNavigateToMyListings = onNavigateToMyListings,
                    onNavigateToUserReviews = onNavigateToUserReviews,
                    onNavigateToTranslationTest = onNavigateToTranslationTest
                )
            }
        }

        // Floating Action Button
        AnimatedVisibility(
            visible = true,
            enter = slideInVertically { it },
            exit = slideOutVertically { it },
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = Spacing.lg, bottom = 110.dp)
        ) {
            FloatingActionButton(
                onClick = { showCreateSheet = 1 },
                containerColor = LiquidGlassColors.brandPink,
                contentColor = Color.White,
                shape = CircleShape
            ) {
                Icon(
                    imageVector = Icons.Default.Add,
                    contentDescription = "Create Listing"
                )
            }
        }

        // Glass Tab Bar at bottom
        Box(
            modifier = Modifier.align(Alignment.BottomCenter)
        ) {
            GlassTabBar(
                tabs = tabs,
                selectedIndex = selectedTab,
                onTabSelected = { selectedTab = it }
            )
        }

        // Create listing sheet
        if (showCreateSheet == 1) {
            CreateListingScreen(
                onClose = { showCreateSheet = 0 },
                onSuccess = { showCreateSheet = 0 }
            )
        }
    }
}

