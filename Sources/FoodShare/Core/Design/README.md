# Liquid Glass Design System v26

The Liquid Glass Design System v26 is Foodshare's comprehensive design language featuring glassmorphism aesthetics with a premium, modern feel inspired by Airbnb.

## Design Philosophy

- **Glassmorphism**: Frosted glass effects with semi-transparent backgrounds
- **Premium & Modern**: Clean, minimal interface emphasizing content
- **Native iOS Materials**: Leverages `.ultraThinMaterial` and `.thinMaterial`
- **Accessibility First**: Respects system preferences like Reduce Transparency

## Core Principles

1. **Consistency**: Use design tokens for all colors, spacing, and typography
2. **Hierarchy**: Clear visual hierarchy through size, weight, and opacity
3. **Clarity**: High contrast text, readable typography, clear affordances
4. **Delight**: Smooth animations, subtle effects, polished interactions

## Design Tokens

### Colors (`Color.DesignSystem`)

#### Brand Colors
- `primary` - Main brand green (#2ECC71) - Fresh food and sustainability
- `secondary` - Trust blue (#3498DB) - Reliability and trust
- `accent` - Urgency orange (#F39C12) - Expiring food alerts

#### Semantic Colors
- `success` - Success states (#27AE60)
- `warning` - Warning states (#F39C12)
- `error` - Error states (#E74C3C)
- `info` - Informational states (#3498DB)

#### Text Colors
- `textPrimary` - Primary text (adapts to light/dark mode)
- `textSecondary` - Secondary text (adapts to light/dark mode)
- `textTertiary` - Tertiary text for less important content

#### Background Colors
- `background` - Main background (adapts to light/dark mode)
- `backgroundSecondary` - Secondary background layer
- `backgroundGradient` - Animated gradient background (green → blue → orange)

#### Glass Effects
- `glassBackground` - Glass component background (white 15% opacity)
- `glassBorder` - Glass component borders (white 20% opacity)
- `glassHighlight` - Top edge glow effect (white 40% opacity)
- `glassOverlay` - Overlay for glass effects (white 10% opacity)

#### Direct Color Access
You can also access colors directly without the DesignSystem namespace:
- `Color.brandGreen`, `Color.brandBlue`, `Color.brandOrange`
- `Color.success`, `Color.warning`, `Color.error`, `Color.info`
- `Color.glassBorder`, `Color.glassOverlay`
- `Color.categoryProduce`, `Color.categoryDairy`, `Color.categoryBakedGoods`, `Color.categoryPreparedMeals`, `Color.categoryPantryItems`

#### Hex Color Support
Create custom colors from hex strings:
```swift
let customColor = Color(hex: "2ECC71")
let customColorWithHash = Color(hex: "#3498DB")
```

### Spacing (`Spacing`)

Based on 8pt grid system:

- `xxxs` - 4pt (0.5 units)
- `xxs` - 8pt (1 unit)
- `xs` - 12pt (1.5 units)
- `sm` - 16pt (2 units)
- `md` - 24pt (3 units)
- `lg` - 32pt (4 units)
- `xl` - 40pt (5 units)
- `xxl` - 48pt (6 units)
- `xxxl` - 64pt (8 units)

#### Corner Radius
- `radiusXS` - 4pt
- `radiusSM` - 8pt
- `radiusMD` - 12pt
- `radiusLG` - 16pt
- `radiusXL` - 24pt
- `radiusFull` - 9999pt (fully rounded)

#### Shadows
- `shadowSM` - 2pt
- `shadowMD` - 4pt
- `shadowLG` - 8pt
- `shadowXL` - 16pt

### Typography (`Font.DesignSystem`)

#### Display (Bold, Rounded)
- `displayLarge` - 57pt
- `displayMedium` - 45pt
- `displaySmall` - 36pt

#### Headline (Semibold, Rounded)
- `headlineLarge` - 32pt
- `headlineMedium` - 28pt
- `headlineSmall` - 24pt

#### Title (Medium)
- `titleLarge` - 22pt
- `titleMedium` - 16pt
- `titleSmall` - 14pt

#### Body (Regular)
- `bodyLarge` - 16pt
- `bodyMedium` - 14pt
- `bodySmall` - 12pt

#### Label (Medium)
- `labelLarge` - 14pt
- `labelMedium` - 12pt
- `labelSmall` - 11pt

## Components

### GlassButton

Premium button with glass effect and multiple styles.

```swift
GlassButton("Share Food", icon: "plus.circle.fill", style: .primary) {
    // Action
}
```

**Styles:**
- `.primary` - Solid gradient background
- `.secondary` - Glass background with border
- `.outline` - Transparent with colored border
- `.ghost` - Transparent, no border

### GlassTextField

Text input with glass effect, focus animations, and optional secure entry.

```swift
// Standard text field
GlassTextField("Email", text: $email, icon: "envelope.fill")

// Secure field with visibility toggle
GlassTextField("Password", text: $password, icon: "lock.fill", isSecure: true)

// With keyboard type
GlassTextField("Phone", text: $phone, icon: "phone.fill", keyboardType: .phonePad)

// Convenience wrapper for secure fields
GlassSecureField("Confirm Password", text: $confirmPassword, icon: "lock.fill")
```

**Parameters:**
- `placeholder` - Placeholder text
- `text` - Binding to text value
- `icon` - Optional SF Symbol name
- `isSecure` - Enable secure entry with visibility toggle (default: `false`)
- `keyboardType` - UIKeyboardType (default: `.default`)

### GlassCard

Reusable card container with frosted glass effect.

```swift
GlassCard(cornerRadius: 16, shadow: .medium) {
    VStack {
        Text("Content")
    }
    .padding()
}

// Or use modifier
Text("Content")
    .padding()
    .glassCard(cornerRadius: 16, shadow: .medium)
```

### FoodItemCard

Specialized card for food listings.

```swift
FoodItemCard(foodItem: item) {
    // Handle tap
}
```

## Usage Guidelines

### Do's ✅

- Use `Color.DesignSystem.*` for all colors
- Use `Spacing.*` for all spacing and padding
- Use `Font.DesignSystem.*` for all typography
- Use `.ultraThinMaterial` for glass backgrounds
- Respect accessibility settings (Reduce Transparency)
- Use semantic colors for states (success, error, warning)

### Don'ts ❌

- Don't hardcode colors (e.g., `Color(hex: "...")`)
- Don't use arbitrary spacing values
- Don't use system fonts directly
- Don't create custom glass effects (use components)
- Don't ignore dark mode support
- Don't use colors for meaning alone (add icons/text)

## Examples

### Glass Card with Content

```swift
VStack(spacing: Spacing.md) {
    Text("Welcome")
        .font(.DesignSystem.displayMedium)
        .foregroundStyle(Color.DesignSystem.text)
    
    Text("Share food, reduce waste")
        .font(.DesignSystem.bodyLarge)
        .foregroundStyle(Color.DesignSystem.textSecondary)
    
    GlassButton("Get Started", icon: "arrow.right", style: .primary) {
        // Action
    }
}
.padding(Spacing.lg)
.glassCard(cornerRadius: Spacing.radiusXL, shadow: .strong)
```

### Animated Background

```swift
ZStack {
    Color.DesignSystem.backgroundGradient
    
    // Content
}
.ignoresSafeArea()
```

### Status Messages

```swift
HStack(spacing: Spacing.sm) {
    Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(Color.DesignSystem.success)
    
    Text("Success!")
        .font(.DesignSystem.bodyMedium)
        .foregroundStyle(Color.DesignSystem.success)
}
.padding(Spacing.md)
.glassCard()
```

## Color Usage Patterns

### Recommended: DesignSystem Namespace
```swift
// Use DesignSystem namespace for consistency
Text("Hello")
    .foregroundStyle(Color.DesignSystem.primary)
    .background(Color.DesignSystem.background)
```

### Alternative: Direct Access
```swift
// Direct access is also supported
Text("Hello")
    .foregroundStyle(Color.brandGreen)
    .background(Color.glassBorder)
```

Both approaches are valid, but the DesignSystem namespace is recommended for better semantic meaning and easier refactoring.

## Advanced Components

### GlassAlert
Custom alert dialogs with glass effect.

```swift
GlassAlert(
    type: .success,
    title: "Success!",
    message: "Your food item has been shared.",
    primaryAction: .init(title: "Done", action: {}),
    secondaryAction: .init(title: "Share Another", action: {})
)
```

### GlassLoadingView
Full-screen loading overlay with animated spinner.

```swift
if isLoading {
    GlassLoadingView(message: "Sharing food...")
}
```

### Skeleton Loading Components
Animated skeleton placeholders for smooth loading states.

**Skeleton Modifier** - Apply to any view:
```swift
Text("Loading content")
    .skeleton(isLoading: isLoading)
```

**Skeleton Shapes** - Basic building blocks:
```swift
SkeletonLine(width: 120, height: 16)  // Text placeholder
SkeletonCircle(size: 40)               // Avatar placeholder
SkeletonRect(height: 150)              // Image placeholder
```

**Pre-built Skeletons** - Ready-to-use loading states:
```swift
SkeletonFoodCard()      // Food listing card skeleton
SkeletonRoomRow()       // Chat room row skeleton
SkeletonProfileHeader() // Profile header skeleton
```

**Skeleton List** - Generate multiple skeletons:
```swift
SkeletonList(count: 5) {
    SkeletonFoodCard()
}
```

### GlassBadge
Status badges with semantic colors.

```swift
GlassBadge("Available", style: .success)
GlassBadge("Expiring Soon", style: .warning)
```

### GlassInfoCard
Information cards with icons and actions.

```swift
GlassInfoCard(
    icon: "leaf.circle.fill",
    title: "24 Items Shared",
    subtitle: "You've helped reduce food waste",
    accentColor: Color.DesignSystem.success
) {
    // Handle tap
}
```

### AnimatedGlassBackground
Animated gradient background with floating orbs.

```swift
ZStack {
    AnimatedGlassBackground()
    // Your content
}
```

### GlassDivider
Dividers with multiple styles.

```swift
GlassDivider(style: .horizontal)
GlassDivider(style: .gradient)
GlassDivider(style: .dotted)
```

## View Modifiers

### Glass Effect
Apply glass morphism to any view.

```swift
Text("Content")
    .padding()
    .glassEffect(cornerRadius: 16, shadowRadius: 12)
```

### Shimmer
Add shimmer animation effect.

```swift
Text("Loading...")
    .shimmer(duration: 2.0)
```

### Glow
Add glow effect around view.

```swift
Image(systemName: "star.fill")
    .glow(color: Color.DesignSystem.primary, radius: 10)
```

### Press Animation
Add press feedback animation.

```swift
Button("Tap Me") {}
    .pressAnimation(scale: 0.95)
```

### Floating
Add floating animation.

```swift
Image(systemName: "cloud")
    .floating(distance: 10, duration: 2.0)
```

### Gradient Text
Apply gradient to text.

```swift
Text("Gradient Text")
    .gradientText(
        colors: [Color.DesignSystem.primary, Color.DesignSystem.secondary]
    )
```

### Pulse
Add pulse animation.

```swift
Circle()
    .pulse(maxScale: 1.1, duration: 1.0)
```

## Design System Showcase

Preview all components in one place:

```swift
DesignSystemShowcase()
```

## Production Status

✅ **Production Ready** - All components are stable and tested

### Available Components (20+)
**Buttons & Inputs:**
- `GlassButton` - 4 styles (primary, secondary, outline, ghost)
- `GlassTextField` - Text input with glass effect

**Cards:**
- `GlassCard` - Reusable card container
- `FoodItemCard` - Enhanced food listing card
- `GlassInfoCard` - Information card with icon

**Feedback:**
- `GlassAlert` - Custom alert dialogs
- `GlassLoadingView` - Loading overlay
- `GlassBadge` - Status badges

**Loading States:**
- `SkeletonLine` - Text placeholder
- `SkeletonCircle` - Avatar placeholder
- `SkeletonRect` - Image/content placeholder
- `SkeletonFoodCard` - Food listing skeleton
- `SkeletonRoomRow` - Chat room skeleton
- `SkeletonProfileHeader` - Profile skeleton
- `SkeletonList` - Generate multiple skeletons
- `.skeleton()` modifier - Apply to any view

**Layout:**
- `GlassDivider` - Multiple divider styles
- `AnimatedGlassBackground` - Animated backgrounds

**Modifiers (7):**
- `.glassEffect()` - Apply glass morphism
- `.shimmer()` - Shimmer animation
- `.glow()` - Glow effect
- `.pressAnimation()` - Press feedback
- `.floating()` - Floating animation
- `.gradientText()` - Gradient text
- `.pulse()` - Pulse animation

### Design Tokens
- Complete color system with light/dark mode support
- 8pt grid spacing system
- Typography scale with 15 variants
- Glass effect tokens
- Semantic color system

---

**Version**: 26
**Status**: ✅ Production Ready
**Components**: 25+
**Modifiers**: 8
**Last Updated**: December 2025
**Maintained by**: Foodshare Design Team
