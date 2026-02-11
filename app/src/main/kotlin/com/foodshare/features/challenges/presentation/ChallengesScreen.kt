package com.foodshare.features.challenges.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
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
import com.foodshare.features.challenges.domain.model.*
import com.foodshare.features.challenges.presentation.components.ChallengeCard
import com.foodshare.features.challenges.presentation.components.ChallengeFilterBar
import com.foodshare.features.challenges.presentation.components.ChallengeStatsRow
import com.foodshare.features.challenges.presentation.components.LeaderboardSection
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.Spacing

/**
 * Main Challenges screen.
 *
 * SYNC: This mirrors Swift ChallengesView
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChallengesScreen(
    onNavigateToChallenge: (Int) -> Unit,
    viewModel: ChallengesViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var isRefreshing by remember { mutableStateOf(false) }

    LaunchedEffect(isRefreshing) {
        if (isRefreshing) {
            viewModel.loadChallenges()
            isRefreshing = false
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("Challenges")
                        Text(
                            text = "${uiState.joinedChallengesCount} joined, ${uiState.completedChallengesCount} completed",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                },
                actions = {
                    // View mode toggle
                    IconButton(onClick = {
                        val newMode = when (uiState.viewMode) {
                            ChallengeViewMode.LIST -> ChallengeViewMode.DECK
                            ChallengeViewMode.DECK -> ChallengeViewMode.LEADERBOARD
                            ChallengeViewMode.LEADERBOARD -> ChallengeViewMode.LIST
                        }
                        viewModel.setViewMode(newMode)
                    }) {
                        Icon(
                            imageVector = when (uiState.viewMode) {
                                ChallengeViewMode.LIST -> Icons.Default.ViewCarousel
                                ChallengeViewMode.DECK -> Icons.Default.Leaderboard
                                ChallengeViewMode.LEADERBOARD -> Icons.Default.ViewList
                            },
                            contentDescription = "Change view"
                        )
                    }
                }
            )
        }
    ) { paddingValues ->
        PullToRefreshBox(
            isRefreshing = uiState.isLoading,
            onRefresh = { isRefreshing = true },
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            when {
                uiState.isLoading && uiState.userChallenges.isEmpty() -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator()
                    }
                }

                uiState.error != null && uiState.userChallenges.isEmpty() -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = uiState.error ?: "Error loading challenges",
                                color = MaterialTheme.colorScheme.error
                            )
                            Spacer(modifier = Modifier.height(Spacing.sm))
                            TextButton(onClick = { viewModel.loadChallenges() }) {
                                Text("Retry")
                            }
                        }
                    }
                }

                else -> {
                    when (uiState.viewMode) {
                        ChallengeViewMode.LIST -> ChallengesListView(
                            uiState = uiState,
                            onFilterChange = { viewModel.setFilter(it) },
                            onChallengeClick = { onNavigateToChallenge(it.challenge.id) },
                            onAccept = { viewModel.acceptChallenge(it) },
                            onComplete = { viewModel.completeChallenge(it) },
                            onLikeToggle = { viewModel.toggleLike(it) }
                        )
                        ChallengeViewMode.DECK -> ChallengesDeckView(
                            challenges = uiState.deckChallenges,
                            isJoining = uiState.isJoining,
                            onAccept = { viewModel.acceptChallenge(it) },
                            onReject = { viewModel.rejectChallenge(it) }
                        )
                        ChallengeViewMode.LEADERBOARD -> ChallengesLeaderboardView(
                            challenges = uiState.userChallenges,
                            selectedChallenge = uiState.selectedChallenge,
                            leaderboard = uiState.leaderboard,
                            isLoading = uiState.isLoadingLeaderboard,
                            onChallengeSelect = { viewModel.selectChallenge(it.challenge) }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ChallengesListView(
    uiState: ChallengesUiState,
    onFilterChange: (ChallengeFilter) -> Unit,
    onChallengeClick: (ChallengeWithStatus) -> Unit,
    onAccept: (Int) -> Unit,
    onComplete: (Int) -> Unit,
    onLikeToggle: (Int) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(Spacing.md)
    ) {
        // Filter chips
        item {
            ChallengeFilterBar(
                selectedFilter = uiState.selectedFilter,
                onFilterChange = onFilterChange,
                modifier = Modifier.padding(bottom = Spacing.md)
            )
        }

        // Stats summary
        item {
            ChallengeStatsRow(
                joinedCount = uiState.joinedChallengesCount,
                completedCount = uiState.completedChallengesCount,
                modifier = Modifier.padding(bottom = Spacing.md)
            )
        }

        // Challenge cards
        if (uiState.filteredChallenges.isEmpty()) {
            item {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(200.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            Icons.Outlined.EmojiEvents,
                            contentDescription = null,
                            modifier = Modifier.size(48.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(Spacing.sm))
                        Text(
                            text = "No challenges found",
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }

        items(
            items = uiState.filteredChallenges,
            key = { it.challenge.id }
        ) { challengeWithStatus ->
            ChallengeCard(
                challengeWithStatus = challengeWithStatus,
                isLiked = uiState.likeStates[challengeWithStatus.challenge.id] ?: false,
                likeCount = uiState.likeCounts[challengeWithStatus.challenge.id]
                    ?: challengeWithStatus.challenge.likesCount,
                onClick = { onChallengeClick(challengeWithStatus) },
                onAccept = { onAccept(challengeWithStatus.challenge.id) },
                onComplete = { onComplete(challengeWithStatus.challenge.id) },
                onLikeToggle = { onLikeToggle(challengeWithStatus.challenge.id) },
                modifier = Modifier.padding(vertical = Spacing.xs)
            )
        }
    }
}

@Composable
private fun ChallengesDeckView(
    challenges: List<ChallengeWithStatus>,
    isJoining: Boolean,
    onAccept: (Int) -> Unit,
    onReject: (Int) -> Unit
) {
    if (challenges.isEmpty()) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    Icons.Default.CheckCircle,
                    contentDescription = null,
                    modifier = Modifier.size(64.dp),
                    tint = LiquidGlassColors.brandPink
                )
                Spacer(modifier = Modifier.height(Spacing.md))
                Text(
                    text = "All caught up!",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "No new challenges to explore",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        return
    }

    val currentChallenge = challenges.firstOrNull() ?: return

    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.padding(Spacing.lg)
        ) {
            // Simple card display (deck animation would be more complex)
            ChallengeCard(
                challengeWithStatus = currentChallenge,
                isLiked = false,
                likeCount = currentChallenge.challenge.likesCount,
                onClick = { },
                onAccept = { onAccept(currentChallenge.challenge.id) },
                onComplete = { },
                onLikeToggle = { },
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(Spacing.lg))

            // Action buttons
            Row(
                horizontalArrangement = Arrangement.spacedBy(Spacing.lg)
            ) {
                // Reject button
                FloatingActionButton(
                    onClick = { if (!isJoining) onReject(currentChallenge.challenge.id) },
                    containerColor = if (isJoining)
                        MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.5f)
                    else
                        MaterialTheme.colorScheme.errorContainer
                ) {
                    Icon(Icons.Default.Close, contentDescription = "Skip")
                }

                // Accept button
                FloatingActionButton(
                    onClick = { if (!isJoining) onAccept(currentChallenge.challenge.id) },
                    containerColor = if (isJoining)
                        LiquidGlassColors.brandPink.copy(alpha = 0.5f)
                    else
                        LiquidGlassColors.brandPink
                ) {
                    if (isJoining) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(24.dp),
                            color = Color.White,
                            strokeWidth = 2.dp
                        )
                    } else {
                        Icon(Icons.Default.Check, contentDescription = "Accept", tint = Color.White)
                    }
                }
            }

            Spacer(modifier = Modifier.height(Spacing.sm))

            Text(
                text = "${challenges.size} more challenges",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun ChallengesLeaderboardView(
    challenges: List<ChallengeWithStatus>,
    selectedChallenge: ChallengeWithStatus?,
    leaderboard: List<ChallengeLeaderboardEntry>,
    isLoading: Boolean,
    onChallengeSelect: (ChallengeWithStatus) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(Spacing.md)
    ) {
        // Challenge selector
        item {
            Text(
                text = "Select a Challenge",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = Spacing.sm)
            )
        }

        items(challenges.take(5)) { challenge ->
            Surface(
                onClick = { onChallengeSelect(challenge) },
                shape = RoundedCornerShape(12.dp),
                color = if (selectedChallenge?.challenge?.id == challenge.challenge.id) {
                    MaterialTheme.colorScheme.primaryContainer
                } else {
                    MaterialTheme.colorScheme.surface
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 4.dp)
            ) {
                Row(
                    modifier = Modifier.padding(Spacing.sm),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.EmojiEvents,
                        contentDescription = null,
                        tint = Color(challenge.challenge.difficulty.color)
                    )
                    Spacer(modifier = Modifier.width(Spacing.sm))
                    Text(
                        text = challenge.challenge.displayTitle,
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.weight(1f)
                    )
                    Text(
                        text = "${challenge.challenge.participantCount} joined",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        // Leaderboard
        if (selectedChallenge != null) {
            item {
                Spacer(modifier = Modifier.height(Spacing.lg))
                LeaderboardSection(
                    entries = leaderboard,
                    isLoading = isLoading
                )
            }
        }
    }
}

@Composable
private fun StatsRow(
    joinedCount: Int,
    completedCount: Int,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(Spacing.md)
    ) {
        StatCard(
            label = "Joined",
            value = joinedCount.toString(),
            icon = Icons.Default.PlayArrow,
            color = LiquidGlassColors.brandBlue,
            modifier = Modifier.weight(1f)
        )
        StatCard(
            label = "Completed",
            value = completedCount.toString(),
            icon = Icons.Default.CheckCircle,
            color = LiquidGlassColors.brandPink,
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun StatCard(
    label: String,
    value: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    color: Color,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(
            containerColor = color.copy(alpha = 0.1f)
        )
    ) {
        Row(
            modifier = Modifier.padding(Spacing.md),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = color,
                modifier = Modifier.size(24.dp)
            )
            Spacer(modifier = Modifier.width(Spacing.sm))
            Column {
                Text(
                    text = value,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = color
                )
                Text(
                    text = label,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}
