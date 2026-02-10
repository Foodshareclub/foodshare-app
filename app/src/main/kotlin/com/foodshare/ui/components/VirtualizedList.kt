package com.foodshare.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyItemScope
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.foodshare.core.pagination.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

/**
 * Configuration for VirtualizedList
 */
data class VirtualizedListConfig(
    val pageSize: Int = 20,
    val prefetchThreshold: Int = 5,
    val showLoadingIndicator: Boolean = true,
    val showRefreshIndicator: Boolean = true,
    val enablePullToRefresh: Boolean = true,
    val estimatedItemHeight: Float = 100f,
    val overscanCount: Int = 5
)

/**
 * A high-performance virtualized list with lazy loading support
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun <T> VirtualizedList(
    items: List<T>,
    state: PaginationState,
    onLoadMore: () -> Unit,
    onRefresh: () -> Unit,
    modifier: Modifier = Modifier,
    config: VirtualizedListConfig = VirtualizedListConfig(),
    listState: LazyListState = rememberLazyListState(),
    key: ((index: Int, item: T) -> Any)? = null,
    contentType: ((index: Int, item: T) -> Any?)? = null,
    header: @Composable (() -> Unit)? = null,
    footer: @Composable (() -> Unit)? = null,
    emptyContent: @Composable () -> Unit = { DefaultEmptyContent() },
    loadingContent: @Composable () -> Unit = { DefaultLoadingContent() },
    errorContent: @Composable (onRetry: () -> Unit) -> Unit = { DefaultErrorContent(it) },
    itemContent: @Composable LazyItemScope.(index: Int, item: T) -> Unit
) {
    // Track scroll state for lazy loading
    val shouldLoadMore by remember(items.size, state) {
        derivedStateOf {
            val lastVisibleIndex = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            val totalItems = items.size

            PaginationBridge.shouldPrefetch(
                visibleIndex = lastVisibleIndex,
                totalItems = totalItems,
                threshold = config.prefetchThreshold,
                hasMore = state != PaginationState.EXHAUSTED && state != PaginationState.LOADING_MORE
            )
        }
    }

    // Trigger load more when threshold is reached
    LaunchedEffect(shouldLoadMore) {
        if (shouldLoadMore && state == PaginationState.IDLE) {
            onLoadMore()
        }
    }

    // Pull to refresh state
    val isRefreshing = state == PaginationState.REFRESHING

    Box(modifier = modifier) {
        when {
            // Initial loading
            state == PaginationState.LOADING && items.isEmpty() -> {
                loadingContent()
            }

            // Error with no data
            state == PaginationState.ERROR && items.isEmpty() -> {
                errorContent(onRefresh)
            }

            // Empty state
            items.isEmpty() && state != PaginationState.LOADING -> {
                emptyContent()
            }

            // Content
            else -> {
                if (config.enablePullToRefresh) {
                    PullToRefreshBox(
                        isRefreshing = isRefreshing,
                        onRefresh = onRefresh
                    ) {
                        VirtualizedListContent(
                            items = items,
                            state = state,
                            listState = listState,
                            config = config,
                            key = key,
                            contentType = contentType,
                            header = header,
                            footer = footer,
                            itemContent = itemContent
                        )
                    }
                } else {
                    VirtualizedListContent(
                        items = items,
                        state = state,
                        listState = listState,
                        config = config,
                        key = key,
                        contentType = contentType,
                        header = header,
                        footer = footer,
                        itemContent = itemContent
                    )
                }
            }
        }
    }
}

@Composable
private fun <T> VirtualizedListContent(
    items: List<T>,
    state: PaginationState,
    listState: LazyListState,
    config: VirtualizedListConfig,
    key: ((index: Int, item: T) -> Any)?,
    contentType: ((index: Int, item: T) -> Any?)?,
    header: @Composable (() -> Unit)?,
    footer: @Composable (() -> Unit)?,
    itemContent: @Composable LazyItemScope.(index: Int, item: T) -> Unit
) {
    LazyColumn(
        state = listState,
        modifier = Modifier.fillMaxSize()
    ) {
        // Header
        header?.let {
            item(key = "header", contentType = "header") {
                it()
            }
        }

        // Items
        itemsIndexed(
            items = items,
            key = key,
            contentType = contentType ?: { _, _ -> null }
        ) { index: Int, item: T ->
            itemContent(index, item)
        }

        // Loading more indicator
        if (state == PaginationState.LOADING_MORE && config.showLoadingIndicator) {
            item(key = "loading_more", contentType = "loading") {
                LoadingMoreIndicator()
            }
        }

        // Footer
        footer?.let {
            item(key = "footer", contentType = "footer") {
                it()
            }
        }
    }
}

/**
 * VirtualizedList with built-in Paginator support
 */
