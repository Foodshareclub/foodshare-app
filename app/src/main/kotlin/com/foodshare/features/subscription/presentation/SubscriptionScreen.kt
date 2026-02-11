package com.foodshare.features.subscription.presentation

import android.app.Activity
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
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
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Block
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Diamond
import androidx.compose.material.icons.filled.Restore
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Verified
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.foodshare.features.subscription.domain.model.SubscriptionPeriod
import com.foodshare.features.subscription.domain.model.SubscriptionPlan
import com.foodshare.features.subscription.presentation.components.SubscriptionBenefits
import com.foodshare.features.subscription.presentation.components.SubscriptionHero
import com.foodshare.features.subscription.presentation.components.SubscriptionPlanCard
import com.foodshare.ui.design.components.buttons.GlassButton
import com.foodshare.ui.design.components.buttons.GlassButtonStyle
import com.foodshare.ui.design.components.cards.GlassCard
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing

private val premiumGold = Color(0xFFFFD700)
private val premiumGradient = Brush.linearGradient(
    colors = listOf(premiumGold, Color(0xFFFFA500))
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SubscriptionScreen(
    onNavigateBack: () -> Unit,
    viewModel: SubscriptionViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    val context = LocalContext.current

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
                        text = "Premium",
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
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
        snackbarHost = { SnackbarHost(snackbarHostState) },
        containerColor = Color.Transparent,
        modifier = Modifier.background(brush = LiquidGlassGradients.darkAuth)
    ) { padding ->
        when {
            uiState.isLoading -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = premiumGold)
                }
            }

            uiState.isSubscribed -> {
                ActiveSubscriptionContent(
                    modifier = Modifier.padding(padding),
                    onBack = onNavigateBack
                )
            }

            else -> {
                SubscriptionContent(
                    uiState = uiState,
                    modifier = Modifier.padding(padding),
                    onSelectPlan = viewModel::selectPlan,
                    onPurchase = {
                        (context as? Activity)?.let { activity ->
                            viewModel.purchase(activity)
                        }
                    },
                    onRestore = viewModel::restorePurchases
                )
            }
        }
    }
}

@Composable
private fun SubscriptionContent(
    uiState: SubscriptionUiState,
    modifier: Modifier = Modifier,
    onSelectPlan: (SubscriptionPlan) -> Unit,
    onPurchase: () -> Unit,
    onRestore: () -> Unit
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = Spacing.md),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(Modifier.height(Spacing.lg))

        // Hero
        SubscriptionHero()

        Spacer(Modifier.height(Spacing.xl))

        // Benefits
        SubscriptionBenefits()

        Spacer(Modifier.height(Spacing.xl))

        // Plan selection
        Text(
            text = "Choose Your Plan",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
        Spacer(Modifier.height(Spacing.md))

        uiState.plans.forEach { plan ->
            SubscriptionPlanCard(
                plan = plan,
                isSelected = uiState.selectedPlan == plan,
                savingsPercent = if (plan.isYearly) uiState.pricing.savingsPercent else 0,
                effectiveMonthly = if (plan.isYearly) uiState.pricing.effectiveMonthlyPrice else null,
                onClick = { onSelectPlan(plan) }
            )
            Spacer(Modifier.height(Spacing.sm))
        }

        Spacer(Modifier.height(Spacing.lg))

        // Purchase button
        GlassButton(
            text = if (uiState.isPurchasing) "Processing..." else "Subscribe Now",
            onClick = onPurchase,
            enabled = uiState.selectedPlan != null && !uiState.isPurchasing,
            isLoading = uiState.isPurchasing,
            icon = Icons.Default.Diamond,
            style = GlassButtonStyle.Primary,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(Modifier.height(Spacing.md))

        // Restore
        Text(
            text = if (uiState.isRestoring) "Restoring..." else "Restore Purchases",
            style = MaterialTheme.typography.bodySmall,
            color = LiquidGlassColors.brandTeal,
            fontWeight = FontWeight.Medium,
            textDecoration = TextDecoration.Underline,
            modifier = Modifier.clickable(enabled = !uiState.isRestoring) { onRestore() }
        )

        Spacer(Modifier.height(Spacing.xl))

        // Legal text
        Text(
            text = "Subscriptions auto-renew until cancelled. " +
                    "Payment will be charged to your Google Play account. " +
                    "You can manage or cancel subscriptions in your Google Play settings.",
            style = MaterialTheme.typography.labelSmall,
            color = Color.White.copy(alpha = 0.4f),
            textAlign = TextAlign.Center
        )

        Spacer(Modifier.height(Spacing.xxl))
    }
}

@Composable
private fun ActiveSubscriptionContent(
    modifier: Modifier = Modifier,
    onBack: () -> Unit
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .padding(Spacing.xl),
        contentAlignment = Alignment.Center
    ) {
        GlassCard {
            Column(
                modifier = Modifier.padding(Spacing.xl),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Icon(
                    Icons.Default.Star,
                    contentDescription = null,
                    tint = premiumGold,
                    modifier = Modifier.size(64.dp)
                )
                Spacer(Modifier.height(Spacing.lg))
                Text(
                    text = "You're Premium!",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = premiumGold
                )
                Spacer(Modifier.height(Spacing.sm))
                Text(
                    text = "Thank you for supporting Foodshare. You have access to all premium features.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.White.copy(alpha = 0.7f),
                    textAlign = TextAlign.Center
                )
                Spacer(Modifier.height(Spacing.xl))
                GlassButton(
                    text = "Back",
                    onClick = onBack,
                    style = GlassButtonStyle.Secondary,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}
