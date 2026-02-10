package com.foodshare.features.notifications.presentation

import androidx.compose.animation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.foodshare.features.notifications.domain.model.UserNotification
import com.foodshare.features.notifications.presentation.components.NotificationRow
import com.foodshare.features.notifications.presentation.components.NotificationSkeletonLoader
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.Spacing

/**
 * Main Notifications screen.
 *
 * SYNC: Mirrors Swift NotificationsView
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationsScreen(
    onNavigateToListing: (Int) -> Unit,
    onNavigateToRoom: (String) -> Unit,
    onNavigateToProfile: (String) -> Unit,
    viewModel: NotificationsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()

    // Load more when reaching the end
    val shouldLoadMore by remember {
        derivedStateOf {
            val lastVisibleItem = listState.layoutInfo.visibleItemsInfo.lastOrNull()
            val totalItems = listState.layoutInfo.totalItemsCount
            lastVisibleItem != null &&
                lastVisibleItem.index >= totalItems - 3 &&
                !uiState.isLoadingMore &&
                uiState.hasMorePages
        }
    }

    LaunchedEffect(shouldLoadMore) {
        if (shouldLoadMore) {
            viewModel.loadMore()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Notifications",
                        fontWeight = FontWeight.Bold
                    )
                },
                actions = {
                    if (uiState.unreadCount > 0) {
                        TextButton(onClick = { viewModel.markAllAsRead() }) {
                            Text(
                                text = "Mark All Read",
                                style = MaterialTheme.typography.labelMedium,
                                color = LiquidGlassColors.brandGreen
                            )
                        }
                    }
                }
            )
        }
    ) { paddingValues ->
        PullToRefreshBox(
            isRefreshing = uiState.isLoading && uiState.notifications.isNotEmpty(),
            onRefresh = { viewModel.refresh() },
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            when {
                // Initial loading
                uiState.isLoading && uiState.notifications.isEmpty() -> {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(Spacing.md)
                    ) {
                        items(6) { index ->
                            NotificationSkeletonLoader(
                                modifier = Modifier.padding(vertical = Spacing.xs)
                            )
                        }
                    }
                }

                // Empty state
                uiState.isEmpty -> {
                    EmptyNotificationsState()
                }

                // Error state with no data
                uiState.error != null && uiState.notifications.isEmpty() -> {
                    ErrorState(
                        message = uiState.error ?: "Error loading notifications",
                        onRetry = { viewModel.loadNotifications() }
                    )
                }

                // Loaded state
                else -> {
                    LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(Spacing.md)
                    ) {
                        items(
                            items = uiState.notifications,
                            key = { it.id }
                        ) { notification ->
                            NotificationRow(
                                notification = notification,
                                onClick = {
                                    viewModel.markAsRead(notification)
                                    handleNotificationClick(
                                        notification,
                                        onNavigateToListing,
                                        onNavigateToRoom,
                                        onNavigateToProfile
                                    )
                                },
                                modifier = Modifier
                                    .padding(vertical = Spacing.xs)
                                    .animateItem()
                            )
                        }

                        // Loading more indicator
                        if (uiState.isLoadingMore) {
                            item {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(Spacing.md),
                                    contentAlignment = Alignment.Center
                                ) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(24.dp),
                                        strokeWidth = 2.dp
                                    )
                                }
                            }
                        }

                        // End of list indicator
                        if (!uiState.hasMorePages && uiState.notifications.isNotEmpty()) {
                            item {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(Spacing.md),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        text = "You're all caught up!",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        // Error snackbar
        uiState.error?.let { error ->
            if (uiState.notifications.isNotEmpty()) {
                Snackbar(
                    modifier = Modifier.padding(Spacing.md),
                    action = {
                        TextButton(onClick = { viewModel.clearError() }) {
                            Text("Dismiss")
                        }
                    }
                ) {
                    Text(error)
                }
            }
        }
    }
}

private fun handleNotificationClick(
    notification: UserNotification,
    onNavigateToListing: (Int) -> Unit,
    onNavigateToRoom: (String) -> Unit,
    onNavigateToProfile: (String) -> Unit
) {
    when {
        notification.postId != null -> onNavigateToListing(notification.postId)
        notification.roomId != null -> onNavigateToRoom(notification.roomId)
        notification.actorId != null -> onNavigateToProfile(notification.actorId)
    }
}

@Composable
private fun EmptyNotificationsState() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Animated icon with gradient background
            Surface(
                shape = CircleShape,
                color = LiquidGlassColors.brandGreen.copy(alpha = 0.1f),
                modifier = Modifier.size(160.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        Icons.Default.NotificationsOff,
                        contentDescription = null,
                        modifier = Modifier.size(50.dp),
                        tint = LiquidGlassColors.brandGreen
                    )
                }
            }
            Spacer(modifier = Modifier.height(Spacing.lg))
            Text(
                text = "No Notifications",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(Spacing.xs))
            Text(
                text = "When you receive notifications about\nmessages, arrangements, or nearby food,\nthey'll appear here.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun ErrorState(
    message: String,
    onRetry: () -> Unit
) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                Icons.Default.ErrorOutline,
                contentDescription = null,
                modifier = Modifier.size(48.dp),
                tint = MaterialTheme.colorScheme.error
            )
            Spacer(modifier = Modifier.height(Spacing.md))
            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.error
            )
            Spacer(modifier = Modifier.height(Spacing.md))
            TextButton(onClick = onRetry) {
                Text("Retry")
            }
        }
    }
}
