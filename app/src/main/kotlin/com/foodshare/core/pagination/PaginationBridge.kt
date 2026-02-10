package com.foodshare.core.pagination

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

/**
 * Pagination state
 */
enum class PaginationState {
    IDLE,
    LOADING,
    LOADING_MORE,
    REFRESHING,
    ERROR,
    EXHAUSTED
}

/**
 * Load priority for lazy loading
 */
enum class LoadPriority(val value: Int) {
    LOW(0),
    NORMAL(1),
    HIGH(2),
    IMMEDIATE(3)
}

/**
 * Lazy load trigger type
 */
enum class TriggerType(val value: String) {
    THRESHOLD("threshold"),
    PERCENTAGE("percentage"),
    PREDICTIVE("predictive")
}

/**
 * Page info from API response
 */
@Serializable
data class PageInfo(
    val pageNumber: Int,
    val pageSize: Int,
    val totalItems: Int? = null,
    val totalPages: Int? = null,
    val hasNextPage: Boolean,
    val hasPreviousPage: Boolean = false,
    val cursor: String? = null
)

/**
 * Pagination configuration
 */
data class PaginationConfig(
    val pageSize: Int = 20,
    val windowSize: Int = 5,
    val prefetchThreshold: Int = 5,
    val initialLoadSize: Int? = null
) {
    companion object {
        val STANDARD = PaginationConfig()

        val LARGE_LIST = PaginationConfig(
            pageSize = 50,
            windowSize = 3,
            prefetchThreshold = 10,
            initialLoadSize = 100
        )

        val MEMORY_CONSTRAINED = PaginationConfig(
            pageSize = 10,
            windowSize = 3,
            prefetchThreshold = 3
        )
    }
}

/**
 * Lazy load trigger result
 */
@Serializable
data class TriggerResult(
    val shouldTrigger: Boolean,
    val reason: String = "",
    val priority: Int = 1,
    val suggestedPrefetchCount: Int = 0
) {
    val loadPriority: LoadPriority
        get() = LoadPriority.entries.find { it.value == priority } ?: LoadPriority.NORMAL

    companion object {
        val NO_TRIGGER = TriggerResult(shouldTrigger = false)
    }
}

/**
 * Visible range information
 */
@Serializable
data class VisibleRange(
    val startIndex: Int,
    val endIndex: Int,
    val renderStartIndex: Int,
    val renderEndIndex: Int,
    val visibleCount: Int = 0,
    val renderCount: Int = 0
)

/**
 * Scroll state for lazy loading decisions
 */
data class ScrollState(
    val firstVisibleIndex: Int,
    val lastVisibleIndex: Int,
    val totalItems: Int,
    val scrollVelocity: Double = 0.0,
    val isScrollingDown: Boolean = true
) {
    val visibleCount: Int
        get() = lastVisibleIndex - firstVisibleIndex + 1

    val scrollPercentage: Double
        get() = if (totalItems > 0) lastVisibleIndex.toDouble() / (totalItems - 1) else 0.0

    val remainingItems: Int
        get() = maxOf(0, totalItems - lastVisibleIndex - 1)
}

/**
 * Visible info from Swift
 */
@Serializable
data class VisibleInfo(
    val visibleCount: Int,
    val scrollPercentage: Double,
    val remainingItems: Int,
    val atStart: Boolean,
    val atEnd: Boolean
)

/**
 * Recycler metrics
 */
@Serializable
data class RecyclerMetrics(
    val poolHits: Int,
    val poolMisses: Int,
    val currentPoolSize: Int,
    val totalRecycled: Int,
    val hitRate: Double
)

/**
 * Pagination logic.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for pagination calculations
 * - Prefetch decisions, page calculations, virtualization are pure functions
 * - No JNI required for these stateless operations
 */
object PaginationBridge {

    /**
     * Create pagination config JSON (for debugging/logging)
     */
    fun createConfig(config: PaginationConfig): String {
        return """{"pageSize":${config.pageSize},"windowSize":${config.windowSize},"prefetchThreshold":${config.prefetchThreshold},"initialLoadSize":${config.initialLoadSize ?: 0}}"""
    }

