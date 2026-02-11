package com.foodshare.features.profile.presentation.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.foodshare.core.validation.ValidationBridge
import com.foodshare.ui.design.components.buttons.GlassButton
import com.foodshare.ui.design.components.buttons.GlassButtonStyle
import com.foodshare.ui.design.components.cards.GlassCard
import com.foodshare.ui.design.components.inputs.GlassTextArea
import com.foodshare.ui.design.components.inputs.GlassTextField
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.Spacing

@Composable
fun InviteForm(
    email: String,
    emailError: String?,
    message: String,
    messageError: String?,
    successMessage: String?,
    error: String?,
    isSending: Boolean,
    canSend: Boolean,
    onEmailChange: (String) -> Unit,
    onMessageChange: (String) -> Unit,
    onSend: () -> Unit,
    modifier: Modifier = Modifier
) {
    GlassCard(modifier = modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(Spacing.md)) {
            Text(
                text = "Send Direct Invitation",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            Spacer(Modifier.height(Spacing.xxs))

            Text(
                text = "Send a personalized invitation directly to someone's email.",
                style = MaterialTheme.typography.bodySmall,
                color = Color.White.copy(alpha = 0.7f)
            )

            Spacer(Modifier.height(Spacing.sm))

            // Email input
            GlassTextField(
                value = email,
                onValueChange = onEmailChange,
                label = "Email Address",
                placeholder = "friend@example.com",
                error = emailError,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(Modifier.height(Spacing.xs))

            // Personal message
            GlassTextArea(
                value = message,
                onValueChange = onMessageChange,
                label = "Personal Message (optional)",
                placeholder = "Hey! Join me on FoodShare...",
                error = messageError,
                helperText = "${message.length}/${ValidationBridge.MAX_INVITATION_MESSAGE_LENGTH}",
                minLines = 3,
                maxLines = 5,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(Modifier.height(Spacing.sm))

            // Success message
            if (successMessage != null) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(8.dp))
                        .background(LiquidGlassColors.success.copy(alpha = 0.15f))
                        .padding(Spacing.xs),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.CheckCircle,
                        contentDescription = null,
                        tint = LiquidGlassColors.success,
                        modifier = Modifier.size(16.dp)
                    )

                    Spacer(Modifier.width(Spacing.xxs))

                    Text(
                        text = successMessage,
                        style = MaterialTheme.typography.bodySmall,
                        color = LiquidGlassColors.success
                    )
                }

                Spacer(Modifier.height(Spacing.xs))
            }

            // Error message
            if (error != null) {
                Text(
                    text = error,
                    style = MaterialTheme.typography.bodySmall,
                    color = LiquidGlassColors.error,
                    modifier = Modifier.padding(bottom = Spacing.xs)
                )
            }

            // Send button
            GlassButton(
                text = if (isSending) "Sending..." else "Send Invitation",
                onClick = onSend,
                icon = Icons.AutoMirrored.Filled.Send,
                style = GlassButtonStyle.PinkTeal,
                isLoading = isSending,
                enabled = canSend,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}
