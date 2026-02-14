import LocalAuthentication
import FoodShareSecurity
import SwiftUI
import FoodShareSecurity
import FoodShareDesignSystem
import FoodShareSecurity

// MARK: - Glass Biometric Prompt

/// Glass-styled biometric authentication prompt with animated icons
public struct GlassBiometricPrompt: View {

    // MARK: - Properties

    private let customTitle: String?
    private let customSubtitle: String?
    let onAuthenticate: () async throws -> Bool
    let onSuccess: () -> Void
    let onCancel: () -> Void

    @State private var biometryType: BiometryType = .none
    @State private var isAuthenticating = false
    @State private var authState: AuthState = .idle
    @State private var iconScale: CGFloat = 1.0
    @State private var iconOpacity = 1.0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.translationService) private var t

    private enum AuthState {
        case idle
        case authenticating
        case success
        case failure
    }

    /// Localized title - uses translation service if no custom title provided
    private var title: String {
        customTitle ?? t.t("biometric.auth_required")
    }

    /// Localized subtitle - uses translation service if no custom subtitle provided
    private var subtitle: String {
        customSubtitle ?? t.t("biometric.verify_identity")
    }

    // MARK: - Initialization

    public init(
        title: String? = nil,
        subtitle: String? = nil,
        onAuthenticate: @escaping () async throws -> Bool,
        onSuccess: @escaping () -> Void,
        onCancel: @escaping () -> Void,
    ) {
        self.customTitle = title
        self.customSubtitle = subtitle
        self.onAuthenticate = onAuthenticate
        self.onSuccess = onSuccess
        self.onCancel = onCancel
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: Spacing.xl) {
            // Animated biometric icon
            biometricIconView

            // Title and subtitle
            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.DesignSystem.headlineLarge)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.DesignSystem.textPrimary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.DesignSystem.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Action buttons
            VStack(spacing: Spacing.sm) {
                // Authenticate button
                GlassButton(
                    authButtonLabel,
                    icon: biometryType.iconName,
                    style: .primary,
                    isLoading: isAuthenticating,
                ) {
                    authenticate()
                }
                .disabled(isAuthenticating || authState == .success)

                // Cancel button
                Button {
                    HapticManager.shared.impact(.light)
                    onCancel()
                } label: {
                    Text(t.t("common.cancel"))
                        .font(.DesignSystem.bodyMedium)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
                .disabled(isAuthenticating)
            }
        }
        .padding(Spacing.xl)
        .background(glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl))
        .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 15)
        .padding(.horizontal, Spacing.lg)
        .task {
            biometryType = await BiometricAuth.shared.biometryType
        }
    }

    // MARK: - Subviews

    private var biometricIconView: some View {
        ZStack {
            // Outer pulse rings
            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .stroke(iconColor.opacity(0.15 - Double(index) * 0.04), lineWidth: 2)
                    .frame(width: 120 + CGFloat(index) * 20, height: 120 + CGFloat(index) * 20)
                    .scaleEffect(pulseScale)
                    .opacity(authState == .authenticating ? 1 : 0)
            }

            // Glow background
            Circle()
                .fill(iconColor.opacity(glowOpacity * 0.3))
                .frame(width: 100, height: 100)
                .blur(radius: 20)

            // Icon background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            iconColor.opacity(0.3),
                            iconColor.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
                .frame(width: 80, height: 80)

            // Icon
            Image(systemName: currentIconName)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(iconColor)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

            // Success checkmark overlay
            if authState == .success {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(Color.DesignSystem.success)
                    .transition(.scale.combined(with: .opacity))
            }

            // Failure X overlay
            if authState == .failure {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(Color.DesignSystem.error)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: authState)
    }

    private var glassBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )

            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                    lineWidth: 1,
                )
        }
    }

    // MARK: - Computed Properties

    private var currentIconName: String {
        switch authState {
        case .success: "checkmark"
        case .failure: "xmark"
        default: biometryType.iconName
        }
    }

    private var iconColor: Color {
        switch authState {
        case .success: .DesignSystem.success
        case .failure: .DesignSystem.error
        default: .DesignSystem.brandGreen
        }
    }

    private var authButtonLabel: String {
        switch authState {
        case .idle: t.t("biometric.authenticate_with", args: ["type": biometryType.displayName])
        case .authenticating: t.t("common.loading")
        case .success: t.t("common.success")
        case .failure: t.t("common.try_again")
        }
    }

    // MARK: - Actions

    private func authenticate() {
        guard !isAuthenticating else { return }

        isAuthenticating = true
        authState = .authenticating

        // Start animations
        startAuthenticatingAnimation()

        Task {
            do {
                let success = try await onAuthenticate()
                await MainActor.run {
                    if success {
                        authState = .success
                        playSuccessAnimation()

                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(800))
                            onSuccess()
                        }
                    } else {
                        authState = .failure
                        playFailureAnimation()
                    }
                    isAuthenticating = false
                }
            } catch {
                await MainActor.run {
                    authState = .failure
                    playFailureAnimation()
                    isAuthenticating = false
                }
            }
        }
    }

    // MARK: - Animations

    private func startAuthenticatingAnimation() {
        guard !reduceMotion else { return }

        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
            glowOpacity = 0.8
        }

        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            iconScale = 1.1
        }
    }

    private func playSuccessAnimation() {
        HapticManager.shared.notification(.success)

        withAnimation(.interpolatingSpring(stiffness: 400, damping: 15)) {
            iconScale = 1.3
            glowOpacity = 1.0
        }

        withAnimation(.interpolatingSpring(stiffness: 300, damping: 20).delay(0.1)) {
            iconScale = 1.0
        }
    }

    private func playFailureAnimation() {
        HapticManager.shared.notification(.error)

        // Shake animation
        let shakeSequence: [CGFloat] = [0, -10, 10, -8, 8, -5, 5, 0]

        Task { @MainActor in
            for (index, offset) in shakeSequence.enumerated() {
                try? await Task.sleep(for: .milliseconds(50 * UInt64(index)))
                withAnimation(.linear(duration: 0.05)) {
                    // Shake effect would be applied here via offset
                }
            }

            // Reset after delay
            try? await Task.sleep(for: .milliseconds(1500))
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
                authState = .idle
                iconScale = 1.0
                glowOpacity = 0
                pulseScale = 1.0
            }
        }
    }
}

// MARK: - Biometric Prompt Sheet Modifier

/// Shows a biometric prompt as a sheet
public struct BiometricPromptSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let subtitle: String
    let onSuccess: () -> Void

    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                GlassBiometricPrompt(
                    title: title,
                    subtitle: subtitle,
                    onAuthenticate: {
                        try await BiometricAuth.shared.authenticate(reason: subtitle)
                    },
                    onSuccess: {
                        isPresented = false
                        onSuccess()
                    },
                    onCancel: {
                        isPresented = false
                    },
                )
                .presentationDetents([.height(400)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
            }
    }
}

extension View {
    /// Shows a biometric authentication prompt sheet
    public func biometricPrompt(
        isPresented: Binding<Bool>,
        title: String = "Authentication Required",
        subtitle: String = "Verify your identity to continue",
        onSuccess: @escaping () -> Void,
    ) -> some View {
        modifier(BiometricPromptSheetModifier(
            isPresented: isPresented,
            title: title,
            subtitle: subtitle,
            onSuccess: onSuccess,
        ))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.DesignSystem.background
            .ignoresSafeArea()

        GlassBiometricPrompt(
            title: "Confirm Payment",
            subtitle: "Authenticate to complete your purchase",
            onAuthenticate: {
                try? await Task.sleep(for: .seconds(2))
                return true
            },
            onSuccess: { print("Success!") },
            onCancel: { print("Cancelled") },
        )
    }
}
