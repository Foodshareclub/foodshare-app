//
//  EditProfileView.swift
//  FoodShare
//
//  Elegant edit profile screen using Liquid Glass design system with:
//  - Hero avatar section with preview, compression, and upload progress
//  - Glass-styled form sections for all persisted fields
//  - Proper validation with inline errors
//  - Success toast feedback
//  - Staggered appearance animations
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Edit Profile View

struct EditProfileView: View {
    @Environment(\.translationService) private var t
    @Environment(\.dismiss) private var dismiss

    @State var viewModel: EditProfileViewModel

    // Animation state
    @State private var sectionAppearance: [Bool] = [false, false, false]

    init(repository: ProfileRepository, userId: UUID, profile: UserProfile?) {
        _viewModel = State(initialValue: EditProfileViewModel(
            repository: repository,
            userId: userId,
            profile: profile
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Avatar Section
                        EditProfileAvatarSection(viewModel: viewModel)
                            .opacity(sectionAppearance[0] ? 1 : 0)
                            .offset(y: sectionAppearance[0] ? 0 : 20)

                        // Profile Information Form
                        profileInfoSection
                            .opacity(sectionAppearance[1] ? 1 : 0)
                            .offset(y: sectionAppearance[1] ? 0 : 20)

                        // Preferences Section
                        preferencesSection
                            .opacity(sectionAppearance[2] ? 1 : 0)
                            .offset(y: sectionAppearance[2] ? 0 : 20)

                        // Spacer for bottom padding
                        Spacer(minLength: Spacing.xxl)
                    }
                    .padding(Spacing.md)
                }
            }
            .navigationTitle(t.t("profile.edit_profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t.t("common.cancel")) {
                        HapticManager.light()
                        dismiss()
                    }
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    saveButton
                }
            }
            .onAppear(perform: animateSections)
            .alert(t.t("common.error.title"), isPresented: $viewModel.showError) {
                Button(t.t("common.ok")) { viewModel.showError = false }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .overlay(alignment: .top) {
                if viewModel.showSuccessToast {
                    successToast
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            Task {
                                try? await Task.sleep(for: .seconds(1.5))
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    viewModel.showSuccessToast = false
                                }
                                try? await Task.sleep(for: .seconds(0.3))
                                dismiss()
                            }
                        }
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showSuccessToast)
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            Task {
                _ = await viewModel.save()
            }
        } label: {
            if viewModel.isSaving {
                ProgressView()
                    .tint(Color.DesignSystem.brandGreen)
            } else {
                Text(t.t("common.save"))
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        viewModel.hasChanges
                            ? Color.DesignSystem.brandGreen
                            : Color.DesignSystem.textTertiary
                    )
            }
        }
        .disabled(!viewModel.hasChanges || viewModel.isSaving)
    }

    // MARK: - Profile Info Section

    private var profileInfoSection: some View {
        GlassForm(title: t.t("profile.edit.info_title")) {
            VStack(spacing: Spacing.md) {
                // Display Name
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    GlassTextField(
                        t.t("profile.edit.nickname"),
                        text: $viewModel.nickname,
                        icon: "person.fill"
                    )
                    .onChange(of: viewModel.nickname) { _, _ in
                        viewModel.clearValidationError(for: "nickname")
                    }

                    if let error = viewModel.nicknameError {
                        validationErrorText(error)
                    }
                }

                // Bio
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    GlassTextArea(
                        t.t("profile.edit.bio_placeholder"),
                        text: $viewModel.bio,
                        icon: "text.quote",
                        characterLimit: viewModel.bioCharacterLimit
                    )
                    .onChange(of: viewModel.bio) { _, _ in
                        viewModel.clearValidationError(for: "bio")
                    }

                    if let error = viewModel.bioError {
                        validationErrorText(error)
                    }
                }

                // Address (tappable field with picker)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    GlassAddressField(
                        address: viewModel.address,
                        onTap: { viewModel.showAddressPicker = true }
                    )

                    if let error = viewModel.locationError {
                        validationErrorText(error)
                    }
                }
                .sheet(isPresented: $viewModel.showAddressPicker) {
                    AddressPickerSheet(
                        address: $viewModel.address,
                        onSave: { viewModel.showAddressPicker = false }
                    )
                }
            }
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        GlassForm(title: t.t("profile.edit.preferences")) {
            VStack(spacing: Spacing.md) {
                // Search Radius (max 805km = 500 miles)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    GlassSlider(
                        value: $viewModel.searchRadiusKm,
                        in: 1...805,
                        step: 5,
                        label: t.t("profile.edit.search_radius"),
                        icon: "location.circle.fill",
                        accentColor: .DesignSystem.brandBlue,
                        valueFormatter: { "\(Int($0)) km" }
                    )
                    .onChange(of: viewModel.searchRadiusKm) { _, _ in
                        viewModel.clearValidationError(for: "searchRadius")
                    }

                    if let error = viewModel.searchRadiusError {
                        validationErrorText(error)
                    }
                }
            }
        }
    }

    // MARK: - Validation Error Text

    private func validationErrorText(_ message: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
            Text(message)
                .font(.DesignSystem.captionSmall)
        }
        .foregroundStyle(Color.DesignSystem.error)
        .padding(.leading, Spacing.sm)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: message)
    }

    // MARK: - Success Toast

    private var successToast: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.DesignSystem.brandGreen)

            Text(t.t("settings.changes_saved"))
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.text)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.DesignSystem.brandGreen.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: Color.DesignSystem.brandGreen.opacity(0.2), radius: 12, y: 4)
        .padding(.top, Spacing.lg)
    }

    // MARK: - Animations

    private func animateSections() {
        for index in sectionAppearance.indices {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.08)) {
                sectionAppearance[index] = true
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    EditProfileView(
        repository: MockProfileRepository(),
        userId: UUID(),
        profile: .fixture()
    )
}
#endif
