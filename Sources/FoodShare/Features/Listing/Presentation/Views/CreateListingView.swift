//
//  CreateListingView.swift
//  Foodshare
//
//  Create listing view with Liquid Glass v26 design
//  Supports all listing types matching web app
//

import FoodShareDesignSystem
import FoodShareNetworking
import PhotosUI
import SwiftUI

#if DEBUG
    import Inject
#endif

struct CreateListingView: View {

    @Environment(\.dismiss) private var dismiss
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
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial),
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
                matching: .images,
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

        do {
            let result = try await ImageUploader.shared.uploadOptimized(
                data,
                bucket: "food-images",
                generateThumbnail: true,
                extractEXIF: true,
                enableAI: false,
                supabase: appState.authService.supabase,
            )

            viewModel.addImage(data)

            // Auto-fill location from EXIF GPS
            if let gps = result.metadata.exif?.gps, viewModel.pickupAddress.isEmpty {
                // TODO: Reverse geocode GPS to address
                viewModel.pickupAddress = "\(gps.latitude), \(gps.longitude)"
            }

            HapticManager.success()
        } catch {
            viewModel.error = error.localizedDescription
            viewModel.showError = true
            HapticManager.error()
        }
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
                        .frame(width: 32, height: 32)

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
                .fill(.ultraThinMaterial)
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
                        .frame(width: 32, height: 32)

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
                        .frame(width: 120, height: 120)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(.ultraThinMaterial),
                        )
                    }

                    // Selected images with animated transitions
                    ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, data in
                        if let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                                )
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        withAnimation(ProMotionAnimation.bouncy) {
                                            viewModel.removeImage(at: index)
                                        }
                                        HapticManager.medium()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundStyle(.white, .black.opacity(0.6))
                                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                                    }
                                    .padding(Spacing.xs)
                                    .buttonStyle(ProMotionButtonStyle())
                                }
                                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                                    removal: .scale(scale: 0.8).combined(with: .opacity),
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
                .fill(.ultraThinMaterial)
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
                        .frame(width: 32, height: 32)

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
                .fill(.ultraThinMaterial)
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
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isFocused)
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
                .background(.ultraThinMaterial),
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
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isFocused)
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
                        .frame(width: 32, height: 32)

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
                .fill(.ultraThinMaterial)
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
                        .frame(width: 32, height: 32)

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
                .fill(.ultraThinMaterial)
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
                        .frame(width: 56, height: 56)

                    Image(systemName: category.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isSelected ? .white : category.color)
                }

                Text(category.localizedDisplayName(using: t))
                    .font(.DesignSystem.captionSmall)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? category.color : .DesignSystem.textSecondary)
            }
            .frame(width: 80)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(isSelected ? category.color.opacity(0.1) : Color.clear)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .fill(.ultraThinMaterial),
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
                            .frame(width: 52, height: 52)
                            .blur(radius: 6)
                    }

                    if isSelected {
                        Circle()
                            .fill(color)
                            .frame(width: 44, height: 44)
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
                            .frame(width: 44, height: 44)
                    }

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isSelected ? .white : color)
                        .symbolEffect(.bounce, value: isSelected)
                }

                Text(title)
                    .font(.DesignSystem.captionSmall)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? color : .DesignSystem.textSecondary)
            }
            .frame(width: 72, height: 80)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(isSelected ? color.opacity(0.12) : Color.clear)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(.ultraThinMaterial),
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
        .sensoryFeedback(.selection, trigger: isSelected)
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
                    .frame(width: 48, height: 48)

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
        .frame(width: 120, height: 120)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(.ultraThinMaterial)
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

// MARK: - Camera Picker

#if !SKIP
private struct CameraImagePicker: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraImagePicker

        init(_ parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any],
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.capturedImage = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif
