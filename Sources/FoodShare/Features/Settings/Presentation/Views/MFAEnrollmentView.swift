//
//  MFAEnrollmentView.swift
//  Foodshare
//
//  MFA enrollment flow with QR code and verification
//  Uses Liquid Glass Design System v26
//

import CoreImage.CIFilterBuiltins
import SwiftUI
import FoodShareDesignSystem



struct MFAEnrollmentView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.translationService) private var t

    private let mfaService = MFAService.shared

    @State private var verificationCode = ""
    @State private var enrollment: MFAEnrollmentResult?
    @State private var error: String?
    @State private var currentStep: EnrollmentStep = .loading
    @State private var showSecretKey = false

    enum EnrollmentStep {
        case loading
        case scanQR
        case verify
        case success
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background with animated gradient
                backgroundView

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Progress indicator
                        progressIndicator

                        // Content based on step
                        switch currentStep {
                        case .loading:
                            loadingView
                        case .scanQR:
                            scanQRView
                        case .verify:
                            verifyView
                        case .success:
                            successView
                        }

                        // Error display
                        if let error {
                            errorBanner(message: error)
                        }
                    }
                    .padding(.vertical, Spacing.md)
                }
            }
            .navigationTitle(t.t("settings.mfa.setup_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t.t("common.cancel")) {
                        HapticManager.light()
                        mfaService.cancelEnrollment()
                        dismiss()
                    }
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                }

                if currentStep == .scanQR {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(t.t("common.next")) {
                            HapticManager.light()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentStep = .verify
                            }
                        }
                        .foregroundStyle(Color.DesignSystem.brandGreen)
                    }
                }
            }
            .interactiveDismissDisabled(currentStep == .verify)
            .task {
                await startEnrollment()
            }
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            Color.DesignSystem.background
                .ignoresSafeArea()

            // Gradient orb that changes based on step
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            stepColor.opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 250,
                    ),
                )
                .frame(width: 500, height: 500)
                .blur(radius: 80)
                .offset(y: -150)
                .animation(.interpolatingSpring(stiffness: 200, damping: 20), value: currentStep)
        }
    }

    private var stepColor: Color {
        switch currentStep {
        case .loading: Color.DesignSystem.brandBlue
        case .scanQR: Color.DesignSystem.brandGreen
        case .verify: Color.DesignSystem.brandOrange
        case .success: Color.DesignSystem.success
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: Spacing.md) {
            ForEach(0 ..< 3) { index in
                progressStep(
                    index: index,
                    icon: stepIcon(for: index),
                    label: stepLabel(for: index),
                )

                if index < 2 {
                    // Connecting line
                    Rectangle()
                        .fill(
                            index < currentStepIndex
                                ? Color.DesignSystem.brandGreen
                                : Color.white.opacity(0.1),
                        )
                        .frame(height: 2)
                        .frame(maxWidth: 40)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    private func progressStep(index: Int, icon: String, label: String) -> some View {
        let isCompleted = index < currentStepIndex
        let isCurrent = index == currentStepIndex

        return VStack(spacing: Spacing.xs) {
            ZStack {
                Circle()
                    .fill(
                        isCompleted
                            ? Color.DesignSystem.brandGreen
                            : isCurrent
                                ? stepColor.opacity(0.2)
                                : Color.white.opacity(0.08),
                    )
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(
                                isCompleted
                                    ? Color.DesignSystem.brandGreen
                                    : isCurrent
                                        ? stepColor
                                        : Color.white.opacity(0.1),
                                lineWidth: isCurrent ? 2 : 1,
                            ),
                    )
                    .shadow(
                        color: isCurrent ? stepColor.opacity(0.3) : Color.clear,
                        radius: 6,
                        y: 2,
                    )

                Image(systemName: isCompleted ? "checkmark" : icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        isCompleted
                            ? Color.DesignSystem.contrastText
                            : isCurrent
                                ? stepColor
                                : Color.DesignSystem.textTertiary,
                    )
            }

            Text(label)
                .font(.DesignSystem.captionSmall)
                .foregroundStyle(
                    isCurrent
                        ? Color.DesignSystem.text
                        : Color.DesignSystem.textTertiary,
                )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
    }

    private var currentStepIndex: Int {
        switch currentStep {
        case .loading: 0
        case .scanQR: 1
        case .verify: 2
        case .success: 3
        }
    }

    private func stepIcon(for index: Int) -> String {
        switch index {
        case 0: "key"
        case 1: "qrcode"
        case 2: "checkmark.shield"
        default: ""
        }
    }

    private func stepLabel(for index: Int) -> String {
        switch index {
        case 0: t.t("settings.mfa.step_setup")
        case 1: t.t("settings.mfa.step_scan")
        case 2: t.t("settings.mfa.step_verify")
        default: ""
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Glass loading indicator
            ZStack {
                // Outer glow
                Circle()
                    .fill(Color.DesignSystem.brandBlue.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)

                // Glass circle
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
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

                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .DesignSystem.brandBlue))
            }

            VStack(spacing: Spacing.sm) {
                Text(t.t("settings.mfa.generating_key"))
                    .font(.DesignSystem.headlineSmall)
                    .foregroundStyle(Color.DesignSystem.text)

                Text(t.t("settings.mfa.generating_key_desc"))
                    .font(.DesignSystem.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            Spacer()
        }
        .padding(Spacing.xl)
    }

    // MARK: - Scan QR View

    private var scanQRView: some View {
        VStack(spacing: Spacing.lg) {
            // Glass header
            VStack(spacing: Spacing.md) {
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(Color.DesignSystem.brandGreen.opacity(0.1))
                        .frame(width: 100, height: 100)
                        .blur(radius: 15)

                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.DesignSystem.brandGreen.opacity(0.4),
                                            Color.DesignSystem.brandGreen.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing,
                                    ),
                                    lineWidth: 1,
                                ),
                        )

                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 36, weight: .medium))
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
                }

                Text(t.t("settings.mfa.scan_qr_title"))
                    .font(.DesignSystem.headlineLarge)
                    .foregroundStyle(Color.DesignSystem.text)

                Text(t.t("settings.mfa.scan_qr_desc"))
                    .font(.DesignSystem.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.md)
            }

            // QR Code with glass frame
            if let enrollment {
                ZStack {
                    // Glass container for QR
                    RoundedRectangle(cornerRadius: CornerRadius.xl)
                        .fill(Color.white)
                        .frame(width: 240, height: 240)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.xl)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.DesignSystem.brandGreen.opacity(0.3),
                                            Color.white.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing,
                                    ),
                                    lineWidth: 3,
                                ),
                        )
                        .shadow(color: Color.DesignSystem.brandGreen.opacity(0.2), radius: 20, y: 8)

                    qrCodeImage(from: enrollment.qrCode)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                }

                // Manual entry option
                manualEntrySection(secret: enrollment.secret)
            }

            // Continue button
            GlassButton(t.t("settings.mfa.scanned_code"), icon: "arrow.right", style: .primary) {
                HapticManager.light()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    currentStep = .verify
                }
            }
            .padding(.horizontal, Spacing.md)
        }
        .padding(.horizontal, Spacing.md)
    }

    private func manualEntrySection(secret: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Button {
                HapticManager.light()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showSecretKey.toggle()
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text(t.t("settings.mfa.cant_scan"))
                        .font(.DesignSystem.bodySmall)
                        .foregroundStyle(Color.DesignSystem.brandGreen)
                    Image(systemName: showSecretKey ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.DesignSystem.brandGreen)
                        .rotationEffect(.degrees(showSecretKey ? 0 : 0))
                }
            }

            if showSecretKey {
                VStack(spacing: Spacing.sm) {
                    Text(t.t("settings.mfa.secret_key"))
                        .font(.DesignSystem.captionSmall)
                        .foregroundStyle(Color.DesignSystem.textSecondary)

                    HStack {
                        Text(secret)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Color.DesignSystem.text)
                            .textSelection(.enabled)

                        Spacer()

                        Button {
                            UIPasteboard.general.string = secret
                            HapticManager.success()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.DesignSystem.brandGreen)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(Color.DesignSystem.brandGreen.opacity(0.1)),
                                )
                        }
                        .buttonStyle(ScaleButtonStyle(scale: 0.9, haptic: .none))
                    }
                    .padding(Spacing.md)
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
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity,
                ))
            }
        }
        .padding(.top, Spacing.md)
    }

    @FocusState private var isCodeFocused: Bool
    @State private var cursorOpacity = 1.0

    // MARK: - Verify View

    private var verifyView: some View {
        VStack(spacing: Spacing.lg) {
            // Glass header
            VStack(spacing: Spacing.md) {
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(Color.DesignSystem.brandOrange.opacity(0.1))
                        .frame(width: 100, height: 100)
                        .blur(radius: 15)

                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.DesignSystem.brandOrange.opacity(0.4),
                                            Color.DesignSystem.brandOrange.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing,
                                    ),
                                    lineWidth: 1,
                                ),
                        )

                    Image(systemName: "lock.shield")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.brandOrange,
                                    Color.DesignSystem.brandOrange.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .symbolEffect(.pulse, options: .repeating, isActive: mfaService.isLoading)
                }

                Text(t.t("settings.mfa.enter_code_title"))
                    .font(.DesignSystem.headlineLarge)
                    .foregroundStyle(Color.DesignSystem.text)

                Text(t.t("settings.mfa.enter_code_desc"))
                    .font(.DesignSystem.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.md)
            }

            // 6-digit code display with glass styling
            VStack(spacing: Spacing.lg) {
                HStack(spacing: Spacing.sm) {
                    ForEach(0 ..< 6, id: \.self) { index in
                        codeDigitBox(at: index)
                    }
                }
                .onTapGesture {
                    isCodeFocused = true
                }

                // Hidden text field for input
                TextField("", text: $verificationCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .focused($isCodeFocused)
                    .onChange(of: verificationCode) { _, newValue in
                        let filtered = newValue.filter(\.isNumber)
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
            }

            // Verify button
            GlassButton(
                mfaService.isLoading ? t.t("settings.mfa.verifying") : t.t("settings.mfa.verify"),
                icon: mfaService.isLoading ? nil : "checkmark.shield",
                style: .primary,
                isLoading: mfaService.isLoading,
            ) {
                Task { await verifyCode() }
            }
            .disabled(verificationCode.count != 6 || mfaService.isLoading)
            .padding(.horizontal, Spacing.md)

            // Back button
            Button {
                HapticManager.light()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    currentStep = .scanQR
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text(t.t("settings.mfa.back_to_qr"))
                }
                .font(.DesignSystem.bodySmall)
                .foregroundStyle(Color.DesignSystem.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.md)
        .onAppear {
            isCodeFocused = true
        }
    }

    // MARK: - Code Digit Box

    private func codeDigitBox(at index: Int) -> some View {
        let digit = index < verificationCode.count
            ? String(verificationCode[verificationCode.index(verificationCode.startIndex, offsetBy: index)])
            : ""
        let isFocused = index == verificationCode.count && isCodeFocused
        let hasDigit = !digit.isEmpty

        return ZStack {
            // Glass background
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(
                    hasDigit
                        ? Color.DesignSystem.brandOrange.opacity(0.08)
                        : Color.white.opacity(0.05),
                )
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))

            // Border
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(
                    isFocused
                        ? Color.DesignSystem.brandOrange
                        : hasDigit
                            ? Color.DesignSystem.brandOrange.opacity(0.3)
                            : Color.white.opacity(0.12),
                    lineWidth: isFocused ? 2 : 1,
                )

            // Digit
            Text(digit)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.DesignSystem.text)
                .contentTransition(.numericText())

            // Cursor animation
            if isFocused, digit.isEmpty {
                Rectangle()
                    .fill(Color.DesignSystem.brandOrange)
                    .frame(width: 2, height: 28)
                    .opacity(cursorOpacity)
                    .animation(.easeInOut(duration: 0.5).repeatForever(), value: cursorOpacity)
                    .onAppear { cursorOpacity = 0.3 }
            }
        }
        .frame(width: 48, height: 60)
        .shadow(
            color: isFocused ? Color.DesignSystem.brandOrange.opacity(0.2) : Color.clear,
            radius: 8,
            y: 2,
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hasDigit)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Glass success indicator
            ZStack {
                // Outer glow
                Circle()
                    .fill(Color.DesignSystem.success.opacity(0.15))
                    .frame(width: 140, height: 140)
                    .blur(radius: 25)

                // Glass circle
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.DesignSystem.success.opacity(0.5),
                                        Color.DesignSystem.success.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                                lineWidth: 2,
                            ),
                    )
                    .shadow(color: Color.DesignSystem.success.opacity(0.3), radius: 15, y: 5)

                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.success,
                                Color.DesignSystem.success.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .modifier(BounceSymbolEffectModifier())
            }

            VStack(spacing: Spacing.sm) {
                Text(t.t("settings.mfa.enabled_title"))
                    .font(.DesignSystem.headlineLarge)
                    .foregroundStyle(Color.DesignSystem.text)

                Text(t.t("settings.mfa.enabled_desc"))
                    .font(.DesignSystem.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }

            Spacer()

            GlassButton(t.t("common.done"), icon: "checkmark", style: .primary) {
                HapticManager.success()
                dismiss()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.lg)
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Error Banner

    private func errorBanner(message: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.DesignSystem.error)

            Text(message)
                .font(.DesignSystem.bodySmall)
                .foregroundStyle(Color.DesignSystem.error)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    error = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.DesignSystem.error)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(Color.DesignSystem.error.opacity(0.15)),
                    )
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(Color.DesignSystem.error.opacity(0.1))
                .background(.ultraThinMaterial),
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(Color.DesignSystem.error.opacity(0.2), lineWidth: 1),
        )
        .padding(.horizontal, Spacing.md)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity,
        ))
    }

    // MARK: - QR Code Generation

    private func qrCodeImage(from svgString: String) -> Image {
        // The Supabase SDK returns an SVG string for the QR code
        // We need to generate our own QR code from the URI instead
        if let enrollment, let qrImage = generateQRCode(from: enrollment.uri) {
            return Image(uiImage: qrImage)
        }
        return Image(systemName: "qrcode")
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        guard let data = string.data(using: .utf8) else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        // Scale up the QR code for better display
        let scale = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: scale)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Actions

    private func startEnrollment() async {
        error = nil
        do {
            enrollment = try await mfaService.enroll()
            withAnimation { currentStep = .scanQR }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func verifyCode() async {
        guard let enrollment else { return }
        error = nil

        do {
            try await mfaService.verify(factorId: enrollment.factorId, code: verificationCode)
            withAnimation { currentStep = .success }
        } catch {
            self.error = error.localizedDescription
            verificationCode = ""
        }
    }
}

// MARK: - Bounce Symbol Effect Modifier

/// Applies bounce symbol effect on iOS 18+, no-op on iOS 17
private struct BounceSymbolEffectModifier: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .symbolEffect(.bounce, value: isAnimating)
                .onAppear { isAnimating = true }
        } else {
            // Fallback: simple scale animation
            content
                .scaleEffect(isAnimating ? 1.0 : 0.8)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isAnimating)
                .onAppear { isAnimating = true }
        }
    }
}

// MARK: - Preview

#Preview {
    MFAEnrollmentView()
}
