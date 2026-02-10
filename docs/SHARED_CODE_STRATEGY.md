# Shared Code Strategy

What Swift code to share between iOS and Android, and what to keep platform-native.

---

## Sharing Principles

| Share | Don't Share |
|-------|-------------|
| Domain models | UI components |
| Validation logic | Platform APIs |
| Business rules | Navigation |
| Constants | Animations |
| Type definitions | State management |

---

## Code Sharing Layers

```
┌─────────────────────────────────────────────────────────┐
│                    SHARE NOTHING                        │
│              (Platform-Specific Layer)                  │
├────────────────────────┬────────────────────────────────┤
│       iOS              │           Android              │
│   ┌────────────────┐   │   ┌────────────────────┐       │
│   │    SwiftUI     │   │   │   Jetpack Compose  │       │
│   │   Components   │   │   │     Composables    │       │
│   └────────────────┘   │   └────────────────────┘       │
│   ┌────────────────┐   │   ┌────────────────────┐       │
│   │   @Observable  │   │   │   ViewModel +      │       │
│   │   ViewModels   │   │   │   State Hoisting   │       │
│   └────────────────┘   │   └────────────────────┘       │
├────────────────────────┴────────────────────────────────┤
│                    SHARE EVERYTHING                     │
│                  (Swift Core Package)                   │
├─────────────────────────────────────────────────────────┤
│   ┌─────────────────────────────────────────────────┐   │
│   │              Domain Models                      │   │
│   │   FoodListing, UserProfile, Category, etc.      │   │
│   └─────────────────────────────────────────────────┘   │
│   ┌─────────────────────────────────────────────────┐   │
│   │              Validation Logic                   │   │
│   │   ListingValidator, ProfileValidator, etc.      │   │
│   └─────────────────────────────────────────────────┘   │
│   ┌─────────────────────────────────────────────────┐   │
│   │              Constants & Types                  │   │
│   │   Categories, ErrorCodes, Configuration         │   │
│   └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

---

## Shared Swift Package Structure

```
FoodshareCore/
├── Package.swift
└── Sources/
    └── FoodshareCore/
        ├── Models/
        │   ├── FoodListing.swift
        │   ├── UserProfile.swift
        │   ├── Category.swift
        │   ├── Coordinate.swift
        │   └── Message.swift
        ├── Validation/
        │   ├── ListingValidator.swift
        │   ├── ProfileValidator.swift
        │   └── ValidationError.swift
        ├── Constants/
        │   ├── Categories.swift
        │   ├── ErrorCodes.swift
        │   └── Configuration.swift
        └── Utilities/
            ├── DateFormatting.swift
            └── DistanceCalculation.swift
```

---

## Example: Shared Domain Model

### Swift (Shared)

```swift
// FoodshareCore/Sources/FoodshareCore/Models/FoodListing.swift

import Foundation

/// A food listing that can be shared or claimed
/// Shared between iOS and Android
public struct FoodListing: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let userId: UUID
    public let title: String
    public let description: String
    public let category: Category
    public let location: Coordinate
    public let imageUrl: URL?
    public let quantity: Int
    public let expiresAt: Date
    public let createdAt: Date
    public let status: ListingStatus

    public init(
        id: UUID = UUID(),
        userId: UUID,
        title: String,
        description: String,
        category: Category,
        location: Coordinate,
        imageUrl: URL? = nil,
        quantity: Int,
        expiresAt: Date,
        createdAt: Date = Date(),
        status: ListingStatus = .available
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.description = description
        self.category = category
        self.location = location
        self.imageUrl = imageUrl
        self.quantity = quantity
        self.expiresAt = expiresAt
        self.createdAt = createdAt
        self.status = status
    }
}

public enum ListingStatus: String, Codable, Sendable {
    case available
    case claimed
    case expired
    case deleted
}

public struct Coordinate: Codable, Sendable, Hashable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Calculate distance to another coordinate in kilometers
    public func distance(to other: Coordinate) -> Double {
        let earthRadius = 6371.0 // km
        let dLat = (other.latitude - latitude) * .pi / 180
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2) +
                cos(latitude * .pi / 180) * cos(other.latitude * .pi / 180) *
                sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        return earthRadius * c
    }
}

