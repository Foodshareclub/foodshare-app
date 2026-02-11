---
name: liquid-glass-compose
description: Liquid Glass design system tokens and components for Foodshare Android Compose. Use when building UI, styling components, or reviewing visual consistency. All UI must use these tokens exclusively.
---

<objective>
All Foodshare Android UI must use the Liquid Glass design system. Never use raw Material defaults, hardcoded colors, or system typography.
</objective>

<essential_principles>
## Design System Files

| Token | File |
|-------|------|
| Colors | `ui/design/tokens/LiquidGlassColors.kt` |
| Typography | `ui/design/tokens/LiquidGlassTypography.kt` |
| Spacing | `ui/design/tokens/LiquidGlassSpacing.kt` |
| Animations | `ui/design/tokens/LiquidGlassAnimations.kt` |

## Required Tokens

### Colors
```kotlin
LiquidGlassColors.primary
LiquidGlassColors.background
LiquidGlassColors.glassBackground
LiquidGlassColors.textPrimary
LiquidGlassColors.textSecondary
LiquidGlassColors.surface
LiquidGlassColors.error
LiquidGlassColors.success
```

### Typography
```kotlin
LiquidGlassTypography.displayLarge
LiquidGlassTypography.headlineLarge
LiquidGlassTypography.headlineMedium
LiquidGlassTypography.bodyLarge
LiquidGlassTypography.bodyMedium
LiquidGlassTypography.caption
LiquidGlassTypography.label
```

### Spacing
```kotlin
LiquidGlassSpacing.xs   // 4.dp
LiquidGlassSpacing.sm   // 8.dp
LiquidGlassSpacing.md   // 16.dp
LiquidGlassSpacing.lg   // 24.dp
LiquidGlassSpacing.xl   // 32.dp
```

### Animations
```kotlin
LiquidGlassAnimations.defaultTween
LiquidGlassAnimations.springBounce
LiquidGlassAnimations.fadeIn
LiquidGlassAnimations.slideUp
```

## Required Components

```kotlin
GlassCard(modifier = Modifier) { /* content */ }
GlassButton(text = "Label", icon = Icons.Default.Add, style = GlassButtonStyle.Primary) { }
GlassTextField(value = text, onValueChange = { }, placeholder = "Search...", leadingIcon = Icons.Default.Search)
GlassBottomSheet { /* content */ }
FoodItemCard(listing = item, onClick = { })
```

## Forbidden

- Raw `Color.Blue`, `Color.Red`, or any non-design-system colors
- `MaterialTheme.typography.*` without Liquid Glass mapping
- `MaterialTheme.colorScheme.*` without Liquid Glass mapping
- Hardcoded `Dp` values for spacing (use `LiquidGlassSpacing.*`)
- Raw `Button`, `TextField`, `Card` without Glass wrappers
- Hardcoded font sizes
</essential_principles>

## Component Examples

### Glass Card
```kotlin
GlassCard(
    modifier = Modifier
        .fillMaxWidth()
        .padding(LiquidGlassSpacing.md),
) {
    Column(
        modifier = Modifier.padding(LiquidGlassSpacing.md),
        verticalArrangement = Arrangement.spacedBy(LiquidGlassSpacing.sm),
    ) {
        Text(
            text = listing.title,
            style = LiquidGlassTypography.headlineMedium,
            color = LiquidGlassColors.textPrimary,
        )
        Text(
            text = listing.description,
            style = LiquidGlassTypography.bodyMedium,
            color = LiquidGlassColors.textSecondary,
        )
    }
}
```

### Animated Transitions
```kotlin
AnimatedVisibility(
    visible = isVisible,
    enter = fadeIn(animationSpec = LiquidGlassAnimations.defaultTween) +
            slideInVertically(animationSpec = LiquidGlassAnimations.springBounce),
    exit = fadeOut(),
) {
    GlassCard { /* content */ }
}
```

<success_criteria>
Design system is correctly applied when:
- [ ] Zero hardcoded colors in Compose code
- [ ] Zero hardcoded spacing values
- [ ] All text uses LiquidGlassTypography styles
- [ ] All interactive elements use Glass* components
- [ ] Animations use LiquidGlassAnimations specs
- [ ] Dark/light mode handled by theme automatically
</success_criteria>
