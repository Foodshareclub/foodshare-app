//
//  ScreenRecordingWarningView.swift
//  Foodshare
//
//  Warning banner shown when screen recording is detected
//



#if !SKIP
import SwiftUI

struct ScreenRecordingWarningBanner: View {
    @Environment(\.translationService) private var t
    @Binding var isVisible: Bool

    var body: some View {
        if isVisible {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "record.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    #if !SKIP
                    .symbolEffect(.pulse)
                    #endif

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
            #if !SKIP
            .safeAreaInset(edge: VerticalEdge.top) {
                ScreenRecordingWarningBanner(isVisible: $showWarning)
            }
            #else
            .overlay(alignment: Alignment.top) {
                ScreenRecordingWarningBanner(isVisible: $showWarning)
            }
            #endif
            .onAppear {
                showWarning = privacyService.isScreenRecording && privacyService.screenRecordingWarningEnabled
            }
            #if !SKIP
            .onReceive(NotificationCenter.default.publisher(for: .screenRecordingDetected)) { _ in
                withAnimation {
                    showWarning = true
                }
            }
            #endif
    }
}

extension View {
    func screenRecordingWarning() -> some View {
        modifier(ScreenRecordingAlertModifier())
    }
}


#endif
