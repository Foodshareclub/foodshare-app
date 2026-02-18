//
//  EditProfileAvatarSection.swift
//  FoodShare
//
//  Hero avatar section for edit profile with:
//  - GlassAsyncImage display or preview image
//  - Gradient border (brandGreen → brandBlue)
//  - Camera badge overlay with PhotosPicker
//  - Upload progress overlay
//  - "Tap to change photo" hint
//


#if !SKIP
import Kingfisher
import PhotosUI
import SwiftUI

// MARK: - Edit Profile Avatar Section

struct EditProfileAvatarSection: View {
    @Environment(\.translationService) private var t
    @Bindable var viewModel: EditProfileViewModel

    @State private var isPressed = false
    @State private var hasAppeared = false

    private let avatarSize: CGFloat = 120

    var body: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                // Avatar image (preview or remote)
                avatarImage
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(Circle())
                    .overlay(gradientBorder)
                    .shadow(color: Color.DesignSystem.brandGreen.opacity(0.3), radius: 12, y: 5)
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                    .animation(Animation.interpolatingSpring(stiffness: 300, damping: 20), value: isPressed)

                // Upload progress overlay
                if viewModel.isUploadingAvatar {
                    uploadProgressOverlay
                }

                // Camera badge
                cameraBadge
            }
            .onTapGesture {
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                }
            }

            // Hint text
            Text(t.t("profile.tap_to_change_photo"))
                .font(.DesignSystem.caption)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
        .padding(.vertical, Spacing.lg)
        .frame(maxWidth: .infinity)
        .glassEffect(cornerRadius: CornerRadius.xl)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                hasAppeared = true
            }
        }
        .onChange(of: viewModel.selectedPhotoItem) { _, _ in
            Task { await viewModel.loadSelectedPhoto() }
        }
    }

    // MARK: - Avatar Image

    @ViewBuilder
    private var avatarImage: some View {
        if let previewImage = viewModel.previewImage {
            // Show preview of selected image
            Image(uiImage: previewImage)
                .resizable()
                .aspectRatio(contentMode: ContentMode.fill)
                .transition(AnyTransition.opacity.combined(with: AnyTransition.scale(scale: 0.95)))
        } else if let avatarUrl = viewModel.displayAvatarUrl,
                  let url = URL(string: avatarUrl)
        {
            // Show remote avatar with Kingfisher
            KFImage(url)
                .placeholder {
                    avatarPlaceholder
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(Color.DesignSystem.brandGreen),
                        )
                }
                .fade(duration: 0.3)
                .resizable()
                .aspectRatio(contentMode: ContentMode.fill)
        } else {
            // Show placeholder
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.DesignSystem.brandGreen.opacity(0.3),
                    Color.DesignSystem.brandBlue.opacity(0.3),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )

            Image(systemName: "person.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
    }

    // MARK: - Gradient Border

    private var gradientBorder: some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: [Color.DesignSystem.brandGreen, Color.DesignSystem.brandBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                ),
                lineWidth: 3,
            )
    }

    // MARK: - Upload Progress Overlay

    private var uploadProgressOverlay: some View {
        Circle()
            #if !SKIP
            .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
            #else
            .fill(Color.DesignSystem.glassSurface.opacity(0.15))
            #endif
            .frame(width: avatarSize, height: avatarSize)
            .overlay(
                VStack(spacing: Spacing.xs) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(Color.DesignSystem.brandGreen)

                    Text(t.t("profile.uploading"))
                        .font(.DesignSystem.captionSmall)
                        .foregroundStyle(Color.DesignSystem.text)
                },
            )
            .transition(AnyTransition.opacity)
    }

    // MARK: - Camera Badge

    private var cameraBadge: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                PhotosPicker(
                    selection: $viewModel.selectedPhotoItem,
                    matching: PHPickerFilter.images
                ) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.DesignSystem.brandGreen, Color.DesignSystem.brandBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                            )
                            .frame(width: 36.0, height: 36)

                        Image(systemName: "camera.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: Color.DesignSystem.brandGreen.opacity(0.4), radius: 8, y: 4)
                }
                .disabled(viewModel.isUploadingAvatar)
            }
        }
        .frame(width: avatarSize, height: avatarSize)
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        ZStack {
            Color.DesignSystem.background.ignoresSafeArea()

            EditProfileAvatarSection(
                viewModel: EditProfileViewModel(
                    repository: MockProfileRepository(),
                    userId: UUID(),
                    profile: .fixture(),
                ),
            )
            .padding()
        }
    }
#endif

#endif
