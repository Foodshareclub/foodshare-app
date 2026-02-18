//
//  LoginSecurityView.swift
//  Foodshare
//
//  View for managing login and security settings
//


#if !SKIP
import SwiftUI

#if DEBUG
    import Inject
#endif

struct LoginSecurityView: View {
    
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.translationService) private var t

    private let mfaService = MFAService.shared

    @State private var showChangePassword = false
    @State private var showTwoFactorAuth = false
    @State private var showSignOutConfirmation = false
    @State private var isSigningOut = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Account Info
                    accountInfoSection

                    // Password Section
                    passwordSection

                    // Two-Factor Authentication
                    twoFactorSection

                    // Sign Out
                    signOutSection
                }
                .padding(.vertical, Spacing.md)
            }
            .background(Color.DesignSystem.background)
            .navigationTitle(t.t("settings.login_security"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t.t("common.done")) { dismiss() }
                }
            }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView()
            }
            .sheet(isPresented: $showTwoFactorAuth) {
                TwoFactorAuthView()
            }
            .alert(t.t("settings.sign_out"), isPresented: $showSignOutConfirmation) {
                Button(t.t("common.cancel"), role: .cancel) {}
                Button(t.t("settings.sign_out"), role: .destructive) {
                    Task { await signOut() }
                }
            } message: {
                Text(t.t("settings.sign_out_confirm"))
            }
            .task {
                await mfaService.checkStatus()
            }
        }
    }

    // MARK: - Account Info Section

    private var accountInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(icon: "person.circle", title: t.t("settings.account"))

            VStack(spacing: 0) {
                // Email
                HStack(spacing: Spacing.md) {
                    Image(systemName: "envelope")
                        .font(.DesignSystem.bodyMedium)
                        .foregroundColor(.white)
                        .frame(width: 32.0, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.small)
                                .fill(Color.DesignSystem.brandBlue.gradient),
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.t("settings.email"))
                            .font(.DesignSystem.captionSmall)
                            .foregroundColor(.DesignSystem.textSecondary)
                        Text(appState.currentUser?.email ?? t.t("settings.not_set"))
                            .font(.DesignSystem.bodyMedium)
                            .foregroundColor(.DesignSystem.text)
                    }

                    Spacer()

                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.DesignSystem.brandGreen)
                }
                .padding(Spacing.md)

                Divider()
                    .padding(.leading, 56)

                // Account Created
                HStack(spacing: Spacing.md) {
                    Image(systemName: "calendar")
                        .font(.DesignSystem.bodyMedium)
                        .foregroundColor(.white)
                        .frame(width: 32.0, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.small)
                                .fill(Color.DesignSystem.accentPurple.gradient),
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.t("settings.member_since"))
                            .font(.DesignSystem.captionSmall)
                            .foregroundColor(.DesignSystem.textSecondary)
                        if let createdTime = appState.currentUser?.createdTime {
                            Text(createdTime, style: .date)
                                .font(.DesignSystem.bodyMedium)
                                .foregroundColor(.DesignSystem.text)
                        } else {
                            Text(t.t("common.unknown"))
                                .font(.DesignSystem.bodyMedium)
                                .foregroundColor(.DesignSystem.text)
                        }
                    }

                    Spacer()
                }
                .padding(Spacing.md)
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    #if !SKIP
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(Color.DesignSystem.glassStroke, lineWidth: 1),
                    ),
            )
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Password Section

    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(icon: "lock", title: t.t("settings.password"))

            Button {
                showChangePassword = true
            } label: {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "key")
                        .font(.DesignSystem.bodyMedium)
                        .foregroundColor(.white)
                        .frame(width: 32.0, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.small)
                                .fill(Color.DesignSystem.accentOrange.gradient),
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.t("settings.change_password"))
                            .font(.DesignSystem.bodyMedium)
                            .foregroundColor(.DesignSystem.text)
                        Text(t.t("settings.change_password_hint"))
                            .font(.DesignSystem.captionSmall)
                            .foregroundColor(.DesignSystem.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.DesignSystem.caption)
                        .foregroundColor(.DesignSystem.textTertiary)
                }
                .padding(Spacing.md)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    #if !SKIP
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(Color.DesignSystem.glassStroke, lineWidth: 1),
                    ),
            )
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Two-Factor Authentication Section

    private var twoFactorSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(icon: "shield.lefthalf.filled", title: t.t("settings.two_factor"))

            Button {
                showTwoFactorAuth = true
            } label: {
                HStack(spacing: Spacing.md) {
                    Image(systemName: mfaService.status.icon)
                        .font(.DesignSystem.bodyMedium)
                        .foregroundColor(.white)
                        .frame(width: 32.0, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.small)
                                .fill(twoFactorIconColor.gradient),
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.t("settings.two_factor"))
                            .font(.DesignSystem.bodyMedium)
                            .foregroundColor(.DesignSystem.text)
                        Text(mfaService.status.description)
                            .font(.DesignSystem.captionSmall)
                            .foregroundColor(.DesignSystem.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Status badge
                    if mfaService.status == .verified {
                        Text(t.t("common.on"))
                            .font(.DesignSystem.captionSmall)
                            .fontWeight(.semibold)
                            .foregroundColor(.DesignSystem.brandGreen)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(Color.DesignSystem.brandGreen.opacity(0.15)),
                            )
                    } else {
                        Text(t.t("common.off"))
                            .font(.DesignSystem.captionSmall)
                            .fontWeight(.semibold)
                            .foregroundColor(.DesignSystem.textTertiary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(Color.DesignSystem.textTertiary.opacity(0.15)),
                            )
                    }

                    Image(systemName: "chevron.right")
                        .font(.DesignSystem.caption)
                        .foregroundColor(.DesignSystem.textTertiary)
                }
                .padding(Spacing.md)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    #if !SKIP
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(
                                mfaService.status == .verified
                                    ? Color.DesignSystem.brandGreen.opacity(0.3)
                                    : Color.DesignSystem.glassStroke,
                                lineWidth: 1,
                            ),
                    ),
            )
        }
        .padding(.horizontal, Spacing.md)
    }

    private var twoFactorIconColor: Color {
        switch mfaService.status {
        case .unenrolled: .DesignSystem.accentGray
        case .unverified: .DesignSystem.warning
        case .verified: .DesignSystem.brandGreen
        case .disabled: .DesignSystem.error
        }
    }

    // MARK: - Sign Out Section

    private var signOutSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(icon: "rectangle.portrait.and.arrow.right", title: t.t("settings.session"))

            Button {
                showSignOutConfirmation = true
            } label: {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.DesignSystem.bodyMedium)
                        .foregroundColor(.white)
                        .frame(width: 32.0, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.small)
                                .fill(Color.DesignSystem.error.gradient),
                        )

                    Text(t.t("settings.sign_out"))
                        .font(.DesignSystem.bodyMedium)
                        .foregroundColor(.DesignSystem.error)

                    Spacer()

                    if isSigningOut {
                        ProgressView()
                    }
                }
                .padding(Spacing.md)
            }
            .buttonStyle(.plain)
            .disabled(isSigningOut)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    #if !SKIP
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(Color.DesignSystem.error.opacity(0.3), lineWidth: 1),
                    ),
            )
        }
        .padding(.horizontal, Spacing.md)
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

    private func signOut() async {
        isSigningOut = true
        await appState.signOut()
        dismiss()
    }
}

