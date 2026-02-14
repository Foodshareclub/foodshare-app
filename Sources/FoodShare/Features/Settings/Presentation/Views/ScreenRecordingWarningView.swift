//
//  ScreenRecordingWarningView.swift
//  Foodshare
//
//  Warning banner shown when screen recording is detected
//

import SwiftUI
import FoodShareDesignSystem

struct ScreenRecordingWarningBanner: View {
    @Environment(\.translationService) private var t
    @Binding var isVisible: Bool

    var body: some View {
        if isVisible {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "record.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse)

                Text(t.t("settings.privacy.recording_active"))
                    .font(.DesignSystem.labelMedium)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    withAnimation {
                        isVisible = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.DesignSystem.error)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Screen Recording Alert Modifier

struct ScreenRecordingAlertModifier: ViewModifier {
    @State private var showWarning = false

    private let privacyService = PrivacyProtectionService.shared

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top) {
                ScreenRecordingWarningBanner(isVisible: $showWarning)
            }
            .onAppear {
                showWarning = privacyService.isScreenRecording && privacyService.screenRecordingWarningEnabled
            }
            .onReceive(NotificationCenter.default.publisher(for: .screenRecordingDetected)) { _ in
                withAnimation {
                    showWarning = true
                }
            }
    }
}

extension View {
    func screenRecordingWarning() -> some View {
        modifier(ScreenRecordingAlertModifier())
    }
}
