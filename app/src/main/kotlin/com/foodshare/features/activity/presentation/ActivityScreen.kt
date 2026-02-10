package com.foodshare.features.activity.presentation

import androidx.compose.animation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.foodshare.features.activity.domain.model.ActivityItem
import com.foodshare.features.activity.presentation.components.ActivityCard
import com.foodshare.features.activity.presentation.components.ActivitySkeletonLoader
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.Spacing

/**
 * Main Activity feed screen.
 *
 * SYNC: Mirrors Swift ActivityFeedView
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ActivityScreen(
    onNavigateToListing: (Int) -> Unit,
    onNavigateToForum: (Int) -> Unit,
    onNavigateToProfile: (String) -> Unit,
    viewModel: ActivityViewModel = hiltViewModel()
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
                        text = "Activity",
                        fontWeight = FontWeight.Bold
                    )
                }
            )
        }
    ) { paddingValues ->
        PullToRefreshBox(
            isRefreshing = uiState.isLoading && uiState.activities.isNotEmpty(),
            onRefresh = { viewModel.refresh() },
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            when {
                // Initial loading
                uiState.isLoading && uiState.activities.isEmpty() -> {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(Spacing.md)
                    ) {
                        items(6) { index ->
                            ActivitySkeletonLoader(
                                modifier = Modifier.padding(vertical = Spacing.xs)
                            )
                        }
                    }
                }

                // Empty state
                uiState.isEmpty -> {
                    EmptyActivityState()
                }

                // Error state with no data
                uiState.error != null && uiState.activities.isEmpty() -> {
                    ErrorState(
                        message = uiState.error ?: "Error loading activity",
                        onRetry = { viewModel.loadActivities() }
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
                            items = uiState.activities,
                            key = { it.id }
                        ) { activity ->
                            ActivityCard(
                                activity = activity,
                                onClick = { handleActivityClick(activity, onNavigateToListing, onNavigateToForum, onNavigateToProfile) },
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
                        if (!uiState.hasMorePages && uiState.activities.isNotEmpty()) {
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
            if (uiState.activities.isNotEmpty()) {
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

private fun handleActivityClick(
    activity: ActivityItem,
    onNavigateToListing: (Int) -> Unit,
    onNavigateToForum: (Int) -> Unit,
    onNavigateToProfile: (String) -> Unit
) {
    when {
        activity.linkedPostId != null -> onNavigateToListing(activity.linkedPostId)
        activity.linkedForumId != null -> onNavigateToForum(activity.linkedForumId)
        activity.linkedProfileId != null -> onNavigateToProfile(activity.linkedProfileId)
    }
}

@Composable
private fun EmptyActivityState() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Surface(
                shape = androidx.compose.foundation.shape.CircleShape,
                color = LiquidGlassColors.brandPink.copy(alpha = 0.1f),
                modifier = Modifier.size(100.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        Icons.Default.Notifications,
                        contentDescription = null,
                        modifier = Modifier.size(48.dp),
                        tint = LiquidGlassColors.brandPink
                    )
                }
            }
            Spacer(modifier = Modifier.height(Spacing.md))
            Text(
                text = "No Activity Yet",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(Spacing.xs))
            Text(
                text = "When there's activity in your community,\nyou'll see it here.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = androidx.compose.ui.text.style.TextAlign.Center
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
