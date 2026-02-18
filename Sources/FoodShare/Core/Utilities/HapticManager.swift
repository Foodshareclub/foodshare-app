//
//  HapticManager.swift
//  Foodshare
//
//  Haptic feedback utility with enhanced patterns
//  Provides consistent, contextual haptic feedback across the app
//


#if !SKIP
import UIKit

@MainActor
enum HapticManager {
    // MARK: - Shared Generators (for performance)

    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private static let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static let selectionGenerator = UISelectionFeedbackGenerator()

    // MARK: - Settings

    private static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "hapticsEnabled") != false
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "hapticsEnabled")
    }

    // MARK: - Prepare (call before expected interaction)

    static func prepare(_ style: FeedbackStyle) {
        guard isEnabled else { return }

        switch style {
        case .light: lightGenerator.prepare()
        case .medium: mediumGenerator.prepare()
        case .heavy: heavyGenerator.prepare()
        case .soft: softGenerator.prepare()
        case .rigid: rigidGenerator.prepare()
        case .success, .error, .warning: notificationGenerator.prepare()
        case .selection: selectionGenerator.prepare()
        }
    }

    // MARK: - Impact Feedback

    static func light() {
        guard isEnabled else { return }
        lightGenerator.impactOccurred()
    }

    static func medium() {
        guard isEnabled else { return }
        mediumGenerator.impactOccurred()
    }

    static func heavy() {
        guard isEnabled else { return }
        heavyGenerator.impactOccurred()
    }

    static func soft() {
        guard isEnabled else { return }
        softGenerator.impactOccurred()
    }

    static func rigid() {
        guard isEnabled else { return }
        rigidGenerator.impactOccurred()
    }

    // MARK: - Impact with Intensity

    static func light(intensity: CGFloat) {
        guard isEnabled else { return }
        lightGenerator.impactOccurred(intensity: intensity)
    }

    static func medium(intensity: CGFloat) {
        guard isEnabled else { return }
        mediumGenerator.impactOccurred(intensity: intensity)
    }

    static func heavy(intensity: CGFloat) {
        guard isEnabled else { return }
        heavyGenerator.impactOccurred(intensity: intensity)
    }

    // MARK: - Notification Feedback

    static func success() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
    }

    static func error() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.error)
    }

    static func warning() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.warning)
    }

    // MARK: - Selection Feedback

    static func selection() {
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
    }

    // MARK: - Contextual Patterns

    /// Button tap feedback
    static func buttonTap() {
        light()
    }

    /// Toggle switch feedback
    static func toggle() {
        medium()
    }

    /// Pull to refresh feedback
    static func pullToRefresh() {
        medium(intensity: 0.7)
    }

    /// Swipe action feedback
    static func swipeAction() {
        light(intensity: 0.8)
    }

    /// Long press feedback
    static func longPress() {
        heavy(intensity: 0.6)
    }

    /// Drag start feedback
    static func dragStart() {
        light()
    }

    /// Drag end/drop feedback
    static func dragEnd() {
        medium()
    }

    /// Page change feedback
    static func pageChange() {
        selection()
    }

    /// Tab change feedback
    static func tabChange() {
        selection()
    }

    /// Slider tick feedback
    static func sliderTick() {
        light(intensity: 0.3)
    }

    /// Message sent feedback
    static func messageSent() {
        soft()
    }

    /// Message received feedback
    static func messageReceived() {
        light(intensity: 0.5)
    }

    /// Like/favorite feedback
    static func like() {
        light()
    }

    /// Unlike/unfavorite feedback
    static func unlike() {
        soft()
    }

    /// Save/bookmark feedback
    static func save() {
        medium(intensity: 0.6)
    }

    /// Delete feedback
    static func delete() {
        rigid()
    }

    /// Refresh complete feedback
    static func refreshComplete() {
        success()
    }

    /// Form validation error feedback
    static func validationError() {
        error()
    }

    /// Network error feedback
    static func networkError() {
        warning()
    }

    // MARK: - Pattern Sequences

    /// Double tap pattern
    static func doubleTap() {
        guard isEnabled else { return }
        light()
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            light()
        }
    }

    /// Triple success pattern (achievement unlocked)
    static func achievement() {
        guard isEnabled else { return }
        light()
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            medium()
            try? await Task.sleep(for: .milliseconds(100))
            success()
        }
    }

    /// Countdown pattern (3, 2, 1)
    static func countdown(completion: @escaping () -> Void) {
        guard isEnabled else {
            completion()
            return
        }

        light()
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            light()
            try? await Task.sleep(for: .milliseconds(500))
            light()
            try? await Task.sleep(for: .milliseconds(500))
            heavy()
            completion()
        }
    }

    /// Heartbeat pattern
    static func heartbeat() {
        guard isEnabled else { return }
        medium(intensity: 0.8)
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            light(intensity: 0.4)
        }
    }

    // MARK: - Feedback Style Enum

    enum FeedbackStyle {
        case light, medium, heavy, soft, rigid
        case success, error, warning
        case selection
    }

    /// Generic feedback method
    static func feedback(_ style: FeedbackStyle) {
        switch style {
        case .light: light()
        case .medium: medium()
        case .heavy: heavy()
        case .soft: soft()
        case .rigid: rigid()
        case .success: success()
        case .error: error()
        case .warning: warning()
        case .selection: selection()
        }
    }
}
#else
// Skip stub — haptics are iOS-only, no-op on Android
@MainActor
enum HapticManager {
    enum FeedbackStyle {
        case light, medium, heavy, soft, rigid
        case success, error, warning
        case selection
    }
    static func prepare(_ style: FeedbackStyle) {}
    static func light() {}
    static func medium() {}
    static func heavy() {}
    static func soft() {}
    static func rigid() {}
    static func light(intensity: CGFloat) {}
    static func medium(intensity: CGFloat) {}
    static func heavy(intensity: CGFloat) {}
    static func success() {}
    static func error() {}
    static func warning() {}
    static func selection() {}
    static func buttonTap() {}
    static func toggle() {}
    static func pullToRefresh() {}
    static func swipeAction() {}
    static func longPress() {}
    static func dragStart() {}
    static func dragEnd() {}
    static func pageChange() {}
    static func tabChange() {}
    static func sliderTick() {}
    static func messageSent() {}
    static func messageReceived() {}
    static func like() {}
    static func unlike() {}
    static func save() {}
    static func delete() {}
    static func refreshComplete() {}
    static func validationError() {}
    static func networkError() {}
    static func doubleTap() {}
    static func achievement() {}
    static func heartbeat() {}
    static func countdown(completion: @escaping () -> Void) { completion() }
    static func feedback(_ style: FeedbackStyle) {}
    static func setEnabled(_ enabled: Bool) {}
}

#endif
