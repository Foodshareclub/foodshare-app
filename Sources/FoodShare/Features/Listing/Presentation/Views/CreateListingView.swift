//
//  CreateListingView.swift
//  Foodshare
//
//  Create listing view with Liquid Glass v26 design
//  Supports all listing types matching web app
//


#if !SKIP
import PhotosUI
import SwiftUI

#if DEBUG
    import Inject
#endif

struct CreateListingView: View {

    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.translationService) private var t
    @Environment(AppState.self) private var appState
    @State private var viewModel: CreateListingViewModel
    @State private var showImagePicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false
    @State private var isGettingLocation = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var capturedImage: UIImage?
    @State private var selectedListingType: ListingCategory = .food
    @State private var hasAppeared = false
    /// Form validation shake triggers
    @State private var shakeTitleField = 0
    @State private var shakeDescriptionField = false
    @State private var shakeAddressField = 0

    init(viewModel: CreateListingViewModel) {
        _viewModel = State(initialValue: viewModel)
        // Initialize selectedListingType from ViewModel's postType
        if let category = ListingCategory(rawValue: viewModel.postType) {
            _selectedListingType = State(initialValue: category)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [
                        Color.DesignSystem.background,
                        selectedListingType.color.opacity(0.1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom,
                )
                .ignoresSafeArea()
                .animation(.interpolatingSpring(stiffness: 300, damping: 24), value: selectedListingType)

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        listingTypeSection
                            .staggeredAppearance(index: 0, baseDelay: 0.1)
                        imageSection
                            .staggeredAppearance(index: 1, baseDelay: 0.1)
                        basicInfoSection
                            .staggeredAppearance(index: 2, baseDelay: 0.1)
                            .proMotionShake(trigger: shakeTitleField)
                        detailsSection
                            .staggeredAppearance(index: 3, baseDelay: 0.1)
                        locationSection
                            .staggeredAppearance(index: 4, baseDelay: 0.1)
                            .proMotionShake(trigger: shakeAddressField)
                        submitButton
                            .staggeredAppearance(index: 5, baseDelay: 0.1)
                    }
                    .padding(Spacing.md)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .glassNavigationBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.DesignSystem.textSecondary)
                            .frame(width: 28.0, height: 28)
                            .background(
                                Circle()
                                    #if !SKIP
                                    .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                                    #else
                                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                                    #endif
                            )
                    }
                }
            }
            .alert(t.t("common.error.title"), isPresented: $viewModel.showError) {
                Button(t.t("common.ok"), role: .cancel) {
                    viewModel.dismissError()
                }
            } message: {
                Text(viewModel.error ?? t.t("common.error_occurred"))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraImagePicker(capturedImage: $capturedImage)
        }
        .sheet(isPresented: $showPhotoLibrary) {
            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 3 - viewModel.selectedImages.count,
                matching: PHPickerFilter.images,
            ) {
                EmptyView()
            }
        }
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage, let data = image.jpegData(compressionQuality: 0.9) {
                Task {
                    await processImage(data)
                }
                capturedImage = nil
            }
        }
    }

    private func processImage(_ data: Data) async {
        isLoadingPhotos = true
        defer { isLoadingPhotos = false }

        // ImageUploader is iOS-only (not available on Skip/Android)
        // Add image data directly to the view model for now
        viewModel.addImage(data)
        HapticManager.success()
    }

    private var navigationTitle: String {
        if viewModel.isEditMode {
            return t.t("listing.edit_title")
        }
        switch selectedListingType {
        case .food: return t.t("listing.type.food")
        case .thing: return t.t("listing.type.item")
        case .borrow: return t.t("listing.type.lend")
        case .wanted: return t.t("listing.type.wanted")
        case .zerowaste: return t.t("listing.type.zerowaste")
        case .vegan: return t.t("listing.type.vegan")
        default: return t.t("listing.create_title")
        }
    }

    // MARK: - Listing Type Section

    private var listingTypeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header with gradient icon
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    selectedListingType.color.opacity(0.2),
                                    selectedListingType.color.opacity(0.1),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .frame(width: 32.0, height: 32)

                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [selectedListingType.color, selectedListingType.color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                }
                .animation(.spring(response: 0.3), value: selectedListingType)

                Text(t.t("listing.what_sharing"))
                    .font(.DesignSystem.headlineSmall)
                    .foregroundColor(.DesignSystem.text)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(ListingCategory.creatableCategories) { category in
                        ListingTypeButton(
                            category: category,
                            isSelected: selectedListingType == category,
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedListingType = category
                                viewModel.postType = category.rawValue
                            }
                            HapticManager.selection()
                        }
                    }
                }
                .padding(.horizontal, Spacing.xs)
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
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
    }

    // MARK: - Image Section

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header with gradient icon
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.DesignSystem.brandBlue.opacity(0.2), .DesignSystem.brandGreen.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .frame(width: 32.0, height: 32)

                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.DesignSystem.brandBlue, .DesignSystem.brandGreen],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                }

                Text(t.t("create.photos"))
                    .font(.DesignSystem.headlineSmall)
                    .foregroundColor(.DesignSystem.text)

                Spacer()

                Text(viewModel.imageCountText)
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(.DesignSystem.textTertiary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(Color.DesignSystem.glassBackground),
                    )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    // Add photo button - only show if less than 3 images and not loading
                    if viewModel.selectedImages.count < 3, !isLoadingPhotos {
                        Menu {
                            Button {
                                showCamera = true
                            } label: {
                                Label("Take Photo", systemImage: "camera.fill")
                            }

                            Button {
                                showPhotoLibrary = true
                            } label: {
                                Label("Choose from Library", systemImage: "photo.on.rectangle")
                            }
                        } label: {
                            AddPhotoLabel()
                        }
                    } else if isLoadingPhotos {
                        // Loading indicator
                        VStack(spacing: Spacing.sm) {
                            ProgressView()
                                .tint(.DesignSystem.brandGreen)
                            Text("Loading...")
                                .font(.DesignSystem.captionSmall)
                                .foregroundColor(.DesignSystem.textSecondary)
                        }
                        .frame(width: 120.0, height: 120)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                #if !SKIP
                                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                                #else
                                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                                #endif
                        )
                    }

                    // Selected images with animated transitions
                    ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, data in
                        if let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120.0, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                                )
                                .overlay(alignment: Alignment.topTrailing) {
                                    Button {
                                        withAnimation(ProMotionAnimation.bouncy) {
                                            viewModel.removeImage(at: index)
                                        }
                                        HapticManager.medium()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundStyle(Color.white)
                                            .shadow(color: Color.black.opacity(0.3), radius: 2, y: 1)
                                    }
                                    .padding(Spacing.xs)
                                    .buttonStyle(ProMotionButtonStyle())
                                }
                                .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                                .transition(AnyTransition.asymmetric(
                                    insertion: AnyTransition.scale(scale: 0.8).combined(with: AnyTransition.opacity),
                                    removal: AnyTransition.scale(scale: 0.8).combined(with: AnyTransition.opacity),
                                ))
                        }
                    }
                    .animation(ProMotionAnimation.bouncy, value: viewModel.selectedImages.count)
                }
                .padding(.horizontal, Spacing.xs)
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
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
        .onChange(of: selectedPhotoItems) { _, newItems in
            guard !newItems.isEmpty else { return }

            Task {
                isLoadingPhotos = true
                defer { isLoadingPhotos = false }

                // Calculate how many we can actually add
                let remainingSlots = 3 - viewModel.selectedImages.count
                let itemsToLoad = Array(newItems.prefix(remainingSlots))

                await loadSelectedImages(from: itemsToLoad)

                // Clear picker selection immediately after loading starts
                selectedPhotoItems = []
            }
        }
    }

    private func loadSelectedImages(from items: [PhotosPickerItem]) async {
        for item in items {
            // Stop if we've reached the limit
            guard viewModel.selectedImages.count < 3 else { break }

            if let data = try? await item.loadTransferable(type: Data.self) {
                viewModel.addImage(data)
            }
        }
    }

    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header with gradient icon
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.DesignSystem.brandGreen.opacity(0.2), .DesignSystem.brandBlue.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .frame(width: 32.0, height: 32)

                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                }

                Text(t.t("create.basic_info"))
                    .font(.DesignSystem.headlineSmall)
                    .foregroundColor(.DesignSystem.text)
            }

            VStack(spacing: Spacing.md) {
                GlassTextField(t.t("common.title"), text: $viewModel.title, icon: "text.alignleft")

                // Description using GlassTextArea style
                GlassDescriptionEditor(
                    text: $viewModel.description,
                    placeholder: t.t("listing.description_placeholder"),
                )
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
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
    }
}

