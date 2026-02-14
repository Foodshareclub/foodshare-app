//
//  PrivacyProtectionService.swift
//  Foodshare
//
//  Enterprise-grade privacy protection service
//  Features: Privacy blur, screenshot prevention, screen recording detection,
//  clipboard auto-clear, and session timeout
//

#if !SKIP
import Combine
#endif
import Foundation
import OSLog
#if !SKIP
import UIKit
#endif

// MARK: - Privacy Protection Service

@MainActor
@Observable
final class PrivacyProtectionService {

    // MARK: - Singleton

    static let shared = PrivacyProtectionService()

    // MARK: - Observable State

    private(set) var isScreenRecording = false
    private(set) var isAppInBackground = false
    private(set) var lastActiveTime = Date()
    private(set) var sessionExpired = false

    // MARK: - Configuration

    /// Whether privacy blur is enabled when app goes to background
    var privacyBlurEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "privacy_blur_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "privacy_blur_enabled") }
    }

    /// Whether to show warning when screen recording is detected
    var screenRecordingWarningEnabled: Bool {
        get {
            // Default to true if not set
            if UserDefaults.standard.object(forKey: "screen_recording_warning") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "screen_recording_warning")
        }
        set { UserDefaults.standard.set(newValue, forKey: "screen_recording_warning") }
    }

    /// Session timeout duration (default 24 hours)
    var sessionTimeoutDuration: TimeInterval {
        get {
            let value = UserDefaults.standard.double(forKey: "session_timeout_duration")
            return value > 0 ? value : 86400 // 24 hours default
        }
        set { UserDefaults.standard.set(newValue, forKey: "session_timeout_duration") }
    }

    /// Whether clipboard auto-clear is enabled
    var clipboardAutoClearEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "clipboard_auto_clear") }
        set { UserDefaults.standard.set(newValue, forKey: "clipboard_auto_clear") }
    }

    /// Clipboard clear delay in seconds (default 60)
    var clipboardClearDelay: TimeInterval {
        get {
            let value = UserDefaults.standard.double(forKey: "clipboard_clear_delay")
            return value > 0 ? value : 60
        }
        set { UserDefaults.standard.set(newValue, forKey: "clipboard_clear_delay") }
    }

    // MARK: - Private Properties

    private let logger = Logger(subsystem: Constants.bundleIdentifier, category: "PrivacyProtection")
    private var privacyWindow: UIWindow?
    // nonisolated(unsafe) allows access in deinit - safe because we only invalidate
    private nonisolated(unsafe) var clipboardClearTimer: Timer?
    private nonisolated(unsafe) var sessionCheckTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupNotifications()
        setupScreenRecordingObserver()
        startSessionTimer()

        // Enable privacy blur by default
        if UserDefaults.standard.object(forKey: "privacy_blur_enabled") == nil {
            privacyBlurEnabled = true
        }
    }

    // MARK: - Setup

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil,
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil,
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil,
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil,
        )
    }

    private func setupScreenRecordingObserver() {
        // Check initial state
        isScreenRecording = UIScreen.main.isCaptured

        // Observe changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenCaptureChanged),
            name: UIScreen.capturedDidChangeNotification,
            object: nil,
        )
    }

    // MARK: - Privacy Blur

    private func showPrivacyBlur() {
        guard privacyBlurEnabled else { return }
        guard privacyWindow == nil else { return }

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return }

        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear

        let blurEffect = UIBlurEffect(style: .systemThickMaterialDark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = window.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Add app icon in center
        let iconContainer = UIView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(iconContainer)

        let iconImageView = UIImageView(image: UIImage(named: "AppIcon"))
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.layer.cornerRadius = 20
        iconImageView.clipsToBounds = true
        iconContainer.addSubview(iconImageView)

        let lockIcon = UIImageView(image: UIImage(systemName: "lock.fill"))
        lockIcon.translatesAutoresizingMaskIntoConstraints = false
        lockIcon.tintColor = .white
        lockIcon.contentMode = .scaleAspectFit
        iconContainer.addSubview(lockIcon)

        NSLayoutConstraint.activate([
            iconContainer.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
            iconContainer.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.topAnchor.constraint(equalTo: iconContainer.topAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 80),
            iconImageView.heightAnchor.constraint(equalToConstant: 80),

            lockIcon.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            lockIcon.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 16),
            lockIcon.bottomAnchor.constraint(equalTo: iconContainer.bottomAnchor),
            lockIcon.widthAnchor.constraint(equalToConstant: 24),
            lockIcon.heightAnchor.constraint(equalToConstant: 24)
        ])

        window.addSubview(blurView)
        window.makeKeyAndVisible()

        privacyWindow = window
        logger.info("Privacy blur shown")
    }

    private func hidePrivacyBlur() {
        privacyWindow?.isHidden = true
        privacyWindow = nil
        logger.info("Privacy blur hidden")
    }

    // MARK: - Screen Recording Detection

    @objc private func screenCaptureChanged() {
        let isCaptured = UIScreen.main.isCaptured

        Task { @MainActor in
            isScreenRecording = isCaptured

            if isCaptured, screenRecordingWarningEnabled {
                logger.warning("Screen recording detected")
                NotificationCenter.default.post(
                    name: .screenRecordingDetected,
                    object: nil,
                )
            }
        }
    }

    // MARK: - Screenshot Prevention

    /// Creates a secure text field that prevents screenshots
    /// Use this for sensitive content
    func makeSecureField() -> UITextField {
        let textField = UITextField()
        textField.isSecureTextEntry = true
        return textField
    }

    // MARK: - Clipboard Management

    /// Copy text to clipboard with auto-clear
    func secureCopy(_ text: String) {
        UIPasteboard.general.string = text

        if clipboardAutoClearEnabled {
            scheduleClipboardClear()
        }

        logger.info("Secure copy performed, will clear in \(self.clipboardClearDelay)s")
    }

    /// Manually clear clipboard
    func clearClipboard() {
        UIPasteboard.general.string = ""
        clipboardClearTimer?.invalidate()
        clipboardClearTimer = nil
        logger.info("Clipboard cleared")
    }

    private func scheduleClipboardClear() {
        clipboardClearTimer?.invalidate()

        clipboardClearTimer = Timer.scheduledTimer(
            withTimeInterval: clipboardClearDelay,
            repeats: false,
        ) { [weak self] _ in
            Task { @MainActor in
                self?.clearClipboard()
            }
        }
    }

    // MARK: - Session Timeout

    private func startSessionTimer() {
        sessionCheckTimer?.invalidate()

        // Check every minute
        sessionCheckTimer = Timer.scheduledTimer(
            withTimeInterval: 60,
            repeats: true,
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkSessionTimeout()
            }
        }
    }

    private func checkSessionTimeout() {
        let timeSinceActive = Date().timeIntervalSince(lastActiveTime)

        if timeSinceActive > sessionTimeoutDuration {
            sessionExpired = true
            logger.warning("Session expired after \(timeSinceActive)s of inactivity")
            NotificationCenter.default.post(
                name: .sessionExpired,
                object: nil,
            )
        }
    }

    /// Update last active time (call on user interaction)
    func updateActivity() {
        lastActiveTime = Date()
        sessionExpired = false
    }

    /// Reset session (call after sign in)
    func resetSession() {
        lastActiveTime = Date()
        sessionExpired = false
        startSessionTimer()
    }

    /// Invalidate session (call on sign out)
    func invalidateSession() {
        sessionCheckTimer?.invalidate()
        sessionCheckTimer = nil
        sessionExpired = false
    }

    // MARK: - App Lifecycle

    @objc private func appWillResignActive() {
        showPrivacyBlur()
    }

    @objc private func appDidBecomeActive() {
        hidePrivacyBlur()
        updateActivity()
    }

    @objc private func appDidEnterBackground() {
        isAppInBackground = true
        showPrivacyBlur()
    }

    @objc private func appWillEnterForeground() {
        isAppInBackground = false
        checkSessionTimeout()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        clipboardClearTimer?.invalidate()
        sessionCheckTimer?.invalidate()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let screenRecordingDetected = Notification.Name("screenRecordingDetected")
    // sessionExpired is defined in NotificationNames.swift
}

// MARK: - Session Timeout Options

enum SessionTimeoutOption: Double, CaseIterable, Identifiable {
    case fifteenMinutes = 900 // 15 min
    case oneHour = 3600 // 1 hour
    case fourHours = 14400 // 4 hours
    case twentyFourHours = 86400 // 24 hours
    case oneWeek = 604_800 // 7 days
    case never = 0

    var id: Double { rawValue }

    var displayName: String {
        switch self {
        case .fifteenMinutes: "15 minutes"
        case .oneHour: "1 hour"
        case .fourHours: "4 hours"
        case .twentyFourHours: "24 hours"
        case .oneWeek: "1 week"
        case .never: "Never"
        }
    }

    /// Localized display name using translation service
    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .fifteenMinutes: t.t("session.timeout.fifteen_minutes")
        case .oneHour: t.t("session.timeout.one_hour")
        case .fourHours: t.t("session.timeout.four_hours")
        case .twentyFourHours: t.t("session.timeout.twenty_four_hours")
        case .oneWeek: t.t("session.timeout.one_week")
        case .never: t.t("session.timeout.never")
        }
    }

    var duration: TimeInterval {
        rawValue == 0 ? .infinity : rawValue
    }
}
