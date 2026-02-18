//
//  CreateForumPostView.swift
//  Foodshare
//
//  Create a new forum post with Liquid Glass design system
//


#if !SKIP
import OSLog
import PhotosUI
import Supabase
import SwiftUI

#if DEBUG
    import Inject
#endif

private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "CreateForumPost")

struct CreateForumPostView: View {
    
    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.translationService) private var t
    @Environment(AppState.self) private var appState

    let repository: ForumRepository
    let categories: [ForumCategory]
    var onPostCreated: ((ForumPost) -> Void)?

    @State private var title = ""
    @State private var description = ""
    @State private var selectedCategory: ForumCategory?
    @State private var selectedPostType: ForumPostType = .discussion
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isSubmitting = false
    @State private var error: String?
    @State private var showCategoryPicker = false

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            title.count >= 5 &&
            description.count >= 10
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Error Banner
                        if let error {
                            errorBanner(error)
                        }

                        // Post Type Selector
                        postTypeSection

                        // Category Selector
                        categorySection

                        // Title Field
                        titleSection

                        // Description Field
                        descriptionSection

                        // Image Upload
                        imageSection

                        // Submit Button
                        submitButton
                    }
                    .padding(Spacing.md)
                }
            }
            .navigationTitle(t.t("forum.new_post"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t.t("common.cancel")) {
                        dismiss()
                    }
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                Task { await loadSelectedPhoto(newValue) }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.05, green: 0.08, blue: 0.12),
                    Color(red: 0.08, green: 0.12, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )

            LinearGradient(
                colors: [
                    Color.DesignSystem.brandPink.opacity(0.1),
                    Color.clear,
                    Color.DesignSystem.brandTeal.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom,
            )
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(Color.DesignSystem.error)

            Text(message)
                .font(.DesignSystem.bodySmall)
                .foregroundColor(Color.DesignSystem.error)

            Spacer()

            Button {
                withAnimation { error = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.DesignSystem.caption)
                    .foregroundColor(Color.DesignSystem.error)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.DesignSystem.error.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.DesignSystem.error.opacity(0.3), lineWidth: 1),
                ),
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Post Type Section

    private var postTypeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(icon: "text.bubble", title: t.t("forum.post_type"))

            HStack(spacing: Spacing.sm) {
                ForEach(ForumPostType.allCases, id: \.self) { type in
                    postTypeButton(type)
                }
            }
        }
    }

    private func postTypeButton(_ type: ForumPostType) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedPostType = type
            }
            HapticManager.light()
        } label: {
            VStack(spacing: Spacing.xs) {
                Image(systemName: type.iconName)
                    .font(.DesignSystem.titleMedium)
                Text(type.localizedDisplayName(using: t))
                    .font(.DesignSystem.caption)
            }
            .foregroundColor(selectedPostType == type ? .white : Color.DesignSystem.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(
                        selectedPostType == type
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color.DesignSystem.brandPink, Color.DesignSystem.brandTeal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ))
                            : AnyShapeStyle(Color.DesignSystem.glassBackground),
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(
                                selectedPostType == type
                                    ? Color.white.opacity(0.3)
                                    : Color.DesignSystem.glassBorder,
                                lineWidth: 1,
                            ),
                    ),
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(icon: "folder", title: t.t("forum.category"))

            Button {
                showCategoryPicker = true
            } label: {
                HStack {
                    if let category = selectedCategory {
                        Image(systemName: category.systemIconName)
                            .foregroundStyle(category.displayColor)
                        Text(category.name)
                            .font(.DesignSystem.bodyMedium)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "folder")
                            .foregroundColor(Color.DesignSystem.textSecondary)
                        Text(t.t("forum.select_category_placeholder"))
                            .font(.DesignSystem.bodyMedium)
                            .foregroundColor(Color.DesignSystem.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.DesignSystem.caption)
                        .foregroundColor(Color.DesignSystem.textSecondary)
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(Color.DesignSystem.glassBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                        ),
                )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showCategoryPicker) {
                categoryPickerSheet
            }
        }
    }

    private var categoryPickerSheet: some View {
        NavigationStack {
            List(categories, id: \.id) { category in
                Button {
                    selectedCategory = category
                    showCategoryPicker = false
                } label: {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: category.systemIconName)
                            .font(.DesignSystem.titleMedium)
                            .foregroundStyle(category.displayColor)
                            .frame(width: 32.0)

                        VStack(alignment: .leading, spacing: Spacing.xxxs) {
                            Text(category.name)
                                .font(.DesignSystem.bodyMedium)
                                .foregroundColor(.primary)
                            if let desc = category.description {
                                Text(desc)
                                    .font(.DesignSystem.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        if selectedCategory?.id == category.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color.DesignSystem.brandPink)
                        }
                    }
                }
            }
            .navigationTitle(t.t("forum.select_category"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t.t("common.done")) { showCategoryPicker = false }
                }
            }
        }
        .presentationDetents([PresentationDetent.medium, PresentationDetent.large])
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                sectionHeader(icon: "textformat", title: t.t("common.title"))
                Spacer()
                Text("\(title.count)/100")
                    .font(.DesignSystem.caption)
                    .foregroundColor(title.count > 100 ? Color.DesignSystem.error : Color.DesignSystem.textTertiary)
            }

            TextField(t.t("forum.title_placeholder"), text: $title)
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.white)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(Color.DesignSystem.glassBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .stroke(
                                    title.count < 5 && !title.isEmpty
                                        ? Color.DesignSystem.warning.opacity(0.5)
                                        : Color.DesignSystem.glassBorder,
                                    lineWidth: 1,
                                ),
                        ),
                )
                .onChange(of: title) { _, newValue in
                    if newValue.count > 100 {
                        title = String(newValue.prefix(100))
                    }
                }

            if !title.isEmpty, title.count < 5 {
                Text(t.t("forum.title_min_length"))
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(Color.DesignSystem.warning)
            }
        }
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                sectionHeader(icon: "doc.text", title: t.t("forum.content"))
                Spacer()
                Text("\(description.count)/2000")
                    .font(.DesignSystem.caption)
                    .foregroundColor(description.count > 2000
                        ? Color.DesignSystem.error
                        : Color.DesignSystem.textTertiary)
            }

            TextEditor(text: $description)
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 150)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(Color.DesignSystem.glassBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .stroke(
                                    description.count < 10 && !description.isEmpty
                                        ? Color.DesignSystem.warning.opacity(0.5)
                                        : Color.DesignSystem.glassBorder,
                                    lineWidth: 1,
                                ),
                        ),
                )
                .onChange(of: description) { _, newValue in
                    if newValue.count > 2000 {
                        description = String(newValue.prefix(2000))
                    }
                }

            if !description.isEmpty, description.count < 10 {
                Text(t.t("forum.content_min_length"))
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(Color.DesignSystem.warning)
            }
        }
    }

    // MARK: - Image Section

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(icon: "photo", title: t.t("forum.image_optional"))

            if let imageData = selectedImageData,
               let uiImage = UIImage(data: imageData) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200.0)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))

                    Button {
                        withAnimation { selectedImageData = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.DesignSystem.titleLarge)
                            #if !SKIP
                            .foregroundStyle(Color.white, Color.DesignSystem.error)
                            #else
                            .foregroundStyle(Color.DesignSystem.error)
                            #endif
                    }
                    .padding(Spacing.sm)
                }
            } else {
                PhotosPicker(selection: $selectedPhotoItem, matching: PHPickerFilter.images) {
                    HStack {
                        Image(systemName: "photo.badge.plus")
                            .font(.DesignSystem.titleMedium)
                        Text(t.t("forum.add_image"))
                            .font(.DesignSystem.bodyMedium)
                    }
                    .foregroundColor(Color.DesignSystem.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 100.0)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(Color.DesignSystem.glassBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.medium)
                                    .strokeBorder(
                                        style: StrokeStyle(lineWidth: 1, dash: [8]),
                                    )
                                    .foregroundColor(Color.DesignSystem.glassBorder),
                            ),
                    )
                }
            }
        }
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        GlassButton(
            t.t("forum.create_post"),
            icon: "paperplane.fill",
            style: .pinkTeal,
            isLoading: isSubmitting,
        ) {
            Task { await submitPost() }
        }
        .disabled(!isValid)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.xl)
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.DesignSystem.caption)
                .foregroundColor(Color.DesignSystem.textSecondary)
            Text(title)
                .font(.DesignSystem.labelMedium)
                .foregroundColor(Color.DesignSystem.textSecondary)
        }
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                if let uiImage = UIImage(data: data) {
                    let resized = resizeImage(uiImage, targetSize: CGSize(width: 1024.0, height: 1024.0))
                    selectedImageData = resized.jpegData(compressionQuality: 0.8)
                } else {
                    selectedImageData = data
                }
                HapticManager.success()
            }
        } catch {
            self.error = t.t("error.failed_load_image")
            HapticManager.error()
        }
    }

    #if !SKIP
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)

        guard ratio < 1 else { return image }

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)

        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    #endif

    private func submitPost() async {
        logger.info("🚀 Starting forum post submission...")

        guard let userId = appState.currentUser?.id else {
            logger.error("❌ User not logged in")
            error = t.t("error.must_be_logged_in")
            return
        }

        logger.info("✅ User authenticated: \(userId.uuidString)")

        isSubmitting = true
        error = nil

        do {
            // Upload image if selected
            var imageUrl: String?
            if let imageData = selectedImageData {
                logger.info("📸 Starting image upload... Size: \(imageData.count) bytes")
                let startTime = Date()
                imageUrl = try await uploadImage(imageData)
                let elapsed = Date().timeIntervalSince(startTime)
                logger.info("✅ Image uploaded in \(String(format: "%.2f", elapsed))s: \(imageUrl ?? "nil")")
            } else {
                logger.info("📷 No image selected, skipping upload")
            }

            logger.info("📝 Creating forum post request...")
            logger.info("   Title: \(title.prefix(50))...")
            logger.info("   Category: \(selectedCategory?.name ?? "none")")
            logger.info("   PostType: \(selectedPostType.rawValue)")

            let request = CreateForumPostRequest(
                profileId: userId,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                categoryId: selectedCategory?.id,
                postType: selectedPostType,
                imageUrl: imageUrl,
            )

            logger.info("📤 Calling repository.createPost()...")
            let startTime = Date()
            let newPost = try await repository.createPost(request)
            let elapsed = Date().timeIntervalSince(startTime)
            logger.info("✅ Post created in \(String(format: "%.2f", elapsed))s - ID: \(newPost.id)")

            HapticManager.success()
            logger.info("🎉 Calling onPostCreated callback and dismissing...")
            onPostCreated?(newPost)
            dismiss()
        } catch {
            logger.error("❌ Failed to create post: \(error.localizedDescription)")
            logger.error("   Full error: \(String(describing: error))")
            self.error = "Failed to create post: \(error.localizedDescription)"
            HapticManager.error()
        }

        isSubmitting = false
        logger.info("🏁 Submit post completed, isSubmitting = false")
    }

    private func uploadImage(_ imageData: Data) async throws -> String {
        let supabase = appState.authService.supabase
        let filename = "\(UUID().uuidString).jpg"
        let path = "forum/\(filename)"

        logger.info("📤 Uploading to forum bucket, path: \(path)")

        let uploadStart = Date()
        _ = try await supabase.storage
            .from("forum")
            .upload(
                path,
                data: imageData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                ),
            )
        let uploadElapsed = Date().timeIntervalSince(uploadStart)
        logger.info("✅ Storage upload completed in \(String(format: "%.2f", uploadElapsed))s")

        logger.info("🔗 Getting public URL...")
        let publicURL = try supabase.storage
            .from("forum")
            .getPublicURL(path: path)

        logger.info("✅ Public URL: \(publicURL.absoluteString)")
        return publicURL.absoluteString
    }
}

#endif