// MARK: - Glass Description Editor

struct GlassDescriptionEditor: View {
    @Binding var text: String
    let placeholder: String

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "text.alignleft")
                .foregroundStyle(isFocused ? Color.DesignSystem.brandGreen : Color.DesignSystem.textSecondary)
                .font(.system(size: 18))
                .animation(Animation.spring(response: 0.3, dampingFraction: 0.75), value: isFocused)
                .padding(.top, Spacing.xs)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.DesignSystem.bodyLarge)
                        .foregroundColor(.DesignSystem.textTertiary)
                        .padding(.top, 2)
                }

                TextEditor(text: $text)
                    .font(.DesignSystem.bodyLarge)
                    .foregroundStyle(Color.DesignSystem.text)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .frame(minHeight: 100, maxHeight: 150)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(Color.white.opacity(isFocused ? 0.12 : 0.08))
                #if !SKIP
                .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .background(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(
                    isFocused
                        ? LinearGradient(
                            colors: [
                                Color.DesignSystem.brandGreen.opacity(0.6),
                                Color.DesignSystem.brandBlue.opacity(0.4),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        )
                        : LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    lineWidth: isFocused ? 1.5 : 1,
                ),
        )
        .animation(Animation.spring(response: 0.3, dampingFraction: 0.75), value: isFocused)
    }
}

