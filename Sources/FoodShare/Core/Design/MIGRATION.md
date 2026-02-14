# Liquid Glass v26 Migration Guide

This guide helps you migrate from the old color system to the new Liquid Glass v26 design system.

## What Changed?

### ✅ Completed

1. **Unified Color System**: All colors now under `Color.DesignSystem.*`
2. **Direct Color Definitions**: No longer dependent on asset catalog
3. **Enhanced Gradients**: Pre-defined gradients for common use cases
4. **Category Colors**: Added to design system
5. **Deprecated Old APIs**: Legacy text styles marked as deprecated

### 🗑️ Removed

- `Foodshare/Core/Design/Tokens/Colors.swift` (old system)
- Direct color references like `Color.brandGreen`, `Color.brandBlue`

## Color Migration Map

| Old Reference | New Reference | Notes |
|--------------|---------------|-------|
| `Color.brandGreen` | `Color.DesignSystem.primary` | Main brand color |
| `Color.brandBlue` | `Color.DesignSystem.secondary` | Secondary brand color |
| `Color.brandOrange` | `Color.DesignSystem.accent` | Accent/urgency color |
| `Color.success` | `Color.DesignSystem.success` | Success states |
| `Color.warning` | `Color.DesignSystem.warning` | Warning states |
| `Color.error` | `Color.DesignSystem.error` | Error states |
| `Color.info` | `Color.DesignSystem.info` | Info states |
| `Color.glassBorder` | `Color.DesignSystem.glassBorder` | Glass borders |
| `Color.glassOverlay` | `Color.DesignSystem.glassBackground` | Glass backgrounds |
| `Color.textPrimary` | `Color.DesignSystem.text` | Primary text |
| `Color.textSecondary` | `Color.DesignSystem.textSecondary` | Secondary text |
| `Color.textTertiary` | `Color.DesignSystem.textTertiary` | Tertiary text |
| `Color.categoryProduce` | `Color.DesignSystem.categoryProduce` | Category colors |
| `Color.categoryDairy` | `Color.DesignSystem.categoryDairy` | Category colors |

## Typography Migration

### Old Style (Deprecated)

```swift
Text("Hello")
    .headlineStyle()  // ⚠️ Deprecated
```

### New Style (LG 26)

```swift
Text("Hello")
    .font(.DesignSystem.headlineMedium)
    .foregroundStyle(Color.DesignSystem.text)
```

## Common Patterns

### Before (Old System)

```swift
// Background gradient
LinearGradient(
    colors: [
        Color.brandGreen.opacity(0.15),
        Color.brandBlue.opacity(0.08),
        Color.brandGreen.opacity(0.12)
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

// Text styling
Text("Title")
    .font(.headline)
    .foregroundColor(.textPrimary)

// Glass card
VStack {
    Text("Content")
}
.background(Color.glassOverlay)
.overlay(
    RoundedRectangle(cornerRadius: 12)
        .stroke(Color.glassBorder, lineWidth: 1)
)
```

### After (LG 26)

```swift
// Background gradient (pre-defined)
Color.DesignSystem.backgroundGradient

// Text styling
Text("Title")
    .font(.DesignSystem.headlineMedium)
    .foregroundStyle(Color.DesignSystem.text)

// Glass card (using component)
VStack {
    Text("Content")
}
.glassCard(cornerRadius: 12, shadow: .medium)
```

## Step-by-Step Migration

### 1. Update Color References

Search for old color patterns and replace:

```bash
# Find old color references
grep -r "Color\.brand" Foodshare/
grep -r "\.textPrimary" Foodshare/
grep -r "\.glassBorder" Foodshare/
```

### 2. Update Typography

Replace deprecated text styles:

```swift
// Before
Text("Hello").headlineStyle()

// After
Text("Hello")
    .font(.DesignSystem.headlineMedium)
    .foregroundStyle(Color.DesignSystem.text)
```

### 3. Use Pre-defined Gradients

Replace custom gradients with design system gradients:

```swift
// Before
LinearGradient(
    colors: [Color.brandGreen, Color.brandGreen.opacity(0.8)],
    startPoint: .top,
    endPoint: .bottom
)

// After
Color.DesignSystem.primaryGradient
```

### 4. Use Glass Components

Replace custom glass effects with components:

```swift
// Before
VStack { }
    .background(Color.glassOverlay)
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.glassBorder))

// After
VStack { }
    .glassCard(cornerRadius: 12)
```

## Updated Components

All core components have been updated to LG 26:

- ✅ `GlassButton` - Uses `Color.DesignSystem.*`
- ✅ `GlassTextField` - Uses `Color.DesignSystem.*`
- ✅ `GlassCard` - Uses `Color.DesignSystem.*`
- ✅ `FoodItemCard` - Uses `Color.DesignSystem.*`
- ✅ `AuthenticationView` - Uses `Color.DesignSystem.*`

## Verification Checklist

After migration, verify:

- [ ] No compiler errors
- [ ] No deprecation warnings (or acknowledged)
- [ ] Colors look correct in light mode
- [ ] Colors look correct in dark mode
- [ ] Glass effects render properly
- [ ] Text is readable with proper contrast
- [ ] Gradients display smoothly
- [ ] Components match design specs

## Testing

Run these tests after migration:

```bash
# Build the project
xcodebuild -scheme Foodshare -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'

# Run tests
xcodebuild test -scheme Foodshare -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'

# Check for diagnostics
# Use Xcode's Issue Navigator (⌘5)
```

## Need Help?

- Review `Foodshare/Core/Design/README.md` for full documentation
- Check component examples in preview providers
- Reference `LiquidGlassColors.swift` for all available colors
- See `LiquidGlassTypography.swift` for typography scale

## Rollback (Emergency)

If you need to rollback:

1. The old `Colors.swift` has been deleted
2. Restore from git: `git checkout HEAD~1 -- Foodshare/Core/Design/Tokens/Colors.swift`
3. Revert color changes in components

**Note**: It's recommended to complete the migration rather than rollback, as the new system is more maintainable and consistent.

---

**Migration Date**: November 2025  
**Version**: 26  
**Status**: ✅ Complete
