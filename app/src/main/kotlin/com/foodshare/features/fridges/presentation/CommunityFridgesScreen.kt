package com.foodshare.features.fridges.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.foodshare.features.fridges.domain.model.CommunityFridge
import com.foodshare.features.fridges.domain.model.FridgeStatus
import com.foodshare.features.fridges.domain.model.StockLevel
import com.foodshare.ui.design.tokens.LiquidGlassColors

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CommunityFridgesScreen(
    onNavigateToDetail: (Int) -> Unit,
    onNavigateBack: () -> Unit,
    viewModel: CommunityFridgesViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Community Fridges") },
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
            Column(
                modifier = Modifier.fillMaxSize()
            ) {
                // Filter and View Mode Controls
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Filter Chips
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        FridgeFilter.entries.forEach { filter ->
                            FilterChip(
                                selected = uiState.selectedFilter == filter,
                                onClick = { viewModel.filterByStatus(filter) },
                                label = {
                                    Text(
                                        when (filter) {
                                            FridgeFilter.ALL -> "All"
                                            FridgeFilter.ACTIVE -> "Active"
                                            FridgeFilter.LOW_STOCK -> "Low Stock"
                                        }
                                    )
                                }
                            )
                        }
                    }

                    // View Mode Toggle
                    IconButton(
                        onClick = { viewModel.toggleViewMode() }
                    ) {
                        Icon(
                            if (uiState.viewMode == ViewMode.MAP) Icons.Default.List else Icons.Default.Map,
                            contentDescription = "Toggle View",
                            tint = Color.White
                        )
                    }
                }

                // Content
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
                    uiState.viewMode == ViewMode.LIST -> {
                        FridgesList(
                            fridges = uiState.filteredFridges,
                            onFridgeClick = onNavigateToDetail
                        )
                    }
                    else -> {
                        // Map View - Placeholder for now
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = "Map view - Google Maps integration required",
                                color = Color.White,
                                modifier = Modifier.padding(16.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FridgesList(
    fridges: List<CommunityFridge>,
    onFridgeClick: (Int) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        items(fridges) { fridge ->
            FridgeCard(
                fridge = fridge,
                onClick = { onFridgeClick(fridge.id) }
            )
        }
    }
}

@Composable
private fun FridgeCard(
    fridge: CommunityFridge,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White.copy(alpha = 0.15f))
            .clickable(onClick = onClick)
            .padding(16.dp)
    ) {
        Column(
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = fridge.name,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )

                StockLevelBadge(stockLevel = fridge.stockLevel)
            }

            Row(
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    Icons.Default.LocationOn,
                    contentDescription = null,
                    tint = Color.White.copy(alpha = 0.7f),
                    modifier = Modifier.size(16.dp)
                )
                Text(
                    text = fridge.address,
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.White.copy(alpha = 0.7f)
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.CheckCircle,
                        contentDescription = null,
                        tint = if (fridge.status == FridgeStatus.ACTIVE) Color.Green else Color.Gray,
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        text = fridge.status.name.lowercase().replaceFirstChar { it.uppercase() },
                        style = MaterialTheme.typography.bodySmall,
                        color = Color.White.copy(alpha = 0.7f)
                    )
                }

                fridge.distance?.let { distance ->
                    Text(
                        text = String.format("%.1f km", distance),
                        style = MaterialTheme.typography.bodySmall,
                        color = Color.White.copy(alpha = 0.7f)
                    )
                }
            }
        }
    }
}

@Composable
private fun StockLevelBadge(stockLevel: StockLevel) {
    val (color, text) = when (stockLevel) {
        StockLevel.FULL -> Color(0xFF4CAF50) to "Full"
        StockLevel.HALF -> Color(0xFFFFEB3B) to "Half"
        StockLevel.LOW -> Color(0xFFFF9800) to "Low"
        StockLevel.EMPTY -> Color(0xFFF44336) to "Empty"
        StockLevel.UNKNOWN -> Color.Gray to "Unknown"
    }

    Surface(
        color = color.copy(alpha = 0.3f),
        shape = RoundedCornerShape(8.dp),
        modifier = Modifier.padding(4.dp)
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelSmall,
            color = color,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
        )
    }
}
