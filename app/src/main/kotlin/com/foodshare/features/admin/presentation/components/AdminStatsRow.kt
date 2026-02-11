package com.foodshare.features.admin.presentation.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Block
import androidx.compose.material.icons.filled.List
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Report
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.foodshare.features.admin.domain.model.AdminDashboardStats
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.Spacing

@Composable
fun AdminDashboardStatsRow(
    stats: AdminDashboardStats,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm)
    ) {
        AdminStatCard(
            title = "Total Users",
            value = stats.totalUsers.toString(),
            icon = Icons.Default.People,
            color = LiquidGlassColors.brandTeal,
            modifier = Modifier.weight(1f)
        )
        AdminStatCard(
            title = "Active Posts",
            value = stats.activePosts.toString(),
            icon = Icons.Default.List,
            color = LiquidGlassColors.success,
            modifier = Modifier.weight(1f)
        )
    }

    Spacer(Modifier.height(Spacing.sm))

    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm)
    ) {
        AdminStatCard(
            title = "Pending Reports",
            value = stats.pendingReports.toString(),
            icon = Icons.Default.Report,
            color = LiquidGlassColors.warning,
            modifier = Modifier.weight(1f)
        )
        AdminStatCard(
            title = "Banned Users",
            value = stats.bannedUsers.toString(),
            icon = Icons.Default.Block,
            color = LiquidGlassColors.error,
            modifier = Modifier.weight(1f)
        )
    }
}
