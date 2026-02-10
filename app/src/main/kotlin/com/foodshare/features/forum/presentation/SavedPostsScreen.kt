package com.foodshare.features.forum.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.BookmarkRemove
import androidx.compose.material.icons.outlined.Bookmark
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.foodshare.features.forum.domain.model.ForumPost
import com.foodshare.features.forum.domain.repository.ForumRepository
import com.foodshare.features.forum.presentation.components.ForumPostCard
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing
import com.foodshare.ui.theme.LocalThemePalette
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * UI State for Saved Posts screen.
 */
data class SavedPostsUiState(
    val posts: List<ForumPost> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null
)

/**
 * ViewModel for Saved Posts screen.
 */
@HiltViewModel
class SavedPostsViewModel @Inject constructor(
    private val repository: ForumRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(SavedPostsUiState())
    val uiState: StateFlow<SavedPostsUiState> = _uiState.asStateFlow()

    init {
        loadSavedPosts()
    }

    fun loadSavedPosts() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            repository.getBookmarkedPosts(limit = 50)
                .onSuccess { posts ->
                    _uiState.update { it.copy(posts = posts, isLoading = false) }
                }
                .onFailure { error ->
                    _uiState.update { it.copy(error = error.message, isLoading = false) }
                }
        }
    }

    fun removeBookmark(postId: Int) {
        viewModelScope.launch {
            repository.toggleBookmark(postId)
                .onSuccess {
                    // Remove from local list
                    _uiState.update { state ->
                        state.copy(posts = state.posts.filter { it.id != postId })
                    }
                }
        }
    }
}

/**
 * Saved Posts Screen - Shows user's bookmarked forum posts
 *
 * SYNC: This mirrors Swift SavedPostsView
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SavedPostsScreen(
    onNavigateBack: () -> Unit,
    onNavigateToPost: (Int) -> Unit,
    viewModel: SavedPostsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val palette = LocalThemePalette.current

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(brush = LiquidGlassGradients.darkAuth)
    ) {
        Scaffold(
            containerColor = Color.Transparent,
            topBar = {
                TopAppBar(
                    title = {
                        Text(
                            text = "Saved Posts",
                            color = Color.White
                        )
                    },
                    navigationIcon = {
                        IconButton(onClick = onNavigateBack) {
                            Icon(
                                Icons.AutoMirrored.Filled.ArrowBack,
                                contentDescription = "Back",
                                tint = Color.White
                            )
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = Color.Transparent
                    )
                )
            }
        ) { paddingValues ->
            PullToRefreshBox(
                isRefreshing = uiState.isLoading,
                onRefresh = { viewModel.loadSavedPosts() },
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
            ) {
                when {
                    uiState.isLoading && uiState.posts.isEmpty() -> {
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center
                        ) {
                            CircularProgressIndicator(color = palette.primaryColor)
                        }
                    }

                    uiState.error != null && uiState.posts.isEmpty() -> {
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center
                        ) {
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Text(
                                    text = uiState.error ?: "Error loading saved posts",
                                    color = LiquidGlassColors.error,
                                    textAlign = TextAlign.Center
                                )
                                Spacer(modifier = Modifier.height(Spacing.md))
                                TextButton(onClick = { viewModel.loadSavedPosts() }) {
                                    Text("Retry", color = palette.primaryColor)
                                }
                            }
                        }
                    }

                    uiState.posts.isEmpty() -> {
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center
                        ) {
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                modifier = Modifier.padding(Spacing.lg)
                            ) {
                                Icon(
                                    Icons.Outlined.Bookmark,
                                    contentDescription = null,
                                    modifier = Modifier.size(64.dp),
                                    tint = Color.White.copy(alpha = 0.5f)
                                )
                                Spacer(modifier = Modifier.height(Spacing.md))
                                Text(
                                    text = "No saved posts yet",
                                    style = MaterialTheme.typography.titleMedium,
                                    color = Color.White
                                )
                                Spacer(modifier = Modifier.height(Spacing.xs))
                                Text(
                                    text = "Bookmark posts to save them for later",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = Color.White.copy(alpha = 0.6f),
                                    textAlign = TextAlign.Center
                                )
                            }
                        }
                    }

                    else -> {
                        LazyColumn(
                            contentPadding = PaddingValues(Spacing.md),
                            verticalArrangement = Arrangement.spacedBy(Spacing.sm)
                        ) {
                            items(
                                items = uiState.posts,
                                key = { it.id }
                            ) { post ->
                                ForumPostCard(
                                    post = post.copy(isBookmarked = true),
                                    onClick = { onNavigateToPost(post.id) },
                                    onBookmark = { viewModel.removeBookmark(post.id) }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
