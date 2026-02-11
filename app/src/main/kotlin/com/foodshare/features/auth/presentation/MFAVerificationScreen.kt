package com.foodshare.features.auth.presentation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
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
import androidx.compose.foundation.text.KeyboardOptions
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
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.foodshare.ui.design.components.buttons.GlassButton
import com.foodshare.ui.design.components.buttons.GlassButtonStyle
import com.foodshare.ui.design.components.cards.GlassCard
import com.foodshare.ui.design.components.inputs.GlassTextField
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing

/**
 * MFA Verification Screen
 *
 * 6-digit code entry for MFA verification during sign-in
 *
 * Features:
 * - Title "Enter Verification Code"
 * - 6 digit input field
 * - Verify button
 * - "Use recovery code" link
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MFAVerificationScreen(
    onVerified: () -> Unit,
    onNavigateBack: () -> Unit,
    viewModel: MFAVerificationViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    // Navigate on verification success
    LaunchedEffect(uiState.isVerified) {
        if (uiState.isVerified) {
            onVerified()
        }
    }

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = "Two-Factor Authentication",
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
                    .padding(Spacing.lg),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                GlassCard(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier.padding(Spacing.lg),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = "Enter Verification Code",
                            style = MaterialTheme.typography.headlineSmall,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )

                        Spacer(Modifier.height(Spacing.sm))

                        Text(
                            text = "Enter the 6-digit code from your authenticator app",
                            style = MaterialTheme.typography.bodyMedium,
                            color = Color.White.copy(alpha = 0.7f),
                            textAlign = TextAlign.Center
                        )

                        Spacer(Modifier.height(Spacing.lg))

                        // 6-digit code entry
                        GlassTextField(
                            value = uiState.code,
                            onValueChange = viewModel::updateCode,
                            label = "Verification Code",
                            placeholder = "000000",
                            keyboardType = KeyboardType.Number,
                            error = uiState.error,
                            modifier = Modifier.fillMaxWidth()
                        )

                        Spacer(Modifier.height(Spacing.lg))

                        // Verify button
                        GlassButton(
                            text = "Verify",
                            onClick = viewModel::verifyCode,
                            style = GlassButtonStyle.Primary,
                            isLoading = uiState.isVerifying,
                            enabled = uiState.code.length == 6,
                            modifier = Modifier.fillMaxWidth()
                        )

                        Spacer(Modifier.height(Spacing.md))

                        // Use recovery code link
                        var showRecoveryInput by remember { mutableStateOf(false) }
                        var recoveryCode by remember { mutableStateOf("") }

                        if (!showRecoveryInput) {
                            TextButton(onClick = { showRecoveryInput = true }) {
                                Text(
                                    text = "Use recovery code",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = LiquidGlassColors.brandPink
                                )
                            }
                        } else {
                            Spacer(Modifier.height(Spacing.md))

                            Text(
                                text = "Enter Recovery Code",
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.SemiBold,
                                color = Color.White
                            )

                            Spacer(Modifier.height(Spacing.sm))

                            GlassTextField(
                                value = recoveryCode,
                                onValueChange = { recoveryCode = it },
                                label = "Recovery Code",
                                placeholder = "xxxx-xxxx-xxxx",
                                modifier = Modifier.fillMaxWidth()
                            )

                            Spacer(Modifier.height(Spacing.sm))

                            GlassButton(
                                text = "Verify Recovery Code",
                                onClick = { viewModel.verifyRecoveryCode(recoveryCode) },
                                style = GlassButtonStyle.Secondary,
                                enabled = recoveryCode.isNotBlank(),
                                modifier = Modifier.fillMaxWidth()
                            )

                            TextButton(onClick = { showRecoveryInput = false }) {
                                Text(
                                    text = "Back to TOTP code",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = Color.White.copy(alpha = 0.7f)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
