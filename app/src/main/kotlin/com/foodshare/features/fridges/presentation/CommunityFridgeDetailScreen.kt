package com.foodshare.features.fridges.presentation

import android.content.Intent
import android.net.Uri
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
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import com.foodshare.features.fridges.domain.model.CommunityFridge
import com.foodshare.features.fridges.domain.model.FridgeReport
import com.foodshare.features.fridges.domain.model.FridgeStatus
import com.foodshare.features.fridges.domain.model.StockLevel
import com.foodshare.ui.design.tokens.LiquidGlassColors
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CommunityFridgeDetailScreen(
    onNavigateBack: () -> Unit,
    viewModel: CommunityFridgeDetailViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    var showReportDialog by remember { mutableStateOf(false) }

    LaunchedEffect(uiState.reportSuccess) {
        if (uiState.reportSuccess) {
            viewModel.clearReportSuccess()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(uiState.fridge?.name ?: "Fridge Details") },
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
                uiState.fridge != null -> {
                    FridgeDetailContent(
                        fridge = uiState.fridge!!,
                        reports = uiState.reports,
                        onReportStock = { showReportDialog = true },
                        onGetDirections = {
                            val uri = Uri.parse(
                                "geo:${uiState.fridge!!.latitude},${uiState.fridge!!.longitude}?q=${uiState.fridge!!.address}"
                            )
                            val intent = Intent(Intent.ACTION_VIEW, uri)
                            intent.setPackage("com.google.android.apps.maps")
                            context.startActivity(intent)
                        }
                    )
                }
            }
        }
    }

    if (showReportDialog) {
        ReportStockDialog(
            onDismiss = { showReportDialog = false },
            onReport = { stockLevel, notes ->
                viewModel.reportStock(stockLevel, notes)
                showReportDialog = false
            },
            isReporting = uiState.isReporting
        )
    }
}

@Composable
private fun FridgeDetailContent(
    fridge: CommunityFridge,
    reports: List<FridgeReport>,
    onReportStock: () -> Unit,
    onGetDirections: () -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Photo Header
        item {
            if (fridge.photoUrl != null) {
                AsyncImage(
                    model = fridge.photoUrl,
                    contentDescription = "Fridge Photo",
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(200.dp)
                        .clip(RoundedCornerShape(16.dp)),
                    contentScale = ContentScale.Crop
                )
            }
        }

        // Details Section
        item {
            GlassDetailSection(title = "Details") {
                DetailRow(icon = Icons.Default.LocationOn, label = "Address", value = fridge.address)
                fridge.operatingHours?.let {
                    DetailRow(icon = Icons.Default.Schedule, label = "Operating Hours", value = it)
                }
                DetailRow(
                    icon = Icons.Default.CheckCircle,
                    label = "Status",
                    value = fridge.status.name.lowercase().replaceFirstChar { it.uppercase() }
                )
                DetailRow(
                    icon = Icons.Default.Inventory,
                    label = "Stock Level",
                    value = fridge.stockLevel.name.lowercase().replaceFirstChar { it.uppercase() }
                )
            }
        }

        // Description
        item {
            if (fridge.description != null) {
                GlassDetailSection(title = "Description") {
                    Text(
                        text = fridge.description,
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color.White.copy(alpha = 0.9f)
                    )
                }
            }
        }

        // Action Buttons
        item {
            Column(
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Button(
                    onClick = onReportStock,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color.White.copy(alpha = 0.2f)
                    )
                ) {
                    Icon(Icons.Default.Report, contentDescription = null)
                    Spacer(Modifier.width(8.dp))
                    Text("Report Stock Level")
                }

                Button(
                    onClick = onGetDirections,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color.White.copy(alpha = 0.2f)
                    )
                ) {
                    Icon(Icons.Default.Directions, contentDescription = null)
                    Spacer(Modifier.width(8.dp))
                    Text("Get Directions")
                }
            }
        }

        // Recent Reports
        item {
            if (reports.isNotEmpty()) {
                GlassDetailSection(title = "Recent Reports") {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        reports.forEach { report ->
                            ReportItem(report = report)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun GlassDetailSection(
    title: String,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White.copy(alpha = 0.15f))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
        content()
    }
}

@Composable
private fun DetailRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    value: String
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = Color.White.copy(alpha = 0.7f),
            modifier = Modifier.size(20.dp)
        )
        Column {
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = Color.White.copy(alpha = 0.6f)
            )
            Text(
                text = value,
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(alpha = 0.9f)
            )
        }
    }
}

@Composable
private fun ReportItem(report: FridgeReport) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(Color.White.copy(alpha = 0.1f))
            .padding(12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column {
            Text(
                text = report.stockLevel.name.lowercase().replaceFirstChar { it.uppercase() },
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
            report.notes?.let {
                Text(
                    text = it,
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White.copy(alpha = 0.7f)
                )
            }
        }
        report.createdAt?.let {
            Text(
                text = formatTimestamp(it),
                style = MaterialTheme.typography.bodySmall,
                color = Color.White.copy(alpha = 0.6f)
            )
        }
    }
}

@Composable
private fun ReportStockDialog(
    onDismiss: () -> Unit,
    onReport: (StockLevel, String?) -> Unit,
    isReporting: Boolean
) {
    var selectedLevel by remember { mutableStateOf<StockLevel?>(null) }
    var notes by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Report Stock Level") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Select current stock level:")

                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    StockLevel.entries.filter { it != StockLevel.UNKNOWN }.forEach { level ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(8.dp))
                                .background(
                                    if (selectedLevel == level)
                                        MaterialTheme.colorScheme.primaryContainer
                                    else
                                        Color.Transparent
                                )
                                .clickable { selectedLevel = level }
                                .padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            RadioButton(
                                selected = selectedLevel == level,
                                onClick = { selectedLevel = level }
                            )
                            Spacer(Modifier.width(8.dp))
                            Text(level.name.lowercase().replaceFirstChar { it.uppercase() })
                        }
                    }
                }

                OutlinedTextField(
                    value = notes,
                    onValueChange = { notes = it },
                    label = { Text("Notes (optional)") },
                    modifier = Modifier.fillMaxWidth(),
                    maxLines = 3
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    selectedLevel?.let { onReport(it, notes.takeIf { it.isNotBlank() }) }
                },
                enabled = selectedLevel != null && !isReporting
            ) {
                if (isReporting) {
                    CircularProgressIndicator(modifier = Modifier.size(16.dp))
                } else {
                    Text("Submit")
                }
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss, enabled = !isReporting) {
                Text("Cancel")
            }
        }
    )
}

private fun formatTimestamp(timestamp: String): String {
    return try {
        val instant = Instant.parse(timestamp)
        val formatter = DateTimeFormatter.ofPattern("MMM dd, HH:mm")
            .withZone(ZoneId.systemDefault())
        formatter.format(instant)
    } catch (e: Exception) {
        timestamp
    }
}
