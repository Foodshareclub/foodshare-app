package com.foodshare.features.arrangement.presentation

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
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
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.foodshare.features.arrangement.domain.model.ArrangementStatus
import com.foodshare.features.arrangement.presentation.components.ArrangementStatusCard
import com.foodshare.ui.design.components.buttons.GlassButton
import com.foodshare.ui.design.components.buttons.GlassButtonStyle
import com.foodshare.ui.design.components.inputs.GlassTextArea
import com.foodshare.ui.design.components.inputs.GlassTextField
import com.foodshare.ui.design.tokens.LiquidGlassTypography
import com.foodshare.ui.design.tokens.Spacing

/**
 * Full arrangement management screen.
 *
 * Features:
 * - Create new arrangements with pickup details
 * - View existing arrangement status
 * - Status-based action buttons (Accept, Decline, Confirm, Complete)
 * - Timeline of status changes
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ArrangementScreen(
    onNavigateBack: () -> Unit,
    onNavigateToReview: ((Int) -> Unit)? = null,
    viewModel: ArrangementViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }

    // Show error or success messages
    LaunchedEffect(uiState.error) {
        uiState.error?.let {
            snackbarHostState.showSnackbar(it)
            viewModel.clearError()
        }
    }

    LaunchedEffect(uiState.successMessage) {
        uiState.successMessage?.let {
            snackbarHostState.showSnackbar(it)
            viewModel.clearSuccessMessage()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = if (uiState.isCreating) "New Arrangement" else "Arrangement",
                        fontWeight = FontWeight.Bold
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back"
                        )
                    }
                }
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { paddingValues ->
        when {
            uiState.isLoading -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator()
                }
            }

            uiState.isCreating -> {
                CreateArrangementContent(
                    uiState = uiState,
                    onPickupDateChange = viewModel::updatePickupDate,
                    onPickupTimeChange = viewModel::updatePickupTime,
                    onPickupLocationChange = viewModel::updatePickupLocation,
                    onNotesChange = viewModel::updateNotes,
                    onSubmit = viewModel::createArrangement,
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues)
                )
            }

            uiState.arrangement != null -> {
                ViewArrangementContent(
                    uiState = uiState,
                    onAccept = viewModel::acceptArrangement,
                    onDecline = viewModel::declineArrangement,
                    onConfirm = viewModel::confirmPickup,
                    onComplete = viewModel::markComplete,
                    onNoShow = viewModel::markNoShow,
                    onNavigateToReview = onNavigateToReview,
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues)
                )
            }

            else -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "Arrangement not found",
                        style = LiquidGlassTypography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
private fun CreateArrangementContent(
    uiState: ArrangementUiState,
    onPickupDateChange: (String) -> Unit,
    onPickupTimeChange: (String) -> Unit,
    onPickupLocationChange: (String) -> Unit,
    onNotesChange: (String) -> Unit,
    onSubmit: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .verticalScroll(rememberScrollState())
            .padding(Spacing.lg)
    ) {
        Text(
            text = "Pickup Details",
            style = LiquidGlassTypography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface
        )

        Spacer(Modifier.height(Spacing.md))

        Text(
            text = "Schedule a time and place to collect the food",
            style = LiquidGlassTypography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(Modifier.height(Spacing.xl))

        GlassTextField(
            value = uiState.pickupDate,
            onValueChange = onPickupDateChange,
            label = "Pickup Date",
            placeholder = "YYYY-MM-DD",
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(Modifier.height(Spacing.md))

        GlassTextField(
            value = uiState.pickupTime,
            onValueChange = onPickupTimeChange,
            label = "Pickup Time",
            placeholder = "HH:MM",
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(Modifier.height(Spacing.md))

        GlassTextField(
            value = uiState.pickupLocation,
            onValueChange = onPickupLocationChange,
            label = "Pickup Location",
            placeholder = "Enter address or location details",
            modifier = Modifier.fillMaxWidth(),
            imeAction = ImeAction.Next
        )

        Spacer(Modifier.height(Spacing.md))

        GlassTextArea(
            value = uiState.notes,
            onValueChange = onNotesChange,
            label = "Notes (Optional)",
            placeholder = "Any additional information...",
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(Modifier.height(Spacing.xl))

        GlassButton(
            text = "Request Pickup",
            onClick = onSubmit,
            isLoading = uiState.isSaving,
            style = GlassButtonStyle.Primary,
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Composable
private fun ViewArrangementContent(
    uiState: ArrangementUiState,
    onAccept: () -> Unit,
    onDecline: () -> Unit,
    onConfirm: () -> Unit,
    onComplete: () -> Unit,
    onNoShow: () -> Unit,
    onNavigateToReview: ((Int) -> Unit)?,
    modifier: Modifier = Modifier
) {
    val arrangement = uiState.arrangement ?: return

    Column(
        modifier = modifier
            .verticalScroll(rememberScrollState())
            .padding(Spacing.lg)
    ) {
        // Status card
        ArrangementStatusCard(
            status = arrangement.status,
            updatedAt = arrangement.updatedAt,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(Modifier.height(Spacing.xl))

        // Arrangement details
        Text(
            text = "Details",
            style = LiquidGlassTypography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface
        )

        Spacer(Modifier.height(Spacing.md))

        arrangement.listingTitle?.let { title ->
            DetailRow(label = "Listing", value = title)
            Spacer(Modifier.height(Spacing.sm))
        }

        arrangement.requesterName?.let { name ->
            DetailRow(label = "Requester", value = name)
            Spacer(Modifier.height(Spacing.sm))
        }

        arrangement.pickupDate?.let { date ->
            DetailRow(label = "Pickup Date", value = date)
            Spacer(Modifier.height(Spacing.sm))
        }

        arrangement.pickupTime?.let { time ->
            DetailRow(label = "Pickup Time", value = time)
            Spacer(Modifier.height(Spacing.sm))
        }

        arrangement.pickupLocation?.let { location ->
            DetailRow(label = "Location", value = location)
            Spacer(Modifier.height(Spacing.sm))
        }

        arrangement.notes?.let { notes ->
            if (notes.isNotBlank()) {
                DetailRow(label = "Notes", value = notes)
                Spacer(Modifier.height(Spacing.sm))
            }
        }

        Spacer(Modifier.height(Spacing.xl))

        // Action buttons based on status
        when {
            uiState.canAccept || uiState.canDecline -> {
                Text(
                    text = "Actions",
                    style = LiquidGlassTypography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )

                Spacer(Modifier.height(Spacing.md))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(Spacing.md)
                ) {
                    GlassButton(
                        text = "Decline",
                        onClick = onDecline,
                        isLoading = uiState.isSaving,
                        style = GlassButtonStyle.Secondary,
                        modifier = Modifier.weight(1f)
                    )

                    GlassButton(
                        text = "Accept",
                        onClick = onAccept,
                        isLoading = uiState.isSaving,
                        style = GlassButtonStyle.Primary,
                        modifier = Modifier.weight(1f)
                    )
                }
            }

            uiState.canConfirm -> {
                GlassButton(
                    text = "Confirm Pickup",
                    onClick = onConfirm,
                    isLoading = uiState.isSaving,
                    style = GlassButtonStyle.Primary,
                    modifier = Modifier.fillMaxWidth()
                )
            }

            uiState.canComplete || uiState.canMarkNoShow -> {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(Spacing.md)
                ) {
                    GlassButton(
                        text = "Mark No-Show",
                        onClick = onNoShow,
                        isLoading = uiState.isSaving,
                        style = GlassButtonStyle.Secondary,
                        modifier = Modifier.weight(1f)
                    )

                    GlassButton(
                        text = "Mark Complete",
                        onClick = onComplete,
                        isLoading = uiState.isSaving,
                        style = GlassButtonStyle.Primary,
                        modifier = Modifier.weight(1f)
                    )
                }
            }

            arrangement.status == ArrangementStatus.COMPLETED && onNavigateToReview != null -> {
                GlassButton(
                    text = "Leave Review",
                    onClick = { onNavigateToReview(arrangement.listingId) },
                    style = GlassButtonStyle.Primary,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}

@Composable
private fun DetailRow(
    label: String,
    value: String
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.Top
    ) {
        Text(
            text = label,
            style = LiquidGlassTypography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.width(120.dp)
        )

        Text(
            text = value,
            style = LiquidGlassTypography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f)
        )
    }
}
