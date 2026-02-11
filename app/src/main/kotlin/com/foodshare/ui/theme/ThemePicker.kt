package com.foodshare.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.foodshare.ui.design.components.cards.GlassCard
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.Spacing

/**
 * Theme Picker component for selecting app theme
 *
 * Displays all 8 themes in a horizontal scrollable row
 * with preview colors and selection state.
 */
@Composable
fun ThemePicker(
    modifier: Modifier = Modifier
) {
    val currentTheme by ThemeManager.currentTheme.collectAsStateWithLifecycle()
    val colorSchemePreference by ThemeManager.colorSchemePreference.collectAsStateWithLifecycle()

    GlassCard(modifier = modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(Spacing.md)
        ) {
            // Section title
            Text(
                text = "Theme",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            Spacer(Modifier.height(Spacing.md))

            // Theme grid
            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm)
            ) {
                items(ThemeManager.availableThemes) { theme ->
                    ThemeCard(
                        theme = theme,
                        isSelected = theme.id == currentTheme.id,
                        onClick = { ThemeManager.setTheme(theme) }
                    )
                }
            }

            Spacer(Modifier.height(Spacing.lg))

            // Color scheme preference
            Text(
                text = "Appearance",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            Spacer(Modifier.height(Spacing.sm))

            ColorSchemeSelector(
                preference = colorSchemePreference,
                onPreferenceChange = { ThemeManager.setColorSchemePreference(it) }
            )
        }
    }
}

@Composable
private fun ThemeCard(
    theme: FoodShareTheme,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val borderColor = if (isSelected) Color.White else Color.Transparent

    Column(
        modifier = modifier
            .width(80.dp)
            .clip(RoundedCornerShape(CornerRadius.medium))
            .background(LiquidGlassColors.Glass.micro)
            .border(
                width = 2.dp,
                color = borderColor,
                shape = RoundedCornerShape(CornerRadius.medium)
            )
            .clickable(onClick = onClick)
            .padding(Spacing.sm),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Color preview circles
        Row(
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            theme.previewColors.forEach { color ->
                Box(
                    modifier = Modifier
                        .size(24.dp)
                        .clip(CircleShape)
                        .background(color)
                )
            }
        }

        Spacer(Modifier.height(Spacing.xs))

        // Theme icon
        Text(
            text = theme.id.icon,
            style = MaterialTheme.typography.titleLarge
        )

        Spacer(Modifier.height(Spacing.xxs))

        // Theme name
        Text(
            text = theme.id.displayName,
            style = MaterialTheme.typography.labelSmall,
            color = Color.White,
            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
        )

        // Selection indicator
        if (isSelected) {
            Spacer(Modifier.height(Spacing.xxs))
            Icon(
                imageVector = Icons.Default.Check,
                contentDescription = "Selected",
                tint = LiquidGlassColors.success,
                modifier = Modifier.size(16.dp)
            )
        }
    }
}

@Composable
private fun ColorSchemeSelector(
    preference: ColorSchemePreference,
    onPreferenceChange: (ColorSchemePreference) -> Unit,
    modifier: Modifier = Modifier
) {
    SingleChoiceSegmentedButtonRow(
        modifier = modifier.fillMaxWidth()
    ) {
        SegmentedButton(
            selected = preference == ColorSchemePreference.LIGHT,
            onClick = { onPreferenceChange(ColorSchemePreference.LIGHT) },
            shape = SegmentedButtonDefaults.itemShape(index = 0, count = 3),
            icon = {
                Icon(
                    imageVector = Icons.Default.LightMode,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp)
                )
            }
        ) {
            Text("Light")
        }

        SegmentedButton(
            selected = preference == ColorSchemePreference.SYSTEM,
            onClick = { onPreferenceChange(ColorSchemePreference.SYSTEM) },
            shape = SegmentedButtonDefaults.itemShape(index = 1, count = 3),
            icon = {
                Icon(
                    imageVector = Icons.Default.Settings,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp)
                )
            }
        ) {
            Text("Auto")
        }

        SegmentedButton(
            selected = preference == ColorSchemePreference.DARK,
            onClick = { onPreferenceChange(ColorSchemePreference.DARK) },
            shape = SegmentedButtonDefaults.itemShape(index = 2, count = 3),
            icon = {
                Icon(
                    imageVector = Icons.Default.DarkMode,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp)
                )
            }
        ) {
            Text("Dark")
        }
    }
}

/**
 * Compact theme picker for use in settings lists
 */
@Composable
fun ThemePickerCompact(
    modifier: Modifier = Modifier,
    onExpandRequest: () -> Unit = {}
) {
    val currentTheme by ThemeManager.currentTheme.collectAsStateWithLifecycle()

    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(CornerRadius.medium))
            .background(LiquidGlassColors.Glass.micro)
            .clickable(onClick = onExpandRequest)
            .padding(Spacing.md),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Preview colors
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                currentTheme.previewColors.forEach { color ->
                    Box(
                        modifier = Modifier
                            .size(20.dp)
                            .clip(CircleShape)
                            .background(color)
                    )
                }
            }

            Column {
                Text(
                    text = "Theme",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    color = Color.White
                )
                Text(
                    text = currentTheme.id.displayName,
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.White.copy(alpha = 0.6f)
                )
            }
        }

        Text(
            text = currentTheme.id.icon,
            style = MaterialTheme.typography.titleLarge
        )
    }
}
