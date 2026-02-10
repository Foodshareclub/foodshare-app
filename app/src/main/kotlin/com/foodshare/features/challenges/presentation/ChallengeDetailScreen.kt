package com.foodshare.features.challenges.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import com.foodshare.features.challenges.domain.model.*
import com.foodshare.ui.design.components.buttons.GlassButton
import com.foodshare.ui.design.components.cards.GlassCard
import com.foodshare.ui.design.modifiers.glassBackground
import com.foodshare.ui.design.modifiers.glow
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing
import com.foodshare.ui.theme.LocalThemePalette

/**
 * Challenge Detail Screen - Shows full details of a challenge
 *
 * SYNC: This mirrors Swift ChallengeDetailView
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChallengeDetailScreen(
    onNavigateBack: () -> Unit,
    viewModel: ChallengeDetailViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val palette = LocalThemePalette.current

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(brush = LiquidGlassGradients.darkAuth)
    ) {
        when {
            uiState.isLoading -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = palette.primaryColor)
                }
            }

            uiState.error != null && uiState.challenge == null -> {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(Spacing.lg),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Icon(
                        Icons.Default.Error,
                        contentDescription = null,
                        modifier = Modifier.size(64.dp),
                        tint = LiquidGlassColors.error
                    )
                    Spacer(modifier = Modifier.height(Spacing.md))
                    Text(
                        text = uiState.error ?: "Error loading challenge",
                        color = Color.White,
                        textAlign = TextAlign.Center
                    )
                    Spacer(modifier = Modifier.height(Spacing.md))
                    GlassButton(
                        text = "Retry",
                        onClick = { viewModel.loadChallenge() }
                    )
                }
            }

            uiState.challenge != null -> {
                ChallengeDetailContent(
                    challengeWithStatus = uiState.challenge!!,
                    leaderboard = uiState.leaderboard,
                    isLoadingLeaderboard = uiState.isLoadingLeaderboard,
                    isActionLoading = uiState.isActionLoading,
                    isLiked = uiState.isLiked,
                    likeCount = uiState.likeCount,
                    onAccept = { viewModel.acceptChallenge() },
                    onComplete = { viewModel.completeChallenge() },
                    onToggleLike = { viewModel.toggleLike() },
                    onNavigateBack = onNavigateBack
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ChallengeDetailContent(
    challengeWithStatus: ChallengeWithStatus,
    leaderboard: List<ChallengeLeaderboardEntry>,
    isLoadingLeaderboard: Boolean,
    isActionLoading: Boolean,
    isLiked: Boolean,
    likeCount: Int,
    onAccept: () -> Unit,
    onComplete: () -> Unit,
    onToggleLike: () -> Unit,
    onNavigateBack: () -> Unit
) {
    val challenge = challengeWithStatus.challenge
    val status = challengeWithStatus.status
    val palette = LocalThemePalette.current

    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = Color.White
                        )
                    }
                },
                actions = {
                    // Like button
                    IconButton(onClick = onToggleLike) {
                        Icon(
                            if (isLiked) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
                            contentDescription = "Like",
                            tint = if (isLiked) LiquidGlassColors.brandPink else Color.White
                        )
                    }
                    // Share button
                    IconButton(onClick = { /* TODO: Share */ }) {
                        Icon(
                            Icons.Default.Share,
                            contentDescription = "Share",
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
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues),
            contentPadding = PaddingValues(bottom = 100.dp)
        ) {
            // Hero Image
            item {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(250.dp)
                ) {
                    if (challenge.imageUrl != null) {
                        AsyncImage(
                            model = challenge.imageUrl,
                            contentDescription = challenge.title,
                            modifier = Modifier.fillMaxSize(),
                            contentScale = ContentScale.Crop
                        )
                    } else {
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .background(
                                    Brush.linearGradient(
                                        colors = listOf(
                                            Color(challenge.difficulty.color),
                                            Color(challenge.difficulty.color).copy(alpha = 0.6f)
                                        )
                                    )
                                ),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                Icons.Default.EmojiEvents,
                                contentDescription = null,
                                modifier = Modifier.size(80.dp),
                                tint = Color.White.copy(alpha = 0.5f)
                            )
                        }
                    }

                    // Gradient overlay
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(
                                Brush.verticalGradient(
                                    colors = listOf(
                                        Color.Transparent,
                                        Color.Black.copy(alpha = 0.7f)
                                    ),
                                    startY = 100f
                                )
                            )
                    )

                    // Difficulty badge
                    Box(
                        modifier = Modifier
                            .align(Alignment.TopEnd)
                            .padding(Spacing.md)
                            .clip(RoundedCornerShape(50))
                            .background(Color(challenge.difficulty.color))
                            .padding(horizontal = Spacing.sm, vertical = Spacing.xs)
                    ) {
                        Text(
                            text = challenge.difficulty.displayName,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                    }
                }
            }

            // Title and description
            item {
                Column(
                    modifier = Modifier.padding(horizontal = Spacing.lg, vertical = Spacing.md)
                ) {
                    Text(
                        text = challenge.title,
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )

                    Spacer(modifier = Modifier.height(Spacing.sm))

                    Text(
                        text = challenge.description,
                        style = MaterialTheme.typography.bodyLarge,
                        color = Color.White.copy(alpha = 0.8f)
                    )
                }
            }

            // Stats row
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = Spacing.lg, vertical = Spacing.sm),
                    horizontalArrangement = Arrangement.SpaceEvenly
                ) {
                    StatItem(
                        icon = Icons.Default.People,
                        value = challenge.formattedParticipants,
                        label = "Joined"
                    )
                    StatItem(
                        icon = Icons.Default.Favorite,
                        value = likeCount.toString(),
                        label = "Likes"
                    )
                    StatItem(
                        icon = Icons.Default.Visibility,
                        value = challenge.viewsCount.toString(),
                        label = "Views"
                    )
                    StatItem(
                        icon = Icons.Default.Stars,
                        value = challenge.formattedScore,
                        label = "Points"
                    )
                }
            }

            // Status badge and action button
            item {
                Column(
                    modifier = Modifier.padding(horizontal = Spacing.lg, vertical = Spacing.md),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    // Status badge
                    StatusBadge(status = status)

                    Spacer(modifier = Modifier.height(Spacing.md))

                    // Action button based on status
                    when (status) {
                        ChallengeUserStatus.NOT_JOINED -> {
                            GlassButton(
                                text = if (isActionLoading) "Joining..." else "Accept Challenge",
                                onClick = onAccept,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .glow(color = palette.primaryColor)
                            )
                        }
                        ChallengeUserStatus.ACCEPTED -> {
                            GlassButton(
                                text = if (isActionLoading) "Completing..." else "Mark Complete",
                                onClick = onComplete,
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                        ChallengeUserStatus.COMPLETED -> {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(LiquidGlassColors.success.copy(alpha = 0.2f))
                                    .border(
                                        width = 1.dp,
                                        color = LiquidGlassColors.success.copy(alpha = 0.5f),
                                        shape = RoundedCornerShape(12.dp)
                                    )
                                    .padding(Spacing.md),
                                contentAlignment = Alignment.Center
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(Spacing.sm)
                                ) {
                                    Icon(
                                        Icons.Default.CheckCircle,
                                        contentDescription = null,
                                        tint = LiquidGlassColors.success
                                    )
                                    Text(
                                        text = "Challenge Completed!",
                                        fontWeight = FontWeight.SemiBold,
                                        color = LiquidGlassColors.success
                                    )
                                }
                            }
                        }
                        ChallengeUserStatus.REJECTED -> {
                            GlassButton(
                                text = "Re-accept Challenge",
                                onClick = onAccept,
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                    }
                }
            }

            // Leaderboard section
            item {
                Column(
                    modifier = Modifier.padding(horizontal = Spacing.lg, vertical = Spacing.md)
                ) {
                    Text(
                        text = "Leaderboard",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )

                    Spacer(modifier = Modifier.height(Spacing.sm))

                    if (isLoadingLeaderboard) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(100.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            CircularProgressIndicator(
                                color = palette.primaryColor,
                                modifier = Modifier.size(32.dp)
                            )
                        }
                    } else if (leaderboard.isEmpty()) {
                        GlassCard(modifier = Modifier.fillMaxWidth()) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(Spacing.lg),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = "Be the first to join!",
                                    color = Color.White.copy(alpha = 0.7f)
                                )
                            }
                        }
                    }
                }
            }

            // Leaderboard entries
            itemsIndexed(
                items = leaderboard,
                key = { _, entry -> entry.id }
            ) { index, entry ->
                LeaderboardRow(
                    entry = entry,
                    rank = index + 1,
                    modifier = Modifier.padding(horizontal = Spacing.lg, vertical = Spacing.xxs)
                )
            }
        }
    }
}

