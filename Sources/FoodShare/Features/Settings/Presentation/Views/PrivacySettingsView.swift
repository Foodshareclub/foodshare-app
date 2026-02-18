//
//  PrivacySettingsView.swift
//  Foodshare
//
//  Advanced privacy settings view
//  Controls for privacy blur, clipboard, session timeout, etc.
//



#if !SKIP
import SwiftUI



struct PrivacySettingsView: View {
    
    @Environment(\.translationService) private var t
    @State private var privacyBlurEnabled: Bool
    @State private var screenRecordingWarning: Bool
    @State private var clipboardAutoClear: Bool
    @State private var selectedTimeout: SessionTimeoutOption

    private let privacyService = PrivacyProtectionService.shared

    init() {
        let service = PrivacyProtectionService.shared
        _privacyBlurEnabled = State(initialValue: service.privacyBlurEnabled)
        _screenRecordingWarning = State(initialValue: service.screenRecordingWarningEnabled)
        _clipboardAutoClear = State(initialValue: service.clipboardAutoClearEnabled)

        // Find matching timeout option
        let currentTimeout = service.sessionTimeoutDuration
        let matchingOption = SessionTimeoutOption.allCases.first {
            abs($0.duration - currentTimeout) < 1
        } ?? SessionTimeoutOption.twentyFourHours
        _selectedTimeout = State(initialValue: matchingOption)
    }

    var body: some View {
        List {
            // Privacy Screen Section
            Section {
                Toggle(isOn: $privacyBlurEnabled) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.t("settings.privacy.screen"))
                                .font(.DesignSystem.bodyMedium)
                            Text(t.t("settings.privacy.screen_desc"))
                                .font(.DesignSystem.caption)
                                .foregroundStyle(Color.DesignSystem.textSecondary)
                        }
                    } icon: {
                        Image(systemName: "eye.slash.fill")
                            .foregroundStyle(Color.DesignSystem.brandGreen)
                    }
                }
                .tint(.DesignSystem.brandGreen)
                .onChange(of: privacyBlurEnabled) { _, newValue in
                    privacyService.privacyBlurEnabled = newValue
                    HapticManager.light()
                }
            } header: {
                Text(t.t("settings.privacy.app_privacy"))
            } footer: {
                Text(t.t("settings.privacy.screen_footer"))
            }

            // Screen Recording Section
            Section {
                Toggle(isOn: $screenRecordingWarning) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.t("settings.privacy.recording_alert"))
                                .font(.DesignSystem.bodyMedium)
                            Text(t.t("settings.privacy.recording_alert_desc"))
                                .font(.DesignSystem.caption)
                                .foregroundStyle(Color.DesignSystem.textSecondary)
                        }
                    } icon: {
                        Image(systemName: "record.circle")
                            .foregroundStyle(Color.DesignSystem.error)
                    }
                }
                .tint(.DesignSystem.brandGreen)
                .onChange(of: screenRecordingWarning) { _, newValue in
                    privacyService.screenRecordingWarningEnabled = newValue
                    HapticManager.light()
                }
            } header: {
                Text(t.t("settings.privacy.screen_recording"))
            } footer: {
                Text(t.t("settings.privacy.recording_footer"))
            }

            // Clipboard Section
            Section {
                Toggle(isOn: $clipboardAutoClear) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.t("settings.privacy.auto_clear_clipboard"))
                                .font(.DesignSystem.bodyMedium)
                            Text(t.t("settings.privacy.auto_clear_desc"))
                                .font(.DesignSystem.caption)
                                .foregroundStyle(Color.DesignSystem.textSecondary)
                        }
                    } icon: {
                        Image(systemName: "doc.on.clipboard")
                            .foregroundStyle(Color.DesignSystem.brandTeal)
                    }
                }
                .tint(.DesignSystem.brandGreen)
                .onChange(of: clipboardAutoClear) { _, newValue in
                    privacyService.clipboardAutoClearEnabled = newValue
                    HapticManager.light()
                }

                if clipboardAutoClear {
                    Button {
                        privacyService.clearClipboard()
                        HapticManager.success()
                    } label: {
                        Label(t.t("settings.privacy.clear_clipboard_now"), systemImage: "trash")
                            .foregroundStyle(Color.DesignSystem.error)
                    }
                }
            } header: {
                Text(t.t("settings.privacy.clipboard"))
            } footer: {
                Text(t.t("settings.privacy.clipboard_footer"))
            }

            // Session Timeout Section
            Section {
                Picker(selection: $selectedTimeout) {
                    ForEach(SessionTimeoutOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                } label: {
                    Label {
                        Text(t.t("settings.privacy.session_timeout"))
                            .font(.DesignSystem.bodyMedium)
                    } icon: {
                        Image(systemName: "timer")
                            .foregroundStyle(Color.DesignSystem.brandBlue)
                    }
                }
                .onChange(of: selectedTimeout) { _, newValue in
                    privacyService.sessionTimeoutDuration = newValue.duration
                    HapticManager.light()
                }
            } header: {
                Text(t.t("settings.session"))
            } footer: {
                Text(t.t("settings.privacy.session_footer"))
            }
        }
        .navigationTitle(t.t("settings.privacy._title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PrivacySettingsView()
    }
}


#endif
