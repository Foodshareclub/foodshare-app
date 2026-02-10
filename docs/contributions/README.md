# Contribution Drafts

Ready-to-submit issues, PRs, and forum posts for the Swift Android community.

## Issues Filed

| File | Target Repository | Status |
|------|-------------------|--------|
| [ISSUE_ANDROID_NDK_ROOT_CONFLICT.md](./ISSUE_ANDROID_NDK_ROOT_CONFLICT.md) | swift-android-sdk | ✅ Filed as [#226](https://github.com/finagolfin/swift-android-sdk/issues/226) → Closed (known upstream issue) |
| [ISSUE_DATEFORMATTER_SENDABLE.md](./ISSUE_DATEFORMATTER_SENDABLE.md) | swift-corelibs-foundation | ❌ Already fixed in [PR #5000](https://github.com/swiftlang/swift-corelibs-foundation/pull/5000) |
| [ISSUE_LIBDISPATCH_STRIPPING.md](./ISSUE_LIBDISPATCH_STRIPPING.md) | swift-android-sdk | ❌ Already documented in [README](https://github.com/finagolfin/swift-android-sdk#building-an-android-app-with-swift) and [#67](https://github.com/finagolfin/swift-android-sdk/issues/67) |

## Forum Posts

| File | Forum | Status |
|------|-------|--------|
| [FORUM_POST_FOODSHARECORE_ARCHITECTURE.md](./FORUM_POST_FOODSHARECORE_ARCHITECTURE.md) | Swift Forums - Android | ✅ Posted [#83948](https://forums.swift.org/t/case-study-sharing-swift-domain-logic-between-ios-and-android-with-foodsharecore/83948) - received feedback, reply pending |

## PRs to Create

| Example | Target Repository | Status |
|---------|-------------------|--------|
| Cross-platform Swift package example | swift-android-examples | 🟡 **Invited by finagolfin** on [#26](https://github.com/swiftlang/swift-android-examples/issues/26#issuecomment-3709108377) - PR pending |

## Pending Actions

### 1. Forum Reply (Manual)

Post reply to [#83948](https://forums.swift.org/t/case-study-sharing-swift-domain-logic-between-ios-and-android-with-foodsharecore/83948) thanking contributors. Draft in [FORUM_POST_FOODSHARECORE_ARCHITECTURE.md](./FORUM_POST_FOODSHARECORE_ARCHITECTURE.md#draft-reply-ready-to-post).

### 2. Cross-Platform Example PR

Create PR for swift-android-examples showing:
- Shared Swift package structure
- iOS integration (direct import)
- Android integration (JNI with `@_cdecl`)
- Build scripts for both platforms

## How to Submit

### GitHub Issues

1. Go to the target repository
2. Click "New Issue"
3. Copy title and description from the draft
4. Add appropriate labels
5. Submit and update [COMMUNITY_CONTRIBUTIONS.md](../COMMUNITY_CONTRIBUTIONS.md)

### Forum Posts

1. Go to [forums.swift.org/c/platform/android](https://forums.swift.org/c/platform/android/115)
2. Click "New Topic"
3. Copy content from the draft
4. Add tags: `android`, relevant keywords
5. Submit and update [COMMUNITY_CONTRIBUTIONS.md](../COMMUNITY_CONTRIBUTIONS.md)

## After Submitting

Update `../COMMUNITY_CONTRIBUTIONS.md` with:
- Issue/post link
- Date submitted
- Current status
