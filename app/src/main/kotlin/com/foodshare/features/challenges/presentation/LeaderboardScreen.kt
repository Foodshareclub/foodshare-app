package com.foodshare.features.challenges.presentation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import com.foodshare.ui.design.components.cards.GlassCard
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing
import com.foodshare.features.challenges.presentation.components.PodiumSection
import com.foodshare.features.challenges.presentation.components.TimePeriodFilterRow
import com.foodshare.features.challenges.presentation.components.CategoryFilterRow
import com.foodshare.features.challenges.presentation.components.CurrentUserRankCard
import com.foodshare.features.challenges.presentation.components.LeaderboardListItem

// ============================================================================
// LeaderboardScreen
// ============================================================================

/**
 * Full leaderboard screen with podium view for top 3 users
 * and a scrollable ranked list below.
 *
 * Features:
 * - Podium display: 2nd (left), 1st (center, tallest), 3rd (right)
 * - Medal colors (gold, silver, bronze)
 * - Time period filter chips (This Week, This Month, All Time)
 * - Category filter chips (Food Shared, Community Impact, Challenges Won)
 * - Current user rank highlighted
 * - EngagementBridge-based score display
 *
 * SYNC: Mirrors Swift LeaderboardView
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LeaderboardScreen(
    onNavigateBack: () -> Unit,
    viewModel: LeaderboardViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
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
                        text = "Leaderboard",
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    )
                },
                actions = {
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
        modifier = Modifier.background(brush = LiquidGlassGradients.darkAuth)
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            when {
                uiState.isLoading && uiState.entries.isEmpty() && uiState.topThree.isEmpty() -> {
                    LeaderboardLoadingState()
                }

                uiState.error != null && uiState.entries.isEmpty() && uiState.topThree.isEmpty() -> {
                    LeaderboardErrorState(
                        message = uiState.error ?: "Something went wrong",
                        onRetry = { viewModel.loadLeaderboard() }
                    )
                }

                else -> {
                    LeaderboardContent(
                        uiState = uiState,
                        onPeriodSelected = { viewModel.selectPeriod(it) },
                        onCategorySelected = { viewModel.selectCategory(it) }
                    )
                }
            }
        }
    }
}

// ============================================================================
// Content
// ============================================================================

@Composable
private fun LeaderboardContent(
    uiState: LeaderboardViewModel.UiState,
    onPeriodSelected: (LeaderboardViewModel.TimePeriod) -> Unit,
    onCategorySelected: (LeaderboardViewModel.LeaderboardCategory) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = Spacing.xxl)
    ) {
        // Time period filter chips
        item {
            TimePeriodFilterRow(
                selectedPeriod = uiState.selectedPeriod,
                onPeriodSelected = onPeriodSelected,
                modifier = Modifier.padding(horizontal = Spacing.md, vertical = Spacing.sm)
            )
        }

        // Category filter chips
        item {
            CategoryFilterRow(
                selectedCategory = uiState.selectedCategory,
                onCategorySelected = onCategorySelected,
                modifier = Modifier.padding(horizontal = Spacing.md, vertical = Spacing.sm)
            )
        }

        // Podium for top 3
        item {
            Spacer(modifier = Modifier.height(Spacing.md))
            if (uiState.topThree.isNotEmpty()) {
                PodiumSection(topThree = uiState.topThree)
            }
            Spacer(modifier = Modifier.height(Spacing.lg))
        }

        // Current user rank highlight (if not in top 3)
        uiState.currentUserEntry?.let { entry ->
            if (entry.rank > 3) {
                item {
                    CurrentUserRankCard(
                        entry = entry,
                        modifier = Modifier.padding(horizontal = Spacing.md, vertical = Spacing.sm)
                    )
                }
            }
        }

        // Ranked list (4th place and below)
        if (uiState.entries.isNotEmpty()) {
            item {
                Text(
                    text = "Rankings",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                    modifier = Modifier.padding(
                        horizontal = Spacing.md,
                        vertical = Spacing.sm
                    )
                )
            }

            items(
                items = uiState.entries,
                key = { it.userId }
            ) { entry ->
                LeaderboardListItem(
                    entry = entry,
                    modifier = Modifier.padding(
                        horizontal = Spacing.md,
                        vertical = Spacing.xxxs
                    )
                )
            }
        }

        // Loading indicator for refresh
        if (uiState.isRefreshing) {
            item {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(Spacing.md),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(
                        color = LiquidGlassColors.brandTeal,
                        modifier = Modifier.size(24.dp),
                        strokeWidth = 2.dp
                    )
                }
            }
        }
    }
}

// Components moved to features/challenges/presentation/components/

// ============================================================================
// States
// ============================================================================

@Composable
private fun LeaderboardLoadingState() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            CircularProgressIndicator(
                color = LiquidGlassColors.brandTeal,
                modifier = Modifier.size(48.dp)
            )
            Spacer(modifier = Modifier.height(Spacing.md))
            Text(
                text = "Loading leaderboard...",
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(alpha = 0.7f)
            )
        }
    }
}

@Composable
private fun LeaderboardErrorState(
    message: String,
    onRetry: () -> Unit
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
                    imageVector = Icons.Default.EmojiEvents,
                    contentDescription = null,
                    tint = Color.White.copy(alpha = 0.5f),
                    modifier = Modifier.size(48.dp)
                )
                Spacer(modifier = Modifier.height(Spacing.md))
                Text(
                    text = message,
                    style = MaterialTheme.typography.bodyLarge,
                    color = Color.White,
                    textAlign = TextAlign.Center
                )
                Spacer(modifier = Modifier.height(Spacing.lg))
                com.foodshare.ui.design.components.buttons.GlassButton(
                    text = "Try Again",
                    onClick = onRetry,
                    style = com.foodshare.ui.design.components.buttons.GlassButtonStyle.Primary
                )
            }
        }
    }
}

// ============================================================================
// Utilities
// ============================================================================

/**
 * Format a numeric score for display with K suffix for large numbers.
 */
private fun formatScore(score: Int): String = when {
    score >= 10_000 -> "${score / 1000}K"
    score >= 1_000 -> "%.1fK".format(score / 1000.0)
    else -> score.toString()
}
