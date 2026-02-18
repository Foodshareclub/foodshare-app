//
//  BiometricSetupPromptView.swift
//  Foodshare
//
//  Prompt shown after first login to encourage biometric setup
//  Enterprise-grade onboarding with Liquid Glass design
//


#if !SKIP
import SwiftUI

#if DEBUG
    import Inject
#endif

struct BiometricSetupPromptView: View {
    
    @Environment(\.translationService) private var t
    let onEnable: () async -> Void
    let onSkip: () -> Void

    @State private var isEnabling = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var animateIcon = false

    private let biometricService = BiometricAuth.shared

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Icon with animation
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.brandGreen.opacity(0.2),
                                Color.DesignSystem.brandTeal.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .frame(width: 140.0, height: 140)
                    .scaleEffect(animateIcon ? 1.1 : 1.0)

                Circle()
                    #if !SKIP
                    .fill(.ultraThinMaterial)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .frame(width: 100.0, height: 100)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.DesignSystem.brandGreen, .DesignSystem.brandTeal],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                                lineWidth: 2,
                            ),
                    )

                Image(systemName: biometricService.availableBiometricType.iconName)
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    animateIcon = true
                }
            }

            // Title
            VStack(spacing: Spacing.sm) {
                Text(t.t("biometric.secure_your_account"))
                    .font(.DesignSystem.displaySmall)
                    .foregroundStyle(Color.DesignSystem.text)
                    .multilineTextAlignment(.center)

                Text(
                    t.t("biometric.enable_description", args: ["type": biometricService.availableBiometricType.displayName]),
                )
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
            }

            // Benefits
            VStack(alignment: .leading, spacing: Spacing.md) {
                benefitRow(icon: "bolt.fill", text: t.t("biometric.benefit.instant_unlock"))
                benefitRow(icon: "lock.shield.fill", text: t.t("biometric.benefit.bank_level_security"))
                benefitRow(icon: "hand.raised.fill", text: t.t("biometric.benefit.protect_sensitive_actions"))
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    #if !SKIP
                    .fill(.ultraThinMaterial)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                    ),
            )
            .padding(.horizontal, Spacing.lg)

            Spacer()

            // Buttons
            VStack(spacing: Spacing.md) {
                GlassButton(
                    "Enable \(biometricService.availableBiometricType.displayName)",
                    icon: biometricService.availableBiometricType.iconName,
                    style: .primary,
                    isLoading: isEnabling,
                ) {
                    enableBiometrics()
                }
                .disabled(isEnabling)

                GlassButton(t.t("common.maybe_later"), style: .ghost) {
                    onSkip()
                }
                .padding(.top, Spacing.xs)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
        .background(Color.DesignSystem.background.ignoresSafeArea())
        .alert(t.t("auth.setup_failed"), isPresented: $showError) {
            Button(t.t("common.try_again")) {
                enableBiometrics()
            }
            Button(t.t("common.skip"), role: .cancel) {
                onSkip()
            }
        } message: {
            Text(errorMessage)
        }
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.DesignSystem.brandGreen)
                .frame(width: 24.0)

            Text(text)
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.text)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.DesignSystem.brandGreen.opacity(0.5))
        }
    }

    private func enableBiometrics() {
        isEnabling = true

        Task { @MainActor in
            do {
                try await biometricService.enableBiometrics()
                isEnabling = false
                HapticManager.success()
                await onEnable()
            } catch let error as BiometricError {
                isEnabling = false
                errorMessage = error.localizedDescription
                showError = true
                HapticManager.error()
            } catch {
                isEnabling = false
                errorMessage = error.localizedDescription
                showError = true
                HapticManager.error()
            }
        }
    }
}

#Preview {
    BiometricSetupPromptView(
        onEnable: {},
        onSkip: {},
    )
}

#endif