// MARK: - CreateListingView Sections

extension CreateListingView {
    // MARK: - Details Section

    var detailsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header with gradient icon
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange.opacity(0.2), .yellow.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .frame(width: 32.0, height: 32)

                    Image(systemName: "tag.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                }

                Text(t.t("create.details"))
                    .font(.DesignSystem.headlineSmall)
                    .foregroundColor(.DesignSystem.text)
            }

            VStack(spacing: Spacing.md) {
                // Category picker
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(t.t("create.category"))
                        .font(.DesignSystem.bodyMedium)
                        .foregroundColor(.DesignSystem.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            CategoryButton(
                                title: "Produce",
                                icon: "leaf.fill",
                                color: .green,
                                isSelected: viewModel.selectedCategoryId == 1,
                            ) {
                                viewModel.selectedCategoryId = 1
                                HapticManager.selection()
                            }
                            CategoryButton(
                                title: "Dairy",
                                icon: "drop.fill",
                                color: .blue,
                                isSelected: viewModel.selectedCategoryId == 2,
                            ) {
                                viewModel.selectedCategoryId = 2
                                HapticManager.selection()
                            }
                            CategoryButton(
                                title: "Baked",
                                icon: "birthday.cake.fill",
                                color: .orange,
                                isSelected: viewModel.selectedCategoryId == 3,
                            ) {
                                viewModel.selectedCategoryId = 3
                                HapticManager.selection()
                            }
                            CategoryButton(
                                title: "Meals",
                                icon: "fork.knife",
                                color: .red,
                                isSelected: viewModel.selectedCategoryId == 4,
                            ) {
                                viewModel.selectedCategoryId = 4
                                HapticManager.selection()
                            }
                        }
                        .padding(.horizontal, Spacing.xs)
                    }
                }

                // Pickup time
                GlassTextField(t.t("listing.placeholder.pickup_time"), text: $viewModel.pickupTime, icon: "clock")
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
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
    }

    // MARK: - Location Section

    var locationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header with gradient icon
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.DesignSystem.error.opacity(0.2), .orange.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .frame(width: 32.0, height: 32)

                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.DesignSystem.error, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                }

                Text(t.t("create.pickup_location"))
                    .font(.DesignSystem.headlineSmall)
                    .foregroundColor(.DesignSystem.text)
            }

            VStack(spacing: Spacing.md) {
                GlassTextField(
                    t.t("listing.placeholder.address"),
                    text: $viewModel.pickupAddress,
                    icon: "mappin.and.ellipse",
                )

                // Use current location button
                Button {
                    HapticManager.light()
                    Task {
                        isGettingLocation = true
                        defer { isGettingLocation = false }

                        do {
                            // Request permission first if not authorized
                            let isAuthorized = await appState.locationManager.isAuthorized
                            if !isAuthorized {
                                try await appState.locationManager.requestPermission()
                            }

                            let location = try await appState.locationManager.getCurrentLocation()
                            viewModel.pickupAddress = "\(location.latitude), \(location.longitude)"
                            HapticManager.success()
                        } catch LocationError.permissionDenied {
                            viewModel.error =
                                "Location permission denied. Please enable in Settings > FoodShare > Location."
                            viewModel.showError = true
                            HapticManager.error()
                        } catch LocationError.locationServicesDisabled {
                            viewModel.error =
                                "Location services are disabled. Please enable in Settings > Privacy > Location Services."
                            viewModel.showError = true
                            HapticManager.error()
                        } catch {
                            viewModel.error = "Unable to get your location. Please try again."
                            viewModel.showError = true
                            HapticManager.error()
                        }
                    }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        if isGettingLocation {
                            ProgressView()
                                .tint(.DesignSystem.brandGreen)
                        } else {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14, weight: .medium))
                        }

                        Text(isGettingLocation ? t.t("common.loading") : t.t("create.use_current_location"))
                            .font(.DesignSystem.bodyMedium)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.DesignSystem.brandGreen)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        Capsule()
                            .fill(Color.DesignSystem.brandGreen.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(Color.DesignSystem.brandGreen.opacity(0.3), lineWidth: 1),
                            ),
                    )
                }
                .disabled(isGettingLocation)
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
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
    }

    // MARK: - Submit Button

    var submitButton: some View {
        GlassButton(
            viewModel.isEditMode ? t.t("listing.save_changes") : t.t("listing.share_food"),
            icon: viewModel.isEditMode ? "checkmark.circle.fill" : "paperplane.fill",
            style: .primary,
            isLoading: viewModel.isLoading,
        ) {
            // Validate required fields with shake feedback
            if viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                shakeTitleField += 1
                HapticManager.error()
                return
            }

            if viewModel.pickupAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !viewModel.isEditMode {
                shakeAddressField += 1
                HapticManager.error()
                return
            }

            Task {
                if viewModel.isEditMode {
                    await viewModel.updateListing()
                } else {
                    guard let userId = appState.currentUser?.id else { return }

                    do {
                        // Request permission first if not authorized
                        let isAuthorized = await appState.locationManager.isAuthorized
                        if !isAuthorized {
                            try await appState.locationManager.requestPermission()
                            // After permission dialog, check again
                            let stillAuthorized = await appState.locationManager.isAuthorized
                            if !stillAuthorized {
                                throw LocationError.permissionDenied
                            }
                        }

                        let location = try await appState.locationManager.getCurrentLocation()
                        await viewModel.createListing(
                            userId: userId,
                            latitude: location.latitude,
                            longitude: location.longitude,
                        )

                        if viewModel.createdListing != nil {
                            HapticManager.success()
                            dismiss()
                        }
                    } catch LocationError.permissionDenied {
                        viewModel.error =
                            "Location permission is required to share food. Please enable in Settings."
                        viewModel.showError = true
                        shakeAddressField += 1
                        HapticManager.error()
                    } catch LocationError.locationServicesDisabled {
                        viewModel.error =
                            "Location services are disabled. Please enable in Settings > Privacy > Location Services."
                        viewModel.showError = true
                        shakeAddressField += 1
                        HapticManager.error()
                    } catch LocationError.timeout {
                        viewModel.error = "Location request timed out. Please try again."
                        viewModel.showError = true
                        shakeAddressField += 1
                        HapticManager.error()
                    } catch {
                        viewModel.error = error.localizedDescription
                        viewModel.showError = true
                        HapticManager.error()
                    }
                }
            }
        }
        .disabled(!viewModel.canSubmit && !viewModel.isEditMode)
    }
}

