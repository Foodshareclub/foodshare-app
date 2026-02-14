# Quick Start Guide: Notification Preferences Components

**Last Updated:** 2026-01-30

---

## 5-Minute Integration

### Step 1: Add to Navigation

Replace your existing notifications settings with the new enterprise view:

```swift
// Old
NavigationLink("Notifications") {
    NotificationsSettingsView()
}

// New
NavigationLink("Notifications") {
    EnterpriseNotificationPreferencesView(
        viewModel: NotificationPreferencesViewModel(
            repository: dependencies.notificationPreferencesRepository
        )
    )
}
```

### Step 2: Test with Previews

Open `EnterpriseNotificationPreferencesView.swift` and click any preview to see it in action:

```swift
#Preview("Enterprise Notification Preferences") {
    NavigationStack {
        EnterpriseNotificationPreferencesView(viewModel: .preview)
    }
}
```

### Step 3: Customize (Optional)

All components are fully customizable. For example, to change colors:

```swift
NotificationToggle(
    isOn: $isEnabled,
    accentColor: .DesignSystem.accentPurple  // Custom color
)
```

That's it! You now have enterprise-grade notification preferences.

---

## Common Use Cases

### Use Case 1: Show Only Specific Channels

```swift
struct SimplifiedNotificationView: View {
    @Bindable var viewModel: NotificationPreferencesViewModel

    var body: some View {
        VStack {
            // Only show push notifications
            CompactChannelHeader(
                channel: .push,
                isEnabled: Binding(
                    get: { viewModel.preferences.settings.pushEnabled },
                    set: { _ in Task { await viewModel.togglePushEnabled() } }
                )
            )
        }
    }
}
```

### Use Case 2: Custom Category Selector

```swift
struct CategorySelector: View {
    let categories: [NotificationCategory]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.sm) {
                ForEach(categories, id: \.self) { category in
                    NotificationIcon(category: category)
                        .onTapGesture {
                            // Handle selection
                        }
                }
            }
        }
    }
}
```

### Use Case 3: Custom Preference Row

```swift
struct CustomPreferenceRow: View {
    @State private var isEnabled = true
    @State private var frequency: NotificationFrequency = .instant

    var body: some View {
        HStack {
            NotificationIcon(category: .posts, size: .small)

            VStack(alignment: .leading) {
                Text("Posts")
                FrequencyBadge(frequency: frequency)
            }

            Spacer()

            NotificationToggle(isOn: $isEnabled)
        }
        .padding()
    }
}
```

### Use Case 4: Standalone DND Card

```swift
struct QuickDNDView: View {
    @Bindable var viewModel: NotificationPreferencesViewModel

    var body: some View {
        DNDStatusCard(
            dnd: viewModel.preferences.settings.dnd,
            onEnable: { hours in
                await viewModel.enableDND(hours: hours)
            },
            onDisable: {
                await viewModel.disableDND()
            }
        )
    }
}
```

### Use Case 5: Search-Only Categories

```swift
struct SearchableCategories: View {
    @Bindable var viewModel: NotificationPreferencesViewModel

    var body: some View {
        VStack {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search", text: $viewModel.searchQuery)
            }
            .padding()
            .background(Color.DesignSystem.glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Filtered categories
            ForEach(viewModel.filteredCategories, id: \.self) { category in
                CompactCategoryPreferenceCard(
                    category: category,
                    enabledCount: /* calculate */,
                    totalCount: 3
                )
            }
        }
    }
}
```

---

## Component Cheat Sheet

### Atoms (Building Blocks)

| Component | Purpose | Key Props |
|-----------|---------|-----------|
| `NotificationToggle` | Toggle control | `isOn`, `isLoading` |
| `NotificationIcon` | Category/channel icon | `category`/`channel`, `size` |
| `FrequencyBadge` | Frequency display | `frequency`, `isCompact` |
| `StatusIndicator` | Status dot | `status`, `showLabel` |

### Molecules (Simple Combos)

| Component | Purpose | Key Props |
|-----------|---------|-----------|
| `NotificationPreferenceRow` | Preference with toggle | `category`, `channel`, `isEnabled`, `frequency` |
| `SimpleNotificationPreferenceRow` | Simplified row | `category`, `channel`, `isEnabled` |
| `ChannelHeader` | Expandable header | `channel`, `isExpanded`, `isEnabled` |
| `CompactChannelHeader` | Simple header | `channel`, `isEnabled` |
| `CategoryPreferenceCard` | Full category card | `category`, `preferences` |
| `CompactCategoryPreferenceCard` | Summary card | `category`, `enabledCount` |
| `DNDStatusCard` | DND controls | `dnd`, `onEnable`, `onDisable` |
| `QuietHoursCard` | Quiet hours | `quietHours`, `onToggle` |

### Organisms (Complex Sections)

| Component | Purpose | Key Props |
|-----------|---------|-----------|
| `GlobalSettingsSection` | All channels | `viewModel` |
| `CategoryPreferencesSection` | All categories | `viewModel` |
| `ScheduleSection` | Time-based | `viewModel` |
| `OfflineBanner` | Offline status | `isOffline`, `pendingChanges` |

---

## Preview Quick Reference

### Test States Quickly

