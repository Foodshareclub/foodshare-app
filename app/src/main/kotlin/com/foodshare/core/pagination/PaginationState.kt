package com.foodshare.core.pagination

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * Direction for cursor-based pagination
 */
enum class CursorDirection {
    FORWARD,  // Load newer items
    BACKWARD  // Load older items
}

/**
 * Parameters for cursor-based pagination
 */
data class CursorPaginationParams(
    val limit: Int = 20,
    val cursor: String? = null,
    val cursorColumn: String = "created_at",
    val direction: CursorDirection = CursorDirection.BACKWARD
) {
    fun next(afterCursor: String) = copy(cursor = afterCursor)

    fun previous(beforeCursor: String) = copy(
        cursor = beforeCursor,
        direction = if (direction == CursorDirection.FORWARD) CursorDirection.BACKWARD else CursorDirection.FORWARD
    )

    companion object {
        val DEFAULT = CursorPaginationParams()
    }
}

/**
 * Parameters for offset-based pagination
 */
data class PaginationParams(
    val limit: Int,
    val offset: Int
) {
    companion object {
        fun fromPage(page: Int, pageSize: Int) = PaginationParams(
            limit = pageSize,
            offset = page * pageSize
        )

        val DEFAULT = PaginationParams(limit = 20, offset = 0)
    }
}

/**
 * State for pagination UI
 */
data class PaginationUiState<T>(
    val items: List<T> = emptyList(),
    val isLoading: Boolean = false,
    val isLoadingMore: Boolean = false,
    val hasMorePages: Boolean = true,
    val hasPreviousPages: Boolean = false,
    val error: Throwable? = null
) {
    val isEmpty: Boolean get() = items.isEmpty() && !isLoading
    val canLoadMore: Boolean get() = hasMorePages && !isLoadingMore && !isLoading
    val canLoadPrevious: Boolean get() = hasPreviousPages && !isLoadingMore && !isLoading
    val totalCount: Int get() = items.size
}

/**
 * Cursor-based pagination state manager
 *
 * More efficient than offset pagination for large datasets and real-time data.
 *
 * Ported from iOS: FoodShare/Core/Utilities/Pagination.swift
 *
 * @param T Item type (must have an id property or be comparable)
 * @param pageSize Number of items per page
 * @param cursorColumn Column name used for cursor-based queries
 * @param extractCursor Function to extract cursor value from an item
 */
class CursorPaginationState<T : Any>(
    val pageSize: Int = 20,
    val cursorColumn: String = "created_at",
    private val extractCursor: (T) -> String
) {
    private val _state = MutableStateFlow(PaginationUiState<T>())
    val state: StateFlow<PaginationUiState<T>> = _state.asStateFlow()

    private var nextCursor: String? = null
    private var previousCursor: String? = null

    val items: List<T> get() = _state.value.items
    val isLoading: Boolean get() = _state.value.isLoading
    val isLoadingMore: Boolean get() = _state.value.isLoadingMore
    val hasMorePages: Boolean get() = _state.value.hasMorePages
    val isEmpty: Boolean get() = _state.value.isEmpty
    val canLoadMore: Boolean get() = _state.value.canLoadMore
    val error: Throwable? get() = _state.value.error

    /**
     * Reset pagination state
     */
    fun reset() {
        nextCursor = null
        previousCursor = null
        _state.value = PaginationUiState()
    }

    /**
     * Load initial page
     */
    suspend fun loadInitial(
        loader: suspend (CursorPaginationParams) -> List<T>
    ) {
        if (_state.value.isLoading) return

        _state.update { it.copy(isLoading = true, error = null) }

        try {
            val params = CursorPaginationParams(
                limit = pageSize,
                cursor = null,
                cursorColumn = cursorColumn,
                direction = CursorDirection.BACKWARD
            )
            val newItems = loader(params)

            nextCursor = newItems.lastOrNull()?.let(extractCursor)
            previousCursor = newItems.firstOrNull()?.let(extractCursor)

            _state.update {
                it.copy(
                    items = newItems,
                    isLoading = false,
                    hasMorePages = newItems.size >= pageSize
                )
            }
        } catch (e: Exception) {
            _state.update { it.copy(isLoading = false, error = e) }
        }
    }

    /**
     * Load next page (older items)
     */
    suspend fun loadMore(
        loader: suspend (CursorPaginationParams) -> List<T>
    ) {
        if (!_state.value.canLoadMore) return

        _state.update { it.copy(isLoadingMore = true) }

        try {
            val params = CursorPaginationParams(
                limit = pageSize,
                cursor = nextCursor,
                cursorColumn = cursorColumn,
                direction = CursorDirection.BACKWARD
            )
            val newItems = loader(params)

            nextCursor = newItems.lastOrNull()?.let(extractCursor)

            _state.update {
                it.copy(
                    items = it.items + newItems,
                    isLoadingMore = false,
                    hasMorePages = newItems.size >= pageSize
                )
            }
        } catch (e: Exception) {
            _state.update { it.copy(isLoadingMore = false) }
        }
    }

    /**
     * Load previous page (newer items) - for bidirectional scroll
     */
    suspend fun loadPrevious(
        loader: suspend (CursorPaginationParams) -> List<T>
    ) {
        if (!_state.value.canLoadPrevious) return

        _state.update { it.copy(isLoadingMore = true) }

        try {
            val params = CursorPaginationParams(
                limit = pageSize,
                cursor = previousCursor,
                cursorColumn = cursorColumn,
                direction = CursorDirection.FORWARD
            )
            val newItems = loader(params)

            previousCursor = newItems.firstOrNull()?.let(extractCursor)

            _state.update {
                it.copy(
                    items = newItems + it.items,
                    isLoadingMore = false,
                    hasPreviousPages = newItems.size >= pageSize
                )
            }
        } catch (e: Exception) {
            _state.update { it.copy(isLoadingMore = false) }
        }
    }

    /**
     * Refresh (reload from beginning)
     */
    suspend fun refresh(
        loader: suspend (CursorPaginationParams) -> List<T>
    ) {
        reset()
        loadInitial(loader)
    }

    /**
     * Check if item is last (for triggering load more)
     */
    fun isLastItem(item: T, getId: (T) -> Any): Boolean {
        val lastItem = _state.value.items.lastOrNull() ?: return false
        return getId(lastItem) == getId(item)
    }

    /**
     * Prepend item (for real-time additions)
     */
    fun prepend(item: T) {
        previousCursor = extractCursor(item)
        _state.update { it.copy(items = listOf(item) + it.items) }
    }

    /**
     * Append item
     */
    fun append(item: T) {
        nextCursor = extractCursor(item)
        _state.update { it.copy(items = it.items + item) }
    }

    /**
     * Remove item matching predicate
     */
    fun remove(predicate: (T) -> Boolean) {
        _state.update { it.copy(items = it.items.filterNot(predicate)) }
    }

    /**
     * Update item
     */
    fun update(item: T, getId: (T) -> Any) {
        _state.update { state ->
            state.copy(
                items = state.items.map { existing ->
                    if (getId(existing) == getId(item)) item else existing
                }
            )
        }
    }
}

