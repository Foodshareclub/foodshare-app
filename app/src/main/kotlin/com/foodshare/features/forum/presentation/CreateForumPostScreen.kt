package com.foodshare.features.forum.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.foodshare.features.forum.domain.model.*
import com.foodshare.features.forum.presentation.components.ForumCategoryChip
import com.foodshare.features.forum.presentation.components.ForumPostTypeChip
import com.foodshare.ui.design.components.buttons.GlassButton
import com.foodshare.ui.design.components.inputs.GlassTextField
import com.foodshare.ui.design.modifiers.glassBackground
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing
import com.foodshare.ui.theme.LocalThemePalette

/**
 * Create Forum Post Screen
 *
 * SYNC: This mirrors Swift CreateForumPostView
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateForumPostScreen(
    onNavigateBack: () -> Unit,
    onPostCreated: () -> Unit = {},
    viewModel: CreateForumPostViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val palette = LocalThemePalette.current

    // Navigate back on success
    LaunchedEffect(uiState.isSuccess) {
        if (uiState.isSuccess) {
            onPostCreated()
            onNavigateBack()
        }
    }

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
                            text = "New Post",
                            color = Color.White
                        )
                    },
                    navigationIcon = {
                        IconButton(onClick = onNavigateBack) {
                            Icon(
                                Icons.Default.Close,
                                contentDescription = "Close",
                                tint = Color.White
                            )
                        }
                    },
                    actions = {
                        TextButton(
                            onClick = { viewModel.submitPost() },
                            enabled = uiState.isValid && !uiState.isSubmitting
                        ) {
                            if (uiState.isSubmitting) {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(20.dp),
                                    strokeWidth = 2.dp,
                                    color = palette.primaryColor
                                )
                            } else {
                                Text(
                                    text = "Post",
                                    color = if (uiState.isValid) palette.primaryColor else Color.White.copy(alpha = 0.3f),
                                    fontWeight = FontWeight.Bold
                                )
                            }
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
                contentPadding = PaddingValues(Spacing.lg)
            ) {
                // Post Type Selector
                item {
                    Text(
                        text = "Post Type",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White,
                        modifier = Modifier.padding(bottom = Spacing.sm)
                    )

                    LazyRow(
                        horizontalArrangement = Arrangement.spacedBy(Spacing.sm)
                    ) {
                        items(ForumPostType.entries) { postType ->
                            ForumPostTypeChip(
                                postType = postType,
                                isSelected = uiState.postType == postType,
                                onClick = { viewModel.selectPostType(postType) }
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(Spacing.lg))
                }

                // Category Selector
                item {
                    Text(
                        text = "Category (Optional)",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White,
                        modifier = Modifier.padding(bottom = Spacing.sm)
                    )

                    LazyRow(
                        horizontalArrangement = Arrangement.spacedBy(Spacing.sm)
                    ) {
                        items(uiState.categories) { category ->
                            ForumCategoryChip(
                                category = category,
                                isSelected = uiState.selectedCategory?.id == category.id,
                                onClick = {
                                    viewModel.selectCategory(
                                        if (uiState.selectedCategory?.id == category.id) null else category
                                    )
                                }
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(Spacing.lg))
                }

                // Title Input
                item {
                    Text(
                        text = "Title",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White,
                        modifier = Modifier.padding(bottom = Spacing.sm)
                    )

                    GlassInputField(
                        value = uiState.title,
                        onValueChange = { viewModel.updateTitle(it) },
                        placeholder = "What's on your mind?",
                        error = uiState.titleError,
                        maxLines = 2
                    )

                    Spacer(modifier = Modifier.height(Spacing.lg))
                }

                // Description Input
                item {
                    Text(
                        text = "Description",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White,
                        modifier = Modifier.padding(bottom = Spacing.sm)
                    )

                    GlassInputField(
                        value = uiState.description,
                        onValueChange = { viewModel.updateDescription(it) },
                        placeholder = "Share more details...",
                        error = uiState.descriptionError,
                        minHeight = 200.dp,
                        maxLines = Int.MAX_VALUE
                    )

                    // Character count
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = Spacing.xs),
                        horizontalArrangement = Arrangement.End
                    ) {
                        Text(
                            text = "${uiState.description.length} / 10000",
                            style = MaterialTheme.typography.labelSmall,
                            color = if (uiState.description.length > 10000)
                                LiquidGlassColors.error
                            else
                                Color.White.copy(alpha = 0.5f)
                        )
                    }

                    Spacer(modifier = Modifier.height(Spacing.lg))
                }

                // Error message
                if (uiState.error != null) {
                    item {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(12.dp))
                                .background(LiquidGlassColors.error.copy(alpha = 0.2f))
                                .border(
                                    width = 1.dp,
                                    color = LiquidGlassColors.error.copy(alpha = 0.5f),
                                    shape = RoundedCornerShape(12.dp)
                                )
                                .padding(Spacing.md)
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    Icons.Default.Error,
                                    contentDescription = null,
                                    tint = LiquidGlassColors.error,
                                    modifier = Modifier.size(20.dp)
                                )
                                Spacer(modifier = Modifier.width(Spacing.sm))
                                Text(
                                    text = uiState.error!!,
                                    color = LiquidGlassColors.error,
                                    style = MaterialTheme.typography.bodySmall
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(Spacing.md))
                    }
                }

                // Submit Button
                item {
                    GlassButton(
                        text = if (uiState.isSubmitting) "Posting..." else "Create Post",
                        onClick = { viewModel.submitPost() },
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                // Tips section
                item {
                    Spacer(modifier = Modifier.height(Spacing.xl))

                    Text(
                        text = "Tips for a great post",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White.copy(alpha = 0.7f),
                        modifier = Modifier.padding(bottom = Spacing.sm)
                    )

                    Column(
                        verticalArrangement = Arrangement.spacedBy(Spacing.xs)
                    ) {
                        TipItem(text = "Use a clear, descriptive title")
                        TipItem(text = "Choose the right category for visibility")
                        TipItem(text = "Be specific and provide context")
                        TipItem(text = "Use 'Question' type if you need help")
                    }
                }
            }
        }
    }
}

@Composable
private fun GlassInputField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    error: String? = null,
    minHeight: androidx.compose.ui.unit.Dp = 56.dp,
    maxLines: Int = 1
) {
    val palette = LocalThemePalette.current

    Column {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = minHeight)
                .clip(RoundedCornerShape(12.dp))
                .background(LiquidGlassColors.Glass.background)
                .border(
                    width = 1.dp,
                    color = if (error != null) LiquidGlassColors.error.copy(alpha = 0.5f)
                    else LiquidGlassColors.Glass.border,
                    shape = RoundedCornerShape(12.dp)
                )
                .padding(Spacing.md)
        ) {
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                textStyle = MaterialTheme.typography.bodyLarge.copy(
                    color = Color.White
                ),
                cursorBrush = SolidColor(palette.primaryColor),
                maxLines = maxLines,
                modifier = Modifier.fillMaxWidth(),
                decorationBox = { innerTextField ->
                    Box {
                        if (value.isEmpty()) {
                            Text(
                                text = placeholder,
                                style = MaterialTheme.typography.bodyLarge,
                                color = Color.White.copy(alpha = 0.4f)
                            )
                        }
                        innerTextField()
                    }
                }
            )
        }

        if (error != null) {
            Text(
                text = error,
                style = MaterialTheme.typography.labelSmall,
                color = LiquidGlassColors.error,
                modifier = Modifier.padding(start = Spacing.sm, top = Spacing.xxs)
            )
        }
    }
}

@Composable
private fun TipItem(text: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            Icons.Default.Lightbulb,
            contentDescription = null,
            modifier = Modifier.size(14.dp),
            tint = Color.White.copy(alpha = 0.4f)
        )
        Spacer(modifier = Modifier.width(Spacing.xs))
        Text(
            text = text,
            style = MaterialTheme.typography.bodySmall,
            color = Color.White.copy(alpha = 0.5f)
        )
    }
}
