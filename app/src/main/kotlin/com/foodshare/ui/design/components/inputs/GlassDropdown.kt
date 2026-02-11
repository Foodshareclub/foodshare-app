package com.foodshare.ui.design.components.inputs

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.foodshare.ui.design.tokens.*

/**
 * Dropdown menu with glass styling
 * Uses ExposedDropdownMenuBox for Material Design dropdown behavior
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GlassDropdown(
    selectedValue: String,
    options: List<String>,
    onOptionSelected: (String) -> Unit,
    modifier: Modifier = Modifier,
    label: String? = null,
    enabled: Boolean = true
) {
    var expanded by remember { mutableStateOf(false) }

    val arrowRotation by animateFloatAsState(
        targetValue = if (expanded) 180f else 0f,
        animationSpec = tween(durationMillis = LiquidGlassAnimations.Duration.standard),
        label = "arrow_rotation"
    )

    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(Spacing.xs)
    ) {
        // Optional label
        label?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.labelMedium,
                color = LiquidGlassColors.Text.secondary
            )
        }

        ExposedDropdownMenuBox(
            expanded = expanded,
            onExpandedChange = { if (enabled) expanded = !expanded }
        ) {
            // Dropdown trigger
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .menuAnchor()
                    .clip(RoundedCornerShape(CornerRadius.medium))
                    .background(LiquidGlassColors.Glass.surface)
                    .border(
                        width = 1.dp,
                        color = LiquidGlassColors.Glass.border,
                        shape = RoundedCornerShape(CornerRadius.medium)
                    )
                    .clickable(enabled = enabled) { expanded = !expanded }
                    .padding(horizontal = Spacing.md, vertical = Spacing.sm)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = selectedValue.ifEmpty { "Select an option" },
                        style = MaterialTheme.typography.bodyMedium,
                        color = if (selectedValue.isEmpty()) {
                            LiquidGlassColors.Text.secondary
                        } else {
                            LiquidGlassColors.Text.primary
                        }
                    )

                    Icon(
                        imageVector = Icons.Default.ArrowDropDown,
                        contentDescription = if (expanded) "Collapse" else "Expand",
                        tint = LiquidGlassColors.Text.secondary,
                        modifier = Modifier.rotate(arrowRotation)
                    )
                }
            }

            // Dropdown menu
            ExposedDropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false },
                modifier = Modifier
                    .background(LiquidGlassColors.Glass.surface)
                    .border(
                        width = 1.dp,
                        color = LiquidGlassColors.Glass.border,
                        shape = RoundedCornerShape(CornerRadius.medium)
                    )
            ) {
                options.forEach { option ->
                    DropdownMenuItem(
                        text = {
                            Text(
                                text = option,
                                style = MaterialTheme.typography.bodyMedium,
                                color = LiquidGlassColors.Text.primary
                            )
                        },
                        onClick = {
                            onOptionSelected(option)
                            expanded = false
                        },
                        modifier = Modifier.background(
                            color = if (option == selectedValue) {
                                LiquidGlassColors.Glass.micro
                            } else {
                                Color.Transparent
                            }
                        )
                    )
                }
            }
        }
    }
}
