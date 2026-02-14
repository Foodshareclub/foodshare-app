//
//  SecurityScoreView.swift
//  Foodshare
//
//  Security score card and detailed security settings view
//  Shows account protection level with actionable recommendations
//

import SwiftUI
import FoodShareSecurity
import FoodShareDesignSystem
import FoodShareSecurity



// MARK: - Security Score Card (Compact)

struct SecurityScoreCard: View {
    
    @Environment(\.translationService) private var t
    @State private var score: Int = 0
    @State private var level: SecurityScoreLevel = .low
    @State private var animateProgress = false

    private let scoreService = SecurityScoreService.shared

    var body: some View {
        NavigationLink {
            SecurityDetailView()
        } label: {
            HStack(spacing: Spacing.md) {
                // Score circle
                ZStack {
                    Circle()
                        .stroke(Color.DesignSystem.glassBackground, lineWidth: 6)
                        .frame(width: 56, height: 56)

                    Circle()
                        .trim(from: 0, to: animateProgress ? CGFloat(score) / 100 : 0)
                        .stroke(
                            level.color,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))

                    Text("\(score)")
                        .font(.DesignSystem.headlineSmall)
                        .fontWeight(.bold)
                        .foregroundStyle(level.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: level.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(level.color)

                        Text(t.t("settings.security.score"))
                            .font(.DesignSystem.labelLarge)
                            .foregroundStyle(Color.DesignSystem.text)
                    }

                    Text(level.displayName)
                        .font(.DesignSystem.caption)
                        .foregroundStyle(level.color)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.DesignSystem.textTertiary)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(level.color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            refreshScore()
        }
        #if !SKIP
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshScore()
        }
        #endif
    }

    private func refreshScore() {
        score = scoreService.calculateScore()
        level = scoreService.getSecurityLevel()

        withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
            animateProgress = true
        }
    }
}

// MARK: - Security Detail View