public enum Category: String, Codable, Sendable, CaseIterable {
    case produce = "Produce"
    case bakery = "Bakery"
    case dairy = "Dairy"
    case prepared = "Prepared"
    case pantry = "Pantry"
    case beverages = "Beverages"
    case other = "Other"

    public var icon: String {
        switch self {
        case .produce: return "leaf.fill"
        case .bakery: return "birthday.cake.fill"
        case .dairy: return "drop.fill"
        case .prepared: return "fork.knife"
        case .pantry: return "shippingbox.fill"
        case .beverages: return "cup.and.saucer.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}
```

### iOS Usage (SwiftUI)

```swift
// iOS app - uses shared model directly
import FoodshareCore
import SwiftUI

struct FoodItemCard: View {
    let listing: FoodListing

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(listing.title)
                    .font(.DesignSystem.headlineMedium)
                Text(listing.category.rawValue)
                    .font(.DesignSystem.caption)
            }
        }
    }
}
```

### Android Usage (via JNI)

```kotlin
// Android app - uses shared model via swift-java bridge
import com.foodshare.swift.FoodListing
import androidx.compose.material3.*

@Composable
fun FoodItemCard(listing: FoodListing) {
    Card {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = listing.title,
                style = MaterialTheme.typography.headlineSmall
            )
            Text(
                text = listing.category.rawValue,
                style = MaterialTheme.typography.bodySmall
            )
        }
    }
}
```

---

## Example: Shared Validation Logic

### Swift (Shared)

```swift
// FoodshareCore/Sources/FoodshareCore/Validation/ListingValidator.swift

import Foundation

public struct ListingValidator {

    public struct ValidationResult {
        public let isValid: Bool
        public let errors: [ValidationError]

        public static let valid = ValidationResult(isValid: true, errors: [])
    }

    public enum ValidationError: Error, Sendable {
        case titleEmpty
        case titleTooShort(minLength: Int)
        case titleTooLong(maxLength: Int)
        case descriptionEmpty
        case descriptionTooLong(maxLength: Int)
        case invalidQuantity
        case expirationInPast
        case expirationTooFarFuture(maxDays: Int)

        public var message: String {
            switch self {
            case .titleEmpty:
                return "Title is required"
            case .titleTooShort(let min):
                return "Title must be at least \(min) characters"
            case .titleTooLong(let max):
                return "Title cannot exceed \(max) characters"
            case .descriptionEmpty:
                return "Description is required"
            case .descriptionTooLong(let max):
                return "Description cannot exceed \(max) characters"
            case .invalidQuantity:
                return "Quantity must be at least 1"
            case .expirationInPast:
                return "Expiration date cannot be in the past"
            case .expirationTooFarFuture(let days):
                return "Expiration date cannot be more than \(days) days from now"
            }
        }
    }

    // Configuration constants
    public static let minTitleLength = 3
    public static let maxTitleLength = 100
    public static let maxDescriptionLength = 500
    public static let maxExpirationDays = 30

    public init() {}

    public func validate(
        title: String,
        description: String,
        quantity: Int,
        expiresAt: Date
    ) -> ValidationResult {
        var errors: [ValidationError] = []

        // Title validation
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            errors.append(.titleEmpty)
        } else if trimmedTitle.count < Self.minTitleLength {
            errors.append(.titleTooShort(minLength: Self.minTitleLength))
        } else if trimmedTitle.count > Self.maxTitleLength {
            errors.append(.titleTooLong(maxLength: Self.maxTitleLength))
        }

        // Description validation
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDescription.isEmpty {
            errors.append(.descriptionEmpty)
        } else if trimmedDescription.count > Self.maxDescriptionLength {
            errors.append(.descriptionTooLong(maxLength: Self.maxDescriptionLength))
        }

        // Quantity validation
        if quantity < 1 {
            errors.append(.invalidQuantity)
        }

        // Expiration validation
        let now = Date()
        if expiresAt < now {
            errors.append(.expirationInPast)
        } else {
            let maxExpiration = Calendar.current.date(
                byAdding: .day,
                value: Self.maxExpirationDays,
                to: now
            )!
            if expiresAt > maxExpiration {
                errors.append(.expirationTooFarFuture(maxDays: Self.maxExpirationDays))
            }
        }

        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
}
```

### iOS Usage

```swift
// iOS ViewModel
import FoodshareCore

