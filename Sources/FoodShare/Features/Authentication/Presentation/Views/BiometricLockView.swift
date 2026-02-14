//
//  BiometricLockView.swift
//  Foodshare
//
//  Enterprise-grade lock screen with biometric authentication
//  Features: Failed attempt tracking, lockout display, Liquid Glass design
//

import SwiftUI
import FoodShareSecurity
import FoodShareDesignSystem
import FoodShareSecurity



struct BiometricLockView: View {
    
    @Environment(\.translationService) private var t
    let onUnlock: () -> Void
    let onUsePassword: () -> Void

    @State private var isAuthenticating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var pulseAnimation = false
    @State private var shakeOffset: CGFloat = 0

    private let biometricService = BiometricAuth.shared

    var body: some View {
        ZStack {
            // Background
            Color.DesignSystem.background
                .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()

                // App Logo
                Image("AppIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .DesignSystem.brandGreen.opacity(0.3), radius: 20)

                Text(t.t("common.app_name"))
                    .font(.DesignSystem.displaySmall)
                    .foregroundStyle(Color.DesignSystem.text)

                Text(t.t("biometric.locked"))
                    .font(.DesignSystem.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)

                // Failed attempts indicator
                if biometricService.failedAttempts > 0 && !biometricService.isLockedOut {
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { index in
                            Circle()
                                .fill(index < biometricService.failedAttempts
                                      ? Color.DesignSystem.error
                                      : Color.DesignSystem.textTertiary.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.top, Spacing.sm)
                }

                Spacer()

                // Lockout message or biometric button
                if biometricService.isLockedOut, let endTime = biometricService.lockoutEndTime {
                    lockoutView(endTime: endTime)
                } else {
                    biometricButton
                }

                // Use Password Option
                GlassButton(t.t("biometric.sign_in_with_password"), icon: "key.fill", style: .ghost) {
                    onUsePassword()
                }
                .padding(.top, Spacing.md)

                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(Spacing.lg)
        }
        .alert(t.t("auth.authentication_failed"), isPresented: $showError) {
            Button(t.t("common.try_again")) {
                authenticate()
            }
            Button(t.t("biometric.use_password"), role: .cancel) {
                onUsePassword()
            }
        } message: {
            Text(errorMessage)
        }
        .task {
            // Auto-trigger authentication on appear (if not locked out)
            if !biometricService.isLockedOut {
                try? await Task.sleep(for: .milliseconds(300))
                authenticate()
            }
        }
    }

    // MARK: - Lockout View

    private func lockoutView(endTime: Date) -> some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.DesignSystem.error.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "lock.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Color.DesignSystem.error)
            }

            Text(t.t("biometric.too_many_attempts"))
                .font(.DesignSystem.headlineSmall)
                .foregroundStyle(Color.DesignSystem.text)

            Text(t.t("biometric.try_again_at", args: ["time": endTime.formatted(date: .omitted, time: .shortened)]))
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
    }

    // MARK: - Biometric Button

    private var biometricButton: some View {
        Button {
            authenticate()
        } label: {
            VStack(spacing: Spacing.md) {
                ZStack {
                    // Pulse animation
                    Circle()
                        .fill(Color.DesignSystem.brandGreen.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .opacity(pulseAnimation ? 0 : 0.5)

                    // Main circle
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandTeal],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )

                    // Icon
                    if isAuthenticating {
                        ProgressView()
                            .tint(.DesignSystem.brandGreen)
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: biometricService.availableBiometricType.iconName)
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.DesignSystem.brandGreen, .DesignSystem.brandTeal],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                .offset(x: shakeOffset)

                Text(t.t("biometric.tap_to_unlock"))
                    .font(.DesignSystem.labelMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }
        }
        .disabled(isAuthenticating)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulseAnimation = true
            }
        }
    }

    // MARK: - Authentication

    private func authenticate() {
        guard !isAuthenticating else { return }

        isAuthenticating = true

        Task {
            do {
                let success = try await biometricService.authenticate(reason: t.t("biometric.unlock_reason"))

                await MainActor.run {
                    isAuthenticating = false
                    if success {
                        HapticManager.success()
                        onUnlock()
                    }
                }
            } catch let error as BiometricError {
                await MainActor.run {
                    isAuthenticating = false

                    switch error {
                    case .cancelled:
                        // User cancelled, don't show error
                        break
                    case .tooManyAttempts:
                        // Lockout triggered, UI will update automatically
                        triggerShake()
                        HapticManager.error()
                    case .biometricChanged:
                        // Biometric changed, force re-auth
                        errorMessage = error.localizedDescription
                        showError = true
                        HapticManager.error()
                    case .jailbreakDetected:
                        // Security issue
                        errorMessage = error.localizedDescription
                        showError = true
                        HapticManager.error()
                    default:
                        triggerShake()
                        errorMessage = error.localizedDescription
                        showError = true
                        HapticManager.error()
                    }
                }
            } catch {
                await MainActor.run {
                    isAuthenticating = false
                    triggerShake()
                    errorMessage = error.localizedDescription
                    showError = true
                    HapticManager.error()
                }
            }
        }
    }

    private func triggerShake() {
        withAnimation(.default) {
            shakeOffset = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.default) {
                shakeOffset = -10
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.default) {
                shakeOffset = 5
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.default) {
                shakeOffset = 0
            }
        }
    }
}

#Preview {
    BiometricLockView(
        onUnlock: {},
        onUsePassword: {}
    )
}
