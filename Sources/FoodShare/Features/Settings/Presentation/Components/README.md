# Notification Preferences Component Library

**Version:** 1.0.0
**Design System:** Liquid Glass v26
**Architecture:** Atomic Design Pattern
**Platform:** iOS 17.0+
**Swift:** 6.2

---

## Overview

This is a fully componentized, enterprise-grade notification preferences UI system built using the Atomic Design pattern with the Liquid Glass design system.

### Key Features

- **Atomic Design Pattern** - Progressive composition from atoms to organisms
- **Liquid Glass Design** - All components use the design system
- **Optimistic UI** - Instant feedback with automatic rollback
- **Offline Support** - Queue changes and sync when back online
- **Undo/Redo** - Full undo support for recent actions
- **Accessibility** - Complete VoiceOver and Dynamic Type support
- **Haptic Feedback** - Tactile responses throughout
- **Animated Transitions** - Smooth 120Hz ProMotion animations
- **Loading States** - Individual component loading indicators
- **Error Recovery** - Automatic retry with exponential backoff

---

## Architecture

```
Components/
├── Atoms/                          # Basic building blocks
│   ├── NotificationToggle.swift    # Animated toggle with loading
│   ├── NotificationIcon.swift      # Category/channel icon
│   ├── FrequencyBadge.swift       # Frequency display pill
│   └── StatusIndicator.swift      # Online/offline/syncing status
│
├── Molecules/                      # Simple combinations
│   ├── NotificationPreferenceRow.swift  # Toggle + frequency picker
│   ├── ChannelHeader.swift             # Expandable section header
│   ├── CategoryPreferenceCard.swift    # All channels for category
│   ├── DNDStatusCard.swift            # Do Not Disturb toggle
│   └── QuietHoursCard.swift           # Quiet hours config
│
└── Organisms/                      # Complex feature sections
    ├── GlobalSettingsSection.swift     # Master channel toggles
    ├── CategoryPreferencesSection.swift # All categories + search
    ├── ScheduleSection.swift          # DND + Quiet Hours + Digest
    └── OfflineBanner.swift            # Offline indicator

Views/
└── EnterpriseNotificationPreferencesView.swift  # Complete view
```

---

## Component Catalog

### Atoms

#### NotificationToggle
Animated toggle control with loading state support.

**Usage:**
```swift
NotificationToggle(
    isOn: $isEnabled,
    isLoading: viewModel.isUpdating(category: .posts, channel: .push)
)
```

**Features:**
- Smooth animations with haptic feedback
- Loading spinner overlay
- Disabled state
- Custom accent colors
- Accessibility labels

**Props:**
- `isOn: Binding<Bool>` - Toggle state
- `isLoading: Bool` - Show loading spinner
- `accentColor: Color` - Custom color (default: brand green)
- `isDisabled: Bool` - Disable interaction

---

#### NotificationIcon
Circular icon with gradient background for categories/channels.

**Usage:**
```swift
NotificationIcon(category: .posts, size: .medium)
NotificationIcon(channel: .push, badgeCount: 3)
```

**Features:**
- Gradient backgrounds
- Multiple sizes (small, medium, large)
- Badge count overlay
- Category/channel presets

**Props:**
- `systemName: String` - SF Symbol name
- `gradientColors: [Color]` - Gradient colors
- `size: Size` - Icon size
- `badgeCount: Int?` - Optional badge number

**Convenience Initializers:**
```swift
NotificationIcon(category: NotificationCategory)
NotificationIcon(channel: NotificationChannel)
```

---

#### FrequencyBadge
Color-coded pill displaying notification frequency.

**Usage:**
```swift
FrequencyBadge(frequency: .instant)
FrequencyBadge(frequency: .daily, isCompact: true)
```

**Features:**
- Color-coded by frequency
- Compact icon-only mode
- Animated transitions
- Contextual styling

**Props:**
- `frequency: NotificationFrequency` - The frequency to display
- `isCompact: Bool` - Show icon only
- `fontSize: CGFloat` - Custom font size

