package com.foodshare.features.insights.presentation

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.foodshare.features.insights.domain.model.CategoryStat
import com.foodshare.features.insights.domain.model.MonthlyStats
import com.foodshare.features.insights.domain.model.UserInsights
import com.foodshare.ui.design.tokens.LiquidGlassColors

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InsightsScreen(
    onNavigateBack: () -> Unit,
    viewModel: InsightsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Your Impact") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.Default.ArrowBack, "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent
                ),
                modifier = Modifier.background(
                    Brush.horizontalGradient(
                        colors = listOf(LiquidGlassColors.blueDark, LiquidGlassColors.brandPurple)
                    )
                )
            )
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(
                    Brush.verticalGradient(
                        colors = listOf(LiquidGlassColors.blueDark, LiquidGlassColors.brandPurple)
                    )
                )
        ) {
            when {
                uiState.isLoading -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(color = Color.White)
                    }
                }
                uiState.error != null -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = uiState.error ?: "Unknown error",
                            color = Color.White,
                            modifier = Modifier.padding(16.dp)
                        )
                    }
                }
                uiState.insights != null -> {
                    InsightsContent(insights = uiState.insights!!)
                }
            }
        }
    }
}

@Composable
private fun InsightsContent(insights: UserInsights) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Environmental Impact Cards
        item {
            Text(
                text = "Environmental Impact",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                modifier = Modifier.padding(vertical = 8.dp)
            )
        }

        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                ImpactCard(
                    icon = Icons.Default.Restaurant,
                    title = "Food Saved",
                    value = String.format("%.1f kg", insights.foodSavedKg),
                    modifier = Modifier.weight(1f)
                )
                ImpactCard(
                    icon = Icons.Default.CloudQueue,
                    title = "CO2 Saved",
                    value = String.format("%.1f kg", insights.co2SavedKg),
                    modifier = Modifier.weight(1f)
                )
            }
        }

        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                ImpactCard(
                    icon = Icons.Default.WaterDrop,
                    title = "Water Saved",
                    value = String.format("%.0f L", insights.waterSavedLiters),
                    modifier = Modifier.weight(1f)
                )
                ImpactCard(
                    icon = Icons.Default.AttachMoney,
                    title = "Money Saved",
                    value = String.format("$%.2f", insights.moneySaved),
                    modifier = Modifier.weight(1f)
                )
            }
        }

        // Activity Stats
        item {
            Text(
                text = "Activity",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                modifier = Modifier.padding(vertical = 8.dp)
            )
        }

        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                StatCard(
                    icon = Icons.Default.Upload,
                    title = "Items Shared",
                    value = insights.itemsShared.toString(),
                    modifier = Modifier.weight(1f)
                )
                StatCard(
                    icon = Icons.Default.Download,
                    title = "Items Received",
                    value = insights.itemsReceived.toString(),
                    modifier = Modifier.weight(1f)
                )
            }
        }

        // Streak
        item {
            if (insights.streakDays > 0) {
                StreakCard(streakDays = insights.streakDays)
            }
        }

        // Monthly Activity Chart
        item {
            if (insights.monthlyStats.isNotEmpty()) {
                Text(
                    text = "Monthly Activity",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                    modifier = Modifier.padding(vertical = 8.dp)
                )
            }
        }

        item {
            if (insights.monthlyStats.isNotEmpty()) {
                MonthlyActivityChart(monthlyStats = insights.monthlyStats)
            }
        }

        // Category Breakdown
        item {
            if (insights.categoryStats.isNotEmpty()) {
                Text(
                    text = "Category Breakdown",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                    modifier = Modifier.padding(vertical = 8.dp)
                )
            }
        }

        item {
            if (insights.categoryStats.isNotEmpty()) {
                CategoryBreakdown(categoryStats = insights.categoryStats)
            }
        }
    }
}

@Composable
private fun ImpactCard(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    value: String,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White.copy(alpha = 0.15f))
            .padding(16.dp)
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                icon,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(32.dp)
            )
            Text(
                text = value,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
            Text(
                text = title,
                style = MaterialTheme.typography.bodySmall,
                color = Color.White.copy(alpha = 0.7f)
            )
        }
    }
}

@Composable
private fun StatCard(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    value: String,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White.copy(alpha = 0.15f))
            .padding(16.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                icon,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(32.dp)
            )
            Column {
                Text(
                    text = value,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Text(
                    text = title,
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White.copy(alpha = 0.7f)
                )
            }
        }
    }
}

@Composable
private fun StreakCard(streakDays: Int) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(
                Brush.horizontalGradient(
                    colors = listOf(
                        Color(0xFFFF6B6B).copy(alpha = 0.3f),
                        Color(0xFFFFD93D).copy(alpha = 0.3f)
                    )
                )
            )
            .padding(16.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                Icons.Default.LocalFireDepartment,
                contentDescription = null,
                tint = Color(0xFFFF6B6B),
                modifier = Modifier.size(48.dp)
            )
            Column {
                Text(
                    text = "$streakDays day streak!",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Text(
                    text = "Keep it going!",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.White.copy(alpha = 0.7f)
                )
            }
        }
    }
}

@Composable
private fun MonthlyActivityChart(monthlyStats: List<MonthlyStats>) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(250.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White.copy(alpha = 0.15f))
            .padding(16.dp)
    ) {
        val maxValue = monthlyStats.maxOfOrNull { maxOf(it.shared, it.received) } ?: 1

        Canvas(modifier = Modifier.fillMaxSize()) {
            val barWidth = size.width / (monthlyStats.size * 2.5f)
            val spacing = barWidth * 0.3f

            monthlyStats.forEachIndexed { index, stats ->
                val x = index * (barWidth * 2 + spacing)

                // Shared bar
                val sharedHeight = (stats.shared.toFloat() / maxValue) * size.height * 0.8f
                drawRect(
                    color = Color(0xFF4CAF50),
                    topLeft = Offset(x, size.height - sharedHeight),
                    size = Size(barWidth, sharedHeight)
                )

                // Received bar
                val receivedHeight = (stats.received.toFloat() / maxValue) * size.height * 0.8f
                drawRect(
                    color = Color(0xFF2196F3),
                    topLeft = Offset(x + barWidth, size.height - receivedHeight),
                    size = Size(barWidth, receivedHeight)
                )
            }
        }

        // Legend
        Row(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(8.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            LegendItem(color = Color(0xFF4CAF50), label = "Shared")
            LegendItem(color = Color(0xFF2196F3), label = "Received")
        }
    }
}

@Composable
private fun LegendItem(color: Color, label: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Box(
            modifier = Modifier
                .size(12.dp)
                .background(color, RoundedCornerShape(2.dp))
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = Color.White.copy(alpha = 0.7f)
        )
    }
}

@Composable
private fun CategoryBreakdown(categoryStats: List<CategoryStat>) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White.copy(alpha = 0.15f))
            .padding(16.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            categoryStats.forEach { stat ->
                CategoryBar(stat = stat)
            }
        }
    }
}

@Composable
private fun CategoryBar(stat: CategoryStat) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = stat.category,
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White
            )
            Text(
                text = "${stat.count} (${String.format("%.1f%%", stat.percentage)})",
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(alpha = 0.7f)
            )
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(8.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(Color.White.copy(alpha = 0.2f))
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(fraction = (stat.percentage / 100).toFloat())
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(4.dp))
                    .background(Color(0xFF4CAF50))
            )
        }
    }
}