/**
 * Offset-based pagination state manager (simpler but less efficient for large datasets)
 */
class OffsetPaginationState<T : Any>(
    val pageSize: Int = 20
) {
    private val _state = MutableStateFlow(PaginationUiState<T>())
    val state: StateFlow<PaginationUiState<T>> = _state.asStateFlow()

    private var currentPage = 0

    val items: List<T> get() = _state.value.items
    val isLoading: Boolean get() = _state.value.isLoading
    val isLoadingMore: Boolean get() = _state.value.isLoadingMore
    val hasMorePages: Boolean get() = _state.value.hasMorePages
    val isEmpty: Boolean get() = _state.value.isEmpty
    val canLoadMore: Boolean get() = _state.value.canLoadMore
    val error: Throwable? get() = _state.value.error

    /**
     * Reset pagination state
     */
    fun reset() {
        currentPage = 0
        _state.value = PaginationUiState()
    }

    /**
     * Load initial page
     *
     * @param loader Function that takes (limit, offset) and returns items
     */
    suspend fun loadInitial(
        loader: suspend (limit: Int, offset: Int) -> List<T>
    ) {
        if (_state.value.isLoading) return

        _state.update { it.copy(isLoading = true, error = null) }
        currentPage = 0

        try {
            val newItems = loader(pageSize, 0)
            _state.update {
                it.copy(
                    items = newItems,
                    isLoading = false,
                    hasMorePages = newItems.size >= pageSize
                )
            }
        } catch (e: Exception) {
            _state.update { it.copy(isLoading = false, error = e) }
        }
    }

    /**
     * Load next page
     */
    suspend fun loadMore(
        loader: suspend (limit: Int, offset: Int) -> List<T>
    ) {
        if (!_state.value.canLoadMore) return

        _state.update { it.copy(isLoadingMore = true) }

        try {
            val nextPage = currentPage + 1
            val offset = nextPage * pageSize
            val newItems = loader(pageSize, offset)

            currentPage = nextPage

            _state.update {
                it.copy(
                    items = it.items + newItems,
                    isLoadingMore = false,
                    hasMorePages = newItems.size >= pageSize
                )
            }
        } catch (e: Exception) {
            _state.update { it.copy(isLoadingMore = false) }
        }
    }

    /**
     * Refresh (reload from beginning)
     */
    suspend fun refresh(
        loader: suspend (limit: Int, offset: Int) -> List<T>
    ) {
        reset()
        loadInitial(loader)
    }

    /**
     * Check if item is last (for triggering load more)
     */
    fun isLastItem(item: T, getId: (T) -> Any): Boolean {
        val lastItem = _state.value.items.lastOrNull() ?: return false
        return getId(lastItem) == getId(item)
    }

    /**
     * Prepend item (for real-time additions)
     */
    fun prepend(item: T) {
        _state.update { it.copy(items = listOf(item) + it.items) }
    }

    /**
     * Remove item matching predicate
     */
    fun remove(predicate: (T) -> Boolean) {
        _state.update { it.copy(items = it.items.filterNot(predicate)) }
    }

    /**
     * Update item
     */
    fun update(item: T, getId: (T) -> Any) {
        _state.update { state ->
            state.copy(
                items = state.items.map { existing ->
                    if (getId(existing) == getId(item)) item else existing
                }
            )
        }
    }
}
