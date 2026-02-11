package com.foodshare.features.settings.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.foodshare.ui.design.components.cards.GlassCard
import com.foodshare.ui.design.components.inputs.GlassDropdown
import com.foodshare.ui.design.components.inputs.GlassToggle
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing

/**
 * App Lock Settings Screen
 *
 * Settings for app lock configuration
 *
 * Features:
 * - Toggle: Enable App Lock
 * - Timeout picker (Immediately, After 1 min, After 5 min, After 15 min)
 * - Toggle: Require on App Launch
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppLockSettingsScreen(
    onNavigateBack: () -> Unit
) {
    var appLockEnabled by remember { mutableStateOf(false) }
    var requireOnLaunch by remember { mutableStateOf(true) }
    var lockTimeout by remember { mutableStateOf("Immediately") }

    val timeoutOptions = listOf(
        "Immediately",
        "After 1 minute",
        "After 5 minutes",
        "After 15 minutes"
    )

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = "App Lock",
                        color = Color.White,
                        style = MaterialTheme.typography.titleLarge
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            imageVector = Icons.Default.ArrowBack,
                            contentDescription = "Back",
                            tint = Color.White
                        )
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = Color.Transparent
                )
            )
        },
        containerColor = Color.Transparent
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(brush = LiquidGlassGradients.darkAuth)
                .padding(paddingValues)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(Spacing.md),
                verticalArrangement = Arrangement.spacedBy(Spacing.md)
            ) {
                // Enable App Lock
                GlassCard(modifier = Modifier.fillMaxWidth()) {
                    GlassToggle(
                        checked = appLockEnabled,
                        onCheckedChange = { appLockEnabled = it },
                        label = "Enable App Lock",
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(Spacing.md)
                    )
                }

                // Lock Timeout (only shown if app lock is enabled)
                if (appLockEnabled) {
                    GlassCard(modifier = Modifier.fillMaxWidth()) {
                        Column(
                            modifier = Modifier.padding(Spacing.md),
                            verticalArrangement = Arrangement.spacedBy(Spacing.sm)
                        ) {
                            Text(
                                text = "Lock Timeout",
                                style = MaterialTheme.typography.titleMedium,
                                color = Color.White
                            )

                            Text(
                                text = "Choose when the app should lock automatically",
                                style = MaterialTheme.typography.bodySmall,
                                color = Color.White.copy(alpha = 0.7f)
                            )

                            GlassDropdown(
                                label = "Timeout",
                                options = timeoutOptions,
                                selectedValue = lockTimeout,
                                onOptionSelected = { lockTimeout = it },
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                    }

                    // Require on Launch
                    GlassCard(modifier = Modifier.fillMaxWidth()) {
                        Column(
                            modifier = Modifier.padding(Spacing.md),
                            verticalArrangement = Arrangement.spacedBy(Spacing.sm)
                        ) {
                            GlassToggle(
                                checked = requireOnLaunch,
                                onCheckedChange = { requireOnLaunch = it },
                                label = "Require on App Launch",
                                modifier = Modifier.fillMaxWidth()
                            )

                            Text(
                                text = "Always require authentication when opening the app",
                                style = MaterialTheme.typography.bodySmall,
                                color = Color.White.copy(alpha = 0.7f)
                            )
                        }
                    }
                }

                // Info card
                GlassCard(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier.padding(Spacing.md),
                        verticalArrangement = Arrangement.spacedBy(Spacing.sm)
                    ) {
                        Text(
                            text = "About App Lock",
                            style = MaterialTheme.typography.titleSmall,
                            color = Color.White
                        )

                        Text(
                            text = "App Lock adds an extra layer of security by requiring biometric authentication " +
                                    "or a PIN to access the app. This helps protect your personal information if your " +
                                    "device is accessed by others.",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color.White.copy(alpha = 0.7f)
                        )
                    }
                }
            }
        }
    }
}