    /**
     * Check if should prefetch based on visible index
     */
    fun shouldPrefetch(
        visibleIndex: Int,
        totalItems: Int,
        threshold: Int,
        hasMore: Boolean
    ): Boolean {
        if (!hasMore) return false
        if (totalItems == 0) return false
        val remainingItems = totalItems - visibleIndex - 1
        return remainingItems <= threshold
    }

    /**
     * Get page number for a given index (0-indexed pages)
     */
    fun pageForIndex(index: Int, pageSize: Int): Int {
        if (pageSize <= 0) return 0
        return index / pageSize
    }

    /**
     * Get index range for a page
     */
    fun rangeForPage(page: Int, pageSize: Int, totalItems: Int): IntRange {
        if (pageSize <= 0 || totalItems <= 0) return 0..0
        val start = page * pageSize
        val end = min(start + pageSize - 1, totalItems - 1)
        return if (start > end) 0..0 else start..end
    }

    /**
     * Evaluate lazy load trigger
     */
    fun evaluateTrigger(
        scrollState: ScrollState,
        hasMoreData: Boolean,
        thresholdItems: Int = 5,
        triggerType: TriggerType = TriggerType.THRESHOLD
    ): TriggerResult {
        if (!hasMoreData) {
            return TriggerResult.NO_TRIGGER
        }

        val shouldTrigger: Boolean
        val reason: String
        var priority = LoadPriority.NORMAL.value
        var suggestedPrefetchCount = 0

        when (triggerType) {
            TriggerType.THRESHOLD -> {
                // Trigger when remaining items <= threshold
                shouldTrigger = scrollState.remainingItems <= thresholdItems
                reason = if (shouldTrigger) "threshold_reached" else ""
                suggestedPrefetchCount = thresholdItems * 2
            }
            TriggerType.PERCENTAGE -> {
                // Trigger when scroll percentage > 80%
                shouldTrigger = scrollState.scrollPercentage > 0.8
                reason = if (shouldTrigger) "percentage_threshold" else ""
                suggestedPrefetchCount = (scrollState.totalItems * 0.2).toInt()
            }
            TriggerType.PREDICTIVE -> {
                // Predict based on scroll velocity
                if (scrollState.isScrollingDown && scrollState.scrollVelocity > 0) {
                    // Estimate time to reach end based on velocity
                    val itemsPerSecond = scrollState.scrollVelocity
                    val timeToEnd = if (itemsPerSecond > 0) {
                        scrollState.remainingItems / itemsPerSecond
                    } else Double.MAX_VALUE

                    // Trigger if we'll reach end in less than 2 seconds
                    shouldTrigger = timeToEnd < 2.0
                    reason = if (shouldTrigger) "predictive_scroll" else ""
                    priority = if (timeToEnd < 1.0) LoadPriority.HIGH.value else LoadPriority.NORMAL.value
                    suggestedPrefetchCount = (itemsPerSecond * 3).toInt().coerceAtLeast(thresholdItems)
                } else {
                    // Fall back to threshold when not scrolling down
                    shouldTrigger = scrollState.remainingItems <= thresholdItems
                    reason = if (shouldTrigger) "threshold_fallback" else ""
                }
            }
        }

        return TriggerResult(
            shouldTrigger = shouldTrigger,
            reason = reason,
            priority = priority,
            suggestedPrefetchCount = suggestedPrefetchCount
        )
    }

    /**
     * Get visible info for scroll state
     */
    fun getVisibleInfo(
        firstVisibleIndex: Int,
        lastVisibleIndex: Int,
        totalItems: Int
    ): VisibleInfo {
        if (totalItems == 0) {
            return VisibleInfo(
                visibleCount = 0,
                scrollPercentage = 0.0,
                remainingItems = 0,
                atStart = true,
                atEnd = true
            )
        }

        val visibleCount = lastVisibleIndex - firstVisibleIndex + 1
        val scrollPercentage = if (totalItems > 1) {
            lastVisibleIndex.toDouble() / (totalItems - 1)
        } else 0.0
        val remainingItems = max(0, totalItems - lastVisibleIndex - 1)

        return VisibleInfo(
            visibleCount = visibleCount,
            scrollPercentage = scrollPercentage,
            remainingItems = remainingItems,
            atStart = firstVisibleIndex == 0,
            atEnd = lastVisibleIndex >= totalItems - 1
        )
    }

