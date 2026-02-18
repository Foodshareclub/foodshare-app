//
//  AccessibilitySettingsView.swift
//  Foodshare
//
//  Settings view for accessibility options
//


#if !SKIP
import SwiftUI

struct AccessibilitySettingsView: View {
    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.translationService) private var t

    // Accessibility settings
    @AppStorage("reduce_animations") private var reduceAnimations = false
    @AppStorage("high_contrast") private var highContrast = false
    @AppStorage("larger_text") private var largerText = false
    @AppStorage("button_shapes") private var buttonShapes = false
    @AppStorage("increase_contrast") private var increaseContrast = false

    // System accessibility state
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion: Bool
    @Environment(\.accessibilityDifferentiateWithoutColor) private var systemDifferentiateWithoutColor: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Header
                headerSection

                // Visual settings
                visualSettingsSection

                // Motion settings
                motionSettingsSection

                // System settings link
                systemSettingsSection

                // Info section
                infoSection
            }
            .padding(Spacing.md)
        }
        .background(Color.DesignSystem.background)
        .navigationTitle(t.t("accessibility"))
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.DesignSystem.brandTeal, .DesignSystem.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80.0, height: 80)

                Image(systemName: "accessibility")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
            }

            Text(t.t("accessibility"))
                .font(.DesignSystem.headlineMedium)
                .foregroundStyle(Color.DesignSystem.text)

            Text(t.t("accessibility_description"))
                .font(.DesignSystem.bodySmall)
                .foregroundStyle(Color.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Visual Settings Section

    private var visualSettingsSection: some View {
        GlassSettingsSection(title: t.t("visual"), icon: "eye.fill") {
            // High contrast
            VStack(alignment: .leading, spacing: Spacing.xs) {
                GlassSettingsToggle(
                    icon: "circle.lefthalf.filled.inverse",
                    iconColor: .DesignSystem.brandBlue,
                    title: t.t("high_contrast"),
                    isOn: $highContrast
                )
                #if !SKIP
                .sensoryFeedback(.selection, trigger: highContrast)
                #endif

                Text(t.t("high_contrast_description"))
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textTertiary)
                    .padding(.leading, 28 + Spacing.md)
                    .padding(.trailing, Spacing.md)
                    .padding(.bottom, Spacing.xs)
            }

            // Larger text
            VStack(alignment: .leading, spacing: Spacing.xs) {
                GlassSettingsToggle(
                    icon: "textformat.size.larger",
                    iconColor: .DesignSystem.brandGreen,
                    title: t.t("larger_text"),
                    isOn: $largerText
                )
                #if !SKIP
                .sensoryFeedback(.selection, trigger: largerText)
                #endif

                Text(t.t("larger_text_description"))
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textTertiary)
                    .padding(.leading, 28 + Spacing.md)
                    .padding(.trailing, Spacing.md)
                    .padding(.bottom, Spacing.xs)
            }

            // Button shapes
            VStack(alignment: .leading, spacing: Spacing.xs) {
                GlassSettingsToggle(
                    icon: "rectangle.on.rectangle",
                    iconColor: .DesignSystem.accentOrange,
                    title: t.t("button_shapes"),
                    isOn: $buttonShapes
                )
                #if !SKIP
                .sensoryFeedback(.selection, trigger: buttonShapes)
                #endif

                Text(t.t("button_shapes_description"))
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textTertiary)
                    .padding(.leading, 28 + Spacing.md)
                    .padding(.trailing, Spacing.md)
                    .padding(.bottom, Spacing.xs)
            }

            // Increase contrast
            VStack(alignment: .leading, spacing: Spacing.xs) {
                GlassSettingsToggle(
                    icon: "sun.max.fill",
                    iconColor: .DesignSystem.accentPurple,
                    title: t.t("increase_contrast"),
                    isOn: $increaseContrast
                )
                #if !SKIP
                .sensoryFeedback(.selection, trigger: increaseContrast)
                #endif

                Text(t.t("increase_contrast_description"))
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textTertiary)
                    .padding(.leading, 28 + Spacing.md)
                    .padding(.trailing, Spacing.md)
                    .padding(.bottom, Spacing.xs)
            }
        }
    }

    // MARK: - Motion Settings Section

    private var motionSettingsSection: some View {
        GlassSettingsSection(title: t.t("motion"), icon: "figure.walk.motion") {
            // Reduce animations
            VStack(alignment: .leading, spacing: Spacing.xs) {
                GlassSettingsToggle(
                    icon: "sparkles",
                    iconColor: .DesignSystem.brandTeal,
                    title: t.t("reduce_animations"),
                    isOn: $reduceAnimations
                )
                #if !SKIP
                .sensoryFeedback(.selection, trigger: reduceAnimations)
                #endif

                Text(t.t("reduce_animations_description"))
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textTertiary)
                    .padding(.leading, 28 + Spacing.md)
                    .padding(.trailing, Spacing.md)
                    .padding(.bottom, Spacing.xs)
            }

            // System reduce motion status
            if systemReduceMotion {
                systemSettingIndicator(
                    icon: "checkmark.circle.fill",
                    color: .DesignSystem.success,
                    text: t.t("system_reduce_motion_enabled")
                )
            }
        }
    }

    // MARK: - System Settings Section

    private var systemSettingsSection: some View {
        GlassSettingsSection(title: t.t("system_settings"), icon: "gear") {
            Button {
                openSystemAccessibilitySettings()
            } label: {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "gear")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.DesignSystem.brandBlue)
                        .frame(width: 28.0)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.t("system_accessibility_settings"))
                            .font(.DesignSystem.bodyMedium)
                            .foregroundStyle(Color.DesignSystem.text)

                        Text(t.t("system_accessibility_description"))
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.DesignSystem.textTertiary)
                }
                .padding(Spacing.md)
                #if !SKIP
                .contentShape(Rectangle())
                #endif
            }
            .buttonStyle(.plain)

            // Current system status
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(t.t("current_system_settings"))
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .padding(.horizontal, Spacing.md)

                VStack(spacing: Spacing.xs) {
                    systemStatusRow(
                        title: t.t("reduce_motion"),
                        isEnabled: systemReduceMotion
                    )

                    systemStatusRow(
                        title: t.t("differentiate_without_color"),
                        isEnabled: systemDifferentiateWithoutColor
                    )
                }
            }
            .padding(.bottom, Spacing.sm)
        }
    }

    private func systemStatusRow(title: String, isEnabled: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(isEnabled ? Color.DesignSystem.success : Color.DesignSystem.textTertiary)
                .frame(width: 8.0, height: 8)

            Text(title)
                .font(.DesignSystem.caption)
                .foregroundStyle(Color.DesignSystem.textSecondary)

            Spacer()

            Text(isEnabled ? t.t("on") : t.t("off"))
                .font(.DesignSystem.caption)
                .foregroundStyle(isEnabled ? Color.DesignSystem.success : Color.DesignSystem.textTertiary)
        }
        .padding(.horizontal, Spacing.md)
    }

    private func systemSettingIndicator(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)

            Text(text)
                .font(.DesignSystem.caption)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                Text(t.t("accessibility_info_title"))
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            Text(t.t("accessibility_info_description"))
                .font(.DesignSystem.caption)
                .foregroundStyle(Color.DesignSystem.textTertiary)
                #if !SKIP
                .fixedSize(horizontal: false, vertical: true)
                #endif
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.DesignSystem.brandTeal.opacity(0.1))
        )
    }

    // MARK: - Actions

    private func openSystemAccessibilitySettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    NavigationStack {
        AccessibilitySettingsView()
    }
}

#endif
