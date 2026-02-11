package com.foodshare.ui.design.components.layout

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.RowScope
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
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients

/**
 * Standard glass-themed scaffold used across all feature screens.
 *
 * Provides:
 * - Dark gradient background (darkAuth gradient)
 * - Transparent top bar with back navigation
 * - Consistent text styling and colors
 * - Optional actions and floating action button support
 *
 * This component eliminates duplication across screens by providing a single
 * source of truth for the common scaffold pattern used throughout the app.
 *
 * Example usage:
 * ```
 * GlassScaffold(
 *     title = "Settings",
 *     onNavigateBack = { navController.popBackStack() }
 * ) { padding ->
 *     LazyColumn(modifier = Modifier.padding(padding)) {
 *         // Your content here
 *     }
 * }
 * ```
 *
 * @param title The screen title displayed in the top bar
 * @param onNavigateBack Callback invoked when the back button is pressed
 * @param modifier Optional modifier for the scaffold
 * @param actions Optional actions to display in the top bar (e.g., save button)
 * @param floatingActionButton Optional floating action button
 * @param content The main content of the screen, receives PaddingValues from scaffold
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GlassScaffold(
    title: String,
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier,
    actions: @Composable RowScope.() -> Unit = {},
    floatingActionButton: @Composable () -> Unit = {},
    content: @Composable (PaddingValues) -> Unit
) {
    Scaffold(
        modifier = modifier.background(brush = LiquidGlassGradients.darkAuth),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = title,
                        fontWeight = FontWeight.Bold,
                        color = LiquidGlassColors.Text.primary
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Navigate back",
                            tint = LiquidGlassColors.Text.primary
                        )
                    }
                },
                actions = actions,
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent
                )
            )
        },
        floatingActionButton = floatingActionButton,
        content = content
    )
}
