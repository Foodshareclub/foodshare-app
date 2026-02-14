//
//  AuthView.swift
//  Foodshare
//
//  Unified authentication view with iOS 18+ Liquid Glass effects
//  Uses @Environment for modern @Observable pattern
//  Premium animated mesh background with guest mode as PRIMARY CTA
//

#if !SKIP
import AuthenticationServices
#endif
import FoodShareDesignSystem
import OSLog
import SwiftUI

#if DEBUG
    import Inject
#endif

struct AuthView: View {

    @Environment(\.translationService) private var t
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(GuestManager.self) private var guestManager

    @State private var isSignUp = false
    @State private var confirmPassword = ""
    @State private var showForgotPassword = false
    @State private var breathingPhase: Double = 0
    @State private var hasAppeared = false

    @FocusState private var focusedField: Field?

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "AuthView")

    enum Field {
        case email
        case password
        case confirmPassword
    }

    var body: some View {
        ZStack {
            // iOS 18+ Animated Mesh Gradient Background (Green/Blue Nature)
            AuthBackground(useMeshGradient: true, style: .nature)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    Spacer()
                        .frame(height: Spacing.xxl)

                    // Logo Section with entrance animation
                    logoSection
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : -20)

                    // Features Section (compact) with staggered animation
                    featuresSection
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 15)

                    // Guest Mode - PRIMARY CTA
                    guestModeSection
                        .opacity(hasAppeared ? 1 : 0)
                        .scaleEffect(hasAppeared ? 1 : 0.95)

                    // Divider
                    signInDivider
                        .opacity(hasAppeared ? 1 : 0)

                    // Login Form with slide-in effect
                    loginFormSection
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)

                    // Action Buttons
                    actionButtonsSection
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 15)

                    // Toggle Sign In/Sign Up
                    toggleModeSection
                        .opacity(hasAppeared ? 1 : 0)

                    Spacer()
                        .frame(height: Spacing.xl)
                }
                .padding(.horizontal, Spacing.md + Spacing.xxxs)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Staggered entrance animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                hasAppeared = true
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet()
                .environment(authViewModel)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(CornerRadius.xl)
        }
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        VStack(spacing: Spacing.sm) {
            // Logo with animated breathing glow effect
            ZStack {
                // Animated glow behind logo - breathing effect (Foodshare Pink brand)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.DesignSystem.brandPink.opacity(0.5 + 0.15 * sin(breathingPhase)),
                                Color.DesignSystem.brandPink.opacity(0.25 + 0.1 * sin(breathingPhase)),
                                Color.DesignSystem.brandTeal.opacity(0.1 + 0.05 * sin(breathingPhase)),
                                Color.clear,
                            ],
                            center: .center,
                            startRadius: 35,
                            endRadius: 95 + 10 * sin(breathingPhase),
                        ),
                    )
                    .frame(width: 150 + 10 * sin(breathingPhase), height: 150 + 10 * sin(breathingPhase))
                    .blur(radius: 25 + 5 * sin(breathingPhase))

                // App logo with subtle scale animation (circular for auth screens)
                AppLogoView(size: .large, showGlow: false, circular: true)
                    .scaleEffect(1.0 + 0.02 * sin(breathingPhase))
                    .offset(y: -2 * sin(breathingPhase))
            }
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 3.0)
                        .repeatForever(autoreverses: false),
                ) {
                    breathingPhase = .pi * 2
                }
            }

            VStack(spacing: Spacing.xxs) {
                Text(t.t("app.name"))
                    .font(.DesignSystem.headlineLarge)
                    .foregroundColor(.white)
                    .shadow(color: Color.DesignSystem.brandPink.opacity(0.4), radius: 4, x: 0, y: 2)

                Text(t.t("auth.tagline"))
                    .font(.DesignSystem.bodyLarge)
                    .foregroundColor(.white.opacity(0.75))
            }
        }
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        HStack(spacing: Spacing.md) {
            AuthFeatureIcon(icon: "square.and.arrow.up.fill", label: t.t("auth.feature.share"))
            AuthFeatureIcon(icon: "person.2.fill", label: t.t("auth.feature.connect"))
            AuthFeatureIcon(icon: "leaf.fill", label: t.t("auth.feature.impact"))
        }
    }

    // MARK: - Sign In Divider

    private var signInDivider: some View {
        HStack(spacing: Spacing.xs) {
            Rectangle()
                .fill(Color.DesignSystem.glassBorder)
                .frame(height: 1)

            Text(t.t("auth.or_sign_in"))
                .font(.DesignSystem.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, Spacing.xxs)

            Rectangle()
                .fill(Color.DesignSystem.glassBorder)
                .frame(height: 1)
        }
    }

    // MARK: - Login Form Section

    private var loginFormSection: some View {
        @Bindable var viewModel = authViewModel
        return VStack(spacing: Spacing.sm) {
            // Email Field
            AuthGlassTextField(
                placeholder: t.t("common.email"),
                text: $viewModel.email,
                icon: "envelope.fill",
                keyboardType: .emailAddress,
                isFocused: focusedField == .email,
            )
            .focused($focusedField, equals: .email)
            .submitLabel(.next)
            .onSubmit {
                focusedField = .password
            }

            // Password Field
            AuthGlassSecureField(
                placeholder: t.t("auth.password"),
                text: $viewModel.password,
                icon: "lock.fill",
                isFocused: focusedField == .password,
            )
            .focused($focusedField, equals: .password)
            .submitLabel(isSignUp ? .next : .done)
            .onSubmit {
                if isSignUp {
                    focusedField = .confirmPassword
                } else {
                    performAuth()
                }
            }

            // Confirm Password (Sign Up only)
            if isSignUp {
                AuthGlassSecureField(
                    placeholder: t.t("auth.confirm_password"),
                    text: $confirmPassword,
                    icon: "lock.fill",
                    isFocused: focusedField == .confirmPassword,
                )
                .focused($focusedField, equals: .confirmPassword)
                .submitLabel(.done)
                .onSubmit {
                    performAuth()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Forgot Password (Sign In only)
            if !isSignUp {
                HStack {
                    Spacer()
                    GlassButton(t.t("auth.forgot_password"), style: .ghost) {
                        showForgotPassword = true
                    }
                }
            }

            // Error Message
            if let error = authViewModel.errorMessage {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.DesignSystem.bodyLarge)
                        .foregroundColor(Color.DesignSystem.error)

                    Text(error)
                        .font(.DesignSystem.caption)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(Color.DesignSystem.error.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .stroke(Color.DesignSystem.error.opacity(0.4), lineWidth: 1),
                        ),
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSignUp)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: authViewModel.errorMessage != nil)
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(spacing: Spacing.sm) {
            // Primary Action Button (Glass style)
            GlassButton(
                isSignUp ? t.t("auth.create_account") : t.t("auth.sign_in_email"),
                icon: isSignUp ? "person.badge.plus.fill" : "arrow.right.circle.fill",
                style: .secondary,
                isLoading: authViewModel.isLoading,
            ) {
                performAuth()
            }
            .disabled(authViewModel.isLoading || !isFormValid)
            .opacity(authViewModel.isLoading ? 0.5 : (!isFormValid ? 0.55 : 1.0))

            // OAuth Buttons (only for sign in)
            if !isSignUp {
                oauthButtonsSection
            }
        }
    }

    // MARK: - Guest Mode Section (PRIMARY CTA)

    private var guestModeSection: some View {
        VStack(spacing: Spacing.xs) {
            // Try as Guest Button - PRIMARY (Foodshare Pink brand)
            GlassButton(t.t("auth.try_as_guest"), icon: "play.circle.fill", style: .pinkTeal) {
                guestManager.enableGuestMode()
            }

            // Guest mode info
            Text(t.t("auth.guest_info"))
                .font(.DesignSystem.caption)
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - OAuth Buttons

    private var oauthButtonsSection: some View {
        VStack(spacing: Spacing.xs) {
            // Apple Sign In Button
            Button(action: signInWithApple) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "apple.logo")
                        .font(.DesignSystem.titleLarge)

                    Text(t.t("auth.continue_apple"))
                        .font(.DesignSystem.titleMedium)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .fill(Color.black)

                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.DesignSystem.glassBackground,
                                        Color.clear,
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom,
                                ),
                            )
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.DesignSystem.glassHighlight,
                                        Color.DesignSystem.glassBorder,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                                lineWidth: 1.5,
                            ),
                    ),
                )
                .shadow(color: Color.black.opacity(0.6), radius: Spacing.xs, x: 0, y: Spacing.xxs)
            }
            .buttonStyle(ScaleButtonStyle())

            // Google Button
            Button(action: signInWithGoogle) {
                HStack(spacing: Spacing.xs) {
                    Text("G")
                        .font(.DesignSystem.titleLarge)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.26, green: 0.52, blue: 0.96),
                                    Color(red: 0.92, green: 0.25, blue: 0.21),
                                    Color(red: 0.96, green: 0.73, blue: 0.0),
                                    Color(red: 0.2, green: 0.66, blue: 0.33),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )

                    Text(t.t("auth.continue_google"))
                        .font(.DesignSystem.titleMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .fill(Color.white)

                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.DesignSystem.glassBackground,
                                        Color.clear,
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom,
                                ),
                            )
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.gray.opacity(0.3),
                                        Color.gray.opacity(0.15),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                                lineWidth: 1.5,
                            ),
                    ),
                )
                .shadow(color: Color.gray.opacity(0.3), radius: Spacing.xs, x: 0, y: Spacing.xxs)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    // MARK: - Toggle Mode Section

    private var toggleModeSection: some View {
        HStack(spacing: Spacing.xxs) {
            Text(isSignUp ? t.t("auth.already_have_account") : t.t("auth.no_account"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.white.opacity(0.7))

            GlassButton(isSignUp ? t.t("auth.sign_in") : t.t("auth.sign_up"), style: .ghost) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isSignUp.toggle()
                    authViewModel.errorMessage = nil
                    if !isSignUp {
                        confirmPassword = ""
                    }
                }
            }
        }
    }

    // MARK: - Form Validation

    private var isFormValid: Bool {
        let emailValid = !authViewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let passwordValid = !authViewModel.password.isEmpty

        if isSignUp {
            return emailValid && passwordValid && !confirmPassword.isEmpty && authViewModel.password == confirmPassword
        } else {
            return emailValid && passwordValid
        }
    }

    // MARK: - Actions

    private func performAuth() {
        guard isFormValid else { return }

        focusedField = nil

        Task {
            if isSignUp {
                await authViewModel.signUpEmail()
            } else {
                await authViewModel.signInEmail()
            }
        }
    }

    private func signInWithApple() {
        Task {
            await authViewModel.signInWithApple()
        }
    }

    private func signInWithGoogle() {
        logger.info("🔐 [AuthView] Google sign-in button tapped")
        Task {
            do {
                logger.info("🔐 [AuthView] Calling AuthenticationService.signInWithGoogle()")
                try await AuthenticationService.shared.signInWithGoogle()
                logger.info("✅ [AuthView] Google sign-in completed successfully")
                authViewModel.clearError()
            } catch {
                logger.error("❌ [AuthView] Google sign-in failed: \(error.localizedDescription)")

                // Check if user cancelled - handle silently
                if let authError = error as? ASWebAuthenticationSessionError,
                   authError.code == .canceledLogin
                {
                    logger.info("[AUTH] Google Sign In cancelled by user")
                    authViewModel.clearError() // Clear any previous errors
                    return
                }

                // Check for cancellation in error description
                let errorDesc = error.localizedDescription.lowercased()
                if errorDesc.contains("cancel") || errorDesc.contains("user") {
                    logger.info("[AUTH] OAuth cancelled by user")
                    authViewModel.clearError()
                    return
                }

                // Parse error for user-friendly message
                let parsedError = AppAuthError.from(supabaseError: error)
                authViewModel.errorMessage = parsedError.errorDescription
                logger.error("[AUTH] Google Sign In failed: \(error.localizedDescription)")
                HapticManager.error()
            }
        }
    }
}

