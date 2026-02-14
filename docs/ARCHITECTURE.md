# FoodShare Architecture

## Overview

FoodShare uses **Skip Fuse** to maintain a single Swift codebase that generates native iOS and Android applications.

```
┌─────────────────────────────────────┐
│      Swift/SwiftUI Source Code      │
│     (Single Source of Truth)        │
└─────────────────┬───────────────────┘
                  │
                  │ Skip Transpiler
                  │
        ┌─────────┴─────────┐
        │                   │
        ▼                   ▼
┌──────────────┐    ┌──────────────┐
│   iOS App    │    │ Android App  │
│   SwiftUI    │    │Jetpack Compose│
│   Native     │    │   Native     │
└──────────────┘    └──────────────┘
```

---

## Architecture Pattern: MVVM

### Model
Data structures and business logic.
- Located in `Sources/FoodShare/Models/`
- Codable for JSON serialization
- Identifiable for SwiftUI lists

### View
UI components built with SwiftUI.
- Located in `Sources/FoodShare/Views/`
- Declarative UI
- Reactive to state changes

### ViewModel (Service Layer)
Business logic and state management.
- Located in `Sources/FoodShare/Services/`
- `@MainActor` for UI updates
- `@Published` properties for reactivity

---

## Project Structure

```
foodshare-android/
├── Sources/FoodShare/
│   ├── FoodShareApp.swift          # App entry point
│   ├── Models/                     # Data models
│   │   ├── Models.swift
│   │   ├── Activity.swift
│   │   ├── Message.swift
│   │   ├── Challenge.swift
│   │   ├── Comment.swift
│   │   └── Leaderboard.swift
│   ├── Services/                   # Business logic
│   │   └── AuthService.swift
│   └── Views/                      # UI components
│       ├── LoginView.swift
│       ├── MainTabView.swift
│       ├── ContentView.swift
│       └── ... (22 views)
├── Darwin/                         # iOS-specific
│   ├── FoodShare.xcodeproj
│   └── Assets.xcassets
├── Android/                        # Android-specific
│   ├── app/
│   │   └── build.gradle.kts
│   └── settings.gradle.kts
├── Tests/                          # Unit tests
├── docs/                           # Documentation
└── Package.swift                   # Dependencies
```

---

## Data Flow

```
User Action
    ↓
View (SwiftUI)
    ↓
Service (@MainActor)
    ↓
Supabase API
    ↓
Database
    ↓
Response
    ↓
Service Updates @Published State
    ↓
View Automatically Re-renders
```

---

## State Management

### Local State
```swift
@State var isLoading = false
```
- Component-local state
- Automatically triggers re-render

### Shared State
```swift
@Environment(\.supabase) var supabase
@Environment(\.authService) var authService
```
- Injected via environment
- Shared across view hierarchy

### Observable Objects
```swift
@MainActor
class AuthService: ObservableObject {
    @Published var isAuthenticated = false
}
```
- Reactive state management
- Automatic UI updates

---

## Navigation

### Tab-Based
```swift
TabView {
    ContentView().tabItem { Label("Feed", systemImage: "house.fill") }
    MapView().tabItem { Label("Map", systemImage: "map.fill") }
    // ...
}
```

### Stack-Based
```swift
NavigationStack {
    List {
        NavigationLink("Detail") {
            DetailView()
        }
    }
}
```

### Modal
```swift
.sheet(isPresented: $showModal) {
    ModalView()
}
```

---

## Networking

### Supabase Client
```swift
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://api.foodshare.club")!,
    supabaseKey: "public_key"
)
```

### API Calls
```swift
let listings: [Listing] = try await supabase
    .from("listings")
    .select()
    .eq("status", value: "available")
    .execute()
    .value
```

### Error Handling
```swift
do {
    let data = try await fetchData()
} catch {
    errorMessage = error.localizedDescription
}
```

---

## Skip Transpilation

### Supported Features
- ✅ SwiftUI views
- ✅ @State, @Binding
- ✅ @Environment
- ✅ NavigationStack, TabView
- ✅ List, ForEach
- ✅ async/await
- ✅ Codable
- ✅ Most Swift standard library

### Limitations
- ❌ UIKit (use SwiftUI)
- ❌ MapKit (use platform-specific)
- ❌ Some iOS-only modifiers
- ❌ Complex animations

### Workarounds
```swift
#if os(iOS)
    // iOS-specific code
#elseif os(Android)
    // Android-specific code
#endif
```

---

## Performance

### Optimization Strategies
1. **Lazy Loading**: Use `LazyVStack` for long lists
2. **Image Caching**: Kingfisher handles caching
3. **Pagination**: Load data in chunks
4. **Debouncing**: Delay search queries
5. **Background Tasks**: Use `Task` for async work

### Memory Management
- Swift ARC handles iOS
- Kotlin GC handles Android
- No manual memory management needed

---

## Security

### Authentication
- JWT tokens from Supabase
- Stored securely (Keychain/EncryptedSharedPreferences)
- Auto-refresh on expiry

### API Security
- HTTPS only
- Row-level security in Supabase
- No secrets in client code

### Data Validation
- Server-side validation
- Client-side for UX
- Type-safe with Codable

---

## Testing Strategy

### Unit Tests
- Model decoding/encoding
- Service logic
- Business rules

### Integration Tests
- API calls
- Database operations
- Auth flows

### UI Tests
- Critical user flows
- Navigation
- Form submission

---

## Deployment

### iOS
1. Archive in Xcode
2. Upload to TestFlight
3. Submit for review
4. Release to App Store

### Android
1. `./gradlew bundleRelease`
2. Upload to Play Console
3. Internal testing
4. Production release

---

## Monitoring

### Crash Reporting
- Sentry integration ready
- Automatic crash reports
- Stack traces

### Analytics
- Firebase Analytics ready
- User behavior tracking
- Conversion funnels

### Performance
- App startup time
- API response times
- Memory usage

---

## Scalability

### Horizontal Scaling
- Supabase handles backend scaling
- CDN for images
- Edge functions for compute

### Code Scaling
- Modular architecture
- Feature-based organization
- Dependency injection

---

**Last Updated**: 2026-02-12
**Version**: 1.0.0
