package com.foodshare.features.feed.presentation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.RestaurantMenu
import androidx.compose.material.icons.filled.SearchOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.pulltorefresh.rememberPullToRefreshState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.foodshare.features.feed.presentation.components.CategoryBar
import com.foodshare.ui.design.components.cards.GlassListingCard
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing

/**
 * Main feed screen displaying nearby food listings
 *
 * Features:
 * - Category filtering via horizontal scroll bar
 * - Pull-to-refresh
 * - Infinite scroll pagination
 * - Empty and error states
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FeedScreen(
    onNavigateToListing: (Int) -> Unit,
    onNavigateToNotifications: () -> Unit = {},
    modifier: Modifier = Modifier,
    viewModel: FeedViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()
    val pullToRefreshState = rememberPullToRefreshState()

    // Detect when we need to load more
    val shouldLoadMore by remember {
        derivedStateOf {
            val lastVisibleItem = listState.layoutInfo.visibleItemsInfo.lastOrNull()
            lastVisibleItem?.index != null &&
                lastVisibleItem.index >= listState.layoutInfo.totalItemsCount - 3
        }
    }

    LaunchedEffect(shouldLoadMore) {
        if (shouldLoadMore && uiState.hasMore && !uiState.isLoadingMore) {
            viewModel.loadMore()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Nearby",
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                },
                actions = {
                    IconButton(onClick = onNavigateToNotifications) {
                        Icon(
                            imageVector = Icons.Default.Notifications,
                            contentDescription = "Notifications",
                            tint = Color.White
                        )
                    }
                    IconButton(onClick = { viewModel.refresh() }) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = "Refresh",
                            tint = Color.White
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent
                )
            )
        },
        containerColor = Color.Transparent,
        modifier = modifier.background(brush = LiquidGlassGradients.darkAuth)
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            // Category filter bar
            CategoryBar(
                selectedCategory = uiState.selectedPostType,
                onCategorySelected = { viewModel.selectCategory(it) }
            )

            // Content
            PullToRefreshBox(
                isRefreshing = uiState.isRefreshing,
                onRefresh = { viewModel.refresh() },
                state = pullToRefreshState,
                modifier = Modifier.fillMaxSize()
            ) {
                when {
                    uiState.isLoading && uiState.listings.isEmpty() -> {
                        LoadingState()
                    }
                    uiState.showEmptyState -> {
                        EmptyState(
                            hasFilter = uiState.selectedPostType != null
                        )
                    }
                    uiState.error != null && uiState.listings.isEmpty() -> {
                        ErrorState(
                            message = uiState.error ?: "Something went wrong",
                            onRetry = { viewModel.refresh() }
                        )
                    }
                    else -> {
                        LazyColumn(
                            state = listState,
                            contentPadding = PaddingValues(
                                horizontal = Spacing.md,
                                vertical = Spacing.sm
                            ),
                            verticalArrangement = Arrangement.spacedBy(Spacing.md),
                            modifier = Modifier.fillMaxSize()
                        ) {
                            items(
                                items = uiState.listings,
                                key = { it.id }
                            ) { listing ->
                                GlassListingCard(
                                    listing = listing,
                                    onClick = { onNavigateToListing(listing.id) },
                                    isFavorite = uiState.favoriteIds.contains(listing.id),
                                    onFavoriteClick = { viewModel.toggleFavorite(listing.id) },
                                    modifier = Modifier.fillMaxWidth()
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
                                            color = LiquidGlassColors.brandPink,
                                            modifier = Modifier.size(24.dp)
                                        )
                                    }
                                }
                            }

                            // Bottom spacing
                            item {
                                Spacer(Modifier.height(Spacing.xxl))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun LoadingState() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.md)
        ) {
            CircularProgressIndicator(
                color = LiquidGlassColors.brandPink,
                modifier = Modifier.size(48.dp)
            )
            Text(
                text = "Finding food near you...",
                style = MaterialTheme.typography.bodyMedium,
                color = LiquidGlassColors.Text.secondary
            )
        }
    }
}

@Composable
private fun EmptyState(hasFilter: Boolean) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(Spacing.xl),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.md)
        ) {
            Icon(
                imageVector = if (hasFilter) Icons.Default.SearchOff else Icons.Default.RestaurantMenu,
                contentDescription = null,
                tint = LiquidGlassColors.Text.tertiary,
                modifier = Modifier.size(64.dp)
            )
            Text(
                text = if (hasFilter) "No listings found" else "No food nearby",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = LiquidGlassColors.Text.primary,
                textAlign = TextAlign.Center
            )
            Text(
                text = if (hasFilter) {
                    "Try changing your filters or check back later"
                } else {
                    "Be the first to share food in your area!"
                },
                style = MaterialTheme.typography.bodyMedium,
                color = LiquidGlassColors.Text.secondary,
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
        modifier = Modifier
            .fillMaxSize()
            .padding(Spacing.xl),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.md)
        ) {
            Text(
                text = "Oops!",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = LiquidGlassColors.Text.primary
            )
            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium,
                color = LiquidGlassColors.Text.secondary,
                textAlign = TextAlign.Center
            )
            Spacer(Modifier.height(Spacing.sm))
            androidx.compose.material3.TextButton(onClick = onRetry) {
                Text(
                    text = "Try Again",
                    color = LiquidGlassColors.brandPink,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
    }
}