// MARK: - Auth Glass Text Field

private struct AuthGlassTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    var keyboardType: UIKeyboardType = .default
    let isFocused: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.DesignSystem.bodyLarge)
                .foregroundStyle(
                    LinearGradient(
                        colors: isFocused
                            ? [Color.DesignSystem.brandPink, Color.DesignSystem.brandTeal]
                            : [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.4),
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
                .frame(width: 26)
                .animation(.interpolatingSpring(stiffness: 300, damping: 24), value: isFocused)

            TextField(placeholder, text: $text)
                .font(.DesignSystem.bodyLarge)
                .foregroundColor(.white)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .sentences)
                .autocorrectionDisabled(keyboardType == .emailAddress)
                .tint(Color.DesignSystem.brandPink)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(isFocused ? Color.DesignSystem.glassSurface : Color.DesignSystem.glassBackground)

                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.05), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom,
                        ),
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(
                        LinearGradient(
                            colors: isFocused
                                ? [
                                    Color.DesignSystem.brandPink.opacity(0.6),
                                    Color.DesignSystem.brandTeal.opacity(0.4),
                                ]
                                : [Color.DesignSystem.glassBorder, Color.DesignSystem.glassBackground],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                        lineWidth: isFocused ? 2 : 1.5,
                    ),
            ),
        )
        .shadow(
            color: isFocused ? Color.DesignSystem.brandPink.opacity(0.3) : Color.black.opacity(0.1),
            radius: isFocused ? Spacing.xs : Spacing.xxs,
            x: 0,
            y: isFocused ? Spacing.xxs : 3,
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isFocused)
    }
}

