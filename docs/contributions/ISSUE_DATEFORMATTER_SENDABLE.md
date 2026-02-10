# Issue: DateFormatter Sendable Conformance for Swift 6

**Repository:** [swiftlang/swift-corelibs-foundation](https://github.com/swiftlang/swift-corelibs-foundation)

---

## Status: ❌ DO NOT FILE - Already Fixed

This issue was **already fixed** in swift-corelibs-foundation.

### Resolution

| PR | Date | Status |
|----|------|--------|
| [#5000](https://github.com/swiftlang/swift-corelibs-foundation/pull/5000) | July 2024 | ✅ Merged |

The PR added `@unchecked Sendable` conformance to `DateFormatter` and other formatters in swift-corelibs-foundation.

### Affected Classes (Now Sendable)

- `DateFormatter`
- `NumberFormatter`
- `ISO8601DateFormatter`
- `DateComponentsFormatter`
- `DateIntervalFormatter`
- `MeasurementFormatter`
- `PersonNameComponentsFormatter`

### Workaround (For Older Swift Versions)

If using a Swift version before this fix, wrap in an `@unchecked Sendable` container:

```swift
/// Thread-safe DateFormatter wrapper for Swift 6 strict concurrency
final class SendableDateFormatter: @unchecked Sendable {
    private let formatter: DateFormatter
    private let lock = NSLock()
    
    init(configure: (DateFormatter) -> Void = { _ in }) {
        self.formatter = DateFormatter()
        configure(self.formatter)
    }
    
    func string(from date: Date) -> String {
        lock.lock()
        defer { lock.unlock() }
        return formatter.string(from: date)
    }
    
    func date(from string: String) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return formatter.date(from: string)
    }
}
```

### Recommendation

Update to Swift 6.0+ which includes this fix. The workaround is only needed for older Swift versions.

---

**Research Date:** January 2026
