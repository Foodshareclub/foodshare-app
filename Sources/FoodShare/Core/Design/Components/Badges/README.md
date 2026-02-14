# Notification Indicator Components

Production-ready notification indicator system following Atomic Design and Liquid Glass design principles.

## Quick Start

### Add a notification dot to any view
```swift
MyButton()
    .notificationIndicator(count: unreadCount)
```

### Add a numbered badge
```swift
ProfileIcon()
    .notificationIndicator(
        count: unreadCount,
        style: .badge,
        color: .DesignSystem.error
    )
```

### Add a tappable notification indicator
```swift
BellIcon()
    .notificationIndicator(
        count: 5,
        style: .badge,
        onTap: { showNotifications = true }
    )
```

## Components

### Atoms

#### NotificationDot
Pulsing dot indicator for active/inactive states.

```swift
NotificationDot(isActive: true)
NotificationDot(isActive: false, size: 20, activeColor: .DesignSystem.brandGreen)
```

#### NotificationBadge
Numbered badge with count display.

```swift
NotificationBadge(count: 5)
NotificationBadge(count: 150, size: .large, color: .DesignSystem.error)
```

Sizes: `.compact` (16pt), `.regular` (20pt), `.large` (24pt)

#### NotificationGlow
Pulsing glow effect (typically used internally).

```swift
NotificationGlow(isActive: true, color: .DesignSystem.brandPink, size: 48)
```

### ViewModifier

#### .notificationIndicator()
Adds a notification indicator to any view.

**Parameters:**
- `count: Int` - Number of notifications
- `style: NotificationIndicatorStyle` - `.dot`, `.badge`, or `.badgeCompact`
- `color: Color?` - Indicator color (default: brandPink)
- `position: NotificationIndicatorPosition` - `.topLeading`, `.topTrailing`, `.bottomLeading`, `.bottomTrailing`
- `showWhenZero: Bool` - Show indicator when count is 0
- `onTap: (() -> Void)?` - Optional tap handler

## Styles

### Dot
Simple pulsing dot, no count display.
```swift
.notificationIndicator(count: unreadCount, style: .dot)
```

### Badge
Regular-sized numbered badge.
```swift
.notificationIndicator(count: unreadCount, style: .badge)
```

### Badge Compact
Smaller numbered badge for dense layouts.
```swift
.notificationIndicator(count: unreadCount, style: .badgeCompact)
```

## Positions

```swift
// Top-right (default)
.notificationIndicator(count: 5, position: .topTrailing)

// Top-left
.notificationIndicator(count: 5, position: .topLeading)

// Bottom-right
.notificationIndicator(count: 5, position: .bottomTrailing)

// Bottom-left
.notificationIndicator(count: 5, position: .bottomLeading)
```

## Colors

Use Liquid Glass design tokens:

```swift
.notificationIndicator(count: 5, color: .DesignSystem.brandPink)    // Default
.notificationIndicator(count: 5, color: .DesignSystem.brandGreen)
.notificationIndicator(count: 5, color: .DesignSystem.error)
.notificationIndicator(count: 5, color: .DesignSystem.brandBlue)
```

## Accessibility

All components include:
- VoiceOver labels and hints
- Dynamic Type support via `@ScaledMetric`
- Minimum 44pt tap targets for interactive indicators
- Reduce Motion support (disables animations)
- Count announcements when count changes

## Performance

- 120Hz ProMotion optimized
- GPU-rasterized layers for smooth animations
- Task-based lifecycle management
- Swift 6 concurrency-safe (`@MainActor`)
- Minimal CPU/memory footprint

## Examples

### Tab Bar Badge
```swift
HStack {
    TabIcon(name: "Messages")
        .notificationIndicator(
            count: messageCount,
            style: .badge,
            color: .DesignSystem.error
        )
}
```

### Profile with Requests
```swift
ProfileButton()
    .notificationIndicator(
        count: pendingRequests,
        style: .dot,
        color: .DesignSystem.brandGreen,
        position: .topTrailing,
        onTap: { showRequests = true }
    )
```

### Bell Icon with Badge
```swift
Image(systemName: "bell.fill")
    .font(.system(size: 24))
    .notificationIndicator(
        count: unreadNotifications,
        style: .badge,
        onTap: { showNotifications = true }
    )
```

### Filter Button with Dot
```swift
GlassActionButton(icon: "slider.horizontal.3") {
    showFilters = true
}
.notificationIndicator(
    count: hasActiveFilters ? 1 : 0,
    style: .dot,
    color: .DesignSystem.brandBlue
)
```

## Migration Guide

### Before (Old Pattern)
```swift
ZStack(alignment: .topTrailing) {
    MyButton()

    if unreadCount > 0 {
        Circle()
            .fill(Color.red)
            .frame(width: 20, height: 20)
            .overlay(
                Text("\(unreadCount)")
                    .font(.caption)
                    .foregroundColor(.white)
            )
            .offset(x: 10, y: -10)
    }
}
```

### After (New Pattern)
```swift
MyButton()
    .notificationIndicator(count: unreadCount, style: .badge)
```

## File Locations

```
FoodShare/Core/Design/Components/Badges/
├── Atoms/
│   ├── NotificationDot.swift
│   ├── NotificationBadge.swift
│   └── NotificationGlow.swift
└── ViewModifiers/
    └── NotificationIndicatorModifier.swift
```

## Support

For issues or questions, see:
- Main documentation: `/NOTIFICATION_INDICATOR_SYSTEM.md`
- Design system: `/FoodShare/Core/Design/`
- Liquid Glass tokens: `/FoodShare/Core/Design/Tokens/`
