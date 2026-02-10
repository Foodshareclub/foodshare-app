package com.foodshare.features.create.presentation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.foodshare.domain.model.PostType
import com.foodshare.features.create.presentation.components.LocationPicker
import com.foodshare.features.create.presentation.components.PhotoPicker
import com.foodshare.ui.design.components.buttons.GlassButton
import com.foodshare.ui.design.components.buttons.GlassButtonStyle
import com.foodshare.ui.design.components.cards.GlassCard
import com.foodshare.ui.design.components.inputs.GlassTextField
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing

/**
 * Screen for creating new food listings
 *
 * Features:
 * - Photo picker
 * - Title and description fields
 * - Post type selection
 * - Pickup time and location
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateListingScreen(
    onClose: () -> Unit,
    onSuccess: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: CreateListingViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Share Food",
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onClose) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Close",
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
        modifier = modifier.background(brush = LiquidGlassGradients.darkAuth)
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = Spacing.md)
        ) {
            // Photo Picker
            PhotoPicker(
                selectedImages = uiState.imageUris,
                onImagesSelected = viewModel::addImages,
                onImageRemoved = viewModel::removeImage
            )

            Spacer(Modifier.height(Spacing.lg))

            // Form Card
            GlassCard(
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(Spacing.lg),
                    verticalArrangement = Arrangement.spacedBy(Spacing.md)
                ) {
                    // Title
                    GlassTextField(
                        value = uiState.title,
                        onValueChange = viewModel::updateTitle,
                        label = "What are you sharing?",
                        placeholder = "e.g., Fresh vegetables, Baked goods...",
                        error = uiState.titleError,
                        imeAction = ImeAction.Next,
                        modifier = Modifier.fillMaxWidth()
                    )

                    // Description
                    GlassTextField(
                        value = uiState.description,
                        onValueChange = viewModel::updateDescription,
                        label = "Description (optional)",
                        placeholder = "Add more details about your items...",
                        error = uiState.descriptionError,
                        singleLine = false,
                        minLines = 3,
                        maxLines = 5,
                        imeAction = ImeAction.Default,
                        modifier = Modifier.fillMaxWidth()
                    )

                    // Post Type Selection
                    Text(
                        text = "Category",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Medium,
                        color = Color.White
                    )

                    PostTypeSelector(
                        selectedType = uiState.selectedPostType,
                        onTypeSelected = viewModel::updatePostType
                    )

                    // Pickup Time
                    GlassTextField(
                        value = uiState.pickupTime,
                        onValueChange = viewModel::updatePickupTime,
                        label = "Pickup Time",
                        placeholder = "e.g., Today 5-7pm, Anytime tomorrow...",
                        imeAction = ImeAction.Next,
                        modifier = Modifier.fillMaxWidth()
                    )

                    // Location Picker
                    LocationPicker(
                        currentAddress = uiState.address,
                        currentLocation = uiState.location,
                        onAddressChange = viewModel::updateAddress,
                        onLocationSelected = viewModel::updateLocation,
                        locationService = viewModel.locationService
                    )
                }
            }

            Spacer(Modifier.height(Spacing.lg))

            // Error message
            AnimatedVisibility(
                visible = uiState.error != null,
                enter = fadeIn(),
                exit = fadeOut()
            ) {
                Text(
                    text = uiState.error ?: "",
                    color = LiquidGlassColors.error,
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(bottom = Spacing.md)
                )
            }

            // Submit Button
            GlassButton(
                text = if (uiState.isSubmitting) "Creating..." else "Share Now",
                onClick = { viewModel.submit(onSuccess) },
                style = GlassButtonStyle.Primary,
                isLoading = uiState.isSubmitting,
                enabled = uiState.canSubmit,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(Modifier.height(Spacing.xxl))
        }
    }
}

@Composable
private fun PostTypeSelector(
    selectedType: PostType,
    onTypeSelected: (PostType) -> Unit
) {
    val types = listOf(
        PostType.FOOD,
        PostType.THING,
        PostType.BORROW,
        PostType.WANTED
    )

    Row(
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        modifier = Modifier.horizontalScroll(rememberScrollState())
    ) {
        types.forEach { type ->
            val isSelected = type == selectedType
            val color = getPostTypeColor(type)

            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(CornerRadius.medium))
                    .background(
                        if (isSelected) color.copy(alpha = 0.2f)
                        else LiquidGlassColors.Glass.micro
                    )
                    .border(
                        width = if (isSelected) 2.dp else 1.dp,
                        color = if (isSelected) color else LiquidGlassColors.Glass.border,
                        shape = RoundedCornerShape(CornerRadius.medium)
                    )
                    .clickable { onTypeSelected(type) }
                    .padding(horizontal = Spacing.md, vertical = Spacing.sm)
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    if (isSelected) {
                        Icon(
                            imageVector = Icons.Default.Check,
                            contentDescription = null,
                            tint = color,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                    Text(
                        text = type.displayName,
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                        color = if (isSelected) color else Color.White.copy(alpha = 0.8f)
                    )
                }
            }
        }
    }
}

private fun getPostTypeColor(type: PostType): Color = when (type) {
    PostType.FOOD -> LiquidGlassColors.Category.food
    PostType.THING -> LiquidGlassColors.Category.thing
    PostType.BORROW -> LiquidGlassColors.Category.borrow
    PostType.WANTED -> LiquidGlassColors.Category.wanted
    else -> LiquidGlassColors.brandPink
}