@Composable
fun <T> VirtualizedListWithPaginator(
    paginator: Paginator<T>,
    onLoadInitial: suspend () -> Pair<List<T>, PageInfo>,
    onLoadMore: suspend (Int) -> Pair<List<T>, PageInfo>,
    modifier: Modifier = Modifier,
    config: VirtualizedListConfig = VirtualizedListConfig(),
    key: ((index: Int, item: T) -> Any)? = null,
    header: @Composable (() -> Unit)? = null,
    footer: @Composable (() -> Unit)? = null,
    emptyContent: @Composable () -> Unit = { DefaultEmptyContent() },
    itemContent: @Composable LazyItemScope.(index: Int, item: T) -> Unit
) {
    val items by paginator.items.collectAsState()
    val state by paginator.state.collectAsState()

    // Load initial data on first composition
    LaunchedEffect(Unit) {
        if (items.isEmpty() && state == PaginationState.IDLE) {
            paginator.loadInitial(onLoadInitial)
        }
    }

    VirtualizedList(
        items = items,
        state = state,
        onLoadMore = {
            CoroutineScope(Dispatchers.Main + SupervisorJob()).launch {
                paginator.loadNextPage(onLoadMore)
            }
        },
        onRefresh = {
            CoroutineScope(Dispatchers.Main + SupervisorJob()).launch {
                paginator.refresh(onLoadInitial)
            }
        },
        modifier = modifier,
        config = config,
        key = key,
        header = header,
        footer = footer,
        emptyContent = emptyContent,
        itemContent = itemContent
    )
}

/**
 * Infinite scroll effect that triggers when approaching the end of the list
 */
@Composable
fun LazyListState.OnBottomReached(
    threshold: Int = 5,
    loadMore: () -> Unit
) {
    val shouldLoadMore = remember {
        derivedStateOf {
            val lastVisibleItem = layoutInfo.visibleItemsInfo.lastOrNull() ?: return@derivedStateOf false
            lastVisibleItem.index >= layoutInfo.totalItemsCount - threshold
        }
    }

    LaunchedEffect(shouldLoadMore) {
        snapshotFlow { shouldLoadMore.value }
            .distinctUntilChanged()
            .collect { shouldLoad ->
                if (shouldLoad) {
                    loadMore()
                }
            }
    }
}

/**
 * Track scroll position for analytics/prefetch
 */
@Composable
fun LazyListState.rememberScrollState(): ScrollState {
    return remember(this) {
        derivedStateOf {
            val visibleItems = layoutInfo.visibleItemsInfo
            val firstVisible = visibleItems.firstOrNull()?.index ?: 0
            val lastVisible = visibleItems.lastOrNull()?.index ?: 0
            val total = layoutInfo.totalItemsCount

            ScrollState(
                firstVisibleIndex = firstVisible,
                lastVisibleIndex = lastVisible,
                totalItems = total,
                scrollVelocity = 0.0,  // Would need velocity tracking
                isScrollingDown = isScrollInProgress
            )
        }
    }.value
}

// ================================
// Default Content Components
// ================================

@Composable
fun DefaultEmptyContent() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = "No items found",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = "Pull down to refresh",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
            )
        }
    }
}

@Composable
fun DefaultLoadingContent() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        CircularProgressIndicator()
    }
}

@Composable
fun DefaultErrorContent(onRetry: () -> Unit) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                text = "Something went wrong",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.error
            )
            Button(onClick = onRetry) {
                Text("Retry")
            }
        }
    }
}

@Composable
fun LoadingMoreIndicator() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        contentAlignment = Alignment.Center
    ) {
        CircularProgressIndicator(
            modifier = Modifier.size(24.dp),
            strokeWidth = 2.dp
        )
    }
}

// ================================
// Shimmer Placeholder
// ================================

@Composable
fun ShimmerPlaceholder(
    modifier: Modifier = Modifier,
    count: Int = 5,
    itemHeight: Float = 100f
) {
    LazyColumn(modifier = modifier) {
        items(count) {
            ShimmerPlaceholderItem(height = itemHeight)
        }
    }
}

@Composable
fun ShimmerPlaceholderItem(
    height: Float = 100f
) {
    // Simple placeholder - in production, use a shimmer animation library
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .height(height.dp)
            .padding(horizontal = 16.dp, vertical = 8.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        shape = MaterialTheme.shapes.medium
    ) {}
}

