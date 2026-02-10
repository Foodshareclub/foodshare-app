package com.foodshare.features.forum.presentation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Reply
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import com.foodshare.features.forum.domain.model.*
import com.foodshare.ui.design.components.cards.GlassCard
import com.foodshare.ui.design.modifiers.glassBackground
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing
import com.foodshare.ui.theme.LocalThemePalette

/**
 * Forum Post Detail Screen - Shows full post with comments
 *
 * SYNC: This mirrors Swift ForumPostDetailView
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ForumPostDetailScreen(
    onNavigateBack: () -> Unit,
    viewModel: ForumPostDetailViewModel = hiltViewModel()
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

            uiState.error != null && uiState.post == null -> {
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
                        text = uiState.error ?: "Error loading post",
                        color = Color.White,
                        textAlign = TextAlign.Center
                    )
                }
            }

            uiState.post != null -> {
                ForumPostDetailContent(
                    post = uiState.post!!,
                    comments = uiState.comments,
                    isLoadingComments = uiState.isLoadingComments,
                    commentText = uiState.commentText,
                    isSubmittingComment = uiState.isSubmittingComment,
                    replyingToComment = uiState.replyingToComment,
                    reactions = uiState.reactions,
                    isBookmarked = uiState.isBookmarked,
                    onNavigateBack = onNavigateBack,
                    onCommentTextChange = { viewModel.updateCommentText(it) },
                    onSubmitComment = { viewModel.submitComment() },
                    onReplyToComment = { viewModel.setReplyingTo(it) },
                    onCancelReply = { viewModel.setReplyingTo(null) },
                    onToggleReaction = { viewModel.toggleReaction(it) },
                    onToggleBookmark = { viewModel.toggleBookmark() },
                    onToggleCommentReaction = { id, type -> viewModel.toggleCommentReaction(id, type) },
                    onMarkBestAnswer = { viewModel.markAsBestAnswer(it) }
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ForumPostDetailContent(
    post: ForumPost,
    comments: List<ForumComment>,
    isLoadingComments: Boolean,
    commentText: String,
    isSubmittingComment: Boolean,
    replyingToComment: ForumComment?,
    reactions: ReactionsSummary,
    isBookmarked: Boolean,
    onNavigateBack: () -> Unit,
    onCommentTextChange: (String) -> Unit,
    onSubmitComment: () -> Unit,
    onReplyToComment: (ForumComment) -> Unit,
    onCancelReply: () -> Unit,
    onToggleReaction: (String) -> Unit,
    onToggleBookmark: () -> Unit,
    onToggleCommentReaction: (Int, String) -> Unit,
    onMarkBestAnswer: (Int) -> Unit
) {
    val palette = LocalThemePalette.current

    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = post.postType.displayName,
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
                actions = {
                    IconButton(onClick = onToggleBookmark) {
                        Icon(
                            if (isBookmarked) Icons.Filled.Bookmark else Icons.Filled.BookmarkBorder,
                            contentDescription = "Bookmark",
                            tint = if (isBookmarked) palette.primaryColor else Color.White
                        )
                    }
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
        },
        bottomBar = {
            CommentInputBar(
                text = commentText,
                isSubmitting = isSubmittingComment,
                replyingTo = replyingToComment,
                onTextChange = onCommentTextChange,
                onSubmit = onSubmitComment,
                onCancelReply = onCancelReply
            )
        }
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues),
            contentPadding = PaddingValues(bottom = 16.dp)
        ) {
            // Post content
            item {
                PostContent(
                    post = post,
                    reactions = reactions,
                    onToggleReaction = onToggleReaction
                )
            }

            // Comments header
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = Spacing.lg, vertical = Spacing.md),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Comments (${post.commentsCount})",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )

                    if (isLoadingComments) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(20.dp),
                            strokeWidth = 2.dp,
                            color = palette.primaryColor
                        )
                    }
                }
            }

            // Comments list
            if (comments.isEmpty() && !isLoadingComments) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(Spacing.lg),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Icon(
                                Icons.Default.Forum,
                                contentDescription = null,
                                modifier = Modifier.size(48.dp),
                                tint = Color.White.copy(alpha = 0.5f)
                            )
                            Spacer(modifier = Modifier.height(Spacing.sm))
                            Text(
                                text = "No comments yet",
                                color = Color.White.copy(alpha = 0.6f)
                            )
                            Text(
                                text = "Be the first to share your thoughts!",
                                style = MaterialTheme.typography.bodySmall,
                                color = Color.White.copy(alpha = 0.4f)
                            )
                        }
                    }
                }
            }

            items(
                items = comments,
                key = { it.id }
            ) { comment ->
                CommentRow(
                    comment = comment,
                    isPostOwner = post.userId == comment.userId,
                    onReply = { onReplyToComment(comment) },
                    onToggleReaction = { onToggleCommentReaction(comment.id, it) },
                    onMarkBestAnswer = { onMarkBestAnswer(comment.id) },
                    modifier = Modifier.padding(
                        start = (comment.depth * 24).dp + Spacing.lg,
                        end = Spacing.lg,
                        top = Spacing.xs,
                        bottom = Spacing.xs
                    )
                )
            }
        }
    }
}

@Composable
private fun PostContent(
    post: ForumPost,
    reactions: ReactionsSummary,
    onToggleReaction: (String) -> Unit
) {
    val palette = LocalThemePalette.current

    Column(
        modifier = Modifier.padding(Spacing.lg)
    ) {
        // Author info
        Row(
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Avatar
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(palette.primaryColor.copy(alpha = 0.3f)),
                contentAlignment = Alignment.Center
            ) {
                if (post.author?.avatarUrl != null) {
                    AsyncImage(
                        model = post.author.avatarUrl,
                        contentDescription = post.author.displayName,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop
                    )
                } else {
                    Text(
                        text = (post.author?.displayName ?: "A").take(1).uppercase(),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = palette.primaryColor
                    )
                }
            }

            Spacer(modifier = Modifier.width(Spacing.sm))

            Column {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Spacing.xs)
                ) {
                    Text(
                        text = post.author?.displayName ?: "Anonymous",
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                    if (post.author?.isVerified == true) {
                        Icon(
                            Icons.Default.Verified,
                            contentDescription = "Verified",
                            modifier = Modifier.size(16.dp),
                            tint = palette.primaryColor
                        )
                    }
                }
                Text(
                    text = post.createdAt.take(10), // Simple date display
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White.copy(alpha = 0.6f)
                )
            }

            Spacer(modifier = Modifier.weight(1f))

            // Post type badge
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(palette.primaryColor.copy(alpha = 0.2f))
                    .padding(horizontal = Spacing.sm, vertical = Spacing.xxs)
            ) {
                Text(
                    text = post.postType.displayName,
                    style = MaterialTheme.typography.labelSmall,
                    color = palette.primaryColor
                )
            }
        }

        Spacer(modifier = Modifier.height(Spacing.md))

        // Title
        Text(
            text = post.title,
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )

        // Pinned/Featured badges
        if (post.isPinned || post.isFeatured) {
            Spacer(modifier = Modifier.height(Spacing.xs))
            Row(
                horizontalArrangement = Arrangement.spacedBy(Spacing.xs)
            ) {
                if (post.isPinned) {
                    BadgeChip(text = "Pinned", icon = Icons.Default.PushPin)
                }
                if (post.isFeatured) {
                    BadgeChip(text = "Featured", icon = Icons.Default.Star)
                }
            }
        }

        Spacer(modifier = Modifier.height(Spacing.md))

        // Post image
        if (post.imageUrl != null) {
            AsyncImage(
                model = post.imageUrl,
                contentDescription = null,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp)
                    .clip(RoundedCornerShape(12.dp)),
                contentScale = ContentScale.Crop
            )
            Spacer(modifier = Modifier.height(Spacing.md))
        }

        // Description
        Text(
            text = post.description,
            style = MaterialTheme.typography.bodyLarge,
            color = Color.White.copy(alpha = 0.9f)
        )

        Spacer(modifier = Modifier.height(Spacing.md))

        // Category tag
        if (post.category != null) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(LiquidGlassColors.Glass.background)
                    .border(
                        width = 1.dp,
                        color = LiquidGlassColors.Glass.border,
                        shape = RoundedCornerShape(50)
                    )
                    .padding(horizontal = Spacing.sm, vertical = Spacing.xxs)
            ) {
                Text(
                    text = post.category.name,
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.White.copy(alpha = 0.8f)
                )
            }
        }

        Spacer(modifier = Modifier.height(Spacing.md))

        // Stats row
        Row(
            horizontalArrangement = Arrangement.spacedBy(Spacing.lg)
        ) {
            StatChip(icon = Icons.Default.Visibility, value = post.viewsCount.toString())
            StatChip(icon = Icons.Default.ThumbUp, value = post.likesCount.toString())
            StatChip(icon = Icons.Default.Comment, value = post.commentsCount.toString())
        }

        Spacer(modifier = Modifier.height(Spacing.md))

        // Reactions bar
        ReactionBar(
            reactions = reactions,
            onToggleReaction = onToggleReaction
        )
    }
}

@Composable
private fun BadgeChip(text: String, icon: androidx.compose.ui.graphics.vector.ImageVector) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(LiquidGlassColors.brandPink.copy(alpha = 0.2f))
            .padding(horizontal = Spacing.sm, vertical = Spacing.xxs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.xxs)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(12.dp),
            tint = LiquidGlassColors.brandPink
        )
        Text(
            text = text,
            style = MaterialTheme.typography.labelSmall,
            color = LiquidGlassColors.brandPink
        )
    }
}

@Composable
private fun StatChip(icon: androidx.compose.ui.graphics.vector.ImageVector, value: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.xxs)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(16.dp),
            tint = Color.White.copy(alpha = 0.6f)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodySmall,
            color = Color.White.copy(alpha = 0.6f)
        )
    }
}

@Composable
private fun ReactionBar(
    reactions: ReactionsSummary,
    onToggleReaction: (String) -> Unit
) {
    val palette = LocalThemePalette.current
    val reactionTypes = ReactionType.defaults

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(LiquidGlassColors.Glass.background)
            .padding(Spacing.sm),
        horizontalArrangement = Arrangement.SpaceEvenly
    ) {
        reactionTypes.take(4).forEach { reaction ->
            val count = reactions.reactions[reaction.id] ?: 0
            val hasReacted = reactions.hasUserReacted(reaction.id)

            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .clickable { onToggleReaction(reaction.id) }
                    .background(
                        if (hasReacted) palette.primaryColor.copy(alpha = 0.2f)
                        else Color.Transparent
                    )
                    .padding(horizontal = Spacing.sm, vertical = Spacing.xs)
            ) {
                Text(
                    text = reaction.emoji,
                    style = MaterialTheme.typography.titleMedium
                )
                if (count > 0) {
                    Text(
                        text = count.toString(),
                        style = MaterialTheme.typography.labelSmall,
                        color = if (hasReacted) palette.primaryColor else Color.White.copy(alpha = 0.6f)
                    )
                }
            }
        }
    }
}

@Composable
private fun CommentRow(
    comment: ForumComment,
    isPostOwner: Boolean,
    onReply: () -> Unit,
    onToggleReaction: (String) -> Unit,
    onMarkBestAnswer: () -> Unit,
    modifier: Modifier = Modifier
) {
    val palette = LocalThemePalette.current

    GlassCard(modifier = modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(Spacing.sm)
        ) {
            // Author row
            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Avatar
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(palette.primaryColor.copy(alpha = 0.3f)),
                    contentAlignment = Alignment.Center
                ) {
                    if (comment.author?.avatarUrl != null) {
                        AsyncImage(
                            model = comment.author.avatarUrl,
                            contentDescription = null,
                            modifier = Modifier.fillMaxSize(),
                            contentScale = ContentScale.Crop
                        )
                    } else {
                        Text(
                            text = (comment.author?.displayName ?: "A").take(1).uppercase(),
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.Bold,
                            color = palette.primaryColor
                        )
                    }
                }

                Spacer(modifier = Modifier.width(Spacing.xs))

                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = comment.author?.displayName ?: "Anonymous",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                    Text(
                        text = comment.createdAt.take(10),
                        style = MaterialTheme.typography.labelSmall,
                        color = Color.White.copy(alpha = 0.5f)
                    )
                }

                if (comment.isBestAnswer) {
                    Icon(
                        Icons.Default.CheckCircle,
                        contentDescription = "Best Answer",
                        modifier = Modifier.size(20.dp),
                        tint = LiquidGlassColors.success
                    )
                }
            }

            Spacer(modifier = Modifier.height(Spacing.xs))

            // Comment text
            Text(
                text = comment.comment,
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(alpha = 0.9f)
            )

            Spacer(modifier = Modifier.height(Spacing.xs))

            // Actions row
            Row(
                horizontalArrangement = Arrangement.spacedBy(Spacing.md),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Like button
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .clickable { onToggleReaction("like") }
                        .padding(Spacing.xxs)
                ) {
                    Icon(
                        Icons.Default.ThumbUp,
                        contentDescription = "Like",
                        modifier = Modifier.size(16.dp),
                        tint = Color.White.copy(alpha = 0.6f)
                    )
                    if (comment.likesCount > 0) {
                        Spacer(modifier = Modifier.width(Spacing.xxs))
                        Text(
                            text = comment.likesCount.toString(),
                            style = MaterialTheme.typography.labelSmall,
                            color = Color.White.copy(alpha = 0.6f)
                        )
                    }
                }

                // Reply button
                if (comment.depth < ForumComment.MAX_DEPTH) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .clickable { onReply() }
                            .padding(Spacing.xxs)
                    ) {
                        Icon(
                            Icons.AutoMirrored.Filled.Reply,
                            contentDescription = "Reply",
                            modifier = Modifier.size(16.dp),
                            tint = Color.White.copy(alpha = 0.6f)
                        )
                        Spacer(modifier = Modifier.width(Spacing.xxs))
                        Text(
                            text = "Reply",
                            style = MaterialTheme.typography.labelSmall,
                            color = Color.White.copy(alpha = 0.6f)
                        )
                    }
                }

                // Mark as best answer (only for post owner)
                if (isPostOwner && !comment.isBestAnswer) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .clickable { onMarkBestAnswer() }
                            .padding(Spacing.xxs)
                    ) {
                        Icon(
                            Icons.Default.Check,
                            contentDescription = "Mark as Best",
                            modifier = Modifier.size(16.dp),
                            tint = LiquidGlassColors.success
                        )
                        Spacer(modifier = Modifier.width(Spacing.xxs))
                        Text(
                            text = "Best Answer",
                            style = MaterialTheme.typography.labelSmall,
                            color = LiquidGlassColors.success
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun CommentInputBar(
    text: String,
    isSubmitting: Boolean,
    replyingTo: ForumComment?,
    onTextChange: (String) -> Unit,
    onSubmit: () -> Unit,
    onCancelReply: () -> Unit
) {
    val palette = LocalThemePalette.current

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                brush = Brush.verticalGradient(
                    colors = listOf(
                        Color.Transparent,
                        Color.Black.copy(alpha = 0.8f)
                    )
                )
            )
            .padding(Spacing.md)
    ) {
        // Reply indicator
        AnimatedVisibility(visible = replyingTo != null) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = Spacing.xs),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    Icons.AutoMirrored.Filled.Reply,
                    contentDescription = null,
                    modifier = Modifier.size(16.dp),
                    tint = palette.primaryColor
                )
                Spacer(modifier = Modifier.width(Spacing.xs))
                Text(
                    text = "Replying to ${replyingTo?.author?.displayName ?: "comment"}",
                    style = MaterialTheme.typography.labelSmall,
                    color = palette.primaryColor,
                    modifier = Modifier.weight(1f)
                )
                IconButton(
                    onClick = onCancelReply,
                    modifier = Modifier.size(24.dp)
                ) {
                    Icon(
                        Icons.Default.Close,
                        contentDescription = "Cancel reply",
                        modifier = Modifier.size(16.dp),
                        tint = Color.White.copy(alpha = 0.6f)
                    )
                }
            }
        }

        // Input field
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(24.dp))
                .background(LiquidGlassColors.Glass.background)
                .border(
                    width = 1.dp,
                    color = LiquidGlassColors.Glass.border,
                    shape = RoundedCornerShape(24.dp)
                )
                .padding(horizontal = Spacing.md, vertical = Spacing.sm),
            verticalAlignment = Alignment.CenterVertically
        ) {
            BasicTextField(
                value = text,
                onValueChange = onTextChange,
                textStyle = MaterialTheme.typography.bodyMedium.copy(
                    color = Color.White
                ),
                cursorBrush = SolidColor(palette.primaryColor),
                modifier = Modifier.weight(1f),
                decorationBox = { innerTextField ->
                    Box {
                        if (text.isEmpty()) {
                            Text(
                                text = "Write a comment...",
                                style = MaterialTheme.typography.bodyMedium,
                                color = Color.White.copy(alpha = 0.5f)
                            )
                        }
                        innerTextField()
                    }
                }
            )

            Spacer(modifier = Modifier.width(Spacing.sm))

            IconButton(
                onClick = onSubmit,
                enabled = text.isNotBlank() && !isSubmitting,
                modifier = Modifier.size(36.dp)
            ) {
                if (isSubmitting) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        strokeWidth = 2.dp,
                        color = palette.primaryColor
                    )
                } else {
                    Icon(
                        Icons.AutoMirrored.Filled.Send,
                        contentDescription = "Send",
                        tint = if (text.isNotBlank()) palette.primaryColor else Color.White.copy(alpha = 0.3f)
                    )
                }
            }
        }
    }
}