struct SecurityDetailView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.translationService) private var t
    @State private var score: Int = 0
    @State private var level: SecurityScoreLevel = .low
    @State private var checks: [SecurityCheckItem] = []
    @State private var showBiometricSetup = false
    @State private var animateProgress = false

    private let scoreService = SecurityScoreService.shared
    private let biometricService = BiometricAuth.shared
    private let privacyService = PrivacyProtectionService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Score header
                scoreHeader

                // Recommendation
                if level != .high {
                    recommendationCard
                }

                // Security checks
                securityChecksList
            }
            .padding(Spacing.md)
        }
        .background(Color.DesignSystem.background)
        .navigationTitle(t.t("settings.security._title"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            refreshData()
        }
        .sheet(isPresented: $showBiometricSetup) {
            BiometricSetupPromptView(
                onEnable: {
                    showBiometricSetup = false
                    refreshData()
                },
                onSkip: {
                    showBiometricSetup = false
                }
            )
        }
    }

    // MARK: - Score Header

    private var scoreHeader: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.DesignSystem.glassBackground, lineWidth: 12)
                    .frame(width: 140, height: 140)

                // Progress circle
                Circle()
                    .trim(from: 0, to: animateProgress ? CGFloat(score) / 100 : 0)
                    .stroke(
                        level.color,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))

                // Score text
                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(level.color)

                    Text(t.t("settings.security.out_of_100"))
                        .font(.DesignSystem.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
            }

            VStack(spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: level.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(level.color)

                    Text(level.displayName + " " + t.t("settings.security._title"))
                        .font(.DesignSystem.headlineMedium)
                        .foregroundStyle(Color.DesignSystem.text)
                }

                Text(t.t("settings.security.protections_enabled", args: ["enabled": "\(checks.filter { $0.isEnabled }.count)", "total": "\(checks.count)"]))
                    .font(.DesignSystem.bodySmall)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.xl)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Recommendation Card

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.DesignSystem.accentYellow)

                Text(t.t("settings.security.recommendation"))
                    .font(.DesignSystem.labelLarge)
                    .foregroundStyle(Color.DesignSystem.text)
            }

            Text(level.recommendation)
                .font(.DesignSystem.bodySmall)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(Color.DesignSystem.accentYellow.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.accentYellow.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Security Checks List

    private var securityChecksList: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(t.t("settings.security.features"))
                .font(.DesignSystem.headlineSmall)
                .foregroundStyle(Color.DesignSystem.text)
                .padding(.horizontal, Spacing.sm)

            VStack(spacing: 1) {
                ForEach(checks) { check in
                    SecurityCheckRow(
                        check: check,
                        onAction: { handleAction(check.action) }
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Actions

    private func refreshData() {
        score = scoreService.calculateScore()
        level = scoreService.getSecurityLevel()
        checks = scoreService.getSecurityChecks()

        withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
            animateProgress = true
        }
    }

    private func handleAction(_ action: SecurityCheckItem.SecurityAction?) {
        guard let action else { return }

        switch action {
        case .enableBiometrics:
            showBiometricSetup = true

        case .verifyEmail:
            // Navigate to email verification
            break

        case .enablePrivacyBlur:
            privacyService.privacyBlurEnabled = true
            refreshData()
            HapticManager.success()

        case .enableScreenRecordingWarning:
            privacyService.screenRecordingWarningEnabled = true
            refreshData()
            HapticManager.success()

        case .setSessionTimeout:
            privacyService.sessionTimeoutDuration = SessionTimeoutOption.twentyFourHours.duration
            refreshData()
            HapticManager.success()

        case .enableClipboardClear:
            privacyService.clipboardAutoClearEnabled = true
            refreshData()
            HapticManager.success()

        case .enableSensitiveActionProtection:
            biometricService.requireBiometricForSensitiveActions = true
            refreshData()
            HapticManager.success()
        }
    }
}

// MARK: - Security Check Row

struct SecurityCheckRow: View {
    @Environment(\.translationService) private var t
    let check: SecurityCheckItem
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(check.isEnabled
                          ? Color.DesignSystem.brandGreen.opacity(0.15)
                          : Color.DesignSystem.textTertiary.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: check.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(check.isEnabled
                                     ? Color.DesignSystem.brandGreen
                                     : Color.DesignSystem.textTertiary)
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(check.title)
                    .font(.DesignSystem.labelLarge)
                    .foregroundStyle(Color.DesignSystem.text)

                Text(check.description)
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            // Status / Action
            if check.isEnabled {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.DesignSystem.brandGreen)
            } else if check.action != nil {
                Button {
                    onAction()
                } label: {
                    Text(t.t("common.enable"))
                        .font(.DesignSystem.labelSmall)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.DesignSystem.brandGreen)
                        .cornerRadius(CornerRadius.small)
                }
            }
        }
        .padding(Spacing.md)
        .contentShape(Rectangle())
    }
}

// MARK: - Biometric Setup Onboarding Card

struct BiometricSetupOnboardingCard: View {
    @Environment(\.translationService) private var t
    let onSetup: () -> Void
    let onDismiss: () -> Void

    private let biometricService = BiometricAuth.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: biometricService.availableBiometricType.iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.DesignSystem.textTertiary)
                }
            }

            Text(t.t("settings.security.secure_account"))
                .font(.DesignSystem.headlineSmall)
                .foregroundStyle(Color.DesignSystem.text)

            Text(t.t("settings.security.enable_biometric_desc", args: ["type": biometricService.availableBiometricType.displayName]))
                .font(.DesignSystem.bodySmall)
                .foregroundStyle(Color.DesignSystem.textSecondary)

            Button {
                onSetup()
            } label: {
                Text(t.t("settings.security.setup_now"))
                    .font(.DesignSystem.labelMedium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandTeal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(CornerRadius.medium)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(
                            LinearGradient(
                                colors: [.DesignSystem.brandGreen.opacity(0.5), .DesignSystem.brandTeal.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

#Preview {
    NavigationStack {
        SecurityDetailView()
    }
}
