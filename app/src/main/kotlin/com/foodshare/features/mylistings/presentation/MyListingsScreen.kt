package com.foodshare.features.mylistings.presentation

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.foodshare.domain.model.FoodListing
import com.foodshare.ui.design.components.buttons.GlassButton
import com.foodshare.ui.design.components.buttons.GlassButtonStyle
import com.foodshare.ui.design.components.cards.CardStyle
import com.foodshare.ui.design.components.cards.GlassCard
import com.foodshare.ui.design.components.cards.GlassListingCard
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing

/**
 * My Listings screen showing user's own posts
 *
 * Features:
 * - Filter by status (All, Active, Arranged, Inactive)
 * - Swipe to delete
 * - Pull to refresh
 * - Empty state
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MyListingsScreen(
    onNavigateBack: () -> Unit,
    onNavigateToListing: (Int) -> Unit,
    onNavigateToCreate: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: MyListingsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }

    // Show error in snackbar
    LaunchedEffect(uiState.error) {
        uiState.error?.let { error ->
            snackbarHostState.showSnackbar(error)
            viewModel.clearError()
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = Color.White
                        )
                    }
                },
                title = {
                    Text(
                        text = "My Listings",
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                },
                actions = {
                    IconButton(onClick = onNavigateToCreate) {
                        Icon(
                            imageVector = Icons.Default.Add,
                            contentDescription = "Create listing",
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
            // Filter Chips
            FilterChips(
                currentFilter = uiState.filter,
                counts = FilterCounts(
                    all = uiState.totalCount,
                    active = uiState.activeCount,
                    arranged = uiState.arrangedCount,
                    inactive = uiState.inactiveCount
                ),
                onFilterSelected = viewModel::setFilter
            )

            // Content
            when {
                uiState.isLoading -> {
                    LoadingState()
                }

                uiState.showEmptyState -> {
                    EmptyState(
                        filter = uiState.filter,
                        onCreateClick = onNavigateToCreate
                    )
                }

                else -> {
                    ListingsContent(
                        listings = uiState.listings,
                        isRefreshing = uiState.isRefreshing,
                        onRefresh = viewModel::refresh,
                        onListingClick = onNavigateToListing,
                        onDeleteListing = viewModel::deleteListing
                    )
                }
            }
        }
    }
}

@Composable
private fun FilterChips(
    currentFilter: ListingFilter,
    counts: FilterCounts,
    onFilterSelected: (ListingFilter) -> Unit
) {
    LazyRow(
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        contentPadding = PaddingValues(horizontal = Spacing.md, vertical = Spacing.sm)
    ) {
        items(ListingFilter.entries) { filter ->
            val isSelected = filter == currentFilter
            val count = when (filter) {
                ListingFilter.ALL -> counts.all
                ListingFilter.ACTIVE -> counts.active
                ListingFilter.ARRANGED -> counts.arranged
                ListingFilter.INACTIVE -> counts.inactive
            }

            FilterChip(
                label = filter.displayName,
                count = count,
                isSelected = isSelected,
                onClick = { onFilterSelected(filter) }
            )
        }
    }
}

@Composable
private fun FilterChip(
    label: String,
    count: Int,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    val backgroundColor by animateColorAsState(
        targetValue = if (isSelected)
            LiquidGlassColors.brandTeal.copy(alpha = 0.2f)
        else
            LiquidGlassColors.Glass.micro,
        label = "chipBackground"
    )

    val borderColor by animateColorAsState(
        targetValue = if (isSelected)
            LiquidGlassColors.brandTeal
        else
            LiquidGlassColors.Glass.border,
        label = "chipBorder"
    )

    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(CornerRadius.medium))
            .background(backgroundColor)
            .border(
                width = if (isSelected) 2.dp else 1.dp,
                color = borderColor,
                shape = RoundedCornerShape(CornerRadius.medium)
            )
            .clickable(onClick = onClick)
            .padding(horizontal = Spacing.md, vertical = Spacing.sm),
        horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
            color = if (isSelected) LiquidGlassColors.brandTeal else Color.White.copy(alpha = 0.8f)
        )

        if (count > 0) {
            Box(
                modifier = Modifier
                    .size(20.dp)
                    .clip(CircleShape)
                    .background(
                        if (isSelected) LiquidGlassColors.brandTeal
                        else Color.White.copy(alpha = 0.2f)
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = count.toString(),
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Medium,
                    color = if (isSelected) Color.White else Color.White.copy(alpha = 0.7f)
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ListingsContent(
    listings: List<FoodListing>,
    isRefreshing: Boolean,
    onRefresh: () -> Unit,
    onListingClick: (Int) -> Unit,
    onDeleteListing: (Int) -> Unit
) {
    PullToRefreshBox(
        isRefreshing = isRefreshing,
        onRefresh = onRefresh,
        modifier = Modifier.fillMaxSize()
    ) {
        LazyColumn(
            contentPadding = PaddingValues(Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.md)
        ) {
            items(
                items = listings,
                key = { it.id }
            ) { listing ->
                SwipeableListingCard(
                    listing = listing,
                    onClick = { onListingClick(listing.id) },
                    onDelete = { onDeleteListing(listing.id) }
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SwipeableListingCard(
    listing: FoodListing,
    onClick: () -> Unit,
    onDelete: () -> Unit
) {
    val dismissState = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            if (value == SwipeToDismissBoxValue.EndToStart) {
                onDelete()
                true
            } else {
                false
            }
        }
    )

    SwipeToDismissBox(
        state = dismissState,
        backgroundContent = {
            // Delete background
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .clip(RoundedCornerShape(CornerRadius.large))
                    .background(LiquidGlassColors.error)
                    .padding(end = Spacing.lg),
                contentAlignment = Alignment.CenterEnd
            ) {
                Icon(
                    imageVector = Icons.Default.Delete,
                    contentDescription = "Delete",
                    tint = Color.White,
                    modifier = Modifier.size(24.dp)
                )
            }
        },
        enableDismissFromStartToEnd = false,
        enableDismissFromEndToStart = true
    ) {
        GlassListingCard(
            listing = listing,
            onClick = onClick,
            style = CardStyle.Standard
        )
    }
}

@Composable
private fun LoadingState() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        CircularProgressIndicator(
            color = LiquidGlassColors.brandTeal,
            modifier = Modifier.size(48.dp)
        )
    }
}

@Composable
private fun EmptyState(
    filter: ListingFilter,
    onCreateClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(Spacing.xl),
        contentAlignment = Alignment.Center
    ) {
        GlassCard {
            Column(
                modifier = Modifier.padding(Spacing.xl),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Icon(
                    imageVector = Icons.Default.Inventory2,
                    contentDescription = null,
                    tint = Color.White.copy(alpha = 0.5f),
                    modifier = Modifier.size(64.dp)
                )

                Spacer(Modifier.height(Spacing.md))

                Text(
                    text = when (filter) {
                        ListingFilter.ALL -> "No listings yet"
                        ListingFilter.ACTIVE -> "No active listings"
                        ListingFilter.ARRANGED -> "No arranged listings"
                        ListingFilter.INACTIVE -> "No inactive listings"
                    },
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Medium,
                    color = Color.White
                )

                Spacer(Modifier.height(Spacing.xs))

                Text(
                    text = when (filter) {
                        ListingFilter.ALL -> "Share something with your community"
                        ListingFilter.ACTIVE -> "Create a new listing to get started"
                        ListingFilter.ARRANGED -> "Arranged listings will appear here"
                        ListingFilter.INACTIVE -> "Inactive listings will appear here"
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White.copy(alpha = 0.6f),
                    textAlign = TextAlign.Center
                )

                if (filter == ListingFilter.ALL || filter == ListingFilter.ACTIVE) {
                    Spacer(Modifier.height(Spacing.lg))

                    GlassButton(
                        text = "Create Listing",
                        onClick = onCreateClick,
                        icon = Icons.Default.Add,
                        style = GlassButtonStyle.Primary
                    )
                }
            }
        }
    }
}

/**
 * Helper data class for filter counts
 */
private data class FilterCounts(
    val all: Int,
    val active: Int,
    val arranged: Int,
    val inactive: Int
)
