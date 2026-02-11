package com.foodshare.features.auth.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.foodshare.ui.design.components.buttons.GlassButton
import com.foodshare.ui.design.components.buttons.GlassButtonStyle
import com.foodshare.ui.design.components.cards.GlassCard
import com.foodshare.ui.design.components.sheets.GlassBottomSheet
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing
import androidx.compose.material3.ExperimentalMaterial3Api

/**
 * Sign In Prompt Screen
 *
 * A GlassBottomSheet-based prompt shown when guest users try restricted actions
 *
 * Features:
 * - Lock icon with brand gradient background
 * - Title "Sign In Required"
 * - Feature-specific description explaining benefit
 * - Sign In button (Primary)
 * - Maybe Later button (Ghost)
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SignInPromptScreen(
    onSignIn: () -> Unit,
    onDismiss: () -> Unit,
    featureDescription: String = "Sign in to access this feature and unlock the full FoodShare experience."
) {
    GlassBottomSheet(
        onDismiss = onDismiss,
        title = null
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.md),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.md)
        ) {
            // Lock icon with brand gradient background
            Box(
                modifier = Modifier
                    .size(80.dp)
                    .background(
                        brush = LiquidGlassGradients.brand,
                        shape = CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.Lock,
                    contentDescription = "Sign In Required",
                    tint = Color.White,
                    modifier = Modifier.size(40.dp)
                )
            }

            Spacer(Modifier.height(Spacing.sm))

            // Title
            Text(
                text = "Sign In Required",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                textAlign = TextAlign.Center
            )

            // Description
            Text(
                text = featureDescription,
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(alpha = 0.7f),
                textAlign = TextAlign.Center
            )

            Spacer(Modifier.height(Spacing.md))

            // Sign In button
            GlassButton(
                text = "Sign In",
                onClick = onSignIn,
                style = GlassButtonStyle.Primary,
                modifier = Modifier.fillMaxWidth()
            )

            // Maybe Later button
            GlassButton(
                text = "Maybe Later",
                onClick = onDismiss,
                style = GlassButtonStyle.Ghost,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}