// MARK: - Listing Type Button

struct ListingTypeButton: View {
    @Environment(\.translationService) private var t
    let category: ListingCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(isSelected ? category.color : Color.DesignSystem.glassBackground)
                        .frame(width: 56.0, height: 56)

                    Image(systemName: category.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isSelected ? .white : category.color)
                }

                Text(category.localizedDisplayName(using: t))
                    .font(.DesignSystem.captionSmall)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? category.color : .DesignSystem.textSecondary)
            }
            .frame(width: 80.0)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(isSelected ? category.color.opacity(0.1) : Color.clear)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            #if !SKIP
                            .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                            #else
                            .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                            #endif
                    ),
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(
                        isSelected ? category.color : Color.DesignSystem.glassBorder,
                        lineWidth: isSelected ? 2 : 1,
                    ),
            )
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.95, haptic: .none))
    }
}

// MARK: - Category Button (Liquid Glass Enhanced)

struct CategoryButton: View {
    let title: String
    let icon: String
    var color: Color = .DesignSystem.brandGreen
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
            HapticManager.medium()
        } label: {
            VStack(spacing: Spacing.xs) {
                ZStack {
                    // Outer glow when selected
                    if isSelected {
                        Circle()
                            .fill(color.opacity(0.3))
                            .frame(width: 52.0, height: 52)
                            .blur(radius: 6)
                    }

                    if isSelected {
                        Circle()
                            .fill(color)
                            .frame(width: 44.0, height: 44)
                            .shadow(color: color.opacity(0.4), radius: 8, y: 2)
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.15), color.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                            )
                            .frame(width: 44.0, height: 44)
                    }

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isSelected ? .white : color)
                        #if !SKIP
                        .symbolEffect(.bounce, value: isSelected)
                        #endif
                }

                Text(title)
                    .font(.DesignSystem.captionSmall)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? color : .DesignSystem.textSecondary)
            }
            .frame(width: 72.0, height: 80)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(isSelected ? color.opacity(0.12) : Color.clear)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            #if !SKIP
                            .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                            #else
                            .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                            #endif
                    ),
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(
                        isSelected ? color.opacity(0.5) : Color.DesignSystem.glassBorder,
                        lineWidth: isSelected ? 2 : 1,
                    ),
            )
        }
        .buttonStyle(ProMotionButtonStyle())
        #if !SKIP
        .sensoryFeedback(.selection, trigger: isSelected)
        #endif
        .animation(ProMotionAnimation.bouncy, value: isSelected)
    }
}

