package com.foodshare.features.subscription.presentation.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Block
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.foodshare.ui.design.components.cards.GlassCard
import com.foodshare.ui.design.tokens.Spacing

private val premiumGold = Color(0xFFFFD700)

@Composable
fun SubscriptionBenefits(
    modifier: Modifier = Modifier
) {
    val benefits = listOf(
        BenefitItem(Icons.Default.Block, "Ad-Free Experience", "Enjoy Foodshare without any advertisements"),
        BenefitItem(Icons.Default.Speed, "Priority Matching", "Get matched with food sharers first"),
        BenefitItem(Icons.Default.Verified, "Premium Badge", "Stand out with a verified premium badge"),
        BenefitItem(Icons.Default.AutoAwesome, "Advanced Filters", "Access premium search and filter options")
    )

    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(Spacing.sm)
    ) {
        benefits.forEach { benefit ->
            BenefitRow(benefit)
        }
    }
}

private data class BenefitItem(
    val icon: ImageVector,
    val title: String,
    val description: String
)

@Composable
private fun BenefitRow(benefit: BenefitItem) {
    GlassCard {
        Row(
            modifier = Modifier.padding(Spacing.md),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(premiumGold.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = benefit.icon,
                    contentDescription = null,
                    tint = premiumGold,
                    modifier = Modifier.size(24.dp)
                )
            }

            Spacer(Modifier.width(Spacing.md))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = benefit.title,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White
                )
                Text(
                    text = benefit.description,
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White.copy(alpha = 0.6f)
                )
            }
        }
    }
}
