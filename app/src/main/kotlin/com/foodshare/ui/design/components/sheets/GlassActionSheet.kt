package com.foodshare.ui.design.components.sheets

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.ui.semantics.Role
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.SheetState
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassAnimations
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing

/**
 * Glass Action data class
 *
 * @param label Display text for the action
 * @param icon Optional icon to show before the label
 * @param onClick Callback when action is tapped
 * @param isDestructive If true, shows action in red/destructive styling
 */
data class GlassAction(
    val label: String,
    val icon: ImageVector? = null,
    val onClick: () -> Unit,
    val isDestructive: Boolean = false
)

/**
 * Glassmorphism Action Sheet Component
 *
 * Features:
 * - List of labeled actions with icons
 * - Glass micro background on hover/press
 * - Destructive action styling (red text)
 * - Cancel button at bottom
 * - Scale animation on press
 *
 * Ported from iOS action sheet patterns
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GlassActionSheet(
    onDismiss: () -> Unit,
    actions: List<GlassAction>,
    modifier: Modifier = Modifier,
    sheetState: SheetState = rememberModalBottomSheetState()
) {
    GlassBottomSheet(
        onDismiss = onDismiss,
        modifier = modifier,
        sheetState = sheetState
    ) {
        // Action rows
        actions.forEachIndexed { index, action ->
            GlassActionRow(
                action = action,
                onClick = {
                    action.onClick()
                    onDismiss()
                }
            )

            // Spacer between actions
            if (index < actions.size - 1) {
                Spacer(modifier = Modifier.height(Spacing.xxs))
            }
        }

        // Spacing before cancel
        Spacer(modifier = Modifier.height(Spacing.sm))

        // Cancel button
        GlassActionRow(
            action = GlassAction(
                label = "Cancel",
                icon = null,
                onClick = {},
                isDestructive = false
            ),
            onClick = onDismiss,
            isCancelButton = true
        )
    }
}

/**
 * Individual action row with glass micro background on press
 */
@Composable
private fun GlassActionRow(
    action: GlassAction,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    isCancelButton: Boolean = false
) {
    var isPressed by remember { mutableStateOf(false) }

    val scale by animateFloatAsState(
        targetValue = if (isPressed) LiquidGlassAnimations.Scale.cardPressed else 1f,
        animationSpec = LiquidGlassAnimations.quickPress,
        label = "actionRowScale"
    )

    val rowShape = RoundedCornerShape(CornerRadius.medium)

    Row(
        modifier = modifier
            .fillMaxWidth()
            .scale(scale)
            .clip(rowShape)
            .background(
                brush = if (isPressed) {
                    LiquidGlassGradients.glassSurface
                } else {
                    LiquidGlassGradients.glassSurface
                },
                shape = rowShape
            )
            .border(
                width = 1.dp,
                color = if (isPressed) {
                    LiquidGlassColors.Glass.border
                } else {
                    LiquidGlassColors.Glass.micro
                },
                shape = rowShape
            )
            .clickable(role = Role.Button, onClick = onClick)
            .pointerInput(Unit) {
                detectTapGestures(
                    onPress = {
                        isPressed = true
                        tryAwaitRelease()
                        isPressed = false
                    }
                )
            }
            .padding(horizontal = Spacing.sm, vertical = Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        // Icon (if present)
        action.icon?.let {
            Icon(
                imageVector = it,
                contentDescription = action.label,
                tint = when {
                    action.isDestructive -> LiquidGlassColors.error
                    else -> Color.White
                },
                modifier = Modifier.size(22.dp)
            )
            Spacer(modifier = Modifier.width(Spacing.xs))
        }

        // Label
        Text(
            text = action.label,
            fontSize = 17.sp,
            fontWeight = if (isCancelButton) FontWeight.SemiBold else FontWeight.Medium,
            color = when {
                action.isDestructive -> LiquidGlassColors.error
                else -> Color.White
            }
        )
    }
}