// MARK: - Add Photo Label (Liquid Glass Enhanced)

struct AddPhotoLabel: View {
    @Environment(\.translationService) private var t

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.brandGreen.opacity(0.2),
                                Color.DesignSystem.brandBlue.opacity(0.15),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .frame(width: 48.0, height: 48)

                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
            }

            Text(t.t("create.add_photo"))
                .font(.DesignSystem.captionSmall)
                .fontWeight(.medium)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .frame(width: 120.0, height: 120)
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
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.brandGreen.opacity(0.3),
                                    Color.DesignSystem.brandBlue.opacity(0.2),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                            style: StrokeStyle(lineWidth: 2, dash: [8, 4]),
                        ),
                ),
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
}


#else
// MARK: - Android CreateListingView (Skip)

import SwiftUI

struct CreateListingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var title = ""
    @State private var description = ""
    @State private var pickupAddress = ""
    @State private var pickupTime = ""
    @State private var selectedCategoryId: Int = 1
    @State private var selectedType = "food"
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isCreated = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20.0) {
                    // Listing Type
                    VStack(alignment: .leading, spacing: 10.0) {
                        Text("What are you sharing?")
                            .font(.system(size: 18.0, weight: .semibold))
                            .foregroundStyle(Color.white)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10.0) {
                                ListingTypeChip(label: "Food", icon: "leaf.fill", type: "food", selected: $selectedType)
                                ListingTypeChip(label: "Item", icon: "cube.fill", type: "thing", selected: $selectedType)
                                ListingTypeChip(label: "Lend", icon: "arrow.triangle.2.circlepath", type: "borrow", selected: $selectedType)
                                ListingTypeChip(label: "Wanted", icon: "hand.raised.fill", type: "wanted", selected: $selectedType)
                            }
                        }
                    }
                    .padding(16.0)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12.0))

                    // Basic Info
                    VStack(alignment: .leading, spacing: 12.0) {
                        Text("Basic Info")
                            .font(.system(size: 18.0, weight: .semibold))
                            .foregroundStyle(Color.white)

                        TextField("Title", text: $title)
                            .textFieldStyle(.roundedBorder)

                        ZStack(alignment: .topLeading) {
                            if description.isEmpty {
                                Text("Describe what you're sharing...")
                                    .foregroundStyle(Color.gray)
                                    .padding(.horizontal, 8.0)
                                    .padding(.vertical, 12.0)
                            }
                            TextEditor(text: $description)
                                .frame(minHeight: 100.0)
                                .scrollContentBackground(.hidden)
                                .foregroundStyle(Color.white)
                        }
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8.0))
                    }
                    .padding(16.0)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12.0))

                    // Category
                    VStack(alignment: .leading, spacing: 12.0) {
                        Text("Category")
                            .font(.system(size: 18.0, weight: .semibold))
                            .foregroundStyle(Color.white)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8.0) {
                                CreateCategoryChip(label: "Produce", id: 1, selectedId: $selectedCategoryId)
                                CreateCategoryChip(label: "Dairy", id: 2, selectedId: $selectedCategoryId)
                                CreateCategoryChip(label: "Baked", id: 3, selectedId: $selectedCategoryId)
                                CreateCategoryChip(label: "Meals", id: 4, selectedId: $selectedCategoryId)
                                CreateCategoryChip(label: "Snacks", id: 5, selectedId: $selectedCategoryId)
                                CreateCategoryChip(label: "Drinks", id: 6, selectedId: $selectedCategoryId)
                            }
                        }
                    }
                    .padding(16.0)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12.0))

                    // Location & Pickup
                    VStack(alignment: .leading, spacing: 12.0) {
                        Text("Pickup Details")
                            .font(.system(size: 18.0, weight: .semibold))
                            .foregroundStyle(Color.white)

                        TextField("Pickup address", text: $pickupAddress)
                            .textFieldStyle(.roundedBorder)

                        TextField("Pickup time (e.g. Today 5-7pm)", text: $pickupTime)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(16.0)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12.0))

                    // Submit Button
                    Button(action: { Task { await createListing() } }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text("Share with Community")
                                .font(.system(size: 16.0, weight: .semibold))
                        }
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14.0)
                    }
                    .background(
                        canSubmit
                            ? Color(red: 0.2, green: 0.7, blue: 0.4)
                            : Color.gray.opacity(0.3)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12.0))
                    .disabled(!canSubmit || isLoading)
                }
                .padding(16.0)
            }
            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
            .navigationTitle("Create Listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var canSubmit: Bool {
        return !title.isEmpty && !pickupAddress.isEmpty
    }

    private func createListing() async {
        guard canSubmit else { return }
        isLoading = true

        let baseURL = AppEnvironment.supabaseURL ?? "https://api.foodshare.club"
        let apiKey = AppEnvironment.supabasePublishableKey ?? ""

        guard let url = URL(string: "\(baseURL)/functions/v1/api-v1-products") else {
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthenticationService.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: String] = [
            "name": title,
            "description": description,
            "post_type": selectedType,
            "category_id": "\(selectedCategoryId)",
            "pickup_address": pickupAddress,
            "pickup_time": pickupTime,
        ]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 300 {
                isCreated = true
                dismiss()
            } else {
                errorMessage = "Failed to create listing. Please try again."
                showError = true
            }
        } catch {
            errorMessage = "Network error. Please check your connection."
            showError = true
        }

        isLoading = false
    }
}

