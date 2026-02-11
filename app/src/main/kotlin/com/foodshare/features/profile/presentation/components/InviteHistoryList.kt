package com.foodshare.features.profile.presentation.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.HourglassEmpty
import androidx.compose.material.icons.filled.Mail
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.foodshare.core.invitation.SentInvite
import com.foodshare.core.validation.ValidationBridge
import com.foodshare.ui.design.components.cards.GlassCard
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.Spacing

@Composable
fun InviteHistoryList(
    invites: List<SentInvite>,
    modifier: Modifier = Modifier
) {
    GlassCard(modifier = modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(Spacing.md)) {
            Text(
                text = "Sent Invitations",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            Spacer(Modifier.height(Spacing.xs))

            invites.forEach { invite ->
                InviteHistoryRow(invite = invite)
                Spacer(Modifier.height(Spacing.xxs))
            }
        }
    }
}

@Composable
private fun InviteHistoryRow(
    invite: SentInvite,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(LiquidGlassColors.Glass.micro)
            .padding(Spacing.xs),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Email icon
        Icon(
            imageVector = Icons.Default.Mail,
            contentDescription = null,
            tint = Color.White.copy(alpha = 0.6f),
            modifier = Modifier.size(18.dp)
        )

        Spacer(Modifier.width(Spacing.xxs))

        // Email and date
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = invite.email,
                style = MaterialTheme.typography.bodySmall,
                fontWeight = FontWeight.Medium,
                color = Color.White,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = ValidationBridge.formatDateShort(invite.sentAt),
                style = MaterialTheme.typography.labelSmall,
                color = Color.White.copy(alpha = 0.5f)
            )
        }

        Spacer(Modifier.width(Spacing.xxs))

        // Status indicator
        InviteStatusIndicator(status = invite.status)
    }
}

@Composable
private fun InviteStatusIndicator(
    status: String,
    modifier: Modifier = Modifier
) {
    val statusColor = when (status.lowercase()) {
        "accepted" -> LiquidGlassColors.success
        "expired" -> LiquidGlassColors.accentGray
        else -> LiquidGlassColors.warning
    }

    val statusIcon = when (status.lowercase()) {
        "accepted" -> Icons.Default.CheckCircle
        "expired" -> Icons.Default.Timer
        else -> Icons.Default.HourglassEmpty
    }

    val statusLabel = when (status.lowercase()) {
        "accepted" -> "Accepted"
        "expired" -> "Expired"
        else -> "Sent"
    }

    Row(
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .background(statusColor.copy(alpha = 0.15f))
            .padding(horizontal = Spacing.xxs, vertical = Spacing.xxxs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.xxxs)
    ) {
        Icon(
            imageVector = statusIcon,
            contentDescription = null,
            tint = statusColor,
            modifier = Modifier.size(12.dp)
        )

        Text(
            text = statusLabel,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            color = statusColor
        )
    }
}