@MainActor @Observable
final class CreateListingViewModel {
    var title = ""
    var description = ""
    var quantity = 1
    var expiresAt = Date().addingTimeInterval(86400)
    var validationErrors: [String] = []

    private let validator = ListingValidator()

    func validate() -> Bool {
        let result = validator.validate(
            title: title,
            description: description,
            quantity: quantity,
            expiresAt: expiresAt
        )
        validationErrors = result.errors.map(\.message)
        return result.isValid
    }
}
```

### Android Usage

```kotlin
// Android ViewModel
import com.foodshare.swift.ListingValidator
import com.foodshare.swift.ListingValidator.ValidationResult

class CreateListingViewModel : ViewModel() {
    var title by mutableStateOf("")
    var description by mutableStateOf("")
    var quantity by mutableIntStateOf(1)
    var expiresAt by mutableStateOf(Date())
    var validationErrors by mutableStateOf<List<String>>(emptyList())

    private val validator = ListingValidator()

    fun validate(): Boolean {
        val result = validator.validate(
            title = title,
            description = description,
            quantity = quantity,
            expiresAt = expiresAt
        )
        validationErrors = result.errors.map { it.message }
        return result.isValid
    }
}
```

---

## Package.swift Configuration

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FoodshareCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
        // Android is implied when building with --swift-sdk
    ],
    products: [
        .library(
            name: "FoodshareCore",
            targets: ["FoodshareCore"]
        ),
    ],
    targets: [
        .target(
            name: "FoodshareCore",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "FoodshareCoreTests",
            dependencies: ["FoodshareCore"]
        ),
    ]
)
```

---

## Building for Both Platforms

```bash
# Build for iOS
swift build

# Build for Android ARM64
swift build --swift-sdk aarch64-unknown-linux-android28 --static-swift-stdlib

# Build for Android x86_64 (emulator)
swift build --swift-sdk x86_64-unknown-linux-android28 --static-swift-stdlib

# Run tests (host platform)
swift test
```

---

## JNI Integration with swift-java

The [swift-java](https://github.com/swiftlang/swift-java) project provides automatic binding generation between Swift and Java/Kotlin. See WWDC25: "Explore Swift and Java interoperability".

### Alternative: Swift4j

Per forum discussions ("Introducing Swift4j and Our Vision for Swift on Android"), Swift4j is a community alternative for Java interop with different design goals. Check the forums for current status.

### Two Modes for Android

| Mode | Use Case | JDK Requirement |
|------|----------|-----------------|
| **jextract --mode=jni** | Android apps | Any JDK |
| **jextract --mode=ffm** | Server apps | JDK 22+ (not Android) |

For Android, use `--mode=jni` since Android doesn't support FFM.

### Step 1: Add swift-java Dependency

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/swiftlang/swift-java.git", branch: "main")
]
```

### Step 2: Generate Bindings

```bash
# Generate Kotlin bindings from Swift code (JNI mode for Android)
swift-java jextract --mode=jni Sources/FoodshareCore --output-dir generated-java
```

### Step 3: Include in Android Build

```kotlin
// app/build.gradle.kts
android {
    sourceSets {
        getByName("main") {
            java.srcDirs("../swift-core/generated-java")
        }
    }

    externalNativeBuild {
        cmake {
            path = file("../swift-core/CMakeLists.txt")
        }
    }
}
```

### Recommended: hello-swift-java Example

The [hello-swift-java](https://github.com/swiftlang/swift-android-examples/tree/main/hello-swift-java) example demonstrates automatic JNI binding generation with no manual JNI code required.

Other examples in [swift-android-examples](https://github.com/swiftlang/swift-android-examples):

| Example | Description |
|---------|-------------|
| **hello-swift-java** | Recommended - automatic JNI bindings |
| **swift-java-weather-app** | Async functions, Swift protocols |
| **hello-cpp-swift** | C++ → Swift → Android |
| **hello-world** | Pure native Swift (no Java) |

### Pure Swift Android Apps

Per forum discussions, it's possible to build Android APKs without Java, Gradle, or Android Studio. This is useful for CLI tools or testing, but production apps should use JNI with Jetpack Compose.
```

