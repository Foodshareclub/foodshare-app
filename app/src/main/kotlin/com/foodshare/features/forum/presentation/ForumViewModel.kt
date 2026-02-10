package com.foodshare.features.forum.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.errors.ErrorBridge
import com.foodshare.features.forum.domain.model.*
import com.foodshare.features.forum.domain.repository.ForumRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * UI State for Forum screen.
 */
data class ForumUiState(
    val posts: List<ForumPost> = emptyList(),
    val pinnedPosts: List<ForumPost> = emptyList(),
    val trendingPosts: List<ForumPost> = emptyList(),
    val categories: List<ForumCategory> = emptyList(),
    val tags: List<ForumTag> = emptyList(),
    val filters: ForumFilters = ForumFilters(),
    val isLoading: Boolean = false,
    val isLoadingMore: Boolean = false,
    val isRefreshing: Boolean = false,
    val hasMorePosts: Boolean = true,
    val error: String? = null,
    val searchQuery: String = "",
    val unreadNotificationCount: Int = 0
)

/**
 * ViewModel for Forum feature.
 *
 * SYNC: This mirrors Swift ForumViewModel
 */
@HiltViewModel
class ForumViewModel @Inject constructor(
    private val repository: ForumRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(ForumUiState())
    val uiState: StateFlow<ForumUiState> = _uiState.asStateFlow()

    private var currentCursor: String? = null
    private val pageSize = 20

    init {
        loadInitialData()
    }

    fun loadInitialData() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            // Load categories, trending posts, and main posts in parallel
            launch { loadCategories() }
            launch { loadTrendingPosts() }
            launch { loadPinnedPosts() }
            launch { loadUnreadNotificationCount() }
            loadPosts(refresh = true)
        }
    }

    fun refresh() {
        viewModelScope.launch {
            _uiState.update { it.copy(isRefreshing = true) }
            currentCursor = null
            loadPosts(refresh = true)
            loadTrendingPosts()
            loadUnreadNotificationCount()
            _uiState.update { it.copy(isRefreshing = false) }
        }
    }

    fun loadPosts(refresh: Boolean = false) {
        viewModelScope.launch {
            if (refresh) {
                currentCursor = null
                _uiState.update { it.copy(isLoading = true, error = null) }
            } else {
                _uiState.update { it.copy(isLoadingMore = true) }
            }

            repository.getPosts(
                filters = _uiState.value.filters,
                limit = pageSize,
                cursor = currentCursor
            ).onSuccess { posts ->
                _uiState.update { state ->
                    val newPosts = if (refresh) posts else state.posts + posts
                    currentCursor = posts.lastOrNull()?.createdAt
                    state.copy(
                        posts = newPosts,
                        isLoading = false,
                        isLoadingMore = false,
                        hasMorePosts = posts.size >= pageSize
                    )
                }
            }.onFailure { error ->
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        isLoadingMore = false,
                        error = ErrorBridge.mapForumError(error)
                    )
                }
            }
        }
    }

    fun loadMorePosts() {
        if (_uiState.value.isLoadingMore || !_uiState.value.hasMorePosts) return
        loadPosts(refresh = false)
    }

    private suspend fun loadCategories() {
        repository.getCategories()
            .onSuccess { categories ->
                _uiState.update { it.copy(categories = categories) }
            }
    }

    private suspend fun loadTrendingPosts() {
        repository.getTrendingPosts(limit = 5)
            .onSuccess { posts ->
                _uiState.update { it.copy(trendingPosts = posts) }
            }
    }

    private suspend fun loadPinnedPosts() {
        repository.getPinnedPosts(categoryId = _uiState.value.filters.categoryId)
            .onSuccess { posts ->
                _uiState.update { it.copy(pinnedPosts = posts) }
            }
    }

    private suspend fun loadUnreadNotificationCount() {
        repository.getUnreadNotificationCount()
            .onSuccess { count ->
                _uiState.update { it.copy(unreadNotificationCount = count) }
            }
    }

    fun search(query: String) {
        _uiState.update { it.copy(searchQuery = query) }

        if (query.isBlank()) {
            _uiState.update { it.copy(filters = it.filters.copy(searchQuery = "")) }
            loadPosts(refresh = true)
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            repository.searchPosts(query)
                .onSuccess { posts ->
                    _uiState.update {
                        it.copy(
                            posts = posts,
                            isLoading = false,
                            hasMorePosts = false
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(isLoading = false, error = ErrorBridge.mapForumError(error))
                    }
                }
        }
    }

    fun setCategory(categoryId: Int?) {
        _uiState.update {
            it.copy(filters = it.filters.copy(categoryId = categoryId))
        }
        loadPosts(refresh = true)
        viewModelScope.launch { loadPinnedPosts() }
    }

    fun setPostType(postType: ForumPostType?) {
        _uiState.update {
            it.copy(filters = it.filters.copy(postType = postType))
        }
        loadPosts(refresh = true)
    }

    fun setSortOption(sortBy: ForumSortOption) {
        _uiState.update {
            it.copy(filters = it.filters.copy(sortBy = sortBy))
        }
        loadPosts(refresh = true)
    }

    fun togglePinnedOnly() {
        _uiState.update {
            it.copy(filters = it.filters.copy(showPinnedOnly = !it.filters.showPinnedOnly))
        }
        loadPosts(refresh = true)
    }

    fun toggleQuestionsOnly() {
        _uiState.update {
            it.copy(filters = it.filters.copy(showQuestionsOnly = !it.filters.showQuestionsOnly))
        }
        loadPosts(refresh = true)
    }

    fun toggleBookmark(postId: Int) {
        viewModelScope.launch {
            repository.toggleBookmark(postId)
                .onSuccess { isBookmarked ->
                    _uiState.update { state ->
                        state.copy(
                            posts = state.posts.map { post ->
                                if (post.id == postId) post.copy(isBookmarked = isBookmarked) else post
                            }
                        )
                    }
                }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}
