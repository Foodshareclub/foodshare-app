package com.foodshare.features.help.presentation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.foodshare.features.help.presentation.components.ContactCard
import com.foodshare.features.help.presentation.components.FAQSection
import com.foodshare.ui.design.components.backgrounds.AnimatedMeshGradientBackground
import com.foodshare.ui.design.components.inputs.GlassSearchBar
import com.foodshare.ui.design.tokens.Spacing

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HelpCenterScreen(
    onNavigateBack: () -> Unit,
    onNavigateToConversation: (String) -> Unit = {},
    viewModel: HelpCenterViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val context = androidx.compose.ui.platform.LocalContext.current

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Help Center", color = Color.White) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
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
        containerColor = Color.Transparent
    ) { paddingValues ->
        Box(modifier = Modifier.fillMaxSize()) {
            AnimatedMeshGradientBackground()
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
                    .padding(horizontal = Spacing.md)
            ) {
                // Search bar
                GlassSearchBar(
                    value = uiState.searchQuery,
                    onValueChange = { viewModel.search(it) },
                    placeholder = "Search FAQs...",
                    onClear = { viewModel.clearSearch() },
                    modifier = Modifier.fillMaxWidth()
                )

                Spacer(Modifier.height(Spacing.md))

                // Scrollable content
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                ) {
                    // FAQ sections
                    uiState.filteredSections.forEach { section ->
                        FAQSection(
                            title = section.title,
                            items = section.items,
                            modifier = Modifier.fillMaxWidth()
                        )
                        Spacer(Modifier.height(Spacing.lg))
                    }

                    // Contact card
                    ContactCard(
                        onEmailClick = {
                            val intent = android.content.Intent(android.content.Intent.ACTION_SENDTO).apply {
                                data = android.net.Uri.parse("mailto:support@foodshare.club")
                                putExtra(android.content.Intent.EXTRA_SUBJECT, "FoodShare Support Request")
                            }
                            context.startActivity(intent)
                        },
                        onChatClick = {
                            // Navigate to support chat (room ID: "support")
                            onNavigateToConversation("support")
                        },
                        modifier = Modifier.fillMaxWidth()
                    )

                    Spacer(Modifier.height(Spacing.xl))
                }
            }
        }
    }
}
