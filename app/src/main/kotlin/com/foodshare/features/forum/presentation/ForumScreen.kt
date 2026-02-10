package com.foodshare.features.forum.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import com.foodshare.features.forum.domain.model.*
import com.foodshare.features.forum.presentation.components.ForumPostCard
import com.foodshare.features.forum.presentation.components.TrendingPostsSection
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.Spacing

/**
 * Main Forum screen.
 *
 * SYNC: This mirrors Swift ForumView
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ForumScreen(
    onNavigateToPost: (Int) -> Unit,
    onNavigateToCreatePost: () -> Unit,
    onNavigateToNotifications: () -> Unit,
    onNavigateToSavedPosts: () -> Unit,
    viewModel: ForumViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()
    var showFiltersSheet by remember { mutableStateOf(false) }

    // Load more when reaching end
    LaunchedEffect(listState) {
        snapshotFlow { listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index }
            .collect { lastIndex ->
                if (lastIndex != null && lastIndex >= uiState.posts.size - 3) {
                    viewModel.loadMorePosts()
                }
            }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Community Forum") },
                actions = {
                    // Notifications with badge
                    BadgedBox(
                        badge = {
                            if (uiState.unreadNotificationCount > 0) {
                                Badge { Text(uiState.unreadNotificationCount.toString()) }
                            }
                        }
                    ) {
                        IconButton(onClick = onNavigateToNotifications) {
                            Icon(Icons.Outlined.Notifications, contentDescription = "Notifications")
                        }
                    }

                    // Saved posts
                    IconButton(onClick = onNavigateToSavedPosts) {
                        Icon(Icons.Outlined.Bookmark, contentDescription = "Saved")
                    }

                    // Filters
                    IconButton(onClick = { showFiltersSheet = true }) {
                        Icon(Icons.Default.FilterList, contentDescription = "Filters")
                    }
                }
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = onNavigateToCreatePost,
                containerColor = LiquidGlassColors.brandPink
            ) {
                Icon(
                    Icons.Default.Add,
                    contentDescription = "Create Post",
                    tint = Color.White
                )
            }
        }
    ) { paddingValues ->
        PullToRefreshBox(
            isRefreshing = uiState.isRefreshing,
            onRefresh = { viewModel.refresh() },
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(bottom = 80.dp)
            ) {
                // Search bar
                item {
                    SearchBar(
                        query = uiState.searchQuery,
                        onQueryChange = { viewModel.search(it) },
                        modifier = Modifier.padding(horizontal = Spacing.md, vertical = Spacing.sm)
                    )
                }

                // Categories horizontal scroll
                if (uiState.categories.isNotEmpty()) {
                    item {
                        CategoryChips(
                            categories = uiState.categories,
                            selectedCategoryId = uiState.filters.categoryId,
                            onCategorySelected = { viewModel.setCategory(it) },
                            modifier = Modifier.padding(vertical = Spacing.sm)
                        )
                    }
                }

                // Trending posts section
                if (uiState.trendingPosts.isNotEmpty() && uiState.filters.categoryId == null) {
                    item {
                        TrendingPostsSection(
                            posts = uiState.trendingPosts,
                            onPostClick = onNavigateToPost,
                            modifier = Modifier.padding(vertical = Spacing.sm)
                        )
                    }
                }

                // Sort options
                item {
                    SortChips(
                        currentSort = uiState.filters.sortBy,
                        onSortSelected = { viewModel.setSortOption(it) },
                        modifier = Modifier.padding(horizontal = Spacing.md, vertical = Spacing.xs)
                    )
                }

                // Pinned posts
                if (uiState.pinnedPosts.isNotEmpty()) {
                    item {
                        Text(
                            text = "Pinned",
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(horizontal = Spacing.md, vertical = Spacing.xs)
                        )
                    }

                    items(
                        items = uiState.pinnedPosts,
                        key = { "pinned-${it.id}" }
                    ) { post ->
                        ForumPostCard(
                            post = post,
                            onClick = { onNavigateToPost(post.id) },
                            onBookmark = { viewModel.toggleBookmark(post.id) },
                            isPinned = true,
                            modifier = Modifier.padding(horizontal = Spacing.md, vertical = Spacing.xs)
                        )
                    }

                    item {
                        HorizontalDivider(modifier = Modifier.padding(vertical = Spacing.sm))
                    }
                }

                // Loading state
                if (uiState.isLoading && uiState.posts.isEmpty()) {
                    item {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(200.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            CircularProgressIndicator()
                        }
                    }
                }

                // Error state
                uiState.error?.let { error ->
                    item {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(Spacing.lg),
                            contentAlignment = Alignment.Center
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text(
                                    text = error,
                                    color = MaterialTheme.colorScheme.error
                                )
                                Spacer(modifier = Modifier.height(Spacing.sm))
                                TextButton(onClick = { viewModel.refresh() }) {
                                    Text("Retry")
                                }
                            }
                        }
                    }
                }

                // Posts list
                items(
                    items = uiState.posts,
                    key = { it.id }
                ) { post ->
                    ForumPostCard(
                        post = post,
                        onClick = { onNavigateToPost(post.id) },
                        onBookmark = { viewModel.toggleBookmark(post.id) },
                        modifier = Modifier.padding(horizontal = Spacing.md, vertical = Spacing.xs)
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
                            CircularProgressIndicator(modifier = Modifier.size(24.dp))
                        }
                    }
                }

                // Empty state
                if (!uiState.isLoading && uiState.posts.isEmpty() && uiState.error == null) {
                    item {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(200.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Icon(
                                    Icons.Outlined.Forum,
                                    contentDescription = null,
                                    modifier = Modifier.size(48.dp),
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                Spacer(modifier = Modifier.height(Spacing.sm))
                                Text(
                                    text = "No posts yet",
                                    style = MaterialTheme.typography.bodyLarge,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                Text(
                                    text = "Be the first to start a discussion!",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // Filters bottom sheet
    if (showFiltersSheet) {
        FiltersBottomSheet(
            filters = uiState.filters,
            categories = uiState.categories,
            onDismiss = { showFiltersSheet = false },
            onApply = { filters ->
                viewModel.setCategory(filters.categoryId)
                viewModel.setPostType(filters.postType)
                viewModel.setSortOption(filters.sortBy)
                showFiltersSheet = false
            }
        )
    }
}

@Composable
private fun SearchBar(
    query: String,
    onQueryChange: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    TextField(
        value = query,
        onValueChange = onQueryChange,
        modifier = modifier.fillMaxWidth(),
        placeholder = { Text("Search discussions...") },
        leadingIcon = {
            Icon(Icons.Default.Search, contentDescription = "Search")
        },
        trailingIcon = {
            if (query.isNotEmpty()) {
                IconButton(onClick = { onQueryChange("") }) {
                    Icon(Icons.Default.Clear, contentDescription = "Clear")
                }
            }
        },
        singleLine = true,
        shape = RoundedCornerShape(12.dp),
        colors = TextFieldDefaults.colors(
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent
        )
    )
}

@Composable
private fun CategoryChips(
    categories: List<ForumCategory>,
    selectedCategoryId: Int?,
    onCategorySelected: (Int?) -> Unit,
    modifier: Modifier = Modifier
) {
    LazyRow(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
        contentPadding = PaddingValues(horizontal = Spacing.md)
    ) {
        // All categories chip
        item {
            FilterChip(
                selected = selectedCategoryId == null,
                onClick = { onCategorySelected(null) },
                label = { Text("All") },
                leadingIcon = if (selectedCategoryId == null) {
                    { Icon(Icons.Default.Check, contentDescription = null, Modifier.size(18.dp)) }
                } else null
            )
        }

        items(categories) { category ->
            FilterChip(
                selected = selectedCategoryId == category.id,
                onClick = { onCategorySelected(category.id) },
                label = { Text(category.name) },
                leadingIcon = if (selectedCategoryId == category.id) {
                    { Icon(Icons.Default.Check, contentDescription = null, Modifier.size(18.dp)) }
                } else null
            )
        }
    }
}

@Composable
private fun SortChips(
    currentSort: ForumSortOption,
    onSortSelected: (ForumSortOption) -> Unit,
    modifier: Modifier = Modifier
) {
    LazyRow(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(Spacing.xs)
    ) {
        items(ForumSortOption.entries) { sortOption ->
            FilterChip(
                selected = currentSort == sortOption,
                onClick = { onSortSelected(sortOption) },
                label = { Text(sortOption.displayName) }
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FiltersBottomSheet(
    filters: ForumFilters,
    categories: List<ForumCategory>,
    onDismiss: () -> Unit,
    onApply: (ForumFilters) -> Unit
) {
    var currentFilters by remember { mutableStateOf(filters) }

    ModalBottomSheet(
        onDismissRequest = onDismiss
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.md)
        ) {
            Text(
                text = "Filters",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )

            Spacer(modifier = Modifier.height(Spacing.md))

            // Post type filter
            Text(
                text = "Post Type",
                style = MaterialTheme.typography.titleSmall
            )
            Spacer(modifier = Modifier.height(Spacing.xs))
            LazyRow(horizontalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                item {
                    FilterChip(
                        selected = currentFilters.postType == null,
                        onClick = { currentFilters = currentFilters.copy(postType = null) },
                        label = { Text("All") }
                    )
                }
                items(ForumPostType.entries) { type ->
                    FilterChip(
                        selected = currentFilters.postType == type,
                        onClick = { currentFilters = currentFilters.copy(postType = type) },
                        label = { Text(type.displayName) }
                    )
                }
            }

            Spacer(modifier = Modifier.height(Spacing.md))

            // Toggle filters
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("Show questions only")
                Switch(
                    checked = currentFilters.showQuestionsOnly,
                    onCheckedChange = {
                        currentFilters = currentFilters.copy(showQuestionsOnly = it)
                    }
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("Show unanswered only")
                Switch(
                    checked = currentFilters.showUnansweredOnly,
                    onCheckedChange = {
                        currentFilters = currentFilters.copy(showUnansweredOnly = it)
                    }
                )
            }

            Spacer(modifier = Modifier.height(Spacing.lg))

            // Apply button
            Button(
                onClick = { onApply(currentFilters) },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Apply Filters")
            }

            Spacer(modifier = Modifier.height(Spacing.md))
        }
    }
}
