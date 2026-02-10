package com.foodshare.features.debug

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.foodshare.core.localization.TranslationService
import kotlinx.coroutines.launch

/**
 * Debug screen to test the TranslationService
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun TranslationTestScreen(
    onBack: () -> Unit = {}
) {
    val context = LocalContext.current
    val translationService = remember { TranslationService.getInstance(context) }
    val scope = rememberCoroutineScope()
    
    val currentLocale by translationService.currentLocale.collectAsState()
    val isLoading by translationService.isLoading.collectAsState()
    val lastSyncDate by translationService.lastSyncDate.collectAsState()
    val error by translationService.error.collectAsState()
    
    var syncStatus by remember { mutableStateOf("Not synced yet") }
    var testResults by remember { mutableStateOf<List<Pair<String, String>>>(emptyList()) }
    
    // Test keys to verify
    val testKeys = listOf(
        "welcome_to_foodshare",
        "login",
        "cancel",
        "search",
        "settings",
        "profile.avatar.upload",
        "categories.food",
        "categories.things",
        "Chat.messages",
        "Chat.sendMessage",
        "ForgotPassword.title",
        "Common.refresh"
    )
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Translation Test") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                    }
                },
                actions = {
                    IconButton(
                        onClick = {
                            scope.launch {
                                syncStatus = "Syncing..."
                                try {
                                    translationService.sync(force = true)
                                    syncStatus = "Sync complete!"
                                    // Update test results
                                    testResults = testKeys.map { key ->
                                        key to translationService.t(key)
                                    }
                                } catch (e: Exception) {
                                    syncStatus = "Sync failed: ${e.message}"
                                }
                            }
                        },
                        enabled = !isLoading
                    ) {
                        Icon(Icons.Default.Refresh, "Sync")
                    }
                }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Status section
            item {
                Card(
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            "Status",
                            style = MaterialTheme.typography.titleMedium
                        )
                        
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text("Current Locale:")
                            Text(currentLocale, color = MaterialTheme.colorScheme.primary)
                        }
                        
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text("Loading:")
                            Text(if (isLoading) "Yes" else "No")
                        }
                        
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text("Last Sync:")
                            Text(lastSyncDate?.toString() ?: "Never")
                        }
                        
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text("Sync Status:")
                            Text(syncStatus)
                        }
                        
                        error?.let { err ->
                            Text(
                                "Error: ${err.message}",
                                color = MaterialTheme.colorScheme.error
                            )
                        }
                    }
                }
            }
            
            // Locale selector
            item {
                Card(
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            "Change Locale",
                            style = MaterialTheme.typography.titleMedium
                        )
                        
                        FlowRow(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            TranslationService.SUPPORTED_LOCALES.forEach { locale ->
                                FilterChip(
                                    selected = locale == currentLocale,
                                    onClick = {
                                        scope.launch {
                                            try {
                                                translationService.setLocale(locale)
                                                testResults = testKeys.map { key ->
                                                    key to translationService.t(key)
                                                }
                                            } catch (e: Exception) {
                                                syncStatus = "Failed to change locale: ${e.message}"
                                            }
                                        }
                                    },
                                    label = { Text(locale.uppercase()) }
                                )
                            }
                        }
                    }
                }
            }
            
            // Test results
            item {
                Text(
                    "Translation Tests",
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.padding(top = 8.dp)
                )
            }
            
            if (testResults.isEmpty()) {
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(32.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Text("Tap the refresh button to sync translations")
                                if (isLoading) {
                                    CircularProgressIndicator(modifier = Modifier.size(24.dp))
                                }
                            }
                        }
                    }
                }
            }
            
            items(testResults) { (key, value) ->
                Card(
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(
                        modifier = Modifier.padding(12.dp)
                    ) {
                        Text(
                            key,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            value,
                            style = MaterialTheme.typography.bodyMedium,
                            color = if (value == key) {
                                MaterialTheme.colorScheme.error
                            } else {
                                MaterialTheme.colorScheme.onSurface
                            }
                        )
                    }
                }
            }
            
            // Spacer at bottom
            item {
                Spacer(modifier = Modifier.height(32.dp))
            }
        }
    }
}