    /**
     * Calculate visible range for virtualization
     */
    fun calculateVisibleRange(
        scrollOffset: Double,
        viewportHeight: Double,
        totalItems: Int,
        estimatedItemHeight: Double = 100.0,
        overscanCount: Int = 5
    ): VisibleRange {
        if (totalItems == 0 || estimatedItemHeight <= 0) {
            return VisibleRange(
                startIndex = 0,
                endIndex = 0,
                renderStartIndex = 0,
                renderEndIndex = 0,
                visibleCount = 0,
                renderCount = 0
            )
        }

        // Calculate visible range
        val startIndex = max(0, floor(scrollOffset / estimatedItemHeight).toInt())
        val visibleCount = ceil(viewportHeight / estimatedItemHeight).toInt()
        val endIndex = min(totalItems - 1, startIndex + visibleCount)

        // Calculate render range with overscan
        val renderStartIndex = max(0, startIndex - overscanCount)
        val renderEndIndex = min(totalItems - 1, endIndex + overscanCount)
        val renderCount = renderEndIndex - renderStartIndex + 1

        return VisibleRange(
            startIndex = startIndex,
            endIndex = endIndex,
            renderStartIndex = renderStartIndex,
            renderEndIndex = renderEndIndex,
            visibleCount = endIndex - startIndex + 1,
            renderCount = renderCount
        )
    }

    /**
     * Get recycler metrics
     */
    fun getRecyclerMetrics(
        poolHits: Int,
        poolMisses: Int,
        currentPoolSize: Int,
        totalRecycled: Int
    ): RecyclerMetrics {
        val hitRate = if (poolHits + poolMisses > 0) {
            poolHits.toDouble() / (poolHits + poolMisses)
        } else 0.0

        return RecyclerMetrics(
            poolHits = poolHits,
            poolMisses = poolMisses,
            currentPoolSize = currentPoolSize,
            totalRecycled = totalRecycled,
            hitRate = hitRate
        )
    }
}

/**
 * Generic paginator for managing paginated data
 */
class Paginator<T>(
    private val config: PaginationConfig = PaginationConfig.STANDARD
) {
    private val _state = MutableStateFlow(PaginationState.IDLE)
    val state: StateFlow<PaginationState> = _state.asStateFlow()

    private val _items = MutableStateFlow<List<T>>(emptyList())
    val items: StateFlow<List<T>> = _items.asStateFlow()

    private val _pageInfo = MutableStateFlow<PageInfo?>(null)
    val pageInfo: StateFlow<PageInfo?> = _pageInfo.asStateFlow()

    private var currentPage = 0

    val canLoadMore: Boolean
        get() = _state.value != PaginationState.LOADING &&
                _state.value != PaginationState.LOADING_MORE &&
                _pageInfo.value?.hasNextPage != false

    /**
     * Load initial data
     */
    suspend fun loadInitial(loader: suspend () -> Pair<List<T>, PageInfo>) {
        if (_state.value == PaginationState.LOADING) return

        _state.value = PaginationState.LOADING

        try {
            val (newItems, info) = loader()
            _items.value = newItems
            _pageInfo.value = info
            currentPage = info.pageNumber
            _state.value = if (info.hasNextPage) PaginationState.IDLE else PaginationState.EXHAUSTED
        } catch (e: Exception) {
            _state.value = PaginationState.ERROR
        }
    }

    /**
     * Load next page
     */
    suspend fun loadNextPage(loader: suspend (Int) -> Pair<List<T>, PageInfo>) {
        if (!canLoadMore) return

        _state.value = PaginationState.LOADING_MORE

        try {
            val nextPage = currentPage + 1
            val (newItems, info) = loader(nextPage)

            _items.value = _items.value + newItems
            _pageInfo.value = info
            currentPage = nextPage
            _state.value = if (info.hasNextPage) PaginationState.IDLE else PaginationState.EXHAUSTED
        } catch (e: Exception) {
            _state.value = PaginationState.ERROR
        }
    }

    /**
     * Refresh all data
     */
    suspend fun refresh(loader: suspend () -> Pair<List<T>, PageInfo>) {
        _state.value = PaginationState.REFRESHING

        try {
            val (newItems, info) = loader()
            _items.value = newItems
            _pageInfo.value = info
            currentPage = info.pageNumber
            _state.value = if (info.hasNextPage) PaginationState.IDLE else PaginationState.EXHAUSTED
        } catch (e: Exception) {
            _state.value = PaginationState.ERROR
        }
    }

    /**
     * Reset to initial state
     */
    fun reset() {
        _items.value = emptyList()
        _pageInfo.value = null
        currentPage = 0
        _state.value = PaginationState.IDLE
    }

    /**
     * Check if should prefetch based on visible index
     */
    fun shouldPrefetch(visibleIndex: Int): Boolean {
        return PaginationBridge.shouldPrefetch(
            visibleIndex = visibleIndex,
            totalItems = _items.value.size,
            threshold = config.prefetchThreshold,
            hasMore = canLoadMore
        )
    }

    /**
     * Update a specific item
     */
    fun updateItem(predicate: (T) -> Boolean, transform: (T) -> T) {
        _items.value = _items.value.map { if (predicate(it)) transform(it) else it }
    }

    /**
     * Remove items matching predicate
     */
    fun removeItems(predicate: (T) -> Boolean) {
        _items.value = _items.value.filterNot(predicate)
    }

    /**
     * Prepend item
     */
    fun prependItem(item: T) {
        _items.value = listOf(item) + _items.value
    }
}

