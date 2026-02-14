# Notification Preferences Implementation Guide

## Quick Start

The notification preferences system is fully implemented and ready to use. Here's how to integrate it into your app:

### Basic Usage

```swift
import SwiftUI

struct SettingsView: View {
    @State private var viewModel: NotificationPreferencesViewModel

    init() {
        // Initialize with your repository
        let repository = SupabaseNotificationPreferencesRepository()
        _viewModel = State(initialValue: NotificationPreferencesViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            EnterpriseNotificationPreferencesView(viewModel: viewModel)
        }
    }
}
```

---

## Sheet Implementations

### 1. Do Not Disturb Sheet

**Triggers when:** User taps customize DND button
**ViewModel property:** `viewModel.showDNDSheet`

**Features:**
- Quick duration selection (1hr, 2hr, 4hr, 8hr, 24hr)
- Custom date/time picker for precise control
- Integrates with `viewModel.enableDND(hours:)` and `viewModel.enableDND(until:)`

**UI Flow:**
```
User taps "Customize" → Sheet appears → User selects duration → DND enabled → Sheet dismisses
```

### 2. Quiet Hours Sheet

**Triggers when:** User taps configure quiet hours
**ViewModel property:** `viewModel.showQuietHoursSheet`

**Features:**
- Enable/disable toggle
- Start time picker (wheel style)
- End time picker (wheel style)
- Info card explaining behavior

**UI Flow:**
```
User taps "Configure" → Sheet appears → User sets times → Changes auto-save → User taps "Done"
```

**Time Format:** All times use "HH:mm" 24-hour format (e.g., "22:00", "08:00")

### 3. Phone Verification Sheet

**Triggers when:** User taps "Verify Phone Number"
**ViewModel property:** `viewModel.showPhoneVerificationSheet`

**Features:**
- Two-step flow (phone entry → code verification)
- Auto-verification when 6 digits entered
- Resend code functionality
- Loading states during async operations

**UI Flow:**
```
User taps "Verify" → Enters phone → Code sent → Enters 6-digit code → Auto-verifies → Success
```

**State Management:**
- `viewModel.phoneVerificationNumber`: Phone number binding
- `viewModel.phoneVerificationCode`: Verification code binding
- `viewModel.isVerifyingPhone`: Loading state

---

## Helper Methods

### Time Parsing (in EnterpriseNotificationPreferencesView)

```swift
// Convert "HH:mm" string to Date
private func parseTime(_ timeString: String) -> Date?

// Convert Date to "HH:mm" string
private func formatTime(_ date: Date) -> String
```

**Usage:**
```swift
let quietHours = viewModel.preferences.settings.quietHours
let startDate = parseTime(quietHours.start) // "22:00" → Date
let formattedTime = formatTime(Date()) // Date → "22:00"
```

---

## ViewModel Methods Reference

### DND Operations

```swift
// Enable DND for specific hours
await viewModel.enableDND(hours: 2) // Silences for 2 hours

// Enable DND until specific date
await viewModel.enableDND(until: tomorrow)

// Disable DND
await viewModel.disableDND()
```

### Quiet Hours Operations

```swift
// Update quiet hours settings
await viewModel.updateQuietHours(
    enabled: true,
    start: "22:00",
    end: "08:00"
)
```

### Phone Verification Operations

```swift
// Step 1: Initiate verification (sends SMS)
viewModel.phoneVerificationNumber = "+1234567890"
await viewModel.initiatePhoneVerification()

// Step 2: Verify code (automatic when 6 digits entered)
viewModel.phoneVerificationCode = "123456"
await viewModel.verifyPhoneCode()
```

---

## Design System Usage

### Colors

All sheets use consistent Liquid Glass colors:

```swift
// Backgrounds
Color.DesignSystem.background          // Main background
Color.DesignSystem.glassBackground     // Card backgrounds

// Text
Color.DesignSystem.textPrimary        // Primary text
Color.DesignSystem.textSecondary      // Secondary text
Color.DesignSystem.textTertiary       // Tertiary/disabled

// Brand Colors
Color.DesignSystem.brandGreen         // Primary actions
Color.DesignSystem.brandBlue          // Secondary actions
Color.DesignSystem.accentPurple       // DND theme
Color.DesignSystem.success            // Success states
```

### Spacing

Consistent spacing throughout:

```swift
Spacing.xs    // 12pt - Small gaps
Spacing.sm    // 16pt - Input padding
Spacing.md    // 24pt - Card padding
Spacing.lg    // 32pt - Section spacing
Spacing.xl    // 40pt - Large spacing
```

### Typography

```swift
Font.DesignSystem.headlineLarge    // Sheet titles
Font.DesignSystem.bodyMedium       // Body text
Font.DesignSystem.bodySmall        // Secondary text
Font.DesignSystem.captionSmall     // Captions
```

---

## Haptic Feedback

All user interactions include appropriate haptic feedback:

```swift
HapticFeedback.light()       // Cancel, dismiss
HapticFeedback.selection()   // Time picker changes
HapticFeedback.success()     // Successful actions
```

**When to use:**
- `.light()` - Lightweight interactions (cancel, tap)
- `.selection()` - Picker/toggle changes
- `.success()` - Successful completion (verified, saved)

---

## Accessibility

### VoiceOver Support

All sheets include proper accessibility:

```swift
.accessibilityLabel("Verify Phone Number")
.accessibilityValue("Code: 123456")
.accessibilityHint("Double tap to submit")
```

### Keyboard Types

Appropriate keyboards for each input:

