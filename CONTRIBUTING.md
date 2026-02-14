# Contributing to FoodShare

## Getting Started

### Prerequisites
- macOS 14+
- Xcode 16.2+
- Skip installed: `brew install skiptools/skip/skip`
- Android Studio (for Android testing)

### Setup
```bash
git clone https://github.com/yourorg/foodshare.git
cd foodshare/foodshare-android
open Project.xcworkspace
```

---

## Development Workflow

### 1. Create Feature Branch
```bash
git checkout -b feature/your-feature-name
```

### 2. Write Swift Code
All code goes in `Sources/FoodShare/`:
```swift
// Sources/FoodShare/Views/YourView.swift
import SwiftUI
import SkipFuseUI

struct YourView: View {
    var body: some View {
        Text("Hello")
    }
}
```

### 3. Build & Test
```bash
swift build  # Builds and transpiles
swift test   # Run tests
```

### 4. Run on Both Platforms
In Xcode:
- Select "FoodShare App" scheme
- Press Run (⌘R)
- iOS and Android launch together

### 5. Commit & Push
```bash
git add .
git commit -m "feat: add your feature"
git push origin feature/your-feature-name
```

### 6. Create Pull Request
- Go to GitHub
- Create PR from your branch to `main`
- Wait for CI checks
- Request review

---

## Code Style

### Swift
Follow Swift API Design Guidelines:
```swift
// Good
func loadListings() async throws -> [Listing]

// Bad
func get_listings() -> [Listing]?
```

### Naming
- Types: `PascalCase`
- Functions: `camelCase`
- Constants: `camelCase`
- Files: Match type name

### Comments
```swift
/// Loads listings from Supabase
/// - Returns: Array of available listings
/// - Throws: Network or decoding errors
func loadListings() async throws -> [Listing]
```

---

## Skip Compatibility

### ✅ Use These
- SwiftUI views
- @State, @Binding, @Environment
- async/await
- Codable
- Standard library types

### ❌ Avoid These
- UIKit
- MapKit (use platform-specific)
- Complex animations
- iOS-only modifiers

### Platform-Specific Code
```swift
#if os(iOS)
    // iOS-only code
#elseif os(Android)
    // Android-only code
#endif
```

---

## Testing

### Unit Tests
```swift
import XCTest
@testable import FoodShare

final class YourTests: XCTestCase {
    func testSomething() {
        XCTAssertEqual(1, 1)
    }
}
```

### Run Tests
```bash
swift test
```

---

## Pull Request Guidelines

### Title Format
- `feat: add new feature`
- `fix: fix bug`
- `docs: update documentation`
- `test: add tests`
- `refactor: refactor code`

### Description
- What does this PR do?
- Why is this change needed?
- How was it tested?
- Screenshots (if UI change)

### Checklist
- [ ] Code builds without errors
- [ ] Tests pass
- [ ] No console warnings
- [ ] Tested on iOS
- [ ] Tested on Android
- [ ] Documentation updated

---

## Common Tasks

### Add New View
1. Create `Sources/FoodShare/Views/YourView.swift`
2. Import `SwiftUI` and `SkipFuseUI`
3. Build - Skip transpiles automatically
4. Test on both platforms

### Add New Model
1. Create `Sources/FoodShare/Models/YourModel.swift`
2. Make it `Codable` and `Identifiable`
3. Use snake_case for CodingKeys
4. Build and test

### Add New Service
1. Create `Sources/FoodShare/Services/YourService.swift`
2. Mark with `@MainActor` if UI updates
3. Use `@Published` for reactive state
4. Inject via `@Environment`

---

## Debugging

### iOS
- Use Xcode debugger
- Set breakpoints
- View console logs

### Android
- Use Android Studio logcat
- Filter by "FoodShare"
- View crash reports

### Skip Issues
- Check Skip docs: https://skip.dev/docs
- Ask on forums: https://forums.skip.dev
- File issues: https://github.com/skiptools/skip

---

## Release Process

1. Update version in `Skip.env`
2. Update `CHANGELOG.md`
3. Create release branch
4. Build & test thoroughly
5. Merge to main
6. Tag release: `git tag v0.0.1`
7. CI/CD deploys automatically

---

## Getting Help

- **Skip Docs**: https://skip.dev/docs
- **Swift Forums**: https://forums.swift.org
- **Supabase Docs**: https://supabase.com/docs
- **Team Chat**: [Your Slack/Discord]

---

## Code of Conduct

Be respectful, inclusive, and collaborative.

---

**Thank you for contributing to FoodShare!** 🙏
