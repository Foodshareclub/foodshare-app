//
//  TwoFactorAuthView.swift
//  Foodshare
//
//  Two-Factor Authentication management view
//  Uses Liquid Glass Design System v26
//

import SwiftUI
import FoodShareDesignSystem

#if DEBUG
    import Inject
#endif

struct TwoFactorAuthView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.translationService) private var t

    private let mfaService = MFAService.shared

    @State private var showEnrollSheet = false
    @State private var showRemoveConfirmation = false
    @State private var factorToRemove: MFAFactorInfo?

    var body: some View {
        NavigationStack {
            ZStack {
                // Background with gradient orb
                backgroundView

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Status Card
                        statusCard

                        // Actions
                        if mfaService.status == .unenrolled {
                            enableSection
                        } else if mfaService.status == .verified {
                            managementSection
                        } else if mfaService.status == .unverified {
                            completeEnrollmentSection
                        }

                        // Info Section
                        infoSection
                    }
                    .padding(.vertical, Spacing.md)
                }
            }
            .navigationTitle(t.t("settings.two_factor"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t.t("common.done")) {
                        HapticManager.light()
                        dismiss()
                    }
                    .foregroundStyle(Color.DesignSystem.brandGreen)
                }
            }
            .sheet(isPresented: $showEnrollSheet) {
                MFAEnrollmentView()
            }
            .alert(t.t("settings.mfa.remove_title"), isPresented: $showRemoveConfirmation) {
                Button(t.t("common.cancel"), role: .cancel) {}
                Button(t.t("common.remove"), role: .destructive) {
                    if let factor = factorToRemove {
                        Task { try? await mfaService.unenroll(factorId: factor.id) }
                    }
                }
            } message: {
                Text(t.t("settings.mfa.remove_message"))
            }
            .task {
                await mfaService.checkStatus()
            }
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            Color.DesignSystem.background
                .ignoresSafeArea()

            // Gradient orb based on status
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            statusColor.opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 250,
                    ),
                )
                .frame(width: 500, height: 500)
                .blur(radius: 80)
                .offset(y: -200)
                .animation(.interpolatingSpring(stiffness: 200, damping: 20), value: mfaService.status)
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: Spacing.lg) {
            // Glass icon circle
            ZStack {
                // Outer glow
                Circle()
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .blur(radius: 15)

                // Glass circle background
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        statusColor.opacity(0.4),
                                        statusColor.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                                lineWidth: 1.5,
                            ),
                    )
                    .shadow(color: statusColor.opacity(0.2), radius: 10, y: 4)

                Image(systemName: mfaService.status.icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [statusColor, statusColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .symbolEffect(.pulse, options: .repeating, isActive: mfaService.isLoading)
            }

            // Status text
            VStack(spacing: Spacing.xs) {
                Text(statusTitle)
                    .font(.DesignSystem.headlineMedium)
                    .foregroundStyle(Color.DesignSystem.text)

                Text(mfaService.status.description)
                    .font(.DesignSystem.bodySmall)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Progress indicator when loading
            if mfaService.isLoading {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: statusColor))
                    Text(t.t("settings.mfa.checking_status"))
                        .font(.DesignSystem.caption)
                        .foregroundStyle(Color.DesignSystem.textTertiary)
                }
                .padding(.top, Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .fill(Color.white.opacity(0.05))
                .background(.ultraThinMaterial),
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .stroke(
                    LinearGradient(
                        colors: [
                            statusColor.opacity(0.3),
                            statusColor.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                    lineWidth: 1,
                ),
        )
        .shadow(color: statusColor.opacity(0.15), radius: 20, y: 8)
        .padding(.horizontal, Spacing.md)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: mfaService.status)
    }

    private var statusTitle: String {
        switch mfaService.status {
        case .unenrolled: t.t("settings.mfa.status.not_enabled")
        case .unverified: t.t("settings.mfa.status.incomplete")
        case .verified: t.t("settings.mfa.status.enabled")
        case .disabled: t.t("settings.mfa.status.disabled")
        }
    }

    private var statusColor: Color {
        switch mfaService.status {
        case .unenrolled: .DesignSystem.textSecondary
        case .unverified: .DesignSystem.warning
        case .verified: .DesignSystem.brandGreen
        case .disabled: .DesignSystem.error
        }
    }

    private var statusBorderColor: Color {
        switch mfaService.status {
        case .unenrolled: Color.DesignSystem.glassStroke
        case .unverified: Color.DesignSystem.warning.opacity(0.3)
        case .verified: Color.DesignSystem.brandGreen.opacity(0.3)
        case .disabled: Color.DesignSystem.error.opacity(0.3)
        }
    }

    // MARK: - Enable Section

    private var enableSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(icon: "shield.lefthalf.filled", title: t.t("settings.mfa.enable_2fa"))

            Button {
                HapticManager.light()
                showEnrollSheet = true
            } label: {
                HStack(spacing: Spacing.md) {
                    // Glass icon
                    ZStack {
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(Color.DesignSystem.brandGreen.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: "qrcode")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.DesignSystem.brandGreen)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.t("settings.mfa.setup_authenticator"))
                            .font(.DesignSystem.bodyLarge)
                            .foregroundStyle(Color.DesignSystem.text)
                        Text(t.t("settings.mfa.setup_authenticator_desc"))
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.DesignSystem.textTertiary)
                }
                .padding(Spacing.md)
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.98, haptic: .none))
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Color.white.opacity(0.05))
                    .background(.ultraThinMaterial),
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.brandGreen.opacity(0.2),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                        lineWidth: 1,
                    ),
            )
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Complete Enrollment Section

    private var completeEnrollmentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(icon: "exclamationmark.triangle", title: t.t("settings.mfa.complete_setup"))

            Button {
                HapticManager.light()
                showEnrollSheet = true
            } label: {
                HStack(spacing: Spacing.md) {
                    // Glass icon with warning color
                    ZStack {
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(Color.DesignSystem.warning.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.DesignSystem.warning)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.t("settings.mfa.complete_verification"))
                            .font(.DesignSystem.bodyLarge)
                            .foregroundStyle(Color.DesignSystem.text)
                        Text(t.t("settings.mfa.enter_code_hint"))
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.DesignSystem.textTertiary)
                }
                .padding(Spacing.md)
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.98, haptic: .none))
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Color.white.opacity(0.05))
                    .background(.ultraThinMaterial),
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.warning.opacity(0.3),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                        lineWidth: 1,
                    ),
            )
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Management Section

    private var managementSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(icon: "key", title: t.t("settings.mfa.active_factors"))

            VStack(spacing: 0) {
                ForEach(mfaService.factors) { factor in
                    HStack(spacing: Spacing.md) {
                        // Glass icon
                        ZStack {
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(Color.DesignSystem.brandGreen.opacity(0.15))
                                .frame(width: 44, height: 44)

                            Image(systemName: factor.factorType == "totp" ? "lock.shield" : "phone")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Color.DesignSystem.brandGreen)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(factor.friendlyName ?? t.t("settings.mfa.authenticator_app"))
                                .font(.DesignSystem.bodyLarge)
                                .foregroundStyle(Color.DesignSystem.text)

                            HStack(spacing: Spacing.xs) {
                                Circle()
                                    .fill(factor.status == .verified
                                        ? Color.DesignSystem.success
                                        : Color.DesignSystem.warning)
                                        .frame(width: 6, height: 6)
                                Text("\(t.t("settings.mfa.totp")) • \(factor.status == .verified ? t.t("common.active") : t.t("common.pending"))")
                                    .font(.DesignSystem.caption)
                                    .foregroundStyle(Color.DesignSystem.textSecondary)
                            }
                        }

                        Spacer()

                        Button {
                            HapticManager.warning()
                            factorToRemove = factor
                            showRemoveConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.DesignSystem.error)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(Color.DesignSystem.error.opacity(0.1)),
                                )
                        }
                        .buttonStyle(ScaleButtonStyle(scale: 0.9, haptic: .none))
                    }
                    .padding(Spacing.md)

                    if factor.id != mfaService.factors.last?.id {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.clear, Color.white.opacity(0.1), Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing,
                                ),
                            )
                            .frame(height: 1)
                            .padding(.leading, 60)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Color.white.opacity(0.05))
                    .background(.ultraThinMaterial),
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                        lineWidth: 1,
                    ),
            )
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(icon: "info.circle", title: t.t("settings.mfa.about_2fa"))

            VStack(alignment: .leading, spacing: Spacing.md) {
                infoRow(
                    icon: "checkmark.shield",
                    title: t.t("settings.mfa.extra_security"),
                    description: t.t("settings.mfa.extra_security_desc"),
                    iconColor: .DesignSystem.brandGreen,
                )

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color.white.opacity(0.08), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing,
                        ),
                    )
                    .frame(height: 1)

                infoRow(
                    icon: "apps.iphone",
                    title: t.t("settings.mfa.compatible_apps"),
                    description: t.t("settings.mfa.compatible_apps_desc"),
                    iconColor: .DesignSystem.brandBlue,
                )

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color.white.opacity(0.08), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing,
                        ),
                    )
                    .frame(height: 1)

                infoRow(
                    icon: "clock",
                    title: t.t("settings.mfa.time_based"),
                    description: t.t("settings.mfa.time_based_desc"),
                    iconColor: .DesignSystem.brandOrange,
                )
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Color.white.opacity(0.05))
                    .background(.ultraThinMaterial),
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                        lineWidth: 1,
                    ),
            )
        }
        .padding(.horizontal, Spacing.md)
    }

    private func infoRow(icon: String, title: String, description: String, iconColor: Color) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.DesignSystem.bodyLarge)
                    .foregroundStyle(Color.DesignSystem.text)
                Text(description)
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.DesignSystem.caption)
                .foregroundColor(.DesignSystem.textSecondary)
            Text(title)
                .font(.DesignSystem.bodySmall)
                .fontWeight(.semibold)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .padding(.leading, Spacing.xs)
    }
}

// MARK: - Preview

#Preview {
    TwoFactorAuthView()
}
