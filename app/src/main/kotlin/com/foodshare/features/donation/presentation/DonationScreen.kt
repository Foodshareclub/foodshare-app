package com.foodshare.features.donation.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.foodshare.features.donation.domain.model.Donation
import com.foodshare.features.donation.domain.model.DonationType
import com.foodshare.ui.design.components.buttons.GlassButton
import com.foodshare.ui.design.components.buttons.GlassButtonStyle
import com.foodshare.ui.design.components.cards.GlassCard
import com.foodshare.ui.design.components.inputs.GlassSegmentedControl
import com.foodshare.ui.design.components.inputs.GlassTextArea
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassTypography
import com.foodshare.ui.design.tokens.Spacing
import java.text.SimpleDateFormat
import java.util.Locale

/**
 * Donation screen for creating and viewing donations.
 *
 * Features:
 * - Donation type selector (Food, Supplies, Time)
 * - Notes input
 * - Submit button
 * - Recent donations list
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DonationScreen(
    onNavigateBack: () -> Unit,
    viewModel: DonationViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }

    // Show error messages
    LaunchedEffect(uiState.error) {
        uiState.error?.let {
            snackbarHostState.showSnackbar(it)
            viewModel.clearError()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Make a Donation",
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
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent
                )
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
        containerColor = Color.Transparent
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    brush = Brush.verticalGradient(
                        colors = listOf(
                            Color(0xFF0A0A0F),
                            Color(0xFF1A1A2E)
                        )
                    )
                )
                .padding(paddingValues)
        ) {
            when {
                uiState.isLoading -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator()
                    }
                }

                else -> {
                    LazyColumn(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(Spacing.lg),
                        verticalArrangement = Arrangement.spacedBy(Spacing.lg)
                    ) {
                        // Donation form section
                        item {
                            DonationFormSection(
                                selectedType = uiState.selectedType,
                                notes = uiState.notes,
                                isSaving = uiState.isSaving,
                                onTypeSelected = viewModel::selectType,
                                onNotesChange = viewModel::updateNotes,
                                onSubmit = viewModel::createDonation
                            )
                        }

                        // Recent donations header
                        item {
                            Text(
                                text = "Recent Donations",
                                style = LiquidGlassTypography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                color = Color.White,
                                modifier = Modifier.padding(top = Spacing.lg)
                            )
                        }

                        // Recent donations list
                        if (uiState.donations.isEmpty()) {
                            item {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(vertical = Spacing.xl),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        text = "No donations yet",
                                        style = LiquidGlassTypography.bodyMedium,
                                        color = LiquidGlassColors.Text.secondary
                                    )
                                }
                            }
                        } else {
                            items(uiState.donations) { donation ->
                                DonationCard(donation = donation)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DonationFormSection(
    selectedType: DonationType,
    notes: String,
    isSaving: Boolean,
    onTypeSelected: (DonationType) -> Unit,
    onNotesChange: (String) -> Unit,
    onSubmit: () -> Unit
) {
    GlassCard(
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier.padding(Spacing.lg)
        ) {
            Text(
                text = "Donation Type",
                style = LiquidGlassTypography.labelMedium,
                color = Color.White,
                fontWeight = FontWeight.Medium
            )

            Spacer(Modifier.height(Spacing.sm))

            GlassSegmentedControl(
                options = listOf("Food", "Supplies", "Time"),
                selectedIndex = when (selectedType) {
                    DonationType.FOOD -> 0
                    DonationType.SUPPLIES -> 1
                    DonationType.VOLUNTEER_TIME -> 2
                    else -> 0
                },
                onOptionSelected = { index ->
                    onTypeSelected(
                        when (index) {
                            0 -> DonationType.FOOD
                            1 -> DonationType.SUPPLIES
                            2 -> DonationType.VOLUNTEER_TIME
                            else -> DonationType.FOOD
                        }
                    )
                },
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(Modifier.height(Spacing.lg))

            GlassTextArea(
                value = notes,
                onValueChange = onNotesChange,
                label = "Notes",
                placeholder = "Tell us about your donation...",
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(Modifier.height(Spacing.xl))

            GlassButton(
                text = "Submit Donation",
                onClick = onSubmit,
                isLoading = isSaving,
                style = GlassButtonStyle.Primary,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
private fun DonationCard(
    donation: Donation
) {
    GlassCard(
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier.padding(Spacing.md)
        ) {
            // Type and status row
            androidx.compose.foundation.layout.Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = donation.donationType.name.replace("_", " ")
                        .lowercase()
                        .replaceFirstChar { it.uppercase() },
                    style = LiquidGlassTypography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White
                )

                Text(
                    text = donation.status.name.lowercase()
                        .replaceFirstChar { it.uppercase() },
                    style = LiquidGlassTypography.bodySmall,
                    color = when (donation.status) {
                        com.foodshare.features.donation.domain.model.DonationStatus.COMPLETED ->
                            LiquidGlassColors.success
                        com.foodshare.features.donation.domain.model.DonationStatus.CANCELLED ->
                            LiquidGlassColors.error
                        else -> LiquidGlassColors.Text.secondary
                    }
                )
            }

            donation.notes?.let { notes ->
                if (notes.isNotBlank()) {
                    Spacer(Modifier.height(Spacing.xs))
                    Text(
                        text = notes,
                        style = LiquidGlassTypography.bodyMedium,
                        color = LiquidGlassColors.Text.secondary,
                        maxLines = 2
                    )
                }
            }

            donation.createdAt?.let { createdAt ->
                Spacer(Modifier.height(Spacing.xs))
                Text(
                    text = formatDate(createdAt),
                    style = LiquidGlassTypography.captionSmall,
                    color = LiquidGlassColors.Text.tertiary
                )
            }
        }
    }
}

private fun formatDate(dateString: String): String {
    return try {
        val inputFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
        val outputFormat = SimpleDateFormat("MMM d, yyyy", Locale.getDefault())
        val date = inputFormat.parse(dateString)
        date?.let { outputFormat.format(it) } ?: dateString
    } catch (e: Exception) {
        dateString
    }
}