@Composable
private fun StatItem(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    value: String,
    label: String
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = Color.White.copy(alpha = 0.7f),
            modifier = Modifier.size(24.dp)
        )
        Spacer(modifier = Modifier.height(Spacing.xxs))
        Text(
            text = value,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = Color.White.copy(alpha = 0.6f)
        )
    }
}

@Composable
private fun StatusBadge(status: ChallengeUserStatus) {
    val (color, text) = when (status) {
        ChallengeUserStatus.NOT_JOINED -> LiquidGlassColors.Glass.border to "Not Joined"
        ChallengeUserStatus.ACCEPTED -> LiquidGlassColors.brandBlue to "In Progress"
        ChallengeUserStatus.COMPLETED -> LiquidGlassColors.success to "Completed"
        ChallengeUserStatus.REJECTED -> LiquidGlassColors.Glass.border to "Skipped"
    }

    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(color.copy(alpha = 0.2f))
            .border(
                width = 1.dp,
                color = color.copy(alpha = 0.5f),
                shape = RoundedCornerShape(50)
            )
            .padding(horizontal = Spacing.md, vertical = Spacing.xs)
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.Medium,
            color = color
        )
    }
}

@Composable
private fun LeaderboardRow(
    entry: ChallengeLeaderboardEntry,
    rank: Int,
    modifier: Modifier = Modifier
) {
    val palette = LocalThemePalette.current

    GlassCard(modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.sm),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Rank
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(CircleShape)
                    .background(
                        when (rank) {
                            1 -> Color(0xFFFFD700) // Gold
                            2 -> Color(0xFFC0C0C0) // Silver
                            3 -> Color(0xFFCD7F32) // Bronze
                            else -> LiquidGlassColors.Glass.background
                        }
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = rank.toString(),
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = if (rank <= 3) Color.Black else Color.White
                )
            }

            Spacer(modifier = Modifier.width(Spacing.sm))

            // Avatar
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(palette.primaryColor.copy(alpha = 0.3f)),
                contentAlignment = Alignment.Center
            ) {
                if (entry.avatarUrl != null) {
                    AsyncImage(
                        model = entry.avatarUrl,
                        contentDescription = entry.nickname,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop
                    )
                } else {
                    Text(
                        text = entry.nickname.take(1).uppercase(),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = palette.primaryColor
                    )
                }
            }

            Spacer(modifier = Modifier.width(Spacing.sm))

            // Name
            Text(
                text = entry.nickname,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = Color.White,
                modifier = Modifier.weight(1f)
            )

            // Completion badge
            if (entry.isCompleted) {
                Icon(
                    Icons.Default.CheckCircle,
                    contentDescription = "Completed",
                    tint = LiquidGlassColors.success,
                    modifier = Modifier.size(20.dp)
                )
            }
        }
    }
}