private struct ListingTypeChip: View {
    let label: String
    let icon: String
    let type: String
    @Binding var selected: String

    var body: some View {
        Button(action: { selected = type }) {
            VStack(spacing: 6.0) {
                Image(systemName: icon)
                    .font(.system(size: 20.0))
                Text(label)
                    .font(.system(size: 12.0, weight: .medium))
            }
            .frame(width: 72.0, height: 64.0)
            .foregroundStyle(selected == type ? Color.white : Color.white.opacity(0.6))
            .background(selected == type ? Color(red: 0.2, green: 0.7, blue: 0.4) : Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10.0))
            .border(selected == type ? Color(red: 0.2, green: 0.7, blue: 0.4) : Color.clear, width: selected == type ? 2.0 : 0.0)
        }
    }
}

private struct CreateCategoryChip: View {
    let label: String
    let id: Int
    @Binding var selectedId: Int

    var body: some View {
        Button(action: { selectedId = id }) {
            Text(label)
                .font(.system(size: 13.0, weight: .medium))
                .foregroundStyle(selectedId == id ? Color.white : Color.white.opacity(0.6))
                .padding(.horizontal, 14.0)
                .padding(.vertical, 8.0)
                .background(selectedId == id ? Color(red: 0.2, green: 0.7, blue: 0.4) : Color.white.opacity(0.08))
                .clipShape(Capsule())
        }
    }
}

// Stub for CreateListingViewModel parameter compatibility
@MainActor @Observable
final class CreateListingViewModel {
    var title = ""
    var description = ""
    var pickupAddress = ""
    var pickupTime = ""
    var postType = "food"
    var selectedCategoryId: Int = 1
    var isLoading = false
    var isEditMode = false
    var showError = false
    var error: String?
    var createdListing: FoodItem?
    var selectedImages: [Data] = []
    var canSubmit: Bool { return !title.isEmpty }
    var imageCountText: String { return "\(selectedImages.count)/3" }

    init() {}

    func addImage(_ data: Data) { selectedImages.append(data) }
    func removeImage(at index: Int) {
        guard index < selectedImages.count else { return }
        selectedImages.remove(at: index)
    }
    func dismissError() { showError = false; error = nil }
    func updateListing() async {}
    func createListing(userId: UUID, latitude: Double, longitude: Double) async {}
}

#endif
