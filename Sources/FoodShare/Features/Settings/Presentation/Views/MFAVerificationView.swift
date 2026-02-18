//
//  MFAVerificationView.swift
//  Foodshare
//
//  MFA verification view shown during login when 2FA is enabled
//  Uses Liquid Glass Design System v26
//


#if !SKIP
import SwiftUI



struct MFAVerificationView: View {
    
    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.translationService) private var t

    private let mfaService = MFAService.shared

    @State private var verificationCode = ""
    @State private var error: String?
    @State private var isVerified = false
    @State private var showSuccessAnimation = false

    let onSuccess: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundView

                VStack(spacing: Spacing.lg) {
                    Spacer()

                    // Icon and title
                    headerSection

                    Spacer()

                    // Code input
                    codeInputSection

                    Spacer()

                    // Actions
                    actionsSection
                }
                .padding(.horizontal, Spacing.md)

                // Success overlay
                if showSuccessAnimation {
                    successOverlay
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t.t("common.cancel")) {
                        HapticManager.light()
                        onCancel()
                    }
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                }
            }
            .onAppear {
                isInputFocused = true
            }
        }
    }

    @FocusState private var isInputFocused: Bool

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            Color.DesignSystem.background
                .ignoresSafeArea()

            // Subtle gradient orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.DesignSystem.brandGreen.opacity(0.15),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200,
                    ),
                )
                .frame(width: 400.0, height: 400)
                .blur(radius: 60)
                .offset(y: -100)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            // Animated shield icon
            ZStack {
                // Outer glow
                Circle()
                    .fill(Color.DesignSystem.brandGreen.opacity(0.1))
                    .frame(width: 120.0, height: 120)
                    .blur(radius: 20)

                // Glass circle background
                Circle()
                    #if !SKIP
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .frame(width: 100.0, height: 100)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                                lineWidth: 1,
                            ),
                    )

                Image(systemName: "lock.shield")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.brandGreen,
                                Color.DesignSystem.brandGreen.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    #if !SKIP
                    .symbolEffect(.pulse, options: .repeating, isActive: mfaService.isLoading)
                    #endif
            }

            Text(t.t("settings.two_factor"))
                .font(.DesignSystem.headlineLarge)
                .foregroundStyle(Color.DesignSystem.text)

            Text(t.t("settings.mfa.enter_code_desc"))
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Code Input Section

    private var codeInputSection: some View {
        VStack(spacing: Spacing.lg) {
            // 6-digit code display with glass styling
            HStack(spacing: Spacing.sm) {
                ForEach(0 ..< 6, id: \.self) { index in
                    codeDigitBox(at: index)
                }
            }
            .onTapGesture {
                isInputFocused = true
            }

            // Hidden text field for input
            TextField("", text: $verificationCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .frame(width: 1.0, height: 1)
                .opacity(0.01)
                .focused($isInputFocused)
                .onChange(of: verificationCode) { _, newValue in
                    let filtered = newValue.filter({ $0 >= "0" && $0 <= "9" })
                    if filtered.count > 6 {
                        verificationCode = String(filtered.prefix(6))
                    } else {
                        verificationCode = filtered
                    }
                    if filtered.count == 6 {
                        Task { await verifyCode() }
                    }
                }

            // Timer hint
            HStack(spacing: Spacing.xs) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                Text(t.t("settings.mfa.code_refresh"))
                    .font(.DesignSystem.captionSmall)
            }
            .foregroundStyle(Color.DesignSystem.textTertiary)

            // Error message with glass styling
            if let error {
                errorMessageView(error)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity,
                    ))
            }
        }
    }

    // MARK: - Code Digit Box

    private func codeDigitBox(at index: Int) -> some View {
        let digit = index < verificationCode.count
            ? String(verificationCode[verificationCode.index(verificationCode.startIndex, offsetBy: index)])
            : ""
        let isFocused = index == verificationCode.count && isInputFocused
        let hasDigit = !digit.isEmpty

        return ZStack {
            // Glass background
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(
                    hasDigit
                        ? Color.DesignSystem.brandGreen.opacity(0.08)
                        : Color.white.opacity(0.05),
                )
                #if !SKIP
                .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .background(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))

            // Border
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(
                    isFocused
                        ? Color.DesignSystem.brandGreen
                        : hasDigit
                            ? Color.DesignSystem.brandGreen.opacity(0.3)
                            : Color.white.opacity(0.12),
                    lineWidth: isFocused ? 2 : 1,
                )

            // Digit
            Text(digit)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.DesignSystem.text)
                #if !SKIP
                .contentTransition(.numericText())
                #endif

            // Cursor animation
            if isFocused, digit.isEmpty {
                Rectangle()
                    .fill(Color.DesignSystem.brandGreen)
                    .frame(width: 2.0, height: 28)
                    .opacity(cursorOpacity)
                    .animation(.easeInOut(duration: 0.5).repeatForever(), value: cursorOpacity)
                    .onAppear { cursorOpacity = 0.3 }
            }
        }
        .frame(width: 48.0, height: 60)
        .shadow(
            color: isFocused ? Color.DesignSystem.brandGreen.opacity(0.2) : Color.clear,
            radius: 8,
            y: 2,
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hasDigit)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }

    @State private var cursorOpacity = 1.0

    // MARK: - Error Message

    private func errorMessageView(_ message: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 16))
            Text(message)
                .font(.DesignSystem.bodySmall)
        }
        .foregroundStyle(Color.DesignSystem.error)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.DesignSystem.error.opacity(0.1))
                #if !SKIP
                .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .background(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(Color.DesignSystem.error.opacity(0.2), lineWidth: 1),
        )
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: Spacing.md) {
            GlassButton(
                mfaService.isLoading ? t.t("settings.mfa.verifying") : t.t("settings.mfa.verify"),
                icon: mfaService.isLoading ? nil : "checkmark.shield",
                style: .primary,
                isLoading: mfaService.isLoading,
            ) {
                Task { await verifyCode() }
            }
            .disabled(verificationCode.count != 6 || mfaService.isLoading)

            Button {
                HapticManager.light()
                onCancel()
            } label: {
                Text(t.t("settings.mfa.use_different_account"))
                    .font(.DesignSystem.bodySmall)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }
            .padding(.bottom, Spacing.lg)
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.DesignSystem.background
                .opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(Color.DesignSystem.success.opacity(0.15))
                        .frame(width: 120.0, height: 120)

                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.DesignSystem.success)
                        #if !SKIP
                        .symbolEffect(.bounce, value: showSuccessAnimation)
                        #endif
                }

                Text(t.t("settings.mfa.verified"))
                    .font(.DesignSystem.headlineLarge)
                    .foregroundStyle(Color.DesignSystem.text)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Actions

    private func verifyCode() async {
        error = nil

        do {
            try await mfaService.challengeAndVerify(code: verificationCode)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showSuccessAnimation = true
            }
            HapticManager.success()
            try? await Task.sleep(nanoseconds: 800_000_000)
            onSuccess()
        } catch {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.error = error.localizedDescription
            }
            verificationCode = ""
            HapticManager.error()
        }
    }
}

// MARK: - Preview

#Preview {
    MFAVerificationView(
        onSuccess: { print("Success") },
        onCancel: { print("Cancel") },
    )
}

#endif
