package com.foodshare.features.onboarding.presentation

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.foodshare.features.onboarding.presentation.components.*
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing

/**
 * Onboarding screen with legal disclaimers.
 *
 * SYNC: Mirrors Swift OnboardingView
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OnboardingScreen(
    onOnboardingComplete: () -> Unit,
    viewModel: OnboardingViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(brush = LiquidGlassGradients.darkAuth)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = Spacing.lg),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(Spacing.xxxl))

            // Hero Section - Logo with glow
            HeroSection()

            Spacer(modifier = Modifier.height(Spacing.xl))

            // Welcome Section
            WelcomeSection()

            Spacer(modifier = Modifier.height(Spacing.xl))

            // Disclaimer Card
            DisclaimerCard(
                onReadFullDisclaimer = { viewModel.showFullDisclaimer() }
            )

            Spacer(modifier = Modifier.height(Spacing.xl))

            // Confirmation Section
            ConfirmationSection(
                hasConfirmedAge = uiState.hasConfirmedAge,
                hasAcceptedTerms = uiState.hasAcceptedTerms,
                onAgeConfirmationChange = { viewModel.toggleAgeConfirmation() },
                onTermsAcceptanceChange = { viewModel.toggleTermsAcceptance() },
                onShowTerms = { viewModel.showTermsSheet() },
                onShowPrivacy = { viewModel.showPrivacySheet() },
                onShowAppleEula = {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"))
                    context.startActivity(intent)
                }
            )

            Spacer(modifier = Modifier.height(Spacing.xl))

            // Get Started Button
            GetStartedButton(
                enabled = uiState.canProceed,
                isLoading = uiState.isCompleting,
                onClick = { viewModel.completeOnboarding(onOnboardingComplete) }
            )

            Spacer(modifier = Modifier.height(Spacing.xxl))
        }
    }

    // Full Disclaimer Sheet
    if (uiState.showFullDisclaimer) {
        FullDisclaimerSheet(
            onDismiss = { viewModel.hideFullDisclaimer() }
        )
    }

    // Terms Sheet
    if (uiState.showTermsSheet) {
        LegalSheet(
            title = "Terms of Service",
            content = TERMS_OF_SERVICE_TEXT,
            onDismiss = { viewModel.hideTermsSheet() }
        )
    }

    // Privacy Sheet
    if (uiState.showPrivacySheet) {
        LegalSheet(
            title = "Privacy Policy",
            content = PRIVACY_POLICY_TEXT,
            onDismiss = { viewModel.hidePrivacySheet() }
        )
    }
}

@Composable
private fun HeroSection() {
    Box(contentAlignment = Alignment.Center) {
        // Glow effect
        Box(
            modifier = Modifier
                .size(150.dp)
                .clip(CircleShape)
                .background(
                    brush = Brush.radialGradient(
                        colors = listOf(
                            LiquidGlassColors.brandGreen.copy(alpha = 0.5f),
                            LiquidGlassColors.brandGreen.copy(alpha = 0.25f),
                            LiquidGlassColors.brandBlue.copy(alpha = 0.1f),
                            Color.Transparent
                        )
                    )
                )
                .blur(25.dp)
        )

        // Logo placeholder - leaf icon
        Box(
            modifier = Modifier
                .size(100.dp)
                .clip(CircleShape)
                .background(
                    brush = Brush.linearGradient(
                        colors = listOf(
                            LiquidGlassColors.brandGreen,
                            LiquidGlassColors.brandBlue
                        )
                    )
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.Eco,
                contentDescription = "Foodshare",
                modifier = Modifier.size(50.dp),
                tint = Color.White
            )
        }
    }
}

@Composable
private fun WelcomeSection() {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = "Welcome to Foodshare",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
        Spacer(modifier = Modifier.height(Spacing.xs))
        Text(
            text = "Share food, reduce waste, help your community",
            style = MaterialTheme.typography.bodyLarge,
            color = Color.White.copy(alpha = 0.75f),
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(Spacing.md))

        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.Start
        ) {
            OnboardingFeatureRow(
                icon = Icons.Default.Eco,
                text = "Share surplus food with neighbors in your area"
            )
            OnboardingFeatureRow(
                icon = Icons.Default.LocationOn,
                text = "Find available food nearby on the map"
            )
            OnboardingFeatureRow(
                icon = Icons.Default.Favorite,
                text = "Build community and reduce food waste together"
            )
        }
    }
}

@Composable
private fun DisclaimerCard(
    onReadFullDisclaimer: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(CornerRadius.large),
        colors = CardDefaults.cardColors(
            containerColor = LiquidGlassColors.Glass.background
        ),
        border = androidx.compose.foundation.BorderStroke(
            1.5.dp,
            LiquidGlassColors.warning.copy(alpha = 0.5f)
        )
    ) {
        Column(
            modifier = Modifier.padding(Spacing.md)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.xs)
            ) {
                Icon(
                    imageVector = Icons.Default.Info,
                    contentDescription = null,
                    tint = LiquidGlassColors.warning
                )
                Text(
                    text = "Important Information",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
            }

            Spacer(modifier = Modifier.height(Spacing.sm))

            DisclaimerPoint(
                icon = Icons.Default.People,
                title = "Community Platform",
                description = "Foodshare connects food donors with recipients. We do not verify food quality or safety."
            )
            DisclaimerPoint(
                icon = Icons.Default.VerifiedUser,
                title = "Food Safety",
                description = "Always inspect food for freshness and safety before consumption. Use your judgment."
            )
            DisclaimerPoint(
                icon = Icons.Default.Flag,
                title = "Report Concerns",
                description = "Report any inappropriate listings or users to our support team immediately."
            )

            Spacer(modifier = Modifier.height(Spacing.sm))

            TextButton(
                onClick = onReadFullDisclaimer,
                contentPadding = PaddingValues(0.dp)
            ) {
                Text(
                    text = "Read Full Disclaimer",
                    color = LiquidGlassColors.brandGreen
                )
                Spacer(modifier = Modifier.width(4.dp))
                Icon(
                    imageVector = Icons.Default.ArrowForward,
                    contentDescription = null,
                    modifier = Modifier.size(16.dp),
                    tint = LiquidGlassColors.brandGreen
                )
            }
        }
    }
}

@Composable
private fun ConfirmationSection(
    hasConfirmedAge: Boolean,
    hasAcceptedTerms: Boolean,
    onAgeConfirmationChange: () -> Unit,
    onTermsAcceptanceChange: () -> Unit,
    onShowTerms: () -> Unit,
    onShowPrivacy: () -> Unit,
    onShowAppleEula: () -> Unit
) {
    Column {
        OnboardingCheckboxRow(
            isChecked = hasConfirmedAge,
            text = "I confirm that I am 18 years of age or older",
            onCheckedChange = onAgeConfirmationChange
        )

        OnboardingCheckboxRow(
            isChecked = hasAcceptedTerms,
            text = "I agree to the Terms of Service and Privacy Policy",
            onCheckedChange = onTermsAcceptanceChange
        )

        Row(
            modifier = Modifier.padding(start = Spacing.xl),
            horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
            verticalAlignment = Alignment.CenterVertically
        ) {
            TextButton(
                onClick = onShowTerms,
                contentPadding = PaddingValues(horizontal = 4.dp, vertical = 0.dp)
            ) {
                Text(
                    text = "Terms",
                    style = MaterialTheme.typography.labelSmall,
                    color = LiquidGlassColors.brandGreen
                )
            }
            Text("•", color = Color.White.copy(alpha = 0.3f))
            TextButton(
                onClick = onShowPrivacy,
                contentPadding = PaddingValues(horizontal = 4.dp, vertical = 0.dp)
            ) {
                Text(
                    text = "Privacy",
                    style = MaterialTheme.typography.labelSmall,
                    color = LiquidGlassColors.brandGreen
                )
            }
            Text("•", color = Color.White.copy(alpha = 0.3f))
            TextButton(
                onClick = onShowAppleEula,
                contentPadding = PaddingValues(horizontal = 4.dp, vertical = 0.dp)
            ) {
                Text(
                    text = "Apple EULA",
                    style = MaterialTheme.typography.labelSmall,
                    color = LiquidGlassColors.brandGreen
                )
            }
        }
    }
}

@Composable
private fun GetStartedButton(
    enabled: Boolean,
    isLoading: Boolean,
    onClick: () -> Unit
) {
    Button(
        onClick = onClick,
        enabled = enabled && !isLoading,
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp),
        shape = CircleShape,
        colors = ButtonDefaults.buttonColors(
            containerColor = Color.Transparent,
            disabledContainerColor = Color.Transparent
        ),
        contentPadding = PaddingValues(0.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    brush = if (enabled) {
                        Brush.linearGradient(
                            colors = listOf(
                                LiquidGlassColors.brandGreen,
                                LiquidGlassColors.brandBlue
                            )
                        )
                    } else {
                        Brush.linearGradient(
                            colors = listOf(
                                Color.Gray.copy(alpha = 0.3f),
                                Color.Gray.copy(alpha = 0.3f)
                            )
                        )
                    },
                    shape = CircleShape
                ),
            contentAlignment = Alignment.Center
        ) {
            if (isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(24.dp),
                    color = Color.White,
                    strokeWidth = 2.dp
                )
            } else {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Spacing.xs)
                ) {
                    Icon(
                        imageVector = Icons.Default.Eco,
                        contentDescription = null,
                        tint = Color.White
                    )
                    Text(
                        text = "Get Started",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FullDisclaimerSheet(
    onDismiss: () -> Unit
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = Color(0xFF1A1A2E),
        contentColor = Color.White
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.md)
                .verticalScroll(rememberScrollState())
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Spacing.xs)
                ) {
                    Icon(
                        imageVector = Icons.Default.Warning,
                        contentDescription = null,
                        tint = LiquidGlassColors.warning
                    )
                    Column {
                        Text(
                            text = "Platform Disclaimer",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "Important Legal Information",
                            style = MaterialTheme.typography.labelSmall,
                            color = Color.White.copy(alpha = 0.6f)
                        )
                    }
                }
                TextButton(onClick = onDismiss) {
                    Text("Close", color = LiquidGlassColors.brandGreen)
                }
            }

            Spacer(modifier = Modifier.height(Spacing.md))

            DisclaimerSection(
                title = "Community Platform",
                content = "Foodshare is a community platform that connects people who have surplus food with those who can use it. We are NOT a food bank, restaurant, or food service provider. We do NOT inspect, verify, or guarantee the quality, safety, or freshness of any food items listed on our platform."
            )
            DisclaimerSection(
                title = "Food Safety Responsibility",
                content = "Users are solely responsible for ensuring food safety. Always inspect food items for freshness, proper storage, and potential allergens before consumption. If you have any doubts about the safety of a food item, do NOT consume it."
            )
            DisclaimerSection(
                title = "No Warranties",
                content = "Foodshare makes NO warranties, express or implied, regarding any food items listed on the platform. We do NOT verify the accuracy of listing information provided by users."
            )
            DisclaimerSection(
                title = "User Verification",
                content = "While we encourage users to create profiles, we do NOT perform background checks or verify the identity of users. Exercise caution when meeting with other users and always meet in safe, public locations."
            )
            DisclaimerSection(
                title = "Allergen Warning",
                content = "Food items may contain allergens that are not listed. If you have food allergies, always confirm ingredients with the donor before consuming any food items."
            )
            DisclaimerSection(
                title = "Limitation of Liability",
                content = "To the fullest extent permitted by law, Foodshare and its operators shall not be liable for any direct, indirect, incidental, consequential, or other damages arising from your use of the platform or consumption of any food items obtained through the platform."
            )

            Spacer(modifier = Modifier.height(Spacing.sm))

            Text(
                text = "By using Foodshare, you acknowledge that you have read, understood, and agree to this disclaimer.",
                style = MaterialTheme.typography.labelSmall,
                color = Color.White.copy(alpha = 0.5f),
                fontStyle = androidx.compose.ui.text.font.FontStyle.Italic
            )

            Spacer(modifier = Modifier.height(Spacing.xl))
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LegalSheet(
    title: String,
    content: String,
    onDismiss: () -> Unit
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = Color(0xFF1A1A2E),
        contentColor = Color.White
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.md)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                TextButton(onClick = onDismiss) {
                    Text("Close", color = LiquidGlassColors.brandGreen)
                }
            }

            Spacer(modifier = Modifier.height(Spacing.md))

            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
            ) {
                Text(
                    text = content,
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.White.copy(alpha = 0.85f)
                )
            }

            Spacer(modifier = Modifier.height(Spacing.xl))
        }
    }
}