```swift
// Loading state
#Preview {
    EnterpriseNotificationPreferencesView(
        viewModel: .loadingPreview
    )
}

// Error state
#Preview {
    EnterpriseNotificationPreferencesView(
        viewModel: .errorPreview
    )
}

// Offline state
#Preview {
    EnterpriseNotificationPreferencesView(
        viewModel: .offlinePreview
    )
}

// Normal state
#Preview {
    EnterpriseNotificationPreferencesView(
        viewModel: .preview
    )
}
```

### Interactive Preview Template

```swift
#Preview("Interactive") {
    struct InteractivePreview: View {
        @State private var isEnabled = true

        var body: some View {
            NotificationToggle(isOn: $isEnabled)
        }
    }

    return InteractivePreview()
}
```

---

## Troubleshooting

### Issue: Components not showing

**Solution:** Make sure you import the design system:
```swift
import FoodShareDesignSystem
```

### Issue: Colors look wrong

**Solution:** Use ONLY design system colors:
```swift
// ❌ Wrong
.foregroundColor(.blue)

// ✅ Correct
.foregroundColor(.DesignSystem.brandBlue)
```

### Issue: Spacing inconsistent

**Solution:** Use design system spacing:
```swift
// ❌ Wrong
.padding(16)

// ✅ Correct
.padding(Spacing.md)
```

### Issue: Loading states not working

**Solution:** Check ViewModel integration:
```swift
NotificationToggle(
    isOn: $isEnabled,
    isLoading: viewModel.isUpdating(category: .posts, channel: .push)
)
```

### Issue: Previews showing errors

**Solution:** Use the mock ViewModel:
```swift
#Preview {
    EnterpriseNotificationPreferencesView(
        viewModel: .preview  // ← Use preview static var
    )
}
```

---

## Best Practices

### Do's ✅

1. **Use the ViewModel**
   ```swift
   // Pass the entire ViewModel
   GlobalSettingsSection(viewModel: viewModel)
   ```

2. **Leverage Bindings**
   ```swift
   // Use ViewModel bindings
   NotificationPreferenceRow(
       category: .posts,
       channel: .push,
       isEnabled: viewModel.enabledBinding(category: .posts, channel: .push),
       frequency: viewModel.frequencyBinding(category: .posts, channel: .push)
   )
   ```

3. **Add Loading States**
   ```swift
   NotificationToggle(
       isOn: $isEnabled,
       isLoading: viewModel.isSaving  // Always show loading
   )
   ```

4. **Use Previews Extensively**
   ```swift
   // Test all states
   #Preview("All States") {
       VStack {
           Component(state: .idle)
           Component(state: .loading)
           Component(state: .error)
       }
   }
   ```

### Don'ts ❌

1. **Don't bypass the design system**
   ```swift
   // ❌ Wrong
   Text("Hello").font(.title)

   // ✅ Correct
   Text("Hello").font(.DesignSystem.headlineLarge)
   ```

2. **Don't create custom toggles**
   ```swift
   // ❌ Wrong
   Toggle("", isOn: $isEnabled).tint(.green)

   // ✅ Correct
   NotificationToggle(isOn: $isEnabled)
   ```

3. **Don't hardcode spacing**
   ```swift
   // ❌ Wrong
   VStack(spacing: 16) { }

   // ✅ Correct
   VStack(spacing: Spacing.md) { }
   ```

4. **Don't forget accessibility**
   ```swift
   // ❌ Wrong
   Image(systemName: "bell")

   // ✅ Correct
   Image(systemName: "bell")
       .accessibilityLabel("Notifications")
   ```

---

## Performance Tips

### 1. Use Lazy Stacks for Lists

```swift
// ✅ Good
LazyVStack {
    ForEach(categories) { category in
        CategoryCard(category: category)
    }
}

// ❌ Slow for large lists
VStack {
    ForEach(categories) { category in
        CategoryCard(category: category)
    }
}
```

### 2. Apply Drawing Groups to Glass Effects

```swift
GlassCard {
    ComplexContent()
}
.drawingGroup()  // ← GPU acceleration
```

### 3. Use Explicit Animation Values

```swift
// ✅ Good
.animation(.smooth, value: isExpanded)

// ❌ Can cause issues
.animation(.smooth)
```

### 4. Debounce Search

```swift
TextField("Search", text: $searchQuery)
    .onChange(of: searchQuery) { _, newValue in
        // Already debounced in ViewModel
    }
```

---

## Accessibility Checklist

When creating custom components:

- [ ] Add `.accessibilityLabel()` to all interactive elements
- [ ] Add `.accessibilityValue()` for current state
- [ ] Add `.accessibilityHint()` for complex interactions
- [ ] Test with VoiceOver enabled
- [ ] Test with larger text sizes (Dynamic Type)
- [ ] Ensure minimum 44x44pt touch targets
- [ ] Group related elements with `.accessibilityElement(children: .contain)`

Example:
```swift
NotificationToggle(isOn: $isEnabled)
    .accessibilityLabel("Post notifications")
    .accessibilityValue(isEnabled ? "Enabled" : "Disabled")
    .accessibilityHint("Double tap to toggle")
```

---

## Need Help?

1. **Check the README** - Comprehensive component documentation
2. **Browse Previews** - 50+ examples in the code
3. **See Implementation Summary** - Architecture overview
4. **Review ViewModel** - API reference

---

**Happy Coding!** 🚀

All components are production-ready and fully tested with comprehensive preview coverage.
