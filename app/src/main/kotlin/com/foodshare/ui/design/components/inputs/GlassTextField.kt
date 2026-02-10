package com.foodshare.ui.design.components.inputs

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.LiquidGlassTypography
import com.foodshare.ui.design.tokens.Spacing

/**
 * Glass-styled text field component
 *
 * Features:
 * - Glassmorphism background
 * - Animated border on focus
 * - Error state styling
 * - Support for labels, placeholders, and helper text
 */
@Composable
fun GlassTextField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    label: String? = null,
    placeholder: String? = null,
    error: String? = null,
    helperText: String? = null,
    enabled: Boolean = true,
    readOnly: Boolean = false,
    singleLine: Boolean = true,
    minLines: Int = 1,
    maxLines: Int = if (singleLine) 1 else Int.MAX_VALUE,
    keyboardType: KeyboardType = KeyboardType.Text,
    imeAction: ImeAction = ImeAction.Default,
    onImeAction: () -> Unit = {},
    isPassword: Boolean = false,
    leadingIcon: @Composable (() -> Unit)? = null,
    trailingIcon: @Composable (() -> Unit)? = null,
    cornerRadius: Dp = CornerRadius.medium
) {
    var isFocused by remember { mutableStateOf(false) }
    val hasError = error != null

    val borderColor by animateColorAsState(
        targetValue = when {
            hasError -> LiquidGlassColors.error
            isFocused -> LiquidGlassColors.brandPink
            else -> LiquidGlassColors.Glass.border
        },
        label = "borderColor"
    )

    val shape = RoundedCornerShape(cornerRadius)

    Column(modifier = modifier) {
        // Label
        label?.let {
            Text(
                text = it,
                style = LiquidGlassTypography.labelMedium,
                color = if (hasError) LiquidGlassColors.error else MaterialTheme.colorScheme.onSurface
            )
            Spacer(Modifier.height(Spacing.xxs))
        }

        // Text field container
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(shape)
                .background(brush = LiquidGlassGradients.glassSurface)
                .border(
                    width = if (isFocused || hasError) 2.dp else 1.dp,
                    color = borderColor,
                    shape = shape
                )
                .padding(horizontal = Spacing.md, vertical = Spacing.sm)
        ) {
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                modifier = Modifier
                    .fillMaxWidth()
                    .onFocusChanged { isFocused = it.isFocused },
                enabled = enabled,
                readOnly = readOnly,
                textStyle = TextStyle(
                    color = MaterialTheme.colorScheme.onSurface,
                    fontSize = LiquidGlassTypography.bodyLarge.fontSize,
                    fontWeight = LiquidGlassTypography.bodyLarge.fontWeight
                ),
                keyboardOptions = KeyboardOptions(
                    keyboardType = keyboardType,
                    imeAction = imeAction
                ),
                keyboardActions = KeyboardActions(
                    onDone = { onImeAction() },
                    onGo = { onImeAction() },
                    onNext = { onImeAction() },
                    onSearch = { onImeAction() },
                    onSend = { onImeAction() }
                ),
                singleLine = singleLine,
                minLines = minLines,
                maxLines = maxLines,
                visualTransformation = if (isPassword) PasswordVisualTransformation() else VisualTransformation.None,
                cursorBrush = SolidColor(LiquidGlassColors.brandPink),
                decorationBox = { innerTextField ->
                    Box {
                        if (value.isEmpty() && placeholder != null) {
                            Text(
                                text = placeholder,
                                style = LiquidGlassTypography.bodyLarge,
                                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                            )
                        }
                        innerTextField()
                    }
                }
            )
        }

        // Error or helper text
        val bottomText = error ?: helperText
        bottomText?.let {
            Spacer(Modifier.height(Spacing.xxxs))
            Text(
                text = it,
                style = LiquidGlassTypography.captionSmall,
                color = if (hasError) LiquidGlassColors.error else MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

/**
 * Glass-styled password field with visibility toggle
 */
@Composable
fun GlassPasswordField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    label: String? = null,
    placeholder: String? = null,
    error: String? = null,
    enabled: Boolean = true,
    imeAction: ImeAction = ImeAction.Done,
    onImeAction: () -> Unit = {}
) {
    var passwordVisible by remember { mutableStateOf(false) }

    GlassTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier,
        label = label,
        placeholder = placeholder,
        error = error,
        enabled = enabled,
        singleLine = true,
        keyboardType = KeyboardType.Password,
        imeAction = imeAction,
        onImeAction = onImeAction,
        isPassword = !passwordVisible
    )
}

/**
 * Glass-styled multiline text area
 */
@Composable
fun GlassTextArea(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    label: String? = null,
    placeholder: String? = null,
    error: String? = null,
    helperText: String? = null,
    enabled: Boolean = true,
    minLines: Int = 3,
    maxLines: Int = 6
) {
    GlassTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier,
        label = label,
        placeholder = placeholder,
        error = error,
        helperText = helperText,
        enabled = enabled,
        singleLine = false,
        minLines = minLines,
        maxLines = maxLines,
        cornerRadius = CornerRadius.large
    )
}
