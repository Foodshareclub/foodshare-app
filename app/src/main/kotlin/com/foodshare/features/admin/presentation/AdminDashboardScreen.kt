package com.foodshare.features.admin.presentation

import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AdminPanelSettings
import androidx.compose.material.icons.filled.Block
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.List
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Report
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.TabRowDefaults
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.foodshare.features.admin.presentation.components.AdminActivityCard
import com.foodshare.features.admin.presentation.components.AdminStatCard
import com.foodshare.features.admin.presentation.components.AdminDashboardStatsRow
import com.foodshare.features.admin.presentation.components.AdminUserChart
import com.foodshare.ui.design.components.cards.GlassCard
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminDashboardScreen(
    onNavigateBack: () -> Unit,
    viewModel: AdminViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }

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
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            Icons.Default.AdminPanelSettings,
                            contentDescription = null,
                            tint = LiquidGlassColors.brandTeal,
                            modifier = Modifier.size(24.dp)
                        )
                        Spacer(Modifier.width(Spacing.sm))
                        Text(
                            text = "Admin Dashboard",
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                    }
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
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            when {
                uiState.isLoading && !uiState.hasAccess -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(color = LiquidGlassColors.brandTeal)
                    }
                }

                !uiState.hasAccess -> {
                    AccessDenied()
                }

                else -> {
                    // Tab bar
                    AdminTabRow(
                        currentTab = uiState.currentTab,
                        onSelectTab = viewModel::selectTab
                    )

                    // Tab content
                    when (uiState.currentTab) {
                        AdminTab.Dashboard -> DashboardContent(uiState = uiState)
                        AdminTab.Users -> AdminUsersScreen(
                            uiState = uiState,
                            onSearchChange = viewModel::updateUserSearch,
                            onSelectUser = viewModel::selectUser,
                            onBanUser = viewModel::banUser,
                            onUnbanUser = viewModel::unbanUser,
                            onAssignRole = viewModel::assignRole,
                            onRevokeRole = viewModel::revokeRole
                        )
                        AdminTab.Moderation -> AdminModerationScreen(
                            uiState = uiState,
                            onFilterChange = viewModel::setModerationFilter,
                            onSelectItem = viewModel::selectModerationItem,
                            onResolve = viewModel::resolveModerationItem,
                            onDeletePost = viewModel::deletePost
                        )
                        AdminTab.AuditLog -> AdminAuditLogScreen(uiState = uiState)
                    }
                }
            }
        }
    }
}

@Composable
private fun AdminTabRow(
    currentTab: AdminTab,
    onSelectTab: (AdminTab) -> Unit
) {
    val tabs = listOf(
        AdminTab.Dashboard to "Dashboard",
        AdminTab.Users to "Users",
        AdminTab.Moderation to "Moderation",
        AdminTab.AuditLog to "Audit"
    )
    val selectedIndex = tabs.indexOfFirst { it.first == currentTab }

    TabRow(
        selectedTabIndex = selectedIndex,
        containerColor = Color.Transparent,
        contentColor = Color.White,
        indicator = { tabPositions ->
            if (selectedIndex < tabPositions.size) {
                TabRowDefaults.SecondaryIndicator(
                    modifier = Modifier.tabIndicatorOffset(tabPositions[selectedIndex]),
                    color = LiquidGlassColors.brandTeal
                )
            }
        }
    ) {
        tabs.forEachIndexed { index, (tab, label) ->
            Tab(
                selected = selectedIndex == index,
                onClick = { onSelectTab(tab) },
                text = {
                    Text(
                        text = label,
                        style = MaterialTheme.typography.labelMedium,
                        color = if (selectedIndex == index) Color.White else Color.White.copy(alpha = 0.5f)
                    )
                }
            )
        }
    }
}

@Composable
private fun DashboardContent(uiState: AdminUiState) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(Spacing.md)
    ) {
        // Stats grid
        AdminDashboardStatsRow(stats = uiState.stats)

        // Today's activity
        AdminActivityCard(stats = uiState.stats)

        // Ring chart
        AdminUserChart(
            active = uiState.stats.activeUsers,
            banned = uiState.stats.bannedUsers,
            total = uiState.stats.totalUsers
        )
    }
}

@Composable
private fun AccessDenied() {
    Box(
        modifier = Modifier
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
                    Icons.Default.Shield,
                    contentDescription = null,
                    tint = LiquidGlassColors.error,
                    modifier = Modifier.size(64.dp)
                )
                Spacer(Modifier.height(Spacing.lg))
                Text(
                    text = "Access Denied",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Spacer(Modifier.height(Spacing.sm))
                Text(
                    text = "You do not have admin privileges to access this area.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.White.copy(alpha = 0.7f),
                    textAlign = TextAlign.Center
                )
            }
        }
    }
}
