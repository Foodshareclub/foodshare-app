package com.foodshare.features.settings.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.foodshare.ui.design.components.inputs.GlassToggle
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing

/**
 * Notifications Settings screen
 *
 * Allows users to configure notification preferences
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationsSettingsScreen(
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: NotificationsSettingsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Notifications",
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
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
                .padding(horizontal = Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.md)
        ) {
            Spacer(Modifier.height(Spacing.md))

            // Push Notifications
            NotificationToggleRow(
                title = "Push Notifications",
                subtitle = "Receive notifications on your device",
                checked = uiState.pushEnabled,
                onCheckedChange = viewModel::togglePush
            )

            // Email Notifications
            NotificationToggleRow(
                title = "Email Notifications",
                subtitle = "Receive notifications via email",
                checked = uiState.emailEnabled,
                onCheckedChange = viewModel::toggleEmail
            )

            Spacer(Modifier.height(Spacing.sm))

            // Section header
            Text(
                text = "NOTIFICATION TYPES",
                style = MaterialTheme.typography.labelMedium,
                color = LiquidGlassColors.brandPink,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(horizontal = Spacing.xxs)
            )

            // Messages
            NotificationToggleRow(
                title = "Messages",
                subtitle = "New messages and chat notifications",
                checked = uiState.messagesEnabled,
                onCheckedChange = viewModel::toggleMessages
            )

            // New Listings Nearby
            NotificationToggleRow(
                title = "New Listings Nearby",
                subtitle = "Food listings in your area",
                checked = uiState.newListingsEnabled,
                onCheckedChange = viewModel::toggleNewListings
            )

            // Reviews
            NotificationToggleRow(
                title = "Reviews",
                subtitle = "When someone reviews you",
                checked = uiState.reviewsEnabled,
                onCheckedChange = viewModel::toggleReviews
            )

            // Challenges
            NotificationToggleRow(
                title = "Challenges",
                subtitle = "Challenge updates and completions",
                checked = uiState.challengesEnabled,
                onCheckedChange = viewModel::toggleChallenges
            )

            // Forum Activity
            NotificationToggleRow(
                title = "Forum Activity",
                subtitle = "Replies and mentions in forum",
                checked = uiState.forumEnabled,
                onCheckedChange = viewModel::toggleForum
            )

            Spacer(Modifier.height(Spacing.xxl))
        }
    }
}

/**
 * Notification toggle row component
 */
@Composable
private fun NotificationToggleRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = Spacing.xs),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
                color = LiquidGlassColors.Text.primary
            )
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = LiquidGlassColors.Text.secondary
            )
        }

        GlassToggle(
            checked = checked,
            onCheckedChange = onCheckedChange
        )
    }
}