/**
 * Cursor-based paginator
 */
class CursorPaginator<T>(
    private val pageSize: Int = 20,
    private val prefetchThreshold: Int = 5
) {
    private val _state = MutableStateFlow(PaginationState.IDLE)
    val state: StateFlow<PaginationState> = _state.asStateFlow()

    private val _items = MutableStateFlow<List<T>>(emptyList())
    val items: StateFlow<List<T>> = _items.asStateFlow()

    private var nextCursor: String? = null

    val hasNextPage: Boolean
        get() = nextCursor != null

    val canLoadMore: Boolean
        get() = _state.value != PaginationState.LOADING &&
                _state.value != PaginationState.LOADING_MORE &&
                hasNextPage

    /**
     * Load initial data
     */
    suspend fun loadInitial(loader: suspend () -> Pair<List<T>, String?>) {
        if (_state.value == PaginationState.LOADING) return

        _state.value = PaginationState.LOADING

        try {
            val (newItems, cursor) = loader()
            _items.value = newItems
            nextCursor = cursor
            _state.value = if (cursor != null) PaginationState.IDLE else PaginationState.EXHAUSTED
        } catch (e: Exception) {
            _state.value = PaginationState.ERROR
        }
    }

    /**
     * Load more using cursor
     */
    suspend fun loadMore(loader: suspend (String) -> Pair<List<T>, String?>) {
        val cursor = nextCursor ?: return
        if (!canLoadMore) return

        _state.value = PaginationState.LOADING_MORE

        try {
            val (newItems, newCursor) = loader(cursor)
            _items.value = _items.value + newItems
            nextCursor = newCursor
            _state.value = if (newCursor != null) PaginationState.IDLE else PaginationState.EXHAUSTED
        } catch (e: Exception) {
            _state.value = PaginationState.ERROR
        }
    }

    /**
     * Refresh
     */
    suspend fun refresh(loader: suspend () -> Pair<List<T>, String?>) {
        _state.value = PaginationState.REFRESHING

        try {
            val (newItems, cursor) = loader()
            _items.value = newItems
            nextCursor = cursor
            _state.value = if (cursor != null) PaginationState.IDLE else PaginationState.EXHAUSTED
        } catch (e: Exception) {
            _state.value = PaginationState.ERROR
        }
    }

    /**
     * Reset
     */
    fun reset() {
        _items.value = emptyList()
        nextCursor = null
        _state.value = PaginationState.IDLE
    }

    /**
     * Should prefetch
     */
    fun shouldPrefetch(visibleIndex: Int): Boolean {
        return PaginationBridge.shouldPrefetch(
            visibleIndex = visibleIndex,
            totalItems = _items.value.size,
            threshold = prefetchThreshold,
            hasMore = hasNextPage
        )
    }
}