// MARK: - Auth Glass Secure Field

private struct AuthGlassSecureField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    let isFocused: Bool

    @State private var isPasswordVisible = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.DesignSystem.bodyLarge)
                .foregroundStyle(
                    LinearGradient(
                        colors: isFocused
                            ? [Color.DesignSystem.brandPink, Color.DesignSystem.brandTeal]
                            : [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.4),
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
                .frame(width: 26)
                .animation(.interpolatingSpring(stiffness: 300, damping: 24), value: isFocused)

            if isPasswordVisible {
                TextField(placeholder, text: $text)
                    .font(.DesignSystem.bodyLarge)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .tint(Color.DesignSystem.brandPink)
            } else {
                SecureField(placeholder, text: $text)
                    .font(.DesignSystem.bodyLarge)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .tint(Color.DesignSystem.brandPink)
            }

            Button(action: {
                withAnimation(.interpolatingSpring(stiffness: 400, damping: 20)) {
                    isPasswordVisible.toggle()
                }
            }) {
                Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.white.opacity(isFocused ? 0.65 : 0.5))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(isFocused ? Color.DesignSystem.glassSurface : Color.DesignSystem.glassBackground)

                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(
                        LinearGradient(
                            colors: [Color.DesignSystem.glassHighlight, Color.clear],
                            startPoint: .top,
                            endPoint: .bottom,
                        ),
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(
                        LinearGradient(
                            colors: isFocused
                                ? [
                                    Color.DesignSystem.brandPink.opacity(0.6),
                                    Color.DesignSystem.brandTeal.opacity(0.4),
                                ]
                                : [Color.DesignSystem.glassBorder, Color.DesignSystem.glassBackground],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                        lineWidth: isFocused ? 2 : 1.5,
                    ),
            ),
        )
        .shadow(
            color: isFocused ? Color.DesignSystem.brandPink.opacity(0.3) : Color.black.opacity(0.1),
            radius: isFocused ? Spacing.xs : Spacing.xxs,
            x: 0,
            y: isFocused ? Spacing.xxs : 3,
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isFocused)
    }
}

// MARK: - Auth Feature Icon Component

private struct AuthFeatureIcon: View {
    let icon: String
    let label: String

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            ZStack {
                // Animated glow behind icon
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.DesignSystem.brandPink.opacity(isAnimating ? 0.3 : 0.15),
                                Color.clear,
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 30,
                        ),
                    )
                    .frame(width: 60, height: 60)
                    .blur(radius: 8)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.DesignSystem.brandPink, Color.DesignSystem.brandTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.DesignSystem.glassHighlight,
                                                Color.DesignSystem.glassBorder.opacity(0.5),
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing,
                                        ),
                                        lineWidth: 1,
                                    ),
                            ),
                    )
                    .shadow(color: Color.DesignSystem.brandPink.opacity(0.2), radius: 8, y: 4)
            }

            Text(label)
                .font(.DesignSystem.labelSmall)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.8))
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true),
            ) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AuthView()
        .environment(AuthViewModel(supabase: .init(
            supabaseURL: URL(string: "https://api.foodshare.club")!,
            supabaseKey: "example-key",
        )))
        .environment(GuestManager())
}
