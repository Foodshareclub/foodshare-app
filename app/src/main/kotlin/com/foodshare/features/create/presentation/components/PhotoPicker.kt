package com.foodshare.features.create.presentation.components

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.Spacing

private const val MAX_IMAGES = 5

/**
 * Photo picker component for selecting multiple images
 *
 * Uses Android's photo picker API (PickMultipleVisualMedia) for a
 * modern, privacy-friendly image selection experience.
 */
@Composable
fun PhotoPicker(
    selectedImages: List<Uri>,
    onImagesSelected: (List<Uri>) -> Unit,
    onImageRemoved: (Uri) -> Unit,
    modifier: Modifier = Modifier
) {
    val remainingSlots = MAX_IMAGES - selectedImages.size

    // Photo picker launcher
    val photoPickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickMultipleVisualMedia(
            maxItems = remainingSlots.coerceAtLeast(1)
        )
    ) { uris ->
        if (uris.isNotEmpty()) {
            // Only add up to remaining slots
            val newImages = uris.take(remainingSlots)
            onImagesSelected(newImages)
        }
    }

    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(Spacing.sm)
    ) {
        Text(
            text = "Add Photos",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = Color.White
        )

        Row(
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            modifier = Modifier.horizontalScroll(rememberScrollState())
        ) {
            // Selected images
            selectedImages.forEach { uri ->
                SelectedImageTile(
                    uri = uri,
                    onRemove = { onImageRemoved(uri) }
                )
            }

            // Add photo button (if slots available)
            if (selectedImages.size < MAX_IMAGES) {
                AddPhotoButton(
                    imageCount = selectedImages.size,
                    onClick = {
                        photoPickerLauncher.launch(
                            PickVisualMediaRequest(
                                ActivityResultContracts.PickVisualMedia.ImageOnly
                            )
                        )
                    }
                )
            }

            // Empty placeholder slots
            val emptySlots = (MAX_IMAGES - selectedImages.size - 1).coerceAtLeast(0)
            repeat(emptySlots.coerceAtMost(3)) {
                EmptySlot()
            }
        }

        // Helper text
        Text(
            text = "Add up to $MAX_IMAGES photos. First photo will be the cover.",
            style = MaterialTheme.typography.labelSmall,
            color = Color.White.copy(alpha = 0.5f)
        )
    }
}

@Composable
private fun SelectedImageTile(
    uri: Uri,
    onRemove: () -> Unit
) {
    Box(
        modifier = Modifier
            .size(100.dp)
            .clip(RoundedCornerShape(CornerRadius.medium))
    ) {
        // Image
        AsyncImage(
            model = ImageRequest.Builder(LocalContext.current)
                .data(uri)
                .crossfade(true)
                .build(),
            contentDescription = "Selected photo",
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize()
        )

        // Remove button overlay
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(4.dp)
                .size(24.dp)
                .clip(CircleShape)
                .background(Color.Black.copy(alpha = 0.6f))
                .clickable(onClick = onRemove),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.Close,
                contentDescription = "Remove photo",
                tint = Color.White,
                modifier = Modifier.size(16.dp)
            )
        }

        // Border
        Box(
            modifier = Modifier
                .fillMaxSize()
                .border(
                    width = 2.dp,
                    color = LiquidGlassColors.Glass.border,
                    shape = RoundedCornerShape(CornerRadius.medium)
                )
        )
    }
}

@Composable
private fun AddPhotoButton(
    imageCount: Int,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .size(100.dp)
            .clip(RoundedCornerShape(CornerRadius.medium))
            .background(LiquidGlassColors.Glass.surface)
            .border(
                width = 2.dp,
                color = LiquidGlassColors.brandPink.copy(alpha = 0.5f),
                shape = RoundedCornerShape(CornerRadius.medium)
            )
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.xs)
        ) {
            Icon(
                imageVector = Icons.Default.PhotoCamera,
                contentDescription = "Add photo",
                tint = LiquidGlassColors.brandPink,
                modifier = Modifier.size(32.dp)
            )
            Text(
                text = "$imageCount/$MAX_IMAGES",
                style = MaterialTheme.typography.labelSmall,
                color = Color.White.copy(alpha = 0.7f)
            )
        }
    }
}

@Composable
private fun EmptySlot() {
    Box(
        modifier = Modifier
            .size(100.dp)
            .clip(RoundedCornerShape(CornerRadius.medium))
            .background(LiquidGlassColors.Glass.micro)
            .border(
                width = 1.dp,
                color = LiquidGlassColors.Glass.border.copy(alpha = 0.3f),
                shape = RoundedCornerShape(CornerRadius.medium)
            ),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = Icons.Default.Add,
            contentDescription = null,
            tint = Color.White.copy(alpha = 0.2f),
            modifier = Modifier.size(24.dp)
        )
    }
}
