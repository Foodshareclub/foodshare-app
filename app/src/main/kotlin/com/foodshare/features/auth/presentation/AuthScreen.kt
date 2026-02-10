package com.foodshare.features.auth.presentation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
 * Authentication screen with login/signup forms
 *
 * Features Liquid Glass design system with animated transitions
 */
@Composable
fun AuthScreen(
    viewModel: AuthViewModel = hiltViewModel(),
    onAuthenticated: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    // Navigate when authenticated
    LaunchedEffect(uiState.authState) {
        if (uiState.authState is AuthState.Authenticated) {
            onAuthenticated()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(brush = LiquidGlassGradients.darkAuth)
    ) {
        // Nature accent overlay
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(brush = LiquidGlassGradients.natureAccent)
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(Spacing.lg)
                .imePadding(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // Logo/Brand Section
            AppLogo()

            Spacer(Modifier.height(Spacing.xxl))

            // Auth Form Card
            GlassCard(
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(Spacing.lg),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    // Title
                    Text(
                        text = if (uiState.isSignUp) "Create Account" else "Welcome Back",
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )

                    Text(
                        text = if (uiState.isSignUp)
                            "Join the food sharing community"
                        else
                            "Sign in to continue",
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color.White.copy(alpha = 0.7f)
                    )

                    Spacer(Modifier.height(Spacing.lg))

                    // Email field
                    GlassTextField(
                        value = uiState.email,
                        onValueChange = viewModel::updateEmail,
                        label = "Email",
                        placeholder = "your@email.com",
                        error = uiState.emailError,
                        keyboardType = KeyboardType.Email,
                        imeAction = ImeAction.Next,
                        modifier = Modifier.fillMaxWidth()
                    )

                    Spacer(Modifier.height(Spacing.md))

                    // Nickname field (sign up only)
                    AnimatedVisibility(
                        visible = uiState.isSignUp,
                        enter = fadeIn() + slideInVertically(),
                        exit = fadeOut() + slideOutVertically()
                    ) {
                        Column {
                            GlassTextField(
                                value = uiState.nickname,
                                onValueChange = viewModel::updateNickname,
                                label = "Nickname (optional)",
                                placeholder = "How should we call you?",
                                imeAction = ImeAction.Next,
                                modifier = Modifier.fillMaxWidth()
                            )
                            Spacer(Modifier.height(Spacing.md))
                        }
                    }

                    // Password field
                    GlassTextField(
                        value = uiState.password,
                        onValueChange = viewModel::updatePassword,
                        label = "Password",
                        placeholder = "Enter your password",
                        error = uiState.passwordError,
                        isPassword = true,
                        imeAction = if (uiState.isSignUp) ImeAction.Next else ImeAction.Done,
                        onImeAction = { if (!uiState.isSignUp) viewModel.signIn() },
                        modifier = Modifier.fillMaxWidth()
                    )

                    // Confirm password field (sign up only)
                    AnimatedVisibility(
                        visible = uiState.isSignUp,
                        enter = fadeIn() + slideInVertically(),
                        exit = fadeOut() + slideOutVertically()
                    ) {
                        Column {
                            Spacer(Modifier.height(Spacing.md))
                            GlassTextField(
                                value = uiState.confirmPassword,
                                onValueChange = viewModel::updateConfirmPassword,
                                label = "Confirm Password",
                                placeholder = "Confirm your password",
                                error = uiState.confirmPasswordError,
                                isPassword = true,
                                imeAction = ImeAction.Done,
                                onImeAction = { viewModel.signUp() },
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                    }

                    // Error message
                    AnimatedVisibility(
                        visible = uiState.error != null,
                        enter = fadeIn() + slideInVertically(),
                        exit = fadeOut() + slideOutVertically()
                    ) {
                        Column {
                            Spacer(Modifier.height(Spacing.sm))
                            Text(
                                text = uiState.error ?: "",
                                color = LiquidGlassColors.error,
                                style = MaterialTheme.typography.bodySmall,
                                textAlign = TextAlign.Center,
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                    }

                    Spacer(Modifier.height(Spacing.lg))

                    // Submit button
                    GlassButton(
                        text = if (uiState.isSignUp) "Create Account" else "Sign In",
                        onClick = { if (uiState.isSignUp) viewModel.signUp() else viewModel.signIn() },
                        style = GlassButtonStyle.Primary,
                        isLoading = uiState.isLoading,
                        modifier = Modifier.fillMaxWidth()
                    )

                    Spacer(Modifier.height(Spacing.md))

                    // Toggle auth mode
                    Row(
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = if (uiState.isSignUp)
                                "Already have an account?"
                            else
                                "Don't have an account?",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color.White.copy(alpha = 0.7f)
                        )
                        TextButton(onClick = viewModel::toggleAuthMode) {
                            Text(
                                text = if (uiState.isSignUp) "Sign In" else "Sign Up",
                                style = MaterialTheme.typography.bodySmall,
                                fontWeight = FontWeight.Bold,
                                color = LiquidGlassColors.brandPink
                            )
                        }
                    }
                }
            }

            Spacer(Modifier.height(Spacing.xl))

            // OAuth buttons
            OAuthSection(
                onGoogleClick = viewModel::signInWithGoogle,
                onAppleClick = viewModel::signInWithApple,
                isLoading = uiState.isLoading
            )
        }
    }
}

@Composable
private fun AppLogo() {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Logo icon
        Box(
            modifier = Modifier
                .size(80.dp)
                .background(
                    brush = LiquidGlassGradients.brand,
                    shape = androidx.compose.foundation.shape.CircleShape
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.Person,
                contentDescription = "Foodshare",
                tint = Color.White,
                modifier = Modifier.size(40.dp)
            )
        }

        Spacer(Modifier.height(Spacing.md))

        Text(
            text = "Foodshare",
            fontSize = 32.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )

        Text(
            text = "Share food, reduce waste",
            style = MaterialTheme.typography.bodyMedium,
            color = Color.White.copy(alpha = 0.7f)
        )
    }
}

@Composable
private fun OAuthSection(
    onGoogleClick: () -> Unit,
    onAppleClick: () -> Unit,
    isLoading: Boolean
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(1.dp)
                    .background(Color.White.copy(alpha = 0.2f))
            )
            Text(
                text = "  or continue with  ",
                style = MaterialTheme.typography.bodySmall,
                color = Color.White.copy(alpha = 0.5f)
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(1.dp)
                    .background(Color.White.copy(alpha = 0.2f))
            )
        }

        Spacer(Modifier.height(Spacing.lg))

        // Apple Sign In
        GlassButton(
            text = "Continue with Apple",
            onClick = onAppleClick,
            style = GlassButtonStyle.Secondary,
            enabled = !isLoading,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(Modifier.height(Spacing.sm))

        // Google Sign In
        GlassButton(
            text = "Continue with Google",
            onClick = onGoogleClick,
            style = GlassButtonStyle.Secondary,
            enabled = !isLoading,
            modifier = Modifier.fillMaxWidth()
        )
    }
}