---

#### StatusIndicator
Connection and sync status indicator.

**Usage:**
```swift
StatusIndicator(status: .online)
StatusIndicator(status: .syncing, showLabel: true)
```

**Features:**
- Animated pulse for active states
- Color-coded status
- Optional label text
- Multiple sizes

**Props:**
- `status: Status` - Current status (.online, .offline, .syncing, .error)
- `size: Size` - Indicator size
- `showLabel: Bool` - Show status text

---

### Molecules

#### NotificationPreferenceRow
Complete preference row with toggle and frequency picker.

**Usage:**
```swift
NotificationPreferenceRow(
    category: .posts,
    channel: .push,
    isEnabled: $isEnabled,
    frequency: $frequency,
    isLoading: false
)
```

**Features:**
- Icon, title, description
- Toggle for enable/disable
- Expandable frequency picker
- Loading states
- Haptic feedback

**Props:**
- `category: NotificationCategory` - The category
- `channel: NotificationChannel` - The channel
- `isEnabled: Binding<Bool>` - Enabled state
- `frequency: Binding<NotificationFrequency>` - Frequency setting
- `isLoading: Bool` - Show loading state
- `isDisabled: Bool` - Disable interaction

**Variant:**
```swift
SimpleNotificationPreferenceRow  // No frequency picker
```

---

#### ChannelHeader
Expandable section header for notification channels.

**Usage:**
```swift
ChannelHeader(
    channel: .push,
    isExpanded: $isExpanded,
    isEnabled: $isPushEnabled,
    isAvailable: true
)
```

**Features:**
- Chevron expand/collapse indicator
- Master toggle for channel
- Availability indicator
- Smooth animations

**Props:**
- `channel: NotificationChannel` - The channel
- `isExpanded: Binding<Bool>` - Expansion state
- `isEnabled: Binding<Bool>` - Enabled state
- `isAvailable: Bool` - Channel availability
- `isLoading: Bool` - Loading state
- `onTapAction: (() -> Void)?` - Custom tap handler

---

#### CategoryPreferenceCard
Card showing all channels for one category.

**Usage:**
```swift
CategoryPreferenceCard(
    category: .posts,
    preferences: preferences,
    onToggle: { channel in await viewModel.toggle(channel) },
    onFrequencyChange: { channel, freq in await viewModel.update(channel, freq) }
)
```

**Features:**
- Category icon and description
- All channel preferences
- Frequency badges
- Expandable/collapsible
- Loading states

**Props:**
- `category: NotificationCategory` - The category
- `preferences: [NotificationChannel: CategoryPreference]` - Channel prefs
- `isExpanded: Bool` - Initial expansion state
- `onToggle: (NotificationChannel) async -> Void` - Toggle handler
- `onFrequencyChange: (NotificationChannel, NotificationFrequency) async -> Void` - Frequency handler
- `isLoading: (NotificationChannel) -> Bool` - Loading check
- `isChannelAvailable: (NotificationChannel) -> Bool` - Availability check

---

#### DNDStatusCard
Do Not Disturb quick toggle card.

**Usage:**
```swift
DNDStatusCard(
    dnd: viewModel.preferences.settings.dnd,
    onEnable: { hours in await viewModel.enableDND(hours: hours) },
    onDisable: { await viewModel.disableDND() }
)
```

**Features:**
- Current DND status
- Quick toggle
- Remaining time indicator
- Preset duration buttons
- Custom duration option

**Props:**
- `dnd: DoNotDisturb` - Current DND settings
- `onEnable: (Int) async -> Void` - Enable handler (hours)
- `onDisable: () async -> Void` - Disable handler
- `onCustomize: (() -> Void)?` - Custom duration handler

---

#### QuietHoursCard
Quiet hours configuration card.