```swift
.keyboardType(.phonePad)        // Phone number input
.keyboardType(.numberPad)       // Verification code
```

### Text Content Types

Smart input suggestions:

```swift
.textContentType(.telephoneNumber)  // Phone number
.textContentType(.oneTimeCode)      // Verification code
```

---

## Error Handling

All async operations include proper error handling:

```swift
do {
    await viewModel.enableDND(hours: 2)
    // Success - sheet auto-dismisses
} catch {
    // Error - viewModel.lastError is set
    // OfflineBanner automatically appears
}
```

**Error Display:**
- Errors shown in `OfflineBanner` at top of screen
- User can retry or dismiss
- Offline changes queued automatically

---

## Testing Guide

### SwiftUI Previews

All sheets have dedicated previews:

```swift
#Preview("DND Sheet") {
    EnterpriseNotificationPreferencesView(viewModel: .preview)
}
```

### Manual Testing Checklist

**DND Sheet:**
- [ ] Quick durations (1hr, 2hr, 4hr, 8hr, 24hr) work
- [ ] Custom date picker selects future dates
- [ ] Cancel dismisses without changes
- [ ] Haptic feedback on all taps

**Quiet Hours Sheet:**
- [ ] Toggle enables/disables quiet hours
- [ ] Start time picker shows correctly
- [ ] End time picker shows correctly
- [ ] Times save automatically
- [ ] Done button dismisses

**Phone Verification:**
- [ ] Phone number input accepts formatting
- [ ] Send code button enables when valid
- [ ] Code section appears after sending
- [ ] 6-digit limit enforced
- [ ] Auto-verification at 6 digits
- [ ] Resend code works
- [ ] Success dismisses sheet

---

## Common Integration Patterns

### Presenting from Settings

```swift
struct SettingsView: View {
    @State private var viewModel = NotificationPreferencesViewModel(
        repository: SupabaseNotificationPreferencesRepository()
    )

    var body: some View {
        List {
            NavigationLink("Notifications") {
                EnterpriseNotificationPreferencesView(viewModel: viewModel)
            }
        }
    }
}
```

### Presenting Modally

```swift
struct ParentView: View {
    @State private var showNotifications = false

    var body: some View {
        Button("Manage Notifications") {
            showNotifications = true
        }
        .sheet(isPresented: $showNotifications) {
            NavigationStack {
                EnterpriseNotificationPreferencesView(
                    viewModel: NotificationPreferencesViewModel(
                        repository: SupabaseNotificationPreferencesRepository()
                    )
                )
            }
        }
    }
}
```

### Custom Repository

```swift
// Create custom repository for testing
class MockNotificationRepository: NotificationPreferencesRepository {
    func enableDND(_ request: EnableDNDRequest) async throws -> DoNotDisturb {
        // Custom implementation
    }
    // ... implement other methods
}

let viewModel = NotificationPreferencesViewModel(
    repository: MockNotificationRepository()
)
```

---

## Performance Considerations

### Lazy Loading

All category lists use `LazyVStack` for performance:

```swift
LazyVStack(spacing: Spacing.sm) {
    ForEach(categories) { category in
        CategoryPreferenceCard(category: category)
    }
}
```

### Debouncing

Time picker changes are debounced to reduce API calls:

```swift
.onChange(of: time) { _, newValue in
    onTimeChange(newValue) // ViewModel handles debouncing
}
```

### Optimistic Updates

All toggles update UI immediately, rollback on error:

```swift
// UI updates instantly
isEnabled = true

// Backend call happens async
await viewModel.togglePreference()

// On error, UI reverts
if error { isEnabled = false }
```

---

## Migration from Placeholder

If you had placeholder implementations:

1. **Remove old placeholder sheets** from your view
2. **Import updated EnterpriseNotificationPreferencesView**
3. **No ViewModel changes needed** - all methods already existed
4. **Verify sheet presentation** - should work automatically

### Breaking Changes

**None!** All changes are additive:
- Existing ViewModel methods unchanged
- New helper methods are private
- Sheet implementations replace placeholders
- All public APIs remain compatible

---

## Troubleshooting

### Sheet Doesn't Appear

**Check:**
- ViewModel binding is correct: `.sheet(isPresented: $viewModel.showDNDSheet)`
- Sheet property is being set: `viewModel.showDNDSheet = true`

### Time Parsing Fails

**Check:**
- Time format is "HH:mm" (24-hour)
- No AM/PM indicators
- Example: "22:00" not "10:00 PM"

### Phone Verification Doesn't Work

**Check:**
- Phone number format matches backend requirements
- Code is exactly 6 digits
- `isVerifyingPhone` shows loading state
- Repository method is implemented

### Haptics Don't Work

**Check:**
- Device supports haptics (not simulator)
- System haptics enabled in Settings
- `HapticManager` is properly configured

---

## Best Practices

1. **Always use async/await** for ViewModel methods
2. **Show loading states** during operations
3. **Provide haptic feedback** for all interactions
4. **Use design system tokens** exclusively
5. **Test with VoiceOver** enabled
6. **Handle errors gracefully** with banners
7. **Dismiss sheets** after successful actions
8. **Auto-save** when possible (like Quiet Hours)

---

## Support

For issues or questions:

1. Check `ENTERPRISE_FIXES_SUMMARY.md` for implementation details
2. Review ViewModel documentation in `NotificationPreferencesViewModel.swift`
3. Test with `#Preview` blocks in Xcode
4. Check Console for logger output (category: "NotificationPreferences")

---

**Last Updated:** 2026-01-30
**Version:** 1.0
**Status:** Production Ready ✅