// MARK: - Change Password View

struct ChangePasswordView: View {
    
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.translationService) private var t

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isChanging = false
    @State private var showSuccess = false
    @State private var error: String?

    private var isValid: Bool {
        !currentPassword.isEmpty &&
            newPassword.count >= 8 &&
            newPassword == confirmPassword
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Success
                    if showSuccess {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.DesignSystem.brandGreen)
                            Text(t.t("settings.password_changed_success"))
                                .font(.DesignSystem.bodyMedium)
                                .foregroundColor(.DesignSystem.text)
                            Spacer()
                        }
                        .padding(Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(Color.DesignSystem.brandGreen.opacity(0.1)),
                        )
                        .padding(.horizontal, Spacing.md)
                    }

                    // Error
                    if let error {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.DesignSystem.error)
                            Text(error)
                                .font(.DesignSystem.bodySmall)
                                .foregroundColor(.DesignSystem.error)
                            Spacer()
                        }
                        .padding(Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(Color.DesignSystem.error.opacity(0.1)),
                        )
                        .padding(.horizontal, Spacing.md)
                    }

                    // Form
                    VStack(spacing: Spacing.md) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(t.t("settings.current_password"))
                                .font(.DesignSystem.bodySmall)
                                .fontWeight(.semibold)
                            SecureField(t.t("settings.enter_current_password"), text: $currentPassword)
                                .textContentType(.password)
                                .padding(Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                                        #if !SKIP
                                        .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                                        #else
                                        .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                                        #endif
                                        .overlay(
                                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                                .stroke(Color.DesignSystem.glassStroke, lineWidth: 1),
                                        ),
                                )
                        }

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(t.t("settings.new_password"))
                                .font(.DesignSystem.bodySmall)
                                .fontWeight(.semibold)
                            SecureField(t.t("settings.enter_new_password"), text: $newPassword)
                                .textContentType(.newPassword)
                                .padding(Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                                        #if !SKIP
                                        .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                                        #else
                                        .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                                        #endif
                                        .overlay(
                                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                                .stroke(Color.DesignSystem.glassStroke, lineWidth: 1),
                                        ),
                                )
                            Text(t.t("settings.password_min_chars"))
                                .font(.DesignSystem.captionSmall)
                                .foregroundColor(.DesignSystem.textTertiary)
                        }

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(t.t("settings.confirm_new_password"))
                                .font(.DesignSystem.bodySmall)
                                .fontWeight(.semibold)
                            SecureField(t.t("settings.confirm_new_password_placeholder"), text: $confirmPassword)
                                .textContentType(.newPassword)
                                .padding(Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                                        #if !SKIP
                                        .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                                        #else
                                        .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                                        #endif
                                        .overlay(
                                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                                .stroke(
                                                    !confirmPassword.isEmpty && newPassword != confirmPassword
                                                        ? Color.DesignSystem.error
                                                        : Color.DesignSystem.glassStroke,
                                                    lineWidth: 1,
                                                ),
                                        ),
                                )
                            if !confirmPassword.isEmpty, newPassword != confirmPassword {
                                Text(t.t("settings.passwords_dont_match"))
                                    .font(.DesignSystem.captionSmall)
                                    .foregroundColor(.DesignSystem.error)
                            }
                        }
                    }
                    .padding(Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            #if !SKIP
                            .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                            #else
                            .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                            #endif
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.large)
                                    .stroke(Color.DesignSystem.glassStroke, lineWidth: 1),
                            ),
                    )
                    .padding(.horizontal, Spacing.md)

                    // Submit
                    GlassButton(
                        isChanging ? t.t("settings.changing_password") : t.t("settings.change_password"),
                        icon: isChanging ? nil : "key",
                        style: .primary,
                        isLoading: isChanging,
                    ) {
                        Task { await changePassword() }
                    }
                    .disabled(!isValid)
                    .padding(.horizontal, Spacing.md)
                }
                .padding(.vertical, Spacing.md)
            }
            .background(Color.DesignSystem.background)
            .navigationTitle(t.t("settings.change_password"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t.t("common.cancel")) { dismiss() }
                }
            }
        }
    }

    private func changePassword() async {
        isChanging = true
        error = nil
        defer { isChanging = false }

        // Note: Supabase doesn't have a direct "change password" method
        // This would typically use updateUser or a custom edge function
        do {
            // Placeholder - implement actual password change
            #if SKIP
            try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))
            #else
            try await Task.sleep(for: .seconds(1))
            #endif
            showSuccess = true

            Task {
                #if SKIP
                try? await Task.sleep(nanoseconds: UInt64(2 * 1_000_000_000))
                #else
                try? await Task.sleep(for: .seconds(2))
                #endif
                dismiss()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    LoginSecurityView()
        .environment(AppState.preview)
}

#endif
