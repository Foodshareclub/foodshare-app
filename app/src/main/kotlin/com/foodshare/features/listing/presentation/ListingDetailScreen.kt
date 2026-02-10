package com.foodshare.features.listing.presentation

import android.content.Intent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.RemoveRedEye
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import com.foodshare.domain.model.ListingStatus
import com.foodshare.domain.model.PostType
import com.foodshare.ui.design.components.buttons.GlassButton
import com.foodshare.ui.design.components.buttons.GlassButtonStyle
import com.foodshare.ui.design.components.cards.GlassCard
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing
import kotlinx.coroutines.launch

/**
 * Listing Detail Screen with Liquid Glass design
 *
 * Features:
 * - Image carousel with page indicators
 * - Glass info sections
 * - Contact/claim button
 * - Share functionality
 * - Favorite toggle
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun ListingDetailScreen(
    onNavigateBack: () -> Unit,
    onContactOwner: ((Int) -> Unit)? = null,
    modifier: Modifier = Modifier,
    viewModel: ListingDetailViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    // Show error in snackbar
    LaunchedEffect(uiState.error) {
        uiState.error?.let { error ->
            snackbarHostState.showSnackbar(error)
            viewModel.clearError()
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            DetailTopBar(
                onBack = onNavigateBack,
                onShare = {
                    uiState.listing?.let { listing ->
                        val shareIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_SUBJECT, listing.title)
                            putExtra(
                                Intent.EXTRA_TEXT,
                                "Check out this listing on Foodshare: ${listing.title}"
                            )
                        }
                        context.startActivity(
                            Intent.createChooser(shareIntent, "Share listing")
                        )
                    }
                },
                onFavorite = { viewModel.toggleFavorite() },
                isFavorite = uiState.isFavorite
            )
        },
        containerColor = Color.Transparent,
        modifier = modifier.background(brush = LiquidGlassGradients.darkAuth)
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            when {
                uiState.isLoading -> {
                    LoadingState()
                }

                uiState.error != null && uiState.listing == null -> {
                    ErrorState(
                        message = uiState.error ?: "Something went wrong",
                        onRetry = { viewModel.retry() }
                    )
                }

                uiState.listing != null -> {
                    DetailContent(
                        uiState = uiState,
                        onPageChanged = { viewModel.setCurrentImageIndex(it) },
                        onContactOwner = {
                            uiState.listing?.id?.let { id ->
                                onContactOwner?.invoke(id)
                            }
                        }
                    )
                }

                else -> {
                    EmptyState()
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DetailTopBar(
    onBack: () -> Unit,
    onShare: () -> Unit,
    onFavorite: () -> Unit,
    isFavorite: Boolean
) {
    TopAppBar(
        navigationIcon = {
            IconButton(onClick = onBack) {
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(Color.Black.copy(alpha = 0.3f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back",
                        tint = Color.White
                    )
                }
            }
        },
        title = { },
        actions = {
            IconButton(onClick = onShare) {
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(Color.Black.copy(alpha = 0.3f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Share,
                        contentDescription = "Share",
                        tint = Color.White,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
            IconButton(onClick = onFavorite) {
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(Color.Black.copy(alpha = 0.3f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = if (isFavorite) Icons.Default.Favorite else Icons.Default.FavoriteBorder,
                        contentDescription = if (isFavorite) "Remove from favorites" else "Add to favorites",
                        tint = if (isFavorite) LiquidGlassColors.brandPink else Color.White,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        },
        colors = TopAppBarDefaults.topAppBarColors(
            containerColor = Color.Transparent
        )
    )
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun DetailContent(
    uiState: ListingDetailUiState,
    onPageChanged: (Int) -> Unit,
    onContactOwner: () -> Unit
) {
    val scrollState = rememberScrollState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(scrollState)
            .windowInsetsPadding(WindowInsets.navigationBars)
    ) {
        // Image Carousel
        ImageCarousel(
            images = uiState.images,
            currentIndex = uiState.currentImageIndex,
            onPageChanged = onPageChanged,
            postType = uiState.postType
        )

        // Content sections
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.md)
        ) {
            Spacer(Modifier.height(Spacing.sm))

            // Title & Status Section
            TitleSection(
                title = uiState.title,
                status = uiState.status,
                postType = uiState.postType
            )

            // Quick Info Row
            QuickInfoRow(
                distance = uiState.distanceDisplay,
                viewCount = uiState.viewCount,
                likeCount = uiState.likeCount
            )

            // Description Section
            uiState.description?.let { desc ->
                if (desc.isNotBlank()) {
                    DescriptionSection(description = desc)
                }
            }

            // Pickup Info Section
            PickupInfoSection(
                address = uiState.address,
                pickupTime = uiState.pickupTime
            )

            // Owner Section
            OwnerSection()

            Spacer(Modifier.height(Spacing.sm))

            // Contact Button
            if (uiState.isClaimable) {
                GlassButton(
                    text = "Contact Sharer",
                    onClick = onContactOwner,
                    icon = Icons.AutoMirrored.Filled.Chat,
                    style = GlassButtonStyle.Primary,
                    modifier = Modifier.fillMaxWidth()
                )
            } else {
                GlassButton(
                    text = "Not Available",
                    onClick = { },
                    style = GlassButtonStyle.Secondary,
                    enabled = false,
                    modifier = Modifier.fillMaxWidth()
                )
            }

            Spacer(Modifier.height(Spacing.xl))
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun ImageCarousel(
    images: List<String>,
    currentIndex: Int,
    onPageChanged: (Int) -> Unit,
    postType: PostType?
) {
    val pagerState = rememberPagerState(initialPage = currentIndex) { images.size.coerceAtLeast(1) }

    LaunchedEffect(pagerState.currentPage) {
        onPageChanged(pagerState.currentPage)
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(1f)
    ) {
        if (images.isNotEmpty()) {
            HorizontalPager(
                state = pagerState,
                modifier = Modifier.fillMaxSize()
            ) { page ->
                AsyncImage(
                    model = images[page],
                    contentDescription = "Listing image ${page + 1}",
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )
            }

            // Page indicators
            if (images.size > 1) {
                Row(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = Spacing.md),
                    horizontalArrangement = Arrangement.spacedBy(Spacing.xs)
                ) {
                    repeat(images.size) { index ->
                        val isSelected = pagerState.currentPage == index
                        Box(
                            modifier = Modifier
                                .size(if (isSelected) 10.dp else 8.dp)
                                .clip(CircleShape)
                                .background(
                                    if (isSelected) Color.White
                                    else Color.White.copy(alpha = 0.5f)
                                )
                        )
                    }
                }
            }
        } else {
            // Placeholder when no images
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.linearGradient(
                            colors = listOf(
                                getCategoryColor(postType).copy(alpha = 0.3f),
                                getCategoryColor(postType).copy(alpha = 0.5f)
                            )
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.FavoriteBorder,
                    contentDescription = null,
                    tint = Color.White.copy(alpha = 0.5f),
                    modifier = Modifier.size(80.dp)
                )
            }
        }

        // Gradient overlay at bottom for readability
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(80.dp)
                .align(Alignment.BottomCenter)
                .background(
                    Brush.verticalGradient(
                        colors = listOf(Color.Transparent, Color.Black.copy(alpha = 0.5f))
                    )
                )
        )
    }
}

@Composable
private fun TitleSection(
    title: String,
    status: ListingStatus,
    postType: PostType?
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.Top
    ) {
        Column(modifier = Modifier.weight(1f)) {
            // Category badge
            postType?.let { type ->
                Row(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(getCategoryColor(type).copy(alpha = 0.9f))
                        .padding(horizontal = Spacing.sm, vertical = Spacing.xxs),
                    horizontalArrangement = Arrangement.spacedBy(Spacing.xxs),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = getCategoryLabel(type),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                }

                Spacer(Modifier.height(Spacing.xs))
            }

            // Title
            Text(
                text = title,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
        }

        // Status badge
        StatusBadge(status = status)
    }
}

@Composable
private fun StatusBadge(status: ListingStatus) {
    val color = when (status) {
        ListingStatus.AVAILABLE -> LiquidGlassColors.success
        ListingStatus.ARRANGED -> LiquidGlassColors.warning
        ListingStatus.INACTIVE -> Color.Gray
    }

    Text(
        text = status.displayName,
        style = MaterialTheme.typography.labelMedium,
        fontWeight = FontWeight.SemiBold,
        color = Color.White,
        modifier = Modifier
            .clip(RoundedCornerShape(CornerRadius.medium))
            .background(color)
            .padding(horizontal = Spacing.sm, vertical = Spacing.xxs)
    )
}

@Composable
private fun QuickInfoRow(
    distance: String?,
    viewCount: Int,
    likeCount: Int
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(Spacing.md)
    ) {
        distance?.let {
            InfoChip(
                icon = Icons.Default.LocationOn,
                text = it
            )
        }
        InfoChip(
            icon = Icons.Default.RemoveRedEye,
            text = "$viewCount views"
        )
        if (likeCount > 0) {
            InfoChip(
                icon = Icons.Default.Favorite,
                text = "$likeCount",
                iconTint = LiquidGlassColors.brandPink
            )
        }
    }
}

@Composable
private fun InfoChip(
    icon: ImageVector,
    text: String,
    iconTint: Color = Color.White.copy(alpha = 0.7f)
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(Spacing.xxs),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = iconTint,
            modifier = Modifier.size(16.dp)
        )
        Text(
            text = text,
            style = MaterialTheme.typography.bodySmall,
            color = Color.White.copy(alpha = 0.7f)
        )
    }
}

@Composable
private fun DescriptionSection(description: String) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(Spacing.md)
        ) {
            Text(
                text = "Description",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = Color.White
            )
            Spacer(Modifier.height(Spacing.xs))
            Text(
                text = description,
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(alpha = 0.8f)
            )
        }
    }
}

@Composable
private fun PickupInfoSection(
    address: String?,
    pickupTime: String?
) {
    if (address == null && pickupTime == null) return

    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm)
        ) {
            Text(
                text = "Pickup Details",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = Color.White
            )

            address?.let {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                    verticalAlignment = Alignment.Top
                ) {
                    Icon(
                        imageVector = Icons.Default.LocationOn,
                        contentDescription = null,
                        tint = LiquidGlassColors.brandTeal,
                        modifier = Modifier.size(20.dp)
                    )
                    Text(
                        text = it,
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color.White.copy(alpha = 0.8f)
                    )
                }
            }

            pickupTime?.let {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.AccessTime,
                        contentDescription = null,
                        tint = LiquidGlassColors.brandPink,
                        modifier = Modifier.size(20.dp)
                    )
                    Text(
                        text = it,
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color.White.copy(alpha = 0.8f)
                    )
                }
            }
        }
    }
}

@Composable
private fun OwnerSection() {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.md),
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Avatar
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(brush = LiquidGlassGradients.brand)
                    .border(
                        width = 2.dp,
                        color = Color.White.copy(alpha = 0.3f),
                        shape = CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.Person,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(24.dp)
                )
            }

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "Sharer",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White
                )
                Text(
                    text = "View profile",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White.copy(alpha = 0.6f)
                )
            }
        }
    }
}

@Composable
private fun LoadingState() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        CircularProgressIndicator(
            color = LiquidGlassColors.brandTeal,
            modifier = Modifier.size(48.dp)
        )
    }
}

@Composable
private fun ErrorState(
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
                    imageVector = Icons.Default.Warning,
                    contentDescription = null,
                    tint = LiquidGlassColors.warning,
                    modifier = Modifier.size(48.dp)
                )
                Spacer(Modifier.height(Spacing.md))
                Text(
                    text = message,
                    style = MaterialTheme.typography.bodyLarge,
                    color = Color.White,
                    fontWeight = FontWeight.Medium
                )
                Spacer(Modifier.height(Spacing.lg))
                GlassButton(
                    text = "Try Again",
                    onClick = onRetry,
                    style = GlassButtonStyle.Primary
                )
            }
        }
    }
}

@Composable
private fun EmptyState() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = "Listing not found",
            style = MaterialTheme.typography.bodyLarge,
            color = Color.White.copy(alpha = 0.6f)
        )
    }
}

// Helper functions

private fun getCategoryColor(postType: PostType?): Color = when (postType) {
    PostType.FOOD -> LiquidGlassColors.Category.food
    PostType.THING -> LiquidGlassColors.Category.thing
    PostType.BORROW -> LiquidGlassColors.Category.borrow
    PostType.WANTED -> LiquidGlassColors.Category.wanted
    PostType.FRIDGE -> LiquidGlassColors.Category.fridge
    PostType.FOODBANK -> LiquidGlassColors.Category.foodbank
    PostType.BUSINESS -> LiquidGlassColors.Category.business
    PostType.VOLUNTEER -> LiquidGlassColors.Category.volunteer
    PostType.CHALLENGE -> LiquidGlassColors.Category.challenge
    PostType.ZEROWASTE -> LiquidGlassColors.Category.zerowaste
    PostType.VEGAN -> LiquidGlassColors.Category.vegan
    PostType.COMMUNITY -> LiquidGlassColors.Category.community
    null -> LiquidGlassColors.Category.food
}

private fun getCategoryLabel(postType: PostType): String = when (postType) {
    PostType.FOOD -> "Free Food"
    PostType.THING -> "Thing"
    PostType.BORROW -> "Borrow"
    PostType.WANTED -> "Wanted"
    PostType.FRIDGE -> "Community Fridge"
    PostType.FOODBANK -> "Food Bank"
    PostType.BUSINESS -> "Business"
    PostType.VOLUNTEER -> "Volunteer"
    PostType.CHALLENGE -> "Challenge"
    PostType.ZEROWASTE -> "Zero Waste"
    PostType.VEGAN -> "Vegan"
    PostType.COMMUNITY -> "Community"
}