**Usage:**
```swift
QuietHoursCard(
    quietHours: viewModel.preferences.settings.quietHours,
    onToggle: { enabled in await viewModel.toggleQuietHours(enabled) },
    onConfigure: { viewModel.showQuietHoursSheet = true }
)
```

**Features:**
- Enable/disable toggle
- Time range display
- Visual time indicators
- Configuration button

**Props:**
- `quietHours: QuietHours` - Current settings
- `onToggle: (Bool) async -> Void` - Toggle handler
- `onConfigure: () -> Void` - Config handler

---

### Organisms

#### GlobalSettingsSection
Master toggles for all notification channels.

**Usage:**
```swift
GlobalSettingsSection(viewModel: viewModel)
```

**Features:**
- Master toggles for push/email/SMS
- Expandable channel sections
- Availability indicators
- Verification prompts
- Statistics summary

**Props:**
- `viewModel: NotificationPreferencesViewModel` - The view model

---

#### CategoryPreferencesSection
All categories with search and filter.

**Usage:**
```swift
CategoryPreferencesSection(viewModel: viewModel)
```

**Features:**
- Searchable category list
- Category cards with channel breakdown
- Bulk expand/collapse actions
- Empty state handling

**Props:**
- `viewModel: NotificationPreferencesViewModel` - The view model

---

#### ScheduleSection
Schedule-based notification controls.

**Usage:**
```swift
ScheduleSection(viewModel: viewModel)
```

**Features:**
- Do Not Disturb card
- Quiet Hours card
- Daily/weekly digest settings
- Informational help text

**Props:**
- `viewModel: NotificationPreferencesViewModel` - The view model

---

#### OfflineBanner
Offline mode indicator with pending changes.

**Usage:**
```swift
OfflineBanner(
    isOffline: viewModel.isOffline,
    pendingChanges: viewModel.pendingOfflineChangesCount,
    onRetry: { await viewModel.refreshPreferences() }
)
```

**Features:**
- Offline/syncing/error status
- Pending changes count
- Retry functionality
- Dismissible option

**Props:**
- `type: BannerType` - Banner type
- `onRetry: (() async -> Void)?` - Retry handler
- `onDismiss: (() -> Void)?` - Dismiss handler

**Convenience Initializer:**
```swift
OfflineBanner(
    isOffline: Bool,
    pendingChanges: Int,
    onRetry: (() async -> Void)?
)
```

---

## Main View

### EnterpriseNotificationPreferencesView
Complete notification preferences interface.

**Usage:**
```swift
NavigationStack {
    EnterpriseNotificationPreferencesView(viewModel: viewModel)
}
```

**Features:**
- Three-tab interface (Channels, Categories, Schedule)
- Offline mode support
- Pull-to-refresh
- Undo toast at bottom
- Error handling
- Loading overlays
- Sheet presentations

**Props:**
- `viewModel: NotificationPreferencesViewModel` - The view model

---

## Design System Integration

All components use the Liquid Glass design system:

### Colors
```swift
Color.DesignSystem.brandGreen
Color.DesignSystem.brandBlue
Color.DesignSystem.glassBackground
Color.DesignSystem.textPrimary
Color.DesignSystem.textSecondary
```

### Typography
```swift
Font.DesignSystem.headlineLarge
Font.DesignSystem.bodyMedium
Font.DesignSystem.captionSmall
```

### Spacing
```swift
Spacing.xxs  // 2pt
Spacing.xs   // 4pt
Spacing.sm   // 8pt
Spacing.md   // 16pt
Spacing.lg   // 24pt
Spacing.xl   // 32pt
```

### Components
```swift
GlassCard { }
GlassButton("Label") { }
```

---

## ViewModel Integration

All components are designed to work with `NotificationPreferencesViewModel`:

```swift
@MainActor
@Observable
public final class NotificationPreferencesViewModel {
    // State
    public private(set) var preferences: NotificationPreferences
    public private(set) var loadingState: LoadingState
    public private(set) var updatingPreferences: Set<String>
    public private(set) var isOffline: Bool

    // Computed
    public var filteredCategories: [NotificationCategory]
    public var canUndo: Bool
    public var pendingOfflineChangesCount: Int

    // Actions
    public func loadPreferences() async
    public func togglePreference(category:channel:) async
    public func updateFrequency(category:channel:frequency:) async
    public func enableDND(hours:) async
    public func disableDND() async
    public func updateQuietHours(enabled:start:end:) async
    public func undo() async
}
```

---

## Accessibility

All components implement full accessibility support:

- **VoiceOver Labels** - Descriptive labels for all interactive elements
- **Hints** - Contextual hints for complex interactions
- **Values** - Current state announced to VoiceOver users
- **Dynamic Type** - All text scales with system font size
- **Announcements** - Important changes announced automatically
- **Grouping** - Logical grouping of related elements

### Example
```swift
.accessibilityLabel("\(category.displayName) notifications")
.accessibilityValue(isEnabled ? "Enabled, \(frequency.displayName)" : "Disabled")
.accessibilityHint("Tap to expand frequency options")
```

---

## Performance

### Optimizations
- **Lazy Loading** - Lists use `LazyVStack` for efficiency
- **Debouncing** - Batch updates to reduce API calls
- **Optimistic UI** - Instant feedback without waiting for server
- **Drawing Groups** - Glass effects use `drawingGroup()` for GPU rendering
- **Task Management** - Proper cancellation of async tasks

### 120Hz ProMotion
All animations are optimized for high refresh rate displays:
```swift
.animation(.smooth(duration: 0.3), value: isExpanded)
.animation(.interpolatingSpring(stiffness: 300, damping: 20), value: position)
```

---

## Testing

All components include comprehensive `#Preview` macros:

```swift
#Preview("Component States") {
    VStack {
        NotificationToggle(isOn: .constant(false))
        NotificationToggle(isOn: .constant(true))
        NotificationToggle(isOn: .constant(true), isLoading: true)
    }
}

#Preview("Interactive") {
    struct InteractivePreview: View {
        @State private var isOn = false
        var body: some View {
            NotificationToggle(isOn: $isOn)
        }
    }
    return InteractivePreview()
}
```

---

## Migration Guide

### From Basic Settings View

**Old:**
```swift
Toggle("Push Notifications", isOn: $pushEnabled)
```

**New:**
```swift
NotificationToggle(
    isOn: $pushEnabled,
    isLoading: viewModel.isUpdating(category: .posts, channel: .push)
)
```

### From Manual Layouts

**Old:**
```swift
HStack {
    Image(systemName: "bell.fill")
    Text("Posts")
    Spacer()
    Toggle("", isOn: $isEnabled)
}
```

**New:**
```swift
SimpleNotificationPreferenceRow(
    category: .posts,
    channel: .push,
    isEnabled: $isEnabled
)
```

---

## Best Practices

### Do's ✅
- Use atomic components to build custom molecules
- Leverage the ViewModel for all state management
- Apply design system tokens consistently
- Include accessibility labels on all custom components
- Provide loading states for async operations
- Test with VoiceOver enabled

### Don'ts ❌
- Don't bypass the design system with raw colors/fonts
- Don't implement loading spinners manually - use atoms
- Don't forget haptic feedback on interactions
- Don't use hardcoded spacing values
- Don't skip accessibility implementation

---

## Future Enhancements

- [ ] Add notification preview in real-time
- [ ] Implement drag-to-reorder categories
- [ ] Add notification history/logs
- [ ] Support for notification templates
- [ ] Advanced filtering (by priority, sender, etc.)
- [ ] Notification scheduling rules
- [ ] AI-powered smart grouping

---

## Support

For questions or issues with these components:

1. Check the `#Preview` macros for usage examples
2. Review the ViewModel integration section
3. Consult the Design System documentation
4. See `NotificationPreferencesViewModel.swift` for API details

---

**Last Updated:** 2026-01-30
**Maintained By:** FoodShare iOS Team
**License:** Proprietary
