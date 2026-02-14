//
//  AdvancedHapticEngine.swift
//  FoodShare
//
//  Advanced haptic feedback engine using Core Haptics.
//  Provides custom haptic patterns for celebrations, achievements, and interactions.
//
//  Features:
//  - Custom haptic patterns using CHHapticEngine
//  - Pre-defined patterns for common use cases
//  - Velocity-based intensity scaling
//  - Physics-based feedback
//  - Battery-conscious design
//

#if !SKIP
import CoreHaptics
#endif
#if !SKIP
import UIKit
#endif

// MARK: - Advanced Haptic Pattern

/// Pre-defined advanced haptic patterns
enum AdvancedHapticPattern: CaseIterable {
    /// Celebration pattern for achievements, badge unlocks
    case celebration

    /// Milestone pattern for level ups, XP thresholds
    case milestone

    /// Unlock pattern for new features, achievements
    case unlock

    /// Pull-release elastic snap pattern
    case pullRelease

    /// Card flip 3D rotation feedback
    case cardFlip

    /// Message sent confirmation
    case messageSent

    /// Like/heart animation feedback
    case heartPulse

    /// Success checkmark animation
    case successCheck

    /// Error shake pattern
    case errorShake

    /// Countdown tick pattern
    case countdownTick

    /// Confetti burst pattern
    case confettiBurst
}

// MARK: - Advanced Haptic Engine

/// Core Haptics-based engine for custom haptic patterns
@MainActor
final class AdvancedHapticEngine {
    // MARK: - Singleton

    static let shared = AdvancedHapticEngine()

    // MARK: - Properties

    private var engine: CHHapticEngine?
    private var isSupported: Bool
    private var isEnabled = true

    private let userDefaultsKey = "advancedHapticsEnabled"

    // MARK: - Initialization

    private init() {
        // Check if device supports haptics
        isSupported = CHHapticEngine.capabilitiesForHardware().supportsHaptics

        if isSupported {
            setupEngine()
        }

        // Load user preference
        isEnabled = UserDefaults.standard.bool(forKey: userDefaultsKey)
        if !UserDefaults.standard.contains(key: userDefaultsKey) {
            isEnabled = true // Default to enabled
        }
    }

    // MARK: - Setup

    private func setupEngine() {
        guard isSupported else { return }

        do {
            engine = try CHHapticEngine()

            // Configure engine behavior
            engine?.playsHapticsOnly = true
            engine?.isAutoShutdownEnabled = true

            // Handle engine reset
            engine?.resetHandler = { [weak self] in
                Task { @MainActor in
                    self?.restartEngine()
                }
            }

            // Handle engine stopped
            engine?.stoppedHandler = { [weak self] reason in
                Task { @MainActor in
                    self?.handleEngineStopped(reason: reason)
                }
            }

            try engine?.start()
        } catch {
            isSupported = false
        }
    }

    private func restartEngine() {
        do {
            try engine?.start()
        } catch {
            isSupported = false
        }
    }

    private func handleEngineStopped(reason: CHHapticEngine.StoppedReason) {
        switch reason {
        case .audioSessionInterrupt:
            // Will restart when audio session resumes
            break
        case .applicationSuspended:
            // Will restart when app becomes active
            break
        case .idleTimeout:
            // Engine will restart automatically when needed
            break
        case .notifyWhenFinished:
            // Normal completion
            break
        case .engineDestroyed:
            // Need to recreate engine
            setupEngine()
        case .gameControllerDisconnect:
            break
        case .systemError:
            setupEngine()
        @unknown default:
            break
        }
    }

    // MARK: - Public API