---

## Package Compatibility

Per the [SDK announcement](https://www.swift.org/blog/nightly-swift-sdk-for-android/), over 25% of Swift Package Index packages already build for Android. The Community Showcase now indicates Android compatibility.

Key compatible packages:

| Package | Status | Use Case |
|---------|--------|----------|
| swift-algorithms | ✅ Compatible | Collection algorithms |
| swift-collections | ✅ Compatible | Data structures |
| swift-argument-parser | ✅ Compatible | CLI tools |
| swift-log | ✅ Compatible | Logging |
| swift-metrics | ✅ Compatible | Metrics |
| swift-crypto | ✅ Compatible | Cryptography |

Check compatibility: https://swiftpackageindex.com (filter by Android platform)

> **Tip:** The [Swift Package Index Community Showcase](https://swiftpackageindex.com) now indicates Android compatibility for packages.

---

## Platform-Specific Dependencies

Per [forum discussions](https://forums.swift.org/c/platform/android/115), use SwiftPM conditions for platform-specific code:

```swift
// Package.swift
.target(
    name: "FoodshareCore",
    dependencies: [
        // iOS/macOS only
        .product(name: "KeychainAccess", package: "keychain-access",
                 condition: .when(platforms: [.iOS, .macOS])),
        // Cross-platform
        .product(name: "JavaKit", package: "swift-java"),
    ]
)
```

### Conditional Compilation

Use `#if` directives for platform-specific code within shared files:

```swift
#if os(Android)
import AndroidFoundation
#else
import Foundation
#endif

public struct SecureStorage {
    public func store(key: String, value: String) {
        #if os(Android)
        // Use Android Keystore
        #else
        // Use iOS Keychain
        #endif
    }
}
```

---

## What NOT to Share

### Platform-Specific APIs

```swift
// DON'T share - uses iOS-specific APIs
import CoreLocation

class LocationService {
    let manager = CLLocationManager()  // iOS only
}
```

### UI Components

```swift
// DON'T share - SwiftUI not available on Android
import SwiftUI

struct GlassButton: View {
    // This is iOS-only
}
```

### Platform Navigation

```swift
// DON'T share - navigation is platform-specific
import SwiftUI

@MainActor @Observable
class NavigationCoordinator {
    var path = NavigationPath()  // iOS SwiftUI only
}
```

---

## Summary

| Layer | Share? | iOS | Android |
|-------|--------|-----|---------|
| Domain Models | Yes | Swift | Swift (JNI) |
| Validation | Yes | Swift | Swift (JNI) |
| Constants | Yes | Swift | Swift (JNI) |
| Utilities | Yes | Swift | Swift (JNI) |
| UI Components | No | SwiftUI | Compose |
| ViewModels | No | @Observable | ViewModel |
| Navigation | No | NavigationStack | NavHost |
| Platform APIs | No | UIKit/CoreLocation | Android SDK |
| Push Notifications | Partial | APNs | FCM |
| Secure Storage | No | Keychain | Android Keystore |

---

## Community Best Practices

Based on [Swift Forums Android discussions](https://forums.swift.org/c/platform/android/115):

### Keep Shared Code Pure

- Avoid platform-specific imports in shared code
- Use protocols/interfaces for platform abstractions
- Test shared code on both platforms regularly

### Minimize JNI Boundary Crossings

- Batch operations where possible
- Use simple types at the boundary (primitives, strings)
- Complex objects should be serialized/deserialized

### Version Alignment

- Keep Swift toolchain and SDK versions in sync
- Document required versions in README
- Use CI to test both platforms

---

## Related Documentation

- [Architecture](./ARCHITECTURE.md) - Cross-platform architecture overview
- [Getting Started](./GETTING_STARTED.md) - SDK setup tutorial
- [Swift Android Workgroup](./SWIFT_ANDROID_WORKGROUP.md) - Official workgroup info
- [swift-java](https://github.com/swiftlang/swift-java) - JNI bindings

---

**Last Updated:** December 2025