    /// Enable or disable advanced haptics
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: userDefaultsKey)
    }

    /// Check if advanced haptics are available and enabled
    var isAvailable: Bool {
        isSupported && isEnabled
    }

    /// Play an advanced haptic pattern
    func play(_ pattern: AdvancedHapticPattern) {
        guard isAvailable, let engine else {
            // Fallback to basic haptics
            playBasicFallback(for: pattern)
            return
        }

        do {
            let hapticPattern = try createPattern(for: pattern)
            let player = try engine.makePlayer(with: hapticPattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            playBasicFallback(for: pattern)
        }
    }

    /// Play a custom intensity haptic
    func playCustom(intensity: Float, sharpness: Float, duration: TimeInterval = 0.1) {
        guard isAvailable, let engine else {
            HapticManager.light(intensity: CGFloat(intensity))
            return
        }

        do {
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: 0,
                duration: duration,
            )

            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            HapticManager.light(intensity: CGFloat(intensity))
        }
    }

    /// Play velocity-based haptic (intensity scales with speed)
    func playVelocityBased(velocity: CGFloat, maxVelocity: CGFloat = 1000) {
        let normalizedVelocity = min(abs(velocity) / maxVelocity, 1.0)
        let intensity = Float(0.3 + (normalizedVelocity * 0.7))
        let sharpness = Float(0.2 + (normalizedVelocity * 0.6))

        playCustom(intensity: intensity, sharpness: sharpness, duration: 0.05 + (Double(normalizedVelocity) * 0.1))
    }

    // MARK: - Pattern Creation

    private func createPattern(for pattern: AdvancedHapticPattern) throws -> CHHapticPattern {
        switch pattern {
        case .celebration:
            try createCelebrationPattern()
        case .milestone:
            try createMilestonePattern()
        case .unlock:
            try createUnlockPattern()
        case .pullRelease:
            try createPullReleasePattern()
        case .cardFlip:
            try createCardFlipPattern()
        case .messageSent:
            try createMessageSentPattern()
        case .heartPulse:
            try createHeartPulsePattern()
        case .successCheck:
            try createSuccessCheckPattern()
        case .errorShake:
            try createErrorShakePattern()
        case .countdownTick:
            try createCountdownTickPattern()
        case .confettiBurst:
            try createConfettiBurstPattern()
        }
    }

    // MARK: - Pattern Definitions

    private func createCelebrationPattern() throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []

        // Initial burst
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ],
            relativeTime: 0,
        ))

        // Sparkle pattern (multiple light taps)
        for i in 1 ... 6 {
            let intensity = Float(1.0 - (Double(i) * 0.1))
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: TimeInterval(i) * 0.08,
            ))
        }

        return try CHHapticPattern(events: events, parameters: [])
    }

    private func createMilestonePattern() throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []

        // Building anticipation
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ],
            relativeTime: 0,
            duration: 0.2,
        ))

        // Peak moment
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ],
            relativeTime: 0.25,
        ))

        // Resonance
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ],
            relativeTime: 0.3,
            duration: 0.3,
        ))

        return try CHHapticPattern(events: events, parameters: [])
    }

    private func createUnlockPattern() throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []

        // Click (unlocking)
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ],
            relativeTime: 0,
        ))

        // Reveal
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            ],
            relativeTime: 0.1,
            duration: 0.15,
        ))

        // Success confirmation
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ],
            relativeTime: 0.3,
        ))

        return try CHHapticPattern(events: events, parameters: [])
    }

    private func createPullReleasePattern() throws -> CHHapticPattern {
        // Elastic snap back
        try CHHapticPattern(events: [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                ],
                relativeTime: 0,
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0.1,
            )
        ], parameters: [])
    }

    private func createCardFlipPattern() throws -> CHHapticPattern {
        // 3D rotation feel
        try CHHapticPattern(events: [
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0,
                duration: 0.15,
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0.15,
            )
        ], parameters: [])
    }

    private func createMessageSentPattern() throws -> CHHapticPattern {
        // Whoosh feel
        try CHHapticPattern(events: [
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0,
                duration: 0.1,
            )
        ], parameters: [])
    }

    private func createHeartPulsePattern() throws -> CHHapticPattern {
        // Heartbeat double-tap
        try CHHapticPattern(events: [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0,
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0.15,
            )
        ], parameters: [])
    }

    private func createSuccessCheckPattern() throws -> CHHapticPattern {
        // Checkmark drawing feel
        try CHHapticPattern(events: [
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                ],
                relativeTime: 0,
                duration: 0.1,
            ),
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0.1,
                duration: 0.15,
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                ],
                relativeTime: 0.25,
            )
        ], parameters: [])
    }

    private func createErrorShakePattern() throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []

        // Quick back-and-forth shakes
        for i in 0 ..< 3 {
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                ],
                relativeTime: TimeInterval(i) * 0.1,
            ))
        }

        return try CHHapticPattern(events: events, parameters: [])
    }

    private func createCountdownTickPattern() throws -> CHHapticPattern {
        try CHHapticPattern(events: [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0,
            )
        ], parameters: [])
    }

    private func createConfettiBurstPattern() throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []

        // Initial burst
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ],
            relativeTime: 0,
        ))

        // Scatter (random-feeling but deterministic)
        let scatterTimes: [TimeInterval] = [0.05, 0.12, 0.18, 0.25, 0.33, 0.42, 0.5]
        let intensities: [Float] = [0.7, 0.5, 0.6, 0.4, 0.5, 0.3, 0.2]

        for (index, time) in scatterTimes.enumerated() {
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensities[index]),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                ],
                relativeTime: time,
            ))
        }

        return try CHHapticPattern(events: events, parameters: [])
    }

    // MARK: - Fallback

    private func playBasicFallback(for pattern: AdvancedHapticPattern) {
        switch pattern {
        case .celebration, .milestone, .confettiBurst:
            HapticManager.achievement()
        case .unlock, .successCheck:
            HapticManager.success()
        case .pullRelease, .cardFlip:
            HapticManager.medium()
        case .messageSent:
            HapticManager.messageSent()
        case .heartPulse:
            HapticManager.heartbeat()
        case .errorShake:
            HapticManager.error()
        case .countdownTick:
            HapticManager.light()
        }
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    fileprivate func contains(key: String) -> Bool {
        object(forKey: key) != nil
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

/// View modifier for playing haptic on tap
struct AdvancedHapticModifier: ViewModifier {
    let pattern: AdvancedHapticPattern

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                AdvancedHapticEngine.shared.play(pattern)
            }
    }
}

extension View {
    /// Play advanced haptic pattern on tap
    func hapticOnTap(_ pattern: AdvancedHapticPattern) -> some View {
        modifier(AdvancedHapticModifier(pattern: pattern))
    }
}
